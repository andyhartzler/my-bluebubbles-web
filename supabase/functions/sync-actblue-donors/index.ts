// supabase/functions/sync-actblue-donors/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { parse } from 'https://deno.land/std@0.168.0/encoding/csv.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const ACTBLUE_API_BASE = 'https://secure.actblue.com/api/v1'
const POLLING_DELAY_MS = 2000
const MAX_POLLS = 150

// ActBlue API limit: date range must be 6 months or less
const MAX_DAYS_PER_REQUEST = 180 // ~6 months

interface CSVGenerationResponse {
  id: string
  csv_type: string
  date_range_start: string
  date_range_end: string
  status: string
  download_url: string | null
  created_at: string
}

interface DateChunk {
  startDate: string
  endDate: string
}

/**
 * Splits a date range into chunks of MAX_DAYS_PER_REQUEST or less
 * This is required because ActBlue API only allows 6-month date ranges
 */
function splitDateRange(startDate: string, endDate: string): DateChunk[] {
  const chunks: DateChunk[] = []
  const start = new Date(startDate)
  const end = new Date(endDate)
  
  let currentStart = new Date(start)
  
  while (currentStart < end) {
    // Calculate chunk end date (MAX_DAYS_PER_REQUEST days from start, or end date, whichever is earlier)
    const chunkEnd = new Date(currentStart)
    chunkEnd.setDate(chunkEnd.getDate() + MAX_DAYS_PER_REQUEST - 1)
    
    const actualEnd = chunkEnd > end ? end : chunkEnd
    
    chunks.push({
      startDate: currentStart.toISOString().split('T')[0],
      endDate: actualEnd.toISOString().split('T')[0],
    })
    
    // Move to next chunk (day after current chunk end)
    currentStart = new Date(actualEnd)
    currentStart.setDate(currentStart.getDate() + 1)
  }
  
  console.log(`Split date range ${startDate} to ${endDate} into ${chunks.length} chunk(s):`)
  chunks.forEach((chunk, i) => {
    console.log(`  Chunk ${i + 1}: ${chunk.startDate} to ${chunk.endDate}`)
  })
  
  return chunks
}

/**
 * Calculate a sensible default start date (6 months ago)
 */
function getDefaultStartDate(): string {
  const date = new Date()
  date.setMonth(date.getMonth() - 6)
  date.setDate(1) // Start of that month
  return date.toISOString().split('T')[0]
}

async function requestCSVGeneration(
  clientUuid: string,
  clientSecret: string,
  csvType: string,
  startDate: string,
  endDate: string
): Promise<string> {
  const authString = `${clientUuid}:${clientSecret}`
  const base64Auth = btoa(authString)

  const url = `${ACTBLUE_API_BASE}/csvs`

  console.log(`Requesting CSV generation: ${csvType} from ${startDate} to ${endDate}`)

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${base64Auth}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      csv_type: csvType,
      date_range_start: startDate,
      date_range_end: endDate,
    }),
  })

  if (!response.ok) {
    const errorText = await response.text()
    throw new Error(`ActBlue CSV request failed (${response.status}): ${errorText}`)
  }

  const data: CSVGenerationResponse = await response.json()
  console.log(`CSV generation started with ID: ${data.id}`)
  
  return data.id
}

async function pollForDownloadUrl(
  clientUuid: string,
  clientSecret: string,
  csvId: string
): Promise<string> {
  const authString = `${clientUuid}:${clientSecret}`
  const base64Auth = btoa(authString)

  const url = `${ACTBLUE_API_BASE}/csvs/${csvId}`

  for (let attempt = 0; attempt < MAX_POLLS; attempt++) {
    console.log(`Polling for CSV completion (attempt ${attempt + 1}/${MAX_POLLS})...`)

    const response = await fetch(url, {
      headers: {
        'Authorization': `Basic ${base64Auth}`,
        'Content-Type': 'application/json',
      },
    })

    if (!response.ok) {
      throw new Error(`Failed to poll CSV status: ${response.status}`)
    }

    const data: CSVGenerationResponse = await response.json()

    if (data.download_url) {
      console.log('CSV is ready for download!')
      return data.download_url
    }

    console.log(`CSV status: ${data.status}, waiting...`)
    await new Promise(resolve => setTimeout(resolve, POLLING_DELAY_MS))
  }

  throw new Error('CSV generation timed out')
}

async function downloadAndParseCSV(downloadUrl: string): Promise<{ headers: string[], records: any[] }> {
  console.log('Downloading CSV...')
  
  const response = await fetch(downloadUrl)
  
  if (!response.ok) {
    throw new Error(`Failed to download CSV: ${response.status}`)
  }

  const csvText = await response.text()
  console.log(`Downloaded CSV (${csvText.length} characters)`)

  // Handle empty CSV (just headers or completely empty)
  if (!csvText.trim()) {
    console.log('CSV is empty')
    return { headers: [], records: [] }
  }

  // Parse CSV - keep header row separate
  const allRows = parse(csvText, {
    skipFirstRow: false,
  })

  if (allRows.length === 0) {
    return { headers: [], records: [] }
  }

  const headers = allRows[0] as string[]
  const records = allRows.slice(1)

  console.log(`CSV Headers: ${headers.join(', ')}`)
  console.log(`Parsed ${records.length} contribution records`)

  // Log first row for debugging
  if (records.length > 0) {
    console.log('First record sample:', JSON.stringify(records[0].slice(0, 10)))
  }

  return { headers, records }
}

/**
 * Fetch and parse CSV for a single date chunk
 */
async function fetchChunkData(
  clientUuid: string,
  clientSecret: string,
  csvType: string,
  chunk: DateChunk
): Promise<{ headers: string[], records: any[] }> {
  console.log(`\n=== Processing chunk: ${chunk.startDate} to ${chunk.endDate} ===`)
  
  // Step 1: Request CSV generation
  const csvId = await requestCSVGeneration(
    clientUuid,
    clientSecret,
    csvType,
    chunk.startDate,
    chunk.endDate
  )

  // Step 2: Poll for download URL
  const downloadUrl = await pollForDownloadUrl(
    clientUuid,
    clientSecret,
    csvId
  )

  // Step 3: Download and parse CSV
  return await downloadAndParseCSV(downloadUrl)
}

function parseContributionRow(row: any[], headers: string[]): any {
  // Create a map of header name to value
  const rowData: Record<string, any> = {}
  headers.forEach((header, index) => {
    rowData[header] = row[index]
  })

  return {
    receiptId: rowData['Receipt ID'],
    lineitemId: rowData['Lineitem ID'],
    date: rowData['Date'],
    amount: parseFloat(rowData['Amount']) || 0,
    recurringTotalMonths: rowData['Recurring Total Months'],
    recurrenceNumber: rowData['Recurrence Number'],
    recipient: rowData['Recipient'],
    fundraisingPage: rowData['Fundraising Page'],
    donorFirstName: rowData['Donor First Name'],
    donorLastName: rowData['Donor Last Name'],
    donorAddr1: rowData['Donor Addr1'],
    donorAddr2: rowData['Donor Addr2'],
    donorCity: rowData['Donor City'],
    donorState: rowData['Donor State'],
    donorZip: rowData['Donor ZIP'],
    donorCountry: rowData['Donor Country'],
    donorOccupation: rowData['Donor Occupation'],
    donorEmployer: rowData['Donor Employer'],
    donorEmail: rowData['Donor Email'],
    donorPhone: rowData['Donor Phone'],
    donorId: rowData['Donor ID'],
    paymentId: rowData['Payment ID'],
    paymentDate: rowData['Payment Date'],
    referenceCode: rowData['Reference Code'],
    referenceCode2: rowData['Reference Code 2'],
  }
}

async function processDonor(supabase: any, contribution: any): Promise<string | null> {
  try {
    const donorName = `${contribution.donorFirstName || ''} ${contribution.donorLastName || ''}`.trim()
    const donorEmail = contribution.donorEmail?.toLowerCase().trim() || null

    if (!donorName && !donorEmail) {
      return null
    }

    // Format phone to E.164
    let phoneE164 = null
    if (contribution.donorPhone) {
      const cleaned = contribution.donorPhone.replace(/\D/g, '')
      if (cleaned.length === 10) {
        phoneE164 = `+1${cleaned}`
      } else if (cleaned.length === 11 && cleaned.startsWith('1')) {
        phoneE164 = `+${cleaned}`
      }
    }

    // Use email as unique identifier if available, otherwise use donorId
    const upsertData: any = {
      name: donorName,
      email: donorEmail,
      phone: contribution.donorPhone,
      phone_e164: phoneE164,
      address: contribution.donorAddr1,
      city: contribution.donorCity,
      state: contribution.donorState,
      zip_code: contribution.donorZip,
      country: contribution.donorCountry || 'US',
      employer: contribution.donorEmployer,
      occupation: contribution.donorOccupation,
      actblue_raw_data: contribution,
    }

    // Add actblue_entity_id if available
    if (contribution.donorId) {
      upsertData.actblue_entity_id = contribution.donorId
    }

    const { data: donor, error } = await supabase
      .from('donors')
      .upsert(upsertData, {
        onConflict: donorEmail ? 'email' : 'actblue_entity_id',
        ignoreDuplicates: false,
      })
      .select('id')
      .single()

    if (error) {
      console.error('Donor upsert error:', error.message)
      return null
    }

    return donor?.id || null
  } catch (err) {
    console.error('Error processing donor:', err.message)
    return null
  }
}

async function processDonation(supabase: any, contribution: any, donorId: string): Promise<boolean> {
  try {
    // Use lineitemId as unique identifier (more specific than receiptId)
    const contributionId = contribution.lineitemId || contribution.receiptId
    
    if (!contributionId) {
      return false
    }

    const { error } = await supabase
      .from('donations')
      .upsert({
        donor_id: donorId,
        actblue_contribution_id: contributionId,
        actblue_order_number: contribution.receiptId,
        amount: contribution.amount,
        donation_date: contribution.date || contribution.paymentDate,
        status: 'completed',
        recurring: parseInt(contribution.recurringTotalMonths) > 0,
        designation: contribution.recipient,
        campaign: contribution.fundraisingPage,
        payment_method: 'actblue',
        actblue_raw_data: contribution,
      }, {
        onConflict: 'actblue_contribution_id',
        ignoreDuplicates: false,
      })

    if (error) {
      console.error('Donation upsert error:', error.message)
      return false
    }

    return true
  } catch (err) {
    console.error('Error processing donation:', err.message)
    return false
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('=== ActBlue Sync Started ===')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const ACTBLUE_CLIENT_UUID = Deno.env.get('ACTBLUE_CLIENT_UUID') ?? ''
    const ACTBLUE_CLIENT_SECRET = Deno.env.get('ACTBLUE_CLIENT_SECRET') ?? ''

    if (!ACTBLUE_CLIENT_UUID || !ACTBLUE_CLIENT_SECRET) {
      throw new Error('ActBlue credentials not configured')
    }

    // Parse request
    const requestBody = req.method === 'POST' ? await req.json().catch(() => ({})) : {}
    const { startDate, endDate } = requestBody

    // Default: 6 months ago to today (ensures we stay within the 6-month limit by default)
    const today = new Date().toISOString().split('T')[0]
    const syncStartDate = startDate || getDefaultStartDate()
    const syncEndDate = endDate || today

    console.log(`Syncing ActBlue donations from ${syncStartDate} to ${syncEndDate}`)

    // Split the date range into chunks of 6 months or less
    const dateChunks = splitDateRange(syncStartDate, syncEndDate)

    // Process each chunk and collect all records
    let allRecords: any[] = []
    let headers: string[] = []

    for (const chunk of dateChunks) {
      try {
        const chunkData = await fetchChunkData(
          ACTBLUE_CLIENT_UUID,
          ACTBLUE_CLIENT_SECRET,
          'paid_contributions',
          chunk
        )
        
        // Use headers from first chunk with data
        if (chunkData.headers.length > 0 && headers.length === 0) {
          headers = chunkData.headers
        }
        
        allRecords = allRecords.concat(chunkData.records)
        console.log(`Chunk complete: ${chunkData.records.length} records. Total so far: ${allRecords.length}`)
      } catch (chunkError) {
        console.error(`Error processing chunk ${chunk.startDate} to ${chunk.endDate}:`, chunkError.message)
        // Continue with other chunks even if one fails
      }
    }

    console.log(`\n=== All chunks processed. Total records: ${allRecords.length} ===\n`)

    if (allRecords.length === 0) {
      console.log('No contribution records found in date range')
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No contributions found in date range',
          stats: {
            contributionsFetched: 0,
            processedCount: 0,
            errorCount: 0,
            skippedCount: 0,
          },
          dateRange: {
            startDate: syncStartDate,
            endDate: syncEndDate,
          },
          chunksProcessed: dateChunks.length,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    console.log(`Processing ${allRecords.length} contributions...`)

    let processedCount = 0
    let errorCount = 0
    let skippedCount = 0

    // Process each contribution
    for (let i = 0; i < allRecords.length; i++) {
      // Only log for first record to debug
      const shouldLog = i === 0

      try {
        const contribution = parseContributionRow(allRecords[i], headers)

        // More lenient validation - only need receipt or lineitem ID
        if (!contribution.receiptId && !contribution.lineitemId) {
          if (shouldLog) console.log('Skipping: No receipt or lineitem ID')
          skippedCount++
          continue
        }

        // Process donor
        const donorId = await processDonor(supabase, contribution)
        if (!donorId) {
          if (shouldLog) console.log('Skipping: Could not process donor')
          errorCount++
          continue
        }

        // Process donation
        const success = await processDonation(supabase, contribution, donorId)
        if (!success) {
          if (shouldLog) console.log('Skipping: Could not process donation')
          errorCount++
          continue
        }

        processedCount++

        if (i % 100 === 0 && i > 0) {
          console.log(`Progress: ${i}/${allRecords.length} (${Math.round(i/allRecords.length*100)}%)`)
        }
      } catch (err) {
        console.error('Error processing row:', err.message)
        errorCount++
      }
    }

    console.log('=== ActBlue Sync Complete ===')
    console.log(`Processed: ${processedCount}, Errors: ${errorCount}, Skipped: ${skippedCount}`)

    // Get summary stats
    const { count: donorCount } = await supabase
      .from('donors')
      .select('*', { count: 'exact', head: true })

    const { count: donationCount, data: sumData } = await supabase
      .from('donations')
      .select('amount', { count: 'exact' })

    const totalAmount = sumData?.reduce((sum: number, d: any) => sum + parseFloat(d.amount || 0), 0) || 0

    return new Response(
      JSON.stringify({
        success: true,
        message: `ActBlue sync complete: ${processedCount} processed, ${errorCount} errors, ${skippedCount} skipped`,
        stats: {
          contributionsFetched: allRecords.length,
          processedCount,
          errorCount,
          skippedCount,
          totalDonors: donorCount || 0,
          totalDonations: donationCount || 0,
          totalAmount: Math.round(totalAmount * 100) / 100,
        },
        dateRange: {
          startDate: syncStartDate,
          endDate: syncEndDate,
        },
        chunksProcessed: dateChunks.length,
        csvHeaders: headers,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message,
        stack: error.stack,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})