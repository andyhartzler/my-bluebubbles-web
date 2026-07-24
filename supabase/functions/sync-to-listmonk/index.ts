import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const LISTMONK_URL = Deno.env.get('LISTMONK_URL')!
const LISTMONK_USERNAME = Deno.env.get('LISTMONK_USERNAME')!
const LISTMONK_PASSWORD = Deno.env.get('LISTMONK_PASSWORD')!

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

// Listmonk List IDs (create these manually in Listmonk first)
const LISTS = {
  subscribers: 1,  // Main newsletter list
  donors: 2,       // Donor list
  members: 3,      // Members list
  attendees: 4,    // Event attendees list
}

interface SyncRecord {
  id: string
  table_name: string
  record_id: string
  action: string
  data: any
}

async function callListmonkAPI(endpoint: string, method: string, body?: any) {
  const auth = btoa(`${LISTMONK_USERNAME}:${LISTMONK_PASSWORD}`)
  
  const response = await fetch(`${LISTMONK_URL}/api/${endpoint}`, {
    method,
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  })
  
  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Listmonk API error: ${error}`)
  }
  
  return response.json()
}

async function syncSubscriber(record: any, action: string, tableName: string) {
  const email = record.email
  const name = record.name
  
  if (!email) {
    throw new Error('Email is required')
  }
  
  // Determine which list to add to
  let listIds = [LISTS[tableName as keyof typeof LISTS]]
  
  // Add to subscribers list if subscribed
  if (tableName === 'subscribers' && record.subscription_status === 'subscribed') {
    listIds.push(LISTS.subscribers)
  }
  
  if (action === 'DELETE') {
    // Find subscriber in Listmonk
    const searchResult = await callListmonkAPI(
      `subscribers?query=subscribers.email='${email}'`,
      'GET'
    )
    
    if (searchResult.data.results.length > 0) {
      const subscriberId = searchResult.data.results[0].id
      // Unsubscribe instead of delete (preserve history)
      await callListmonkAPI(
        `subscribers/${subscriberId}`,
        'PUT',
        { status: 'blocklisted' }
      )
    }
    return
  }
  
  // Prepare subscriber data
  const subscriberData = {
    email,
    name,
    status: 'enabled',
    lists: listIds,
    attribs: {
      phone: record.phone || '',
      city: record.city || '',
      state: record.state || '',
      zip_code: record.zip_code || '',
      county: record.county || '',
      congressional_district: record.congressional_district || '',
      source: tableName,
      moyd_id: record.id,
    }
  }
  
  // Check if subscriber exists
  const searchResult = await callListmonkAPI(
    `subscribers?query=subscribers.email='${email}'`,
    'GET'
  )
  
  if (searchResult.data.results.length > 0) {
    // Update existing
    const subscriberId = searchResult.data.results[0].id
    await callListmonkAPI(
      `subscribers/${subscriberId}`,
      'PUT',
      subscriberData
    )
  } else {
    // Create new
    await callListmonkAPI('subscribers', 'POST', subscriberData)
  }
}

async function processSyncQueue() {
  // Fetch unsynced records
  const { data: records, error } = await supabase
    .from('listmonk_sync_queue')
    .select('*')
    .eq('synced', false)
    .order('created_at', { ascending: true })
    .limit(100)
  
  if (error) {
    console.error('Error fetching sync queue:', error)
    return
  }
  
  console.log(`Processing ${records?.length || 0} records`)
  
  for (const record of records || []) {
    try {
      await syncSubscriber(record.data, record.action, record.table_name)
      
      // Mark as synced
      await supabase
        .from('listmonk_sync_queue')
        .update({ 
          synced: true, 
          synced_at: new Date().toISOString() 
        })
        .eq('id', record.id)
      
      console.log(`✓ Synced ${record.table_name} record ${record.record_id}`)
    } catch (error) {
      console.error(`✗ Failed to sync record ${record.id}:`, error)
      
      // Log error
      await supabase
        .from('listmonk_sync_queue')
        .update({ 
          error: error.message 
        })
        .eq('id', record.id)
    }
  }
}

serve(async (req) => {
  try {
    await processSyncQueue()
    
    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})