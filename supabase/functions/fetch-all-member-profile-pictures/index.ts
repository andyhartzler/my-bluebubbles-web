// VERSION WITH MULTIPLE INSTAGRAM METHODS
// Tries 3 different approaches if one fails
// FIXED: Starts with newest members first & consistent error handling

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { memberId, mode = 'single', limit = 5 } = await req.json()

    if (mode === 'batch') {
      console.log(`🔄 Processing ${limit} members (newest first)`)

      // FIXED: Changed to descending order (newest first)
      const { data: allMembers, error: fetchError } = await supabaseClient
        .from('members')
        .select('id, name, instagram, x, tiktok, profile_pictures, created_at')
        .or('instagram.not.is.null,x.not.is.null,tiktok.not.is.null')
        .order('created_at', { ascending: false }) // CHANGED: newest first
        .limit(limit * 3)

      if (fetchError) {
        console.error('Fetch error:', fetchError)
        throw new Error(fetchError.message || 'Failed to fetch members')
      }

      // Filter for members with null or empty profile_pictures
      const members = (allMembers || []).filter(m => {
        if (!m.profile_pictures) return true
        if (typeof m.profile_pictures === 'object' && Object.keys(m.profile_pictures).length === 0) return true
        return false
      }).slice(0, limit)

      if (!members || members.length === 0) {
        return new Response(
          JSON.stringify({
            success: true,
            message: '✅ All members attempted!',
            processed: 0,
            successful: 0,
            failed: 0,
            results: []
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        )
      }

      const results = []

      for (let i = 0; i < members.length; i++) {
        const member = members[i]
        console.log(`\n[${i + 1}/${members.length}] ${member.name} (${member.id})`)

        try {
          const result = await processSingleMember(supabaseClient, member.id, member.instagram, member.x, member.tiktok)
          results.push({ 
            memberId: member.id, 
            name: member.name, 
            success: true,
            ...result 
          })
        } catch (error) {
          console.error(`❌ ${error.message}`)
          
          // Mark as attempted with empty object
          await supabaseClient
            .from('members')
            .update({ profile_pictures: {} })
            .eq('id', member.id)
          
          // FIXED: Ensure consistent result object structure
          results.push({
            memberId: member.id,
            name: member.name,
            success: false,
            error: error?.message || 'Unknown error',
            profilePictures: {},
            publicUrls: {},
            count: 0
          })
        }

        if (i < members.length - 1) {
          console.log('⏳ Waiting 5 seconds...')
          await new Promise(resolve => setTimeout(resolve, 5000))
        }
      }

      const successCount = results.filter(r => r.success === true).length

      return new Response(
        JSON.stringify({
          success: true,
          processed: members.length,
          successful: successCount,
          failed: members.length - successCount,
          results: results // All results now have consistent structure
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    // Single mode
    if (!memberId) throw new Error('memberId required')

    const { data: member } = await supabaseClient
      .from('members')
      .select('instagram, x, tiktok')
      .eq('id', memberId)
      .single()

    const result = await processSingleMember(supabaseClient, memberId, member?.instagram, member?.x, member?.tiktok)

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Top-level error:', error)
    return new Response(
      JSON.stringify({ 
        success: false,
        error: error?.message || 'Unknown error occurred' 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

async function processSingleMember(supabaseClient: any, memberId: string, instagram: string | null, x: string | null, tiktok: string | null) {
  const profileUrls: { [key: string]: string } = {}
  
  // Try Instagram
  if (instagram) {
    console.log('  Fetching Instagram...')
    const instagramUrl = await fetchInstagramProfilePicture(instagram)
    if (instagramUrl) {
      profileUrls.instagram = instagramUrl
      console.log('  ✓ Instagram found')
    } else {
      console.log('  ✗ Instagram failed')
    }
  }

  // Try Twitter
  if (x) {
    console.log('  Fetching Twitter...')
    const twitterUrl = await fetchTwitterProfilePicture(x)
    if (twitterUrl) {
      profileUrls.twitter = twitterUrl
      console.log('  ✓ Twitter found')
    } else {
      console.log('  ✗ Twitter failed')
    }
  }

  // Try TikTok (via unavatar.io — free tier serves TikTok avatars; Instagram
  // is pro-only there, and IG's own endpoints have been dead since ~June 2026)
  if (tiktok) {
    console.log('  Fetching TikTok...')
    const tiktokUrl = await fetchTikTokProfilePicture(tiktok)
    if (tiktokUrl) {
      profileUrls.tiktok = tiktokUrl
      console.log('  ✓ TikTok found')
    } else {
      console.log('  ✗ TikTok failed')
    }
  }

  if (Object.keys(profileUrls).length === 0) {
    throw new Error('Could not fetch any profile pictures')
  }

  // Download and upload
  const uploadedPaths: { [key: string]: string } = {}
  const uploadedUrls: { [key: string]: string } = {}

  for (const [platform, imageUrl] of Object.entries(profileUrls)) {
    try {
      const imageResponse = await fetch(imageUrl)
      if (!imageResponse.ok) continue

      const imageBlob = await imageResponse.blob()
      const arrayBuffer = await imageBlob.arrayBuffer()
      const imageBuffer = new Uint8Array(arrayBuffer)

      const contentType = imageResponse.headers.get('content-type') || 'image/jpeg'
      const extension = contentType.split('/')[1]?.split(';')[0] || 'jpg'
      const fileName = `${memberId}-${platform}.${extension}`

      const { error: uploadError } = await supabaseClient
        .storage
        .from('member-photos')
        .upload(fileName, imageBuffer, {
          contentType: contentType,
          upsert: true
        })

      if (uploadError) {
        console.error(`  Upload error for ${platform}:`, uploadError)
        continue
      }

      uploadedPaths[platform] = fileName

      const { data: { publicUrl } } = supabaseClient
        .storage
        .from('member-photos')
        .getPublicUrl(fileName)
      
      uploadedUrls[platform] = publicUrl

      console.log(`  ✓ Uploaded ${platform}`)
    } catch (error) {
      console.error(`  Error with ${platform}:`, error?.message || error)
    }
  }

  if (Object.keys(uploadedPaths).length === 0) {
    throw new Error('Failed to upload any pictures')
  }

  await supabaseClient
    .from('members')
    .update({ profile_pictures: uploadedPaths })
    .eq('id', memberId)

  return {
    success: true,
    memberId,
    profilePictures: uploadedPaths,
    publicUrls: uploadedUrls,
    count: Object.keys(uploadedPaths).length
  }
}

function cleanInstagramHandle(input: string): string | null {
  if (!input) return null
  let cleaned = input.trim()
  
  if (cleaned.includes('instagram.com/')) {
    const match = cleaned.match(/instagram\.com\/([^/?#]+)/)
    if (match && match[1]) cleaned = match[1]
  }
  
  cleaned = cleaned.replace('@', '').replace(/\/$/, '').replace(/[\/\s]/g, '')
  
  if (!/^[a-zA-Z0-9._]+$/.test(cleaned) || cleaned.length === 0 || cleaned.length > 30) {
    return null
  }
  
  return cleaned.toLowerCase()
}

async function fetchInstagramProfilePicture(rawHandle: string): Promise<string | null> {
  const username = cleanInstagramHandle(rawHandle)
  if (!username) return null
  
  // METHOD 1: Try Instagram's web profile API
  try {
    console.log(`    Method 1: Instagram API...`)
    const response = await fetch(
      `https://www.instagram.com/api/v1/users/web_profile_info/?username=${username}`,
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'X-IG-App-ID': '936619743392459',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': 'https://www.instagram.com/',
          'Sec-Fetch-Dest': 'empty',
          'Sec-Fetch-Mode': 'cors',
          'Sec-Fetch-Site': 'same-origin'
        }
      }
    )

    console.log(`    Status: ${response.status}`)

    if (response.ok) {
      const data = await response.json()
      const pic = data?.data?.user?.profile_pic_url_hd || data?.data?.user?.profile_pic_url
      if (pic) {
        console.log(`    ✓ Method 1 worked`)
        return pic
      }
    }
  } catch (error) {
    console.log(`    ✗ Method 1 failed: ${error?.message || error}`)
  }

  // METHOD 2: Try scraping the public profile page
  try {
    console.log(`    Method 2: Scraping public page...`)
    const response = await fetch(`https://www.instagram.com/${username}/`, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Referer': 'https://www.instagram.com/'
      }
    })

    if (response.ok) {
      const html = await response.text()
      
      // Try to find profile pic in meta tags
      const ogImageMatch = html.match(/<meta property="og:image" content="([^"]+)"/)
      if (ogImageMatch && ogImageMatch[1]) {
        console.log(`    ✓ Method 2 worked (og:image)`)
        return ogImageMatch[1]
      }

      // Try to find in JSON embedded in page
      const jsonMatch = html.match(/"profile_pic_url_hd":"([^"]+)"/)
      if (jsonMatch && jsonMatch[1]) {
        const url = jsonMatch[1].replace(/\\u0026/g, '&')
        console.log(`    ✓ Method 2 worked (embedded JSON)`)
        return url
      }

      // Try alternative JSON pattern
      const jsonMatch2 = html.match(/"profile_pic_url":"([^"]+)"/)
      if (jsonMatch2 && jsonMatch2[1]) {
        const url = jsonMatch2[1].replace(/\\u0026/g, '&')
        console.log(`    ✓ Method 2 worked (alt pattern)`)
        return url
      }
    }
    
    console.log(`    ✗ Method 2 failed`)
  } catch (error) {
    console.log(`    ✗ Method 2 error: ${error?.message || error}`)
  }

  // METHOD 3: Try Instagram's public GraphQL endpoint
  try {
    console.log(`    Method 3: GraphQL endpoint...`)
    const response = await fetch(
      `https://www.instagram.com/graphql/query/?query_hash=c9100bf9110dd6361671f113dd02e7d6&variables={"username":"${username}"}`,
      {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': '*/*'
        }
      }
    )

    if (response.ok) {
      const data = await response.json()
      const pic = data?.data?.user?.profile_pic_url_hd || data?.data?.user?.profile_pic_url
      if (pic) {
        console.log(`    ✓ Method 3 worked`)
        return pic
      }
    }
    
    console.log(`    ✗ Method 3 failed`)
  } catch (error) {
    console.log(`    ✗ Method 3 error: ${error?.message || error}`)
  }

  console.log(`    ❌ All Instagram methods failed for: ${username}`)
  return null
}

function cleanTwitterHandle(input: string): string | null {
  if (!input) return null
  let cleaned = input.trim()
  
  if (cleaned.includes('twitter.com/') || cleaned.includes('x.com/')) {
    const match = cleaned.match(/(?:twitter|x)\.com\/([^/?#]+)/)
    if (match && match[1]) cleaned = match[1]
  }
  
  cleaned = cleaned.replace('@', '').replace(/\/$/, '').replace(/[\/\s]/g, '')
  
  if (!/^[a-zA-Z0-9_]+$/.test(cleaned) || cleaned.length === 0 || cleaned.length > 15) {
    return null
  }
  
  return cleaned
}

async function fetchTwitterProfilePicture(rawHandle: string): Promise<string | null> {
  const username = cleanTwitterHandle(rawHandle)
  if (!username) return null
  
  const bearerToken = Deno.env.get('TWITTER_BEARER_TOKEN')
  if (!bearerToken) {
    console.log(`    Twitter token not configured`)
    return null
  }

  try {
    const response = await fetch(
      `https://api.twitter.com/2/users/by/username/${username}?user.fields=profile_image_url`,
      {
        headers: {
          'Authorization': `Bearer ${bearerToken}`
        }
      }
    )

    if (response.ok) {
      const data = await response.json()
      const profileUrl = data?.data?.profile_image_url
      return profileUrl ? profileUrl.replace('_normal', '_400x400') : null
    }
    
    console.log(`    Twitter API status: ${response.status}; trying unavatar`)
    return await fetchUnavatar('x', username)
  } catch (error) {
    console.log(`    Twitter error: ${error?.message || error}; trying unavatar`)
    return await fetchUnavatar('x', username)
  }
}

// unavatar.io proxies public avatars. `fallback=false` makes a miss a 404
// instead of a generic placeholder image, so a miss stays a miss.
async function fetchUnavatar(provider: string, username: string): Promise<string | null> {
  try {
    const url = `https://unavatar.io/${provider}/${encodeURIComponent(username)}?fallback=false`
    const res = await fetch(url, { redirect: 'follow' })
    const type = res.headers.get('content-type') || ''
    if (res.ok && type.startsWith('image/')) return url
    console.log(`    unavatar ${provider}/${username}: ${res.status} ${type}`)
    return null
  } catch (error) {
    console.log(`    unavatar error: ${error?.message || error}`)
    return null
  }
}

function cleanTikTokHandle(input: string): string | null {
  if (!input) return null
  let cleaned = input.trim()
  if (cleaned.includes('tiktok.com/')) {
    const match = cleaned.match(/tiktok\.com\/@?([^/?#]+)/)
    if (match && match[1]) cleaned = match[1]
  }
  cleaned = cleaned.replace(/^@/, '').replace(/\/$/, '').replace(/\s/g, '')
  if (!/^[a-zA-Z0-9_.]+$/.test(cleaned) || cleaned.length === 0 || cleaned.length > 24) {
    return null
  }
  return cleaned
}

async function fetchTikTokProfilePicture(rawHandle: string): Promise<string | null> {
  const username = cleanTikTokHandle(rawHandle)
  if (!username) return null
  return await fetchUnavatar('tiktok', username)
}