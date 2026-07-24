import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

// Function to extract chapter type from form input
function extractChapterType(chapterTypeInput) {
  const input = chapterTypeInput.toLowerCase().trim();
  if (input.includes('college')) return 'college';
  if (input.includes('high school') || input.includes('highschool')) return 'highschool';
  if (input.includes('county')) return 'county';
  if (input === 'college' || input === 'highschool' || input === 'county') {
    return input;
  }
  throw new Error(`Invalid chapter type: ${chapterTypeInput}. Must contain "college", "high school", or "county"`);
}

// Function to standardize document collection name
function standardizeDocumentName(schoolName) {
  let cleanName = schoolName.trim()
    .replace(/\s+(College\s+)?Dems?$/i, '')
    .replace(/\s+Democrats?$/i, '')
    .replace(/\s+Chapter$/i, '')
    .replace(/\s+Governing\s+Documents$/i, '')
    .trim();

  cleanName = cleanName.replace(/\b(university|college|high school|county)\b/gi, (match) => {
    return match.charAt(0).toUpperCase() + match.slice(1).toLowerCase();
  });

  return `${cleanName} Governing Documents`;
}

// Function to create clean folder name
function createFolderName(schoolName, chapterType) {
  const cleanName = schoolName.toLowerCase().trim()
    .replace(/\s+(college\s+)?dems?$/i, '')
    .replace(/\s+democrats?$/i, '')
    .replace(/\s+chapter$/i, '')
    .replace(/\s+governing\s+documents$/i, '')
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, '-')
    .trim();

  return `${chapterType}/${cleanName}`;
}

// Function to check if document type is a governing document
function isGoverningDocument(documentType) {
  const lowerType = documentType.toLowerCase();
  const governingTypes = [
    'constitution',
    'bylaws',
    'charter',
    'governing documents',
    'governing document'
  ];
  return governingTypes.some(type => lowerType.includes(type));
}

// Function to clean and validate regular URLs (for website)
function cleanUrl(url) {
  if (!url) return null;
  const trimmed = url.trim();
  if (!trimmed) return null;
  
  // Check for null-equivalent values
  const nullValues = ['n/a', 'na', 'none', 'null', '-', 'n.a.', 'n/a.'];
  if (nullValues.includes(trimmed.toLowerCase())) return null;
  
  // Add https:// if no protocol specified
  if (!/^https?:\/\//i.test(trimmed)) {
    return `https://${trimmed}`;
  }
  return trimmed;
}

// Function to normalize state input to uppercase 2-letter code
function normalizeState(stateInput) {
  if (!stateInput) return 'MO'; // Default to MO
  
  const trimmed = stateInput.trim();
  const lowerTrimmed = trimmed.toLowerCase();
  
  // Check for null-equivalent values
  const nullValues = ['n/a', 'na', 'none', 'null', '-'];
  if (nullValues.includes(lowerTrimmed)) return 'MO';
  
  // If it's already 2 letters, just uppercase it
  if (trimmed.length === 2) {
    return trimmed.toUpperCase();
  }
  
  // State name to abbreviation mapping (just Missouri for now, but extensible)
  const stateMap = {
    'missouri': 'MO',
    'kansas': 'KS',
    'illinois': 'IL',
    'iowa': 'IA',
    'nebraska': 'NE',
    'arkansas': 'AR',
    'oklahoma': 'OK',
    'tennessee': 'TN',
    'kentucky': 'KY'
  };
  
  const normalized = stateMap[lowerTrimmed];
  return normalized || 'MO'; // Default to MO if not found
}

// Smart social media URL handler
function cleanSocialMediaUrl(input, platform) {
  if (!input) return null;
  
  const trimmed = input.trim();
  const lowerTrimmed = trimmed.toLowerCase();
  
  // Check for null-equivalent values
  const nullValues = ['n/a', 'na', 'none', 'null', '', '-', 'n.a.', 'n/a.'];
  if (nullValues.includes(lowerTrimmed)) return null;
  
  // If already a full URL, return it (preserving case)
  if (/^https?:\/\//i.test(trimmed)) {
    return trimmed;
  }
  
  // Extract username from handle
  let username = trimmed;
  
  // Remove @ symbol if present
  username = username.replace(/^@/, '');
  
  // Remove any URL fragments that might be present
  username = username.replace(/^(https?:\/\/)?(www\.)?/, '');
  
  // Platform-specific URL construction
  switch(platform) {
    case 'twitter':
      // Remove twitter.com or x.com if present
      username = username.replace(/^(twitter\.com\/|x\.com\/)/, '');
      // Remove any trailing slashes
      username = username.replace(/\/$/, '');
      return username ? `https://twitter.com/${username}` : null;
      
    case 'bluesky':
      // Remove bsky.app prefix if present
      username = username.replace(/^(bsky\.app\/profile\/)/, '');
      // If username doesn't have a domain extension, add .bsky.social
      if (!username.includes('.')) {
        username = `${username}.bsky.social`;
      }
      return username ? `https://bsky.app/profile/${username}` : null;
      
    case 'facebook':
      // Remove facebook.com or fb.com if present
      username = username.replace(/^(facebook\.com\/|fb\.com\/)/, '');
      username = username.replace(/\/$/, '');
      return username ? `https://www.facebook.com/${username}` : null;
      
    case 'instagram':
      // Remove instagram.com if present
      username = username.replace(/^(instagram\.com\/|instagr\.am\/)/, '');
      username = username.replace(/\/$/, '');
      return username ? `https://www.instagram.com/${username}` : null;
      
    case 'threads':
      // Remove threads.net if present
      username = username.replace(/^(threads\.net\/@?)/, '');
      // Threads requires @ in URL
      if (!username.startsWith('@')) {
        username = `@${username}`;
      }
      return username ? `https://www.threads.net/${username}` : null;
      
    case 'tiktok':
      // Remove tiktok.com if present
      username = username.replace(/^(tiktok\.com\/@?)/, '');
      // TikTok requires @ in URL
      if (!username.startsWith('@')) {
        username = `@${username}`;
      }
      return username ? `https://www.tiktok.com/${username}` : null;
      
    default:
      return null;
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const {
      fileId,
      chapterType,
      schoolName,
      chapterName,
      documentType,
      uploadedBy,
      submissionDate,
      website,
      twitter,
      bluesky,
      facebook,
      instagram,
      threads,
      tiktok,
      street_address,
      city,
      state,
      zip
    } = await req.json();

    console.log('=== Upload Request ===');
    console.log('Chapter Type:', chapterType);
    console.log('School Name:', schoolName);
    console.log('Chapter Name:', chapterName);
    console.log('Document Type:', documentType);
    console.log('File ID:', fileId);
    console.log('Uploaded By:', uploadedBy);
    console.log('Submission Date:', submissionDate);
    console.log('Website:', website);
    console.log('Social Media RAW:', { twitter, bluesky, facebook, instagram, threads, tiktok });
    console.log('Address RAW:', { street_address, city, state, zip });

    if (!fileId || !chapterType || !schoolName || !chapterName || !documentType) {
      throw new Error('Missing required fields: fileId, chapterType, schoolName, chapterName, or documentType');
    }

    const normalizedChapterType = extractChapterType(chapterType);
    const standardizedDocName = standardizeDocumentName(schoolName);
    const isGovDoc = isGoverningDocument(documentType);

    console.log('Normalized Type:', normalizedChapterType);
    console.log('Standardized Name:', standardizedDocName);
    console.log('Is Governing Document:', isGovDoc);

    // Parse submission date
    let charterDate = null;
    if (submissionDate) {
      try {
        const date = new Date(submissionDate);
        if (!isNaN(date.getTime())) {
          charterDate = date.toISOString().split('T')[0];
          console.log('Charter Date:', charterDate);
        }
      } catch (error) {
        console.warn('Could not parse submission date:', error);
      }
    }

    // STEP 1: Build chapter upsert data
    console.log('Building chapter upsert data...');
    const chapterUpsertData = {
      chapter_name: chapterName,
      standardized_name: standardizedDocName,
      school_name: schoolName.trim(),
      chapter_type: normalizedChapterType,
      status: 'active',
      last_updated: new Date().toISOString()
    };

    // Set contact email if provided
    if (uploadedBy) {
      chapterUpsertData.contact_email = uploadedBy;
      console.log('Setting contact email:', uploadedBy);
    }

    // If this is a governing document, set charter info
    if (isGovDoc) {
      chapterUpsertData.is_chartered = true;
      if (charterDate) {
        chapterUpsertData.charter_date = charterDate;
      }
      console.log('Setting chapter as chartered with date:', charterDate);
    }

    // Website
    if (website) {
      const cleanWebsite = cleanUrl(website);
      if (cleanWebsite) {
        chapterUpsertData.website = cleanWebsite;
        console.log('Setting website:', chapterUpsertData.website);
      } else {
        console.log('Website was null-equivalent, skipping');
      }
    }

    // Social Media URLs - Using smart handler
    if (twitter) {
      const cleanTwitter = cleanSocialMediaUrl(twitter, 'twitter');
      if (cleanTwitter) {
        chapterUpsertData.twitter = cleanTwitter;
        console.log('Setting Twitter:', chapterUpsertData.twitter);
      } else {
        console.log('Twitter was null-equivalent, skipping');
      }
    }

    if (bluesky) {
      const cleanBluesky = cleanSocialMediaUrl(bluesky, 'bluesky');
      if (cleanBluesky) {
        chapterUpsertData.bluesky = cleanBluesky;
        console.log('Setting Bluesky:', chapterUpsertData.bluesky);
      } else {
        console.log('Bluesky was null-equivalent, skipping');
      }
    }

    if (facebook) {
      const cleanFacebook = cleanSocialMediaUrl(facebook, 'facebook');
      if (cleanFacebook) {
        chapterUpsertData.facebook = cleanFacebook;
        console.log('Setting Facebook:', chapterUpsertData.facebook);
      } else {
        console.log('Facebook was null-equivalent, skipping');
      }
    }

    if (instagram) {
      const cleanInstagram = cleanSocialMediaUrl(instagram, 'instagram');
      if (cleanInstagram) {
        chapterUpsertData.instagram = cleanInstagram;
        console.log('Setting Instagram:', chapterUpsertData.instagram);
      } else {
        console.log('Instagram was null-equivalent, skipping');
      }
    }

    if (threads) {
      const cleanThreads = cleanSocialMediaUrl(threads, 'threads');
      if (cleanThreads) {
        chapterUpsertData.threads = cleanThreads;
        console.log('Setting Threads:', chapterUpsertData.threads);
      } else {
        console.log('Threads was null-equivalent, skipping');
      }
    }

    if (tiktok) {
      const cleanTiktok = cleanSocialMediaUrl(tiktok, 'tiktok');
      if (cleanTiktok) {
        chapterUpsertData.tiktok = cleanTiktok;
        console.log('Setting TikTok:', chapterUpsertData.tiktok);
      } else {
        console.log('TikTok was null-equivalent, skipping');
      }
    }

    // Address fields
    if (street_address) {
      const trimmedAddress = street_address.trim();
      const nullValues = ['n/a', 'na', 'none', 'null', '-'];
      if (trimmedAddress && !nullValues.includes(trimmedAddress.toLowerCase())) {
        chapterUpsertData.street_address = trimmedAddress;
        console.log('Setting street address:', chapterUpsertData.street_address);
      } else {
        console.log('Street address was null-equivalent, skipping');
      }
    }

    if (city) {
      const trimmedCity = city.trim();
      const nullValues = ['n/a', 'na', 'none', 'null', '-'];
      if (trimmedCity && !nullValues.includes(trimmedCity.toLowerCase())) {
        chapterUpsertData.city = trimmedCity;
        console.log('Setting city:', chapterUpsertData.city);
      } else {
        console.log('City was null-equivalent, skipping');
      }
    }

    // State - normalize to uppercase 2-letter code
    const normalizedState = normalizeState(state);
    chapterUpsertData.state = normalizedState;
    console.log('Setting state:', chapterUpsertData.state);

    if (zip) {
      const trimmedZip = zip.toString().trim();
      const nullValues = ['n/a', 'na', 'none', 'null', '-'];
      if (trimmedZip && !nullValues.includes(trimmedZip.toLowerCase())) {
        chapterUpsertData.zip = trimmedZip;
        console.log('Setting zip:', chapterUpsertData.zip);
      } else {
        console.log('Zip was null-equivalent, skipping');
      }
    }

    console.log('Final chapter upsert data:', JSON.stringify(chapterUpsertData, null, 2));

    // Upsert to chapters table
    const { error: chapterError } = await supabase
      .from('chapters')
      .upsert(chapterUpsertData, {
        onConflict: 'chapter_name',
        ignoreDuplicates: false
      });

    if (chapterError) {
      console.error('Chapter upsert error:', chapterError);
      throw new Error(`Failed to upsert chapter: ${chapterError.message}`);
    }

    console.log('✓ Chapter info saved to chapters table');

    // STEP 2: Get Google access token
    console.log('Getting Google access token...');
    const serviceAccountJson = Deno.env.get('GOOGLE_SERVICE_ACCOUNT');
    const serviceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getGoogleAccessToken(serviceAccount);

    // STEP 3: Get file metadata
    console.log('Fetching file metadata...');
    const metadataResponse = await fetch(
      `https://www.googleapis.com/drive/v3/files/${fileId}?fields=name,mimeType,size`,
      {
        headers: { 'Authorization': `Bearer ${accessToken}` }
      }
    );

    if (!metadataResponse.ok) {
      throw new Error(`Failed to get file metadata: ${await metadataResponse.text()}`);
    }

    const metadata = await metadataResponse.json();
    console.log('File metadata:', metadata);

    // STEP 4: Download file from Google Drive
    console.log('Downloading file...');
    let fileBlob;
    let finalMimeType = metadata.mimeType || 'application/pdf';

    if (metadata.mimeType === 'application/vnd.google-apps.document') {
      console.log('Converting Google Doc to PDF...');
      const exportResponse = await fetch(
        `https://www.googleapis.com/drive/v3/files/${fileId}/export?mimeType=application/pdf`,
        {
          headers: { 'Authorization': `Bearer ${accessToken}` }
        }
      );

      if (!exportResponse.ok) {
        throw new Error(`Failed to export Google Doc: ${await exportResponse.text()}`);
      }

      fileBlob = await exportResponse.blob();
      finalMimeType = 'application/pdf';
    } else {
      const downloadResponse = await fetch(
        `https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`,
        {
          headers: { 'Authorization': `Bearer ${accessToken}` }
        }
      );

      if (!downloadResponse.ok) {
        throw new Error(`Failed to download file: ${await downloadResponse.text()}`);
      }

      fileBlob = await downloadResponse.blob();
    }

    const fileSize = fileBlob.size;
    console.log(`✓ File downloaded: ${fileSize} bytes`);

    // STEP 5: Determine file extension
    let extension = 'pdf';
    if (finalMimeType.includes('pdf')) {
      extension = 'pdf';
    } else if (finalMimeType.includes('document') || finalMimeType.includes('word')) {
      extension = 'docx';
    } else if (metadata.name) {
      const match = metadata.name.match(/\.([^.]+)$/);
      if (match) extension = match[1].toLowerCase();
    }

    // STEP 6: Create file path and upload to storage
    const folderName = createFolderName(schoolName, normalizedChapterType);
    const sanitizedDocType = documentType.toLowerCase().trim().replace(/[^a-z0-9]/g, '-');
    const timestamp = new Date().toISOString().split('T')[0];
    const finalFileName = `${folderName}/${sanitizedDocType}-${timestamp}.${extension}`;

    console.log(`Uploading to storage: ${finalFileName}`);

    const { error: uploadError } = await supabase.storage
      .from('governing-documents')
      .upload(finalFileName, fileBlob, {
        contentType: finalMimeType,
        upsert: true,
        cacheControl: '3600'
      });

    if (uploadError) {
      console.error('Storage upload error:', uploadError);
      throw uploadError;
    }

    console.log('✓ File uploaded to storage');

    // STEP 7: Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from('governing-documents')
      .getPublicUrl(finalFileName);

    console.log(`Public URL: ${publicUrl}`);

    // STEP 8: Save document metadata to chapter_documents table
    const { data: dbData, error: dbError } = await supabase
      .from('chapter_documents')
      .upsert({
        chapter_name: chapterName,
        document_type: documentType.toLowerCase(),
        file_path: finalFileName,
        public_url: publicUrl,
        original_filename: metadata.name || 'unknown',
        file_size: fileSize,
        uploaded_by: uploadedBy || null,
        uploaded_at: new Date().toISOString()
      }, {
        onConflict: 'chapter_name,document_type'
      })
      .select()
      .single();

    if (dbError) {
      console.error('Database error:', dbError);
      throw dbError;
    }

    console.log('✓ Document metadata saved to chapter_documents table');
    console.log('=== Upload Complete ===');

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          id: dbData.id,
          chapter_name: dbData.chapter_name,
          document_type: dbData.document_type,
          public_url: dbData.public_url,
          uploaded_at: dbData.uploaded_at,
          is_chartered: isGovDoc,
          charter_date: charterDate,
          contact_email: uploadedBy,
          website: chapterUpsertData.website || null,
          social_media: {
            twitter: chapterUpsertData.twitter || null,
            bluesky: chapterUpsertData.bluesky || null,
            facebook: chapterUpsertData.facebook || null,
            instagram: chapterUpsertData.instagram || null,
            threads: chapterUpsertData.threads || null,
            tiktok: chapterUpsertData.tiktok || null
          },
          address: {
            street_address: chapterUpsertData.street_address || null,
            city: chapterUpsertData.city || null,
            state: chapterUpsertData.state || null,
            zip: chapterUpsertData.zip || null
          }
        },
        message: 'Document uploaded successfully'
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    );
  } catch (error) {
    console.error('=== Upload Error ===');
    console.error(error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error occurred'
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      }
    );
  }
});

async function getGoogleAccessToken(serviceAccount) {
  const jwtHeader = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const now = Math.floor(Date.now() / 1000);
  const jwtClaimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/drive.readonly',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now
  };

  const jwtClaimSetEncoded = btoa(JSON.stringify(jwtClaimSet))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const signatureInput = `${jwtHeader}.${jwtClaimSetEncoded}`;

  const pemHeader = '-----BEGIN PRIVATE KEY-----';
  const pemFooter = '-----END PRIVATE KEY-----';
  const pemContents = serviceAccount.private_key
    .replace(pemHeader, '')
    .replace(pemFooter, '')
    .replace(/\s/g, '');

  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signatureInput)
  );

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const jwt = `${jwtHeader}.${jwtClaimSetEncoded}.${signature}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt
    })
  });

  if (!tokenResponse.ok) {
    throw new Error(`Failed to get access token: ${await tokenResponse.text()}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}