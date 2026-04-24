// supabase/functions/send-general-wallet-notification/index.ts
// Sends Apple Wallet push notifications to members for general announcements
// Use this for: membership reminders, important updates, announcements, etc.
// Wave 4 access-audit 2026-04-24: replaced jose.decodeJwt with jwtVerify using SUPABASE_JWT_SECRET.
// The former only parsed claims without verifying the signature — a forged token with
// role=service_role would have been accepted. jwtVerify enforces signature.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.0';
import * as jose from 'npm:jose@^5.2.0';
serve(async (req)=>{
  // CORS headers
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
      }
    });
  }
  try {
    // Initialize Supabase client with SERVICE_ROLE_KEY for database operations
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // Wave 2 access-audit 2026-04-24: REQUIRE authenticated exec user.
    // Previously auth was optional and service_role was honored; since the
    // browser JWT is going away, we now require a real user JWT + staff gate.
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer /i, '').trim();
    let actorId = null;
    if (!token) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    // Wave 4 access-audit: signature-verify the JWT using SUPABASE_JWT_SECRET before
    // trusting any claims. If role=service_role in a SIGNED token, treat as cron/internal
    // caller. Otherwise verify as user JWT and enforce executive_committee.
    const jwtSecretRaw = Deno.env.get('SUPABASE_JWT_SECRET');
    if (!jwtSecretRaw) {
      console.error('Missing SUPABASE_JWT_SECRET env');
      return new Response(JSON.stringify({ error: 'Server misconfigured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    const jwtSecret = new TextEncoder().encode(jwtSecretRaw);
    let verifiedPayload;
    try {
      const { payload } = await jose.jwtVerify(token, jwtSecret);
      verifiedPayload = payload;
    } catch (error) {
      console.error('JWT signature verification failed:', error);
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    try {
      if (verifiedPayload.role === 'service_role') {
        // Signature-verified service_role token — cron/internal caller.
        console.log('Request authorized with signature-verified service_role token');
        actorId = null;
      } else {
        const userClient = createClient(supabaseUrl, supabaseAnonKey, {
          global: { headers: { Authorization: `Bearer ${token}` } }
        });
        const { data: { user }, error: authError } = await userClient.auth.getUser(token);
        if (authError || !user) {
          return new Response(JSON.stringify({ error: 'Unauthorized' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json' }
          });
        }
        const { data: member } = await supabase
          .from('members')
          .select('executive_committee')
          .eq('id', user.id)
          .maybeSingle();
        if (!member?.executive_committee) {
          return new Response(JSON.stringify({ error: 'Forbidden — executive_committee required' }), {
            status: 403,
            headers: { 'Content-Type': 'application/json' }
          });
        }
        actorId = user.id;
        console.log(`Request authorized for exec user: ${user.id}`);
      }
    } catch (error) {
      console.error('Post-verify auth flow failed:', error);
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    const { notificationTitle, notificationMessage, targetMembers = 'all' } = await req.json();
    // Audit log (non-blocking)
    supabase.from('audit_log').insert({
      action: 'EDGE_FN',
      actor_id: actorId,
      actor_role: actorId ? 'authenticated' : 'service_role',
      schema_name: 'public',
      table_name: 'edge_fn:send-general-wallet-notification',
      row_id: null,
      context: {
        event: 'send-general-wallet-notification',
        title: notificationTitle,
        target: Array.isArray(targetMembers) ? { count: targetMembers.length } : targetMembers
      }
    }).then(() => {}).catch((e) => console.error('[wallet-notification] audit_log insert failed:', e));
    if (!notificationTitle || !notificationMessage) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: notificationTitle, notificationMessage'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Get Apple Wallet credentials
    const apnsKeyBase64 = Deno.env.get('APPLE_WALLET_APNS_KEY_BASE64');
    const apnsKeyId = Deno.env.get('APPLE_WALLET_APNS_KEY_ID');
    const apnsTeamId = Deno.env.get('APPLE_WALLET_TEAM_ID');
    const passTypeId = Deno.env.get('APPLE_WALLET_PASS_TYPE_ID');
    if (!apnsKeyBase64 || !apnsKeyId || !apnsTeamId || !passTypeId) {
      console.error('Missing APNs credentials');
      return new Response(JSON.stringify({
        error: 'APNs credentials not configured'
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    // Build query based on target members
    let query = supabase.from('membership_cards').select('id, member_id, apple_wallet_pass_serial, card_status, expiration_date').not('apple_wallet_pass_serial', 'is', null);
    if (Array.isArray(targetMembers)) {
      // Specific member IDs
      query = query.in('member_id', targetMembers);
    } else if (targetMembers === 'active') {
      // Only active members (not expired)
      query = query.eq('card_status', 'active').or(`expiration_date.is.null,expiration_date.gte.${new Date().toISOString().split('T')[0]}`);
    } else if (targetMembers === 'expired') {
      // Only expired members
      query = query.lt('expiration_date', new Date().toISOString().split('T')[0]);
    }
    // else 'all' - no additional filters
    const { data: cards, error: cardsError } = await query;
    if (cardsError) {
      console.error('Error fetching membership cards:', cardsError);
      return new Response(JSON.stringify({
        error: 'Failed to fetch membership cards'
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    if (!cards || cards.length === 0) {
      return new Response(JSON.stringify({
        message: 'No membership cards found matching criteria',
        sent: 0
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    console.log(`Found ${cards.length} membership cards to notify`);
    const cardIds = cards.map((c)=>c.id);
    // Get registered devices for these cards
    const { data: registrations, error: regError } = await supabase.from('apple_wallet_registrations').select('membership_card_id, push_token').in('membership_card_id', cardIds);
    if (regError) {
      console.error('Error fetching registrations:', regError);
      return new Response(JSON.stringify({
        error: 'Failed to fetch device registrations'
      }), {
        status: 500,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    if (!registrations || registrations.length === 0) {
      return new Response(JSON.stringify({
        message: 'No devices registered for wallet updates',
        sent: 0
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    console.log(`Found ${registrations.length} registered devices`);
    // Decode the APNs private key
    const apnsKeyPem = atob(apnsKeyBase64);
    // Import the private key for JWT signing
    const privateKey = await jose.importPKCS8(apnsKeyPem, 'ES256');
    // Generate JWT token ONCE for all notifications to avoid rate limiting
    // Apple allows tokens to be reused for up to 1 hour
    console.log('Generating APNs authentication token...');
    const apnsToken = await new jose.SignJWT({}).setProtectedHeader({
      alg: 'ES256',
      kid: apnsKeyId
    }).setIssuer(apnsTeamId).setIssuedAt().setExpirationTime('1h').sign(privateKey);
    console.log('✅ APNs token generated, will be reused for all notifications');
    // Update each membership card with notification info and send push
    const results = [];
    const updatedCards = new Set();
    for (const registration of registrations){
      try {
        // Update the membership card with notification info (only once per card)
        if (!updatedCards.has(registration.membership_card_id)) {
          const { error: updateError } = await supabase.from('membership_cards').update({
            apple_wallet_last_updated: new Date().toISOString(),
            event_notification_title: notificationTitle,
            event_notification_message: notificationMessage,
            event_notification_date: new Date().toISOString()
          }).eq('id', registration.membership_card_id);
          if (updateError) {
            console.error('Failed to update card:', updateError);
            results.push({
              cardId: registration.membership_card_id,
              success: false,
              error: 'Failed to update card'
            });
            continue;
          }
          updatedCards.add(registration.membership_card_id);
        }
        // Send push notification via APNs using the shared token
        const success = await sendApnsPush(registration.push_token, apnsToken, passTypeId);
        results.push({
          token: registration.push_token.substring(0, 10) + '...',
          success
        });
      } catch (error) {
        console.error('Failed to send push:', error);
        results.push({
          token: registration.push_token.substring(0, 10) + '...',
          success: false,
          error: error.message
        });
      }
    }
    const successCount = results.filter((r)=>r.success).length;
    const failureCount = results.filter((r)=>!r.success).length;
    console.log(`✅ Notifications sent: ${successCount} successful, ${failureCount} failed`);
    return new Response(JSON.stringify({
      message: 'Push notifications sent',
      sent: successCount,
      failed: failureCount,
      cardsUpdated: updatedCards.size,
      totalCardsFound: cards.length,
      details: results
    }), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
});
/**
 * Sends a push notification to Apple Push Notification service (APNs)
 * This triggers the Wallet app to check for updates to the pass
 *
 * @param pushToken - The device push token
 * @param apnsToken - Pre-generated JWT token (should be reused across multiple calls)
 * @param passTypeId - The pass type identifier
 */ async function sendApnsPush(pushToken, apnsToken, passTypeId) {
  try {
    // Send push notification to APNs
    // Production APNs endpoint
    const apnsUrl = `https://api.push.apple.com/3/device/${pushToken}`;
    const response = await fetch(apnsUrl, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${apnsToken}`,
        'apns-topic': passTypeId,
        'apns-push-type': 'background',
        'apns-priority': '5'
      },
      body: JSON.stringify({})
    });
    if (!response.ok) {
      const errorBody = await response.text();
      console.error(`APNs error (${response.status}):`, errorBody);
      return false;
    }
    console.log(`✅ Push sent to device: ${pushToken.substring(0, 10)}...`);
    return true;
  } catch (error) {
    console.error('Error sending APNs push:', error);
    return false;
  }
}
