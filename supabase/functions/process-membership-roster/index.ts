// supabase/functions/process-membership-roster/index.ts
// ============================================================================
// ROBUST DOCUMENT PROCESSING FOR MEMBERSHIP/OFFICER ROSTERS
// ============================================================================
// Supports: Excel, CSV, Word, PDF (with Claude Vision), Images
// Uses: Claude API for intelligent PDF/image table extraction
// Directly inserts/updates members table with officer fields
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as XLSX from "https://esm.sh/xlsx@0.18.5";
import mammoth from "https://esm.sh/mammoth@1.6.0";
import Anthropic from "https://esm.sh/@anthropic-ai/sdk@0.24.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const anthropic = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ============================================================================
// COLUMN MAPPING - Maps various header names to standard field names
// ============================================================================
// IMPORTANT: Order matters! More specific patterns should come first.
const COLUMN_MAPPINGS: Record<string, string[]> = {
  email: [
    'e-mail', 'email', 'email address', 'emailaddress', 'member email',
    'e-mail (no school or work emails)', 'email (no school or work emails)',
    'personal email', 'email_address', 'member_email', 'contact email'
  ],
  firstName: [
    'first name', 'firstname', 'first', 'fname', 'given name', 'givenname',
    'first_name', 'member first name'
  ],
  lastName: [
    'last name', 'lastname', 'last', 'lname', 'surname', 'family name',
    'familyname', 'last_name', 'member last name'
  ],
  name: [
    'full name', 'fullname', 'member name', 'student name', 
    'full_name', 'member_name', 'officer name', 'name'
  ],
  phone: [
    'phone', 'phone number', 'phonenumber', 'cell', 'mobile', 'cell phone',
    'telephone', 'phone_number', 'member phone', 'contact phone', 'tel'
  ],
  dateOfBirth: [
    'date of birth', 'dob', 'birthdate', 'birth date', 'birthday',
    'date_of_birth', 'birth_date', 'dateofbirth', 'born'
  ],
  address: [
    'street address', 'home address', 'mailing address',
    'street_address', 'home_address', 'street', 'address', 'addr'
  ],
  city: ['city', 'town', 'municipality'],
  state: ['state', 'st', 'province'],
  zipCode: [
    'zip', 'zip code', 'zipcode', 'postal code', 'postalcode', 
    'zip_code', 'postal_code'
  ],
  position: [
    'position', 'title', 'role', 'officer position', 'chapter position',
    'officer_position', 'chapter_position', 'office', 'officer title'
  ],
  dateElected: [
    'date elected', 'date of election', 'election date', 'elected',
    'date_elected', 'election_date', 'dateelected', 'elected on'
  ],
  termExpiration: [
    'term expiration', 'term expires', 'expiration date', 'term_expiration',
    'date of term expiration', 'expiration', 'term end', 'term_end',
    'term ends', 'expires'
  ],
};

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

/**
 * FIXED: Find column index for a field name
 * Uses proper priority matching to avoid false positives like
 * "email address".includes("address") matching the Address column
 */
function findColumn(headers: string[], fieldName: string): number {
  const possibleNames = COLUMN_MAPPINGS[fieldName] || [fieldName];
  const normalizedHeaders = headers.map(h => 
    String(h || '').toLowerCase().trim().replace(/[_\-]/g, ' ')
  );
  
  // PRIORITY 1: Exact matches only
  for (const name of possibleNames) {
    const normalizedName = name.toLowerCase().trim().replace(/[_\-]/g, ' ');
    const exactIndex = normalizedHeaders.findIndex(h => h === normalizedName);
    if (exactIndex !== -1) {
      return exactIndex;
    }
  }
  
  // PRIORITY 2: Header CONTAINS the search term (NOT the reverse!)
  // This finds "E-Mail Address" when searching for "email"
  for (const name of possibleNames) {
    const normalizedName = name.toLowerCase().trim().replace(/[_\-]/g, ' ');
    const containsIndex = normalizedHeaders.findIndex(h => h.includes(normalizedName));
    if (containsIndex !== -1) {
      return containsIndex;
    }
  }
  
  // PRIORITY 3: Search term contains header (only for substantial headers)
  // This handles searching for "email address" when header is just "email"
  // But guards against false positives
  for (const name of possibleNames) {
    const normalizedName = name.toLowerCase().trim().replace(/[_\-]/g, ' ');
    const reverseIndex = normalizedHeaders.findIndex(h => {
      // Only match if header is substantial (at least 3 chars)
      // and is a significant portion of the search term (at least 50%)
      return h.length >= 3 && 
             normalizedName.includes(h) && 
             h.length >= normalizedName.length * 0.5;
    });
    if (reverseIndex !== -1) {
      return reverseIndex;
    }
  }
  
  return -1;
}

function parseDate(value: any): string | null {
  if (!value) return null;
  
  if (value instanceof Date) {
    return value.toISOString().split('T')[0];
  }
  
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    
    // ISO format YYYY-MM-DD
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
      return trimmed;
    }
    
    // MM/DD/YYYY
    const mdyMatch = trimmed.match(/^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/);
    if (mdyMatch) {
      let [_, month, day, year] = mdyMatch;
      let y = parseInt(year);
      if (y < 100) y = y > 50 ? 1900 + y : 2000 + y;
      return `${y}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
    }
    
    // MM-DD-YYYY
    const mdyDashMatch = trimmed.match(/^(\d{1,2})-(\d{1,2})-(\d{2,4})$/);
    if (mdyDashMatch) {
      let [_, month, day, year] = mdyDashMatch;
      let y = parseInt(year);
      if (y < 100) y = y > 50 ? 1900 + y : 2000 + y;
      return `${y}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
    }
    
    try {
      const parsed = new Date(trimmed);
      if (!isNaN(parsed.getTime())) {
        return parsed.toISOString().split('T')[0];
      }
    } catch {}
    
    return null;
  }
  
  // Excel serial date number
  if (typeof value === 'number') {
    const excelEpoch = new Date(1899, 11, 30);
    const date = new Date(excelEpoch.getTime() + value * 24 * 60 * 60 * 1000);
    return date.toISOString().split('T')[0];
  }
  
  return null;
}

function cleanPhone(phone: any): string | null {
  if (!phone) return null;
  const cleaned = String(phone).replace(/\D/g, '');
  if (cleaned.length === 10) return cleaned;
  if (cleaned.length === 11 && cleaned.startsWith('1')) return cleaned.substring(1);
  if (cleaned.length > 0) return cleaned;
  return null;
}

function formatPhoneE164(phone: string | null): string | null {
  if (!phone) return null;
  const cleaned = phone.replace(/\D/g, '');
  if (cleaned.length === 10) return `+1${cleaned}`;
  if (cleaned.length === 11 && cleaned.startsWith('1')) return `+${cleaned}`;
  return null;
}

function cleanEmail(email: any): string | null {
  if (!email) return null;
  const cleaned = String(email).trim().toLowerCase();
  if (cleaned.includes('@') && cleaned.includes('.')) {
    return cleaned;
  }
  return null;
}

// ============================================================================
// FILE PARSING FUNCTIONS
// ============================================================================

function parseCSV(content: string): string[][] {
  const lines = content.split(/\r?\n/);
  const result: string[][] = [];
  
  for (const line of lines) {
    if (!line.trim()) continue;
    
    const row: string[] = [];
    let cell = '';
    let inQuotes = false;
    
    for (let i = 0; i < line.length; i++) {
      const char = line[i];
      const nextChar = line[i + 1];
      
      if (char === '"') {
        if (inQuotes && nextChar === '"') {
          cell += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char === ',' && !inQuotes) {
        row.push(cell.trim());
        cell = '';
      } else {
        cell += char;
      }
    }
    row.push(cell.trim());
    result.push(row);
  }
  
  return result;
}

function parseExcel(arrayBuffer: ArrayBuffer): { headers: string[], rows: any[][] } {
  const workbook = XLSX.read(arrayBuffer, { type: 'array', cellDates: true });
  
  // Skip instruction sheets
  const skipSheets = ['instructions', 'readme', 'info', 'about', 'help'];
  let targetSheet: string | null = null;
  
  for (const sheetName of workbook.SheetNames) {
    if (!skipSheets.includes(sheetName.toLowerCase())) {
      targetSheet = sheetName;
      break;
    }
  }
  
  if (!targetSheet && workbook.SheetNames.length > 0) {
    targetSheet = workbook.SheetNames[workbook.SheetNames.length - 1];
  }
  
  if (!targetSheet) {
    throw new Error('No valid data sheet found in Excel file');
  }
  
  console.log(`Using sheet: ${targetSheet}`);
  
  const sheet = workbook.Sheets[targetSheet];
  const rawData = XLSX.utils.sheet_to_json(sheet, { header: 1, raw: false, dateNF: 'yyyy-mm-dd' }) as any[][];
  
  // Find header row (first row with 3+ non-empty cells that look like text)
  let headerRowIndex = 0;
  for (let i = 0; i < Math.min(10, rawData.length); i++) {
    const row = rawData[i];
    if (!row) continue;
    
    const nonEmptyCells = row.filter(cell => cell !== null && cell !== undefined && String(cell).trim() !== '');
    if (nonEmptyCells.length >= 3) {
      const looksLikeHeaders = nonEmptyCells.every(cell => 
        isNaN(Number(cell)) || String(cell).length > 10
      );
      if (looksLikeHeaders) {
        headerRowIndex = i;
        break;
      }
    }
  }
  
  const headers = (rawData[headerRowIndex] || []).map(h => String(h || ''));
  const rows = rawData.slice(headerRowIndex + 1).filter(row => 
    row && row.some(cell => cell !== null && cell !== undefined && String(cell).trim() !== '')
  );
  
  console.log(`Found headers at row ${headerRowIndex + 1}:`, JSON.stringify(headers));
  
  return { headers, rows };
}

async function parseWordDocument(arrayBuffer: ArrayBuffer): Promise<{ headers: string[], rows: any[][] }> {
  try {
    const result = await mammoth.extractRawText({ arrayBuffer });
    const text = result.value;
    
    const lines = text.split('\n').filter(line => line.trim());
    
    if (lines.length < 2) {
      throw new Error('No tabular data found in Word document');
    }
    
    // Detect delimiter
    const firstLine = lines[0];
    let delimiter: string | RegExp = '\t';
    if (!firstLine.includes('\t')) {
      if (firstLine.includes('|')) {
        delimiter = '|';
      } else if (firstLine.includes('  ')) {
        delimiter = /\s{2,}/;
      }
    }
    
    const rows = lines.map(line => {
      if (typeof delimiter === 'string') {
        return line.split(delimiter).map(cell => cell.trim());
      } else {
        return line.split(delimiter).map(cell => cell.trim());
      }
    });
    
    const headers = rows[0];
    const dataRows = rows.slice(1);
    
    return { headers, rows: dataRows };
  } catch (error) {
    console.error('Error parsing Word document:', error);
    throw new Error(`Failed to parse Word document: ${error.message}`);
  }
}

// ============================================================================
// CLAUDE-POWERED PDF/IMAGE EXTRACTION
// ============================================================================

async function extractTableWithClaude(
  base64Data: string, 
  mediaType: string,
  isOfficersList: boolean
): Promise<{ headers: string[], rows: any[][] }> {
  
  const fieldDescription = isOfficersList 
    ? "first name, last name, address, city, state, zip code, date of birth, email, phone, position/title, date elected, term expiration date"
    : "first name, last name, city, state, zip code, date of birth, email, phone";

  const prompt = `You are extracting member/officer data from a document. Look at this document and extract ALL the tabular data you can find.

The document should contain a roster with these potential fields: ${fieldDescription}

IMPORTANT INSTRUCTIONS:
1. Find ANY table or list of people in the document
2. Extract every row of data you find
3. If you see separate First Name and Last Name columns, keep them separate
4. Dates should be in YYYY-MM-DD format if possible
5. Phone numbers should be digits only (no formatting)
6. Emails should be lowercase

Return your response as a valid JSON object with this exact structure:
{
  "headers": ["First Name", "Last Name", "Email", "Phone", ...],
  "rows": [
    ["John", "Doe", "john@email.com", "5551234567", ...],
    ["Jane", "Smith", "jane@email.com", "5559876543", ...]
  ],
  "notes": "Any issues or observations about the data"
}

If you cannot find any tabular data, return:
{
  "headers": [],
  "rows": [],
  "notes": "Explanation of what you found instead"
}

Return ONLY the JSON object, no other text.`;

  try {
    const response = await anthropic.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: mediaType as "image/jpeg" | "image/png" | "image/gif" | "image/webp",
                data: base64Data,
              },
            },
            {
              type: "text",
              text: prompt,
            },
          ],
        },
      ],
    });

    const textContent = response.content.find(block => block.type === 'text');
    if (!textContent || textContent.type !== 'text') {
      throw new Error('No text response from Claude');
    }

    const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('Could not parse JSON from Claude response');
    }

    const parsed = JSON.parse(jsonMatch[0]);
    
    if (!parsed.headers || !parsed.rows) {
      throw new Error('Invalid response structure from Claude');
    }

    console.log(`Claude extracted ${parsed.rows.length} rows with ${parsed.headers.length} columns`);
    if (parsed.notes) {
      console.log(`Claude notes: ${parsed.notes}`);
    }

    return {
      headers: parsed.headers,
      rows: parsed.rows,
    };

  } catch (error) {
    console.error('Claude extraction error:', error);
    throw new Error(`Failed to extract data with Claude: ${error.message}`);
  }
}

async function processPDFWithClaude(
  arrayBuffer: ArrayBuffer,
  isOfficersList: boolean
): Promise<{ headers: string[], rows: any[][] }> {
  const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
  
  const fieldDescription = isOfficersList 
    ? "first name, last name, address, city, state, zip code, date of birth, email, phone, position/title, date elected, term expiration date"
    : "first name, last name, city, state, zip code, date of birth, email, phone";

  const prompt = `You are extracting member/officer data from a PDF document. Find and extract ALL tabular data containing people's information.

Expected fields: ${fieldDescription}

INSTRUCTIONS:
1. Find ANY table or list of people in the document
2. Extract every row of data
3. Keep First Name and Last Name separate if they're in separate columns
4. Format dates as YYYY-MM-DD
5. Phone numbers as digits only
6. Emails lowercase
7. Skip any instruction text or headers that aren't data

Return a valid JSON object:
{
  "headers": ["First Name", "Last Name", "Email", "Phone", ...],
  "rows": [
    ["John", "Doe", "john@email.com", "5551234567", ...],
    ...
  ],
  "notes": "Any issues or observations"
}

If no tabular data found:
{
  "headers": [],
  "rows": [],
  "notes": "What was found instead"
}

Return ONLY the JSON object.`;

  try {
    const response = await anthropic.messages.create({
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "document",
              source: {
                type: "base64",
                media_type: "application/pdf",
                data: base64,
              },
            },
            {
              type: "text",
              text: prompt,
            },
          ],
        },
      ],
    });

    const textContent = response.content.find(block => block.type === 'text');
    if (!textContent || textContent.type !== 'text') {
      throw new Error('No text response from Claude');
    }

    const jsonMatch = textContent.text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('Could not parse JSON from Claude response');
    }

    const parsed = JSON.parse(jsonMatch[0]);
    
    if (!parsed.headers || !parsed.rows) {
      throw new Error('Invalid response structure');
    }

    console.log(`PDF extracted ${parsed.rows.length} rows with ${parsed.headers.length} columns`);
    if (parsed.notes) {
      console.log(`Notes: ${parsed.notes}`);
    }

    return { headers: parsed.headers, rows: parsed.rows };
  } catch (error) {
    console.error('PDF processing error:', error);
    throw new Error(`Failed to process PDF: ${error.message}`);
  }
}

// ============================================================================
// MAIN FILE PARSER - Detects type and routes appropriately
// ============================================================================

async function parseFile(
  fileData: Blob, 
  fileName: string,
  isOfficersList: boolean
): Promise<{ headers: string[], rows: any[][] }> {
  const lowerFileName = fileName.toLowerCase();
  const arrayBuffer = await fileData.arrayBuffer();
  
  // CSV
  if (lowerFileName.endsWith('.csv')) {
    const text = await fileData.text();
    const rows = parseCSV(text);
    if (rows.length < 2) {
      throw new Error('CSV file must contain at least a header row and one data row');
    }
    return { headers: rows[0], rows: rows.slice(1) };
  }
  
  // Excel
  if (lowerFileName.endsWith('.xlsx') || lowerFileName.endsWith('.xls')) {
    return parseExcel(arrayBuffer);
  }
  
  // Word - use mammoth only, Claude document API only accepts PDFs
  if (lowerFileName.endsWith('.docx') || lowerFileName.endsWith('.doc')) {
    console.log('Processing Word document with mammoth');
    const result = await parseWordDocument(arrayBuffer);
    if (result.headers.length >= 2 && result.rows.length >= 1) {
      return result;
    }
    throw new Error('Could not extract tabular data from Word document. Please use Excel or CSV format.');
  }
  
  // PDF - Use Claude document API
  if (lowerFileName.endsWith('.pdf')) {
    console.log('Processing PDF with Claude Vision');
    return processPDFWithClaude(arrayBuffer, isOfficersList);
  }
  
  // Images - Use Claude vision
  if (lowerFileName.match(/\.(jpg|jpeg|png|gif|webp)$/i)) {
    console.log('Processing image with Claude Vision');
    const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
    const ext = lowerFileName.split('.').pop()!;
    const mediaType = ext === 'jpg' ? 'image/jpeg' : `image/${ext}`;
    return extractTableWithClaude(base64, mediaType, isOfficersList);
  }
  
  // Try to detect by magic bytes
  const bytes = new Uint8Array(arrayBuffer.slice(0, 4));
  
  // Excel XLSX (ZIP format)
  if (bytes[0] === 0x50 && bytes[1] === 0x4B) {
    return parseExcel(arrayBuffer);
  }
  
  // PDF
  if (bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46) {
    return processPDFWithClaude(arrayBuffer, isOfficersList);
  }
  
  // Try as CSV fallback
  try {
    const text = await fileData.text();
    const rows = parseCSV(text);
    if (rows.length >= 2 && rows[0].length >= 2) {
      return { headers: rows[0], rows: rows.slice(1) };
    }
  } catch {}
  
  throw new Error(`Unsupported file type: ${fileName}`);
}

// ============================================================================
// MEMBER EXTRACTION
// ============================================================================

interface ExtractedMember {
  name: string;
  email: string;
  phone?: string | null;
  dateOfBirth?: string | null;
  address?: string | null;
  city?: string | null;
  state?: string | null;
  zipCode?: string | null;
  position?: string | null;
  dateElected?: string | null;
  termExpiration?: string | null;
}

function extractMembers(
  headers: string[], 
  rows: any[][], 
  isOfficersList: boolean
): { members: ExtractedMember[], errors: string[] } {
  const members: ExtractedMember[] = [];
  const errors: string[] = [];
  
  // Build column mapping with detailed logging
  const cols: Record<string, number> = {};
  const fieldOrder = ['email', 'firstName', 'lastName', 'name', 'phone', 'dateOfBirth', 
                      'address', 'city', 'state', 'zipCode', 'position', 'dateElected', 'termExpiration'];
  
  console.log('=== COLUMN MAPPING DEBUG ===');
  console.log('Headers:', JSON.stringify(headers));
  
  for (const field of fieldOrder) {
    cols[field] = findColumn(headers, field);
    if (cols[field] !== -1) {
      console.log(`  ${field} -> column ${cols[field]} ("${headers[cols[field]]}")`);
    }
  }
  
  console.log('Final column mapping:', JSON.stringify(cols));
  
  const hasName = cols.name !== -1 || (cols.firstName !== -1 || cols.lastName !== -1);
  const hasEmail = cols.email !== -1;
  
  if (!hasName) {
    errors.push('Could not find a name column (looked for: First Name, Last Name, Full Name, Name)');
  }
  if (!hasEmail) {
    errors.push('Could not find an email column (looked for: Email, E-Mail, Email Address)');
  }
  
  if (!hasName || !hasEmail) {
    return { members, errors };
  }
  
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    const rowNum = i + 2; // Excel row number (1-indexed + header row)
    
    try {
      // Get name
      let name: string | null = null;
      if (cols.firstName !== -1 || cols.lastName !== -1) {
        const first = cols.firstName !== -1 ? String(row[cols.firstName] || '').trim() : '';
        const last = cols.lastName !== -1 ? String(row[cols.lastName] || '').trim() : '';
        name = `${first} ${last}`.trim();
      } else if (cols.name !== -1) {
        name = String(row[cols.name] || '').trim();
      }
      
      if (!name) {
        errors.push(`Row ${rowNum}: Missing name`);
        continue;
      }
      
      // Get email
      const rawEmail = row[cols.email];
      const email = cleanEmail(rawEmail);
      if (!email) {
        errors.push(`Row ${rowNum}: Missing or invalid email for "${name}" (got: "${rawEmail}")`);
        continue;
      }
      
      const member: ExtractedMember = { name, email };
      
      // Optional fields
      if (cols.phone !== -1) {
        member.phone = cleanPhone(row[cols.phone]);
      }
      
      if (cols.dateOfBirth !== -1) {
        member.dateOfBirth = parseDate(row[cols.dateOfBirth]);
      }
      
      if (cols.address !== -1) {
        const addr = String(row[cols.address] || '').trim();
        if (addr) member.address = addr;
      }
      
      if (cols.city !== -1) {
        const city = String(row[cols.city] || '').trim();
        if (city) member.city = city;
      }
      
      if (cols.state !== -1) {
        const state = String(row[cols.state] || '').trim();
        if (state) member.state = state;
      }
      
      if (cols.zipCode !== -1) {
        const zip = String(row[cols.zipCode] || '').trim();
        if (zip) member.zipCode = zip;
      }
      
      // Officer fields
      if (isOfficersList) {
        if (cols.position !== -1) {
          const pos = String(row[cols.position] || '').trim();
          if (pos) member.position = pos;
        }
        
        if (cols.dateElected !== -1) {
          member.dateElected = parseDate(row[cols.dateElected]);
        }
        
        if (cols.termExpiration !== -1) {
          member.termExpiration = parseDate(row[cols.termExpiration]);
        }
      }
      
      members.push(member);
      console.log(`Row ${rowNum}: Extracted "${member.name}" <${member.email}>`);
      
    } catch (err) {
      errors.push(`Row ${rowNum}: ${err.message}`);
    }
  }
  
  return { members, errors };
}

// ============================================================================
// DIRECT DATABASE INSERTION
// ============================================================================

async function upsertMembers(
  members: ExtractedMember[],
  chapterName: string,
  chapterType: string,
  schoolName: string,
  isOfficersList: boolean,
  county: string | null
): Promise<{ created: number; updated: number; failed: number; errors: string[] }> {
  
  let created = 0;
  let updated = 0;
  let failed = 0;
  const errors: string[] = [];
  
  for (const m of members) {
    try {
      // Build full address
      let fullAddress: string | null = null;
      if (m.address || m.city || m.state || m.zipCode) {
        const parts = [m.address, m.city, m.state, m.zipCode].filter(Boolean);
        fullAddress = parts.join(', ');
      }
      
      // Check if member exists
      const { data: existing } = await supabase
        .from('members')
        .select('id')
        .eq('email', m.email)
        .single();
      
      // Build member data
      const memberData: Record<string, any> = {
        name: m.name,
        email: m.email,
        chapter_name: chapterName,
        current_chapter_member: 'Yes',
        date_joined: new Date().toISOString().split('T')[0],
      };
      
      if (m.phone) {
        memberData.phone = m.phone;
        memberData.phone_e164 = formatPhoneE164(m.phone);
      }
      
      if (m.dateOfBirth) {
        memberData.date_of_birth = m.dateOfBirth;
      }
      
      if (fullAddress) {
        memberData.address = fullAddress;
      }
      
      // Chapter type specific fields
      if (chapterType === 'college') {
        memberData.committee = ['College Democrats'];
        memberData.college = schoolName;
        memberData.school_name = schoolName;
        memberData.in_school = 'Yes';
      } else if (chapterType === 'highschool') {
        memberData.committee = ['High School Democrats'];
        memberData.high_school = schoolName;
        memberData.school_name = schoolName;
        memberData.in_school = 'Yes';
      } else if (chapterType === 'county' && county) {
        memberData.county = county;
      }
      
      // Officer fields
      if (isOfficersList) {
        if (m.position) {
          memberData.chapter_position = m.position;
        }
        if (m.dateElected) {
          memberData.date_elected = m.dateElected;
        }
        if (m.termExpiration) {
          memberData.term_expiration = m.termExpiration;
        }
      }
      
      if (existing) {
        const { error: updateError } = await supabase
          .from('members')
          .update(memberData)
          .eq('id', existing.id);
        
        if (updateError) {
          errors.push(`Failed to update ${m.email}: ${updateError.message}`);
          failed++;
        } else {
          updated++;
        }
      } else {
        const { error: insertError } = await supabase
          .from('members')
          .insert(memberData);
        
        if (insertError) {
          errors.push(`Failed to insert ${m.email}: ${insertError.message}`);
          failed++;
        } else {
          created++;
        }
      }
    } catch (err) {
      errors.push(`Error processing ${m.email}: ${err.message}`);
      failed++;
    }
  }
  
  return { created, updated, failed, errors };
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const {
      chapter_id,
      chapter_name,
      chapter_type,
      school_name,
      county,
      file_path,
      is_officers_list,
      submission_date,
    } = await req.json();

    console.log("=== ROSTER PROCESSING START ===");
    console.log("Chapter:", chapter_name);
    console.log("Type:", chapter_type);
    console.log("School/County:", school_name || county);
    console.log("File path:", file_path);
    console.log("Is officers list:", is_officers_list);

    if (!file_path) {
      throw new Error("No file path provided");
    }

    // Download file from storage
    const { data: fileData, error: downloadError } = await supabase
      .storage
      .from('form-uploads')
      .download(file_path);

    if (downloadError) {
      console.error("Download error:", downloadError);
      throw new Error(`Failed to download file: ${downloadError.message}`);
    }

    const fileName = file_path.split('/').pop() || 'file';
    console.log(`Parsing file: ${fileName}`);
    
    // Parse file
    const { headers, rows } = await parseFile(fileData, fileName, is_officers_list);
    
    console.log(`Found ${headers.length} columns, ${rows.length} data rows`);

    if (rows.length === 0) {
      throw new Error("No data rows found in file");
    }

    // Extract members
    const { members, errors: parsingErrors } = extractMembers(headers, rows, is_officers_list);
    
    console.log(`Extracted ${members.length} members, ${parsingErrors.length} parsing errors`);
    
    if (parsingErrors.length > 0) {
      console.log('Parsing errors:', parsingErrors.slice(0, 5));
    }

    if (members.length === 0) {
      throw new Error(
        `No valid members could be extracted.\nErrors: ${parsingErrors.slice(0, 5).join('; ')}`
      );
    }

    // Insert/update members
    const { created, updated, failed, errors: dbErrors } = await upsertMembers(
      members,
      chapter_name,
      chapter_type,
      school_name,
      is_officers_list,
      county || (chapter_type === 'county' ? school_name : null)
    );

    console.log(`Database results: ${created} created, ${updated} updated, ${failed} failed`);
    console.log("=== ROSTER PROCESSING COMPLETE ===");

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          file_name: fileName,
          total_rows: rows.length,
          processed: members.length,
          created: created,
          updated: updated,
          failed: failed,
          parsing_errors: parsingErrors.slice(0, 20),
          database_errors: dbErrors.slice(0, 10),
          total_parsing_errors: parsingErrors.length,
          is_officers_list,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("=== ROSTER PROCESSING ERROR ===");
    console.error("Error:", err);
    return new Response(
      JSON.stringify({ 
        success: false,
        error: err.message,
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});