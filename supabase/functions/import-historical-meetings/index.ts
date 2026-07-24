// supabase/functions/import-historical-meetings/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

const IGNORED_ATTENDEES = {
  emails: ['info@moyoungdemocrats.org'],
  names: ['Missouri Young Democrats', 'missouri young democrats']
};

// OpenAI Configuration
const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
const OPENAI_MODEL = 'gpt-4o-mini'; // Cost-effective for batch processing

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Get request parameters
    const { from_date, to_date, meeting_ids, dry_run = false } = await req.json();

    console.log('🚀 Starting historical meeting import');
    console.log(`Date range: ${from_date || 'all'} to ${to_date || 'now'}`);
    console.log(`Dry run: ${dry_run}`);

    // Get Zoom access token
    const accessToken = await getZoomAccessToken();

    // Fetch historical meetings
    let meetings = [];
    if (meeting_ids && meeting_ids.length > 0) {
      // Import specific meetings
      console.log(`Fetching ${meeting_ids.length} specific meetings...`);
      for (const meetingId of meeting_ids) {
        try {
          const meeting = await fetchZoomMeetingDetails(accessToken, meetingId);
          if (meeting) meetings.push(meeting);
        } catch (error) {
          console.error(`Failed to fetch meeting ${meetingId}:`, error.message);
        }
      }
    } else {
      // Import by date range
      console.log('Fetching meetings from Zoom API...');
      meetings = await fetchZoomMeetings(accessToken, from_date, to_date);
    }

    console.log(`Found ${meetings.length} total meetings from Zoom`);

    // Filter out false starts (very short meetings with no meaningful activity)
    const MIN_MEETING_DURATION = 5; // minutes
    meetings = filterFalseStarts(meetings, MIN_MEETING_DURATION);

    console.log(`After filtering false starts: ${meetings.length} meetings to process`);

    const results = {
      total: meetings.length,
      processed: 0,
      skipped: 0,
      failed: 0,
      meetings: []
    };

    // Process each meeting
    for (const zoomMeeting of meetings) {
      console.log(`\n${'='.repeat(60)}`);
      console.log(`Processing: ${zoomMeeting.topic}`);
      console.log(`Date: ${zoomMeeting.start_time}`);
      console.log(`Meeting ID: ${zoomMeeting.id}`);
      console.log('='.repeat(60));

      try {
        // Check if meeting already exists
        const { data: existingMeeting } = await supabaseClient
          .from('meetings')
          .select('id, meeting_title, meeting_date')
          .eq('zoom_meeting_id', zoomMeeting.id)
          .maybeSingle();

        if (existingMeeting) {
          console.log(`⏭️  Meeting already exists (ID: ${existingMeeting.id}), skipping...`);
          results.skipped++;
          results.meetings.push({
            zoom_meeting_id: zoomMeeting.id,
            title: zoomMeeting.topic,
            status: 'skipped',
            reason: 'already_exists',
            existing_id: existingMeeting.id
          });
          continue;
        }

        // Fetch participants
        console.log('Fetching participants...');
        const participants = await fetchZoomParticipants(accessToken, zoomMeeting.id);
        console.log(`Found ${participants.length} participant entries`);

        // Filter and deduplicate
        const filteredParticipants = filterIgnoredAttendees(participants);
        const uniqueParticipants = deduplicateParticipants(filteredParticipants);
        console.log(`After filtering: ${uniqueParticipants.length} unique attendees`);

        // Fetch recording and transcript
        console.log('Fetching recording data...');
        const recordingData = await fetchZoomRecordings(accessToken, zoomMeeting.id);
        
        let transcriptText = null;
        let recordingUrl = null;
        let recordingEmbedUrl = null;

        if (recordingData) {
          recordingUrl = recordingData.recording_url;
          recordingEmbedUrl = recordingData.embed_url;
          
          if (recordingData.transcript_url) {
            console.log('Downloading transcript...');
            transcriptText = await downloadZoomTranscript(accessToken, recordingData.transcript_url);
            console.log(`Transcript length: ${transcriptText?.length || 0} characters`);
          }
        }

        // Process transcript with OpenAI
        let aiSummary = null;
        let inferredHost = null;

        if (transcriptText && transcriptText.length > 100) {
          console.log('🤖 Analyzing transcript with OpenAI...');
          
          // Extract meeting summary sections
          aiSummary = await extractMeetingSummary(transcriptText, zoomMeeting.topic);
          console.log('✓ Summary extracted');

          // Infer meeting host
          inferredHost = await inferMeetingHost(
            transcriptText, 
            zoomMeeting.topic, 
            uniqueParticipants.map(p => p.name)
          );
          console.log(`✓ Inferred host: ${inferredHost || 'unknown'}`);
        } else {
          console.log('⚠️  No transcript available for AI analysis');
        }

        // Identify and match host
        let meetingHostMemberId = null;
        let meetingHostName = null;

        const hostHint = inferredHost || zoomMeeting.host_name || null;
        
        if (hostHint) {
          console.log(`\n🔍 Identifying host from hint: "${hostHint}"`);
          const hostResult = await identifyAndMatchHost(
            supabaseClient,
            hostHint,
            zoomMeeting.topic,
            uniqueParticipants
          );

          if (hostResult) {
            meetingHostMemberId = hostResult.memberId;
            meetingHostName = hostResult.memberName;

            // Add host to participants if not present
            if (hostResult.participant) {
              hostResult.participant.isHost = true;
              hostResult.participant.memberId = hostResult.memberId;
            } else {
              uniqueParticipants.push({
                name: hostResult.memberName,
                email: hostResult.memberEmail || undefined,
                totalDuration: zoomMeeting.duration * 60,
                firstJoin: zoomMeeting.start_time,
                lastLeave: new Date(new Date(zoomMeeting.start_time).getTime() + zoomMeeting.duration * 60 * 1000).toISOString(),
                numberOfJoins: 1,
                isHost: true,
                memberId: hostResult.memberId
              });
            }

            console.log(`✓ Host identified: ${meetingHostName}`);
          }
        }

        if (dry_run) {
          console.log('🔍 DRY RUN - Would create meeting with:');
          console.log(`  - Title: ${zoomMeeting.topic}`);
          console.log(`  - Host: ${meetingHostName || 'unknown'}`);
          console.log(`  - Attendees: ${uniqueParticipants.length}`);
          console.log(`  - Summary sections: ${aiSummary ? Object.keys(aiSummary).length : 0}`);
          
          results.processed++;
          results.meetings.push({
            zoom_meeting_id: zoomMeeting.id,
            title: zoomMeeting.topic,
            status: 'dry_run',
            host: meetingHostName,
            attendees: uniqueParticipants.length
          });
          continue;
        }

        // Store transcript if available
        let transcriptFilePath = null;
        if (transcriptText && transcriptText.length > 0) {
          transcriptFilePath = await storeTranscript(
            supabaseClient,
            zoomMeeting.topic,
            zoomMeeting.start_time,
            transcriptText
          );
          console.log(`Transcript stored at: ${transcriptFilePath}`);
        }

        // Create meeting record
        console.log('Creating meeting record...');
        const { data: meeting, error: meetingError } = await supabaseClient
          .from('meetings')
          .insert({
            meeting_date: zoomMeeting.start_time,
            meeting_title: zoomMeeting.topic,
            zoom_meeting_id: zoomMeeting.id,
            duration_minutes: zoomMeeting.duration,
            recording_url: recordingUrl,
            recording_embed_url: recordingEmbedUrl,
            transcript_file_path: transcriptFilePath,
            meeting_host: meetingHostMemberId,
            action_items: aiSummary?.action_items || null,
            executive_recap: aiSummary?.executive_recap || null,
            agenda_reviewed: aiSummary?.agenda_reviewed || null,
            discussion_highlights: aiSummary?.discussion_highlights || null,
            decisions_rationales: aiSummary?.decisions_rationales || null,
            risks_open_questions: aiSummary?.risks_open_questions || null,
            attendance_count: 0,
            processing_status: 'processing'
          })
          .select()
          .single();

        if (meetingError) {
          throw new Error(`Failed to create meeting: ${meetingError.message}`);
        }

        console.log(`✓ Meeting created (ID: ${meeting.id})`);

        // Process attendance
        console.log('Processing attendance...');
        const attendanceResults = await processAttendance(
          supabaseClient,
          meeting.id,
          uniqueParticipants
        );

        const successfulMatches = attendanceResults.filter(r => r.status === 'success').length;

        // Update meeting with attendance count
        await supabaseClient
          .from('meetings')
          .update({
            attendance_count: successfulMatches,
            processing_status: 'completed'
          })
          .eq('id', meeting.id);

        console.log(`✓ Attendance processed: ${successfulMatches} matched`);

        results.processed++;
        results.meetings.push({
          zoom_meeting_id: zoomMeeting.id,
          title: zoomMeeting.topic,
          status: 'success',
          meeting_id: meeting.id,
          host: meetingHostName,
          attendees: uniqueParticipants.length,
          matched: successfulMatches
        });

      } catch (error) {
        console.error(`❌ Failed to process meeting:`, error);
        results.failed++;
        results.meetings.push({
          zoom_meeting_id: zoomMeeting.id,
          title: zoomMeeting.topic,
          status: 'failed',
          error: error.message
        });
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 IMPORT COMPLETE');
    console.log('='.repeat(60));
    console.log(`Total: ${results.total}`);
    console.log(`Processed: ${results.processed}`);
    console.log(`Skipped: ${results.skipped}`);
    console.log(`Failed: ${results.failed}`);
    console.log('='.repeat(60));

    return new Response(JSON.stringify(results), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });

  } catch (error) {
    console.error('Fatal error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      details: error.stack
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    });
  }
});

// ==================== ZOOM API FUNCTIONS ====================

async function getZoomAccessToken() {
  const clientId = Deno.env.get('ZOOM_CLIENT_ID');
  const clientSecret = Deno.env.get('ZOOM_CLIENT_SECRET');
  const accountId = Deno.env.get('ZOOM_ACCOUNT_ID');

  if (!clientId || !clientSecret || !accountId) {
    throw new Error('Missing Zoom credentials in environment');
  }

  const credentials = btoa(`${clientId}:${clientSecret}`);
  const response = await fetch('https://zoom.us/oauth/token', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${credentials}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: `grant_type=account_credentials&account_id=${accountId}`
  });

  if (!response.ok) {
    throw new Error(`Zoom OAuth error: ${response.status}`);
  }

  const data = await response.json();
  return data.access_token;
}

async function fetchZoomMeetings(accessToken: string, fromDate?: string, toDate?: string) {
  const userId = 'me'; // Gets meetings for the account
  const meetings = [];
  let nextPageToken = null;

  // Build query parameters
  const params = new URLSearchParams({
    type: 'past',
    page_size: '300' // Max allowed
  });

  if (fromDate) params.append('from', fromDate);
  if (toDate) params.append('to', toDate);

  do {
    if (nextPageToken) params.set('next_page_token', nextPageToken);

    const response = await fetch(
      `https://api.zoom.us/v2/users/${userId}/meetings?${params}`,
      { headers: { 'Authorization': `Bearer ${accessToken}` } }
    );

    if (!response.ok) {
      throw new Error(`Zoom API error: ${response.status}`);
    }

    const data = await response.json();
    meetings.push(...(data.meetings || []));
    
    nextPageToken = data.next_page_token;
    console.log(`Fetched ${meetings.length} meetings so far...`);
    
  } while (nextPageToken);

  return meetings;
}

async function fetchZoomMeetingDetails(accessToken: string, meetingId: string) {
  const response = await fetch(
    `https://api.zoom.us/v2/past_meetings/${meetingId}`,
    { headers: { 'Authorization': `Bearer ${accessToken}` } }
  );

  if (!response.ok) {
    if (response.status === 404) return null;
    throw new Error(`Zoom API error: ${response.status}`);
  }

  return await response.json();
}

async function fetchZoomParticipants(accessToken: string, meetingId: string) {
  try {
    const participants = [];
    let nextPageToken = null;

    do {
      const params = new URLSearchParams({ page_size: '300' });
      if (nextPageToken) params.set('next_page_token', nextPageToken);

      const response = await fetch(
        `https://api.zoom.us/v2/report/meetings/${meetingId}/participants?${params}`,
        { headers: { 'Authorization': `Bearer ${accessToken}` } }
      );

      if (!response.ok) {
        if (response.status === 404) {
          console.log('No participant report available for this meeting');
          return [];
        }
        throw new Error(`Zoom participants API error: ${response.status}`);
      }

      const data = await response.json();
      participants.push(...(data.participants || []));
      nextPageToken = data.next_page_token;

    } while (nextPageToken);

    return participants;
  } catch (error) {
    console.error('Error fetching participants:', error);
    return [];
  }
}

async function fetchZoomRecordings(accessToken: string, meetingId: string) {
  try {
    const response = await fetch(
      `https://api.zoom.us/v2/meetings/${meetingId}/recordings`,
      { headers: { 'Authorization': `Bearer ${accessToken}` } }
    );

    if (!response.ok) {
      if (response.status === 404) {
        console.log('No recordings found for this meeting');
        return null;
      }
      throw new Error(`Zoom recordings API error: ${response.status}`);
    }

    const data = await response.json();
    
    // Find the video recording and transcript
    let recordingUrl = null;
    let embedUrl = null;
    let transcriptUrl = null;

    if (data.recording_files && data.recording_files.length > 0) {
      // Find shared_screen_with_speaker_view or first video
      const videoFile = data.recording_files.find(f => 
        f.recording_type === 'shared_screen_with_speaker_view' || 
        f.file_type === 'MP4'
      );
      
      if (videoFile) {
        recordingUrl = videoFile.download_url;
        embedUrl = videoFile.play_url;
      }

      // Find transcript file
      const transcriptFile = data.recording_files.find(f => 
        f.file_type === 'TRANSCRIPT' || 
        f.recording_type === 'audio_transcript'
      );
      
      if (transcriptFile) {
        transcriptUrl = transcriptFile.download_url;
      }
    }

    return {
      recording_url: recordingUrl,
      embed_url: embedUrl,
      transcript_url: transcriptUrl
    };

  } catch (error) {
    console.error('Error fetching recordings:', error);
    return null;
  }
}

async function downloadZoomTranscript(accessToken: string, transcriptUrl: string) {
  try {
    const response = await fetch(transcriptUrl, {
      headers: { 'Authorization': `Bearer ${accessToken}` }
    });

    if (!response.ok) {
      throw new Error(`Failed to download transcript: ${response.status}`);
    }

    const text = await response.text();
    
    // Zoom transcripts are in VTT format - extract text content
    return parseVTTTranscript(text);

  } catch (error) {
    console.error('Error downloading transcript:', error);
    return null;
  }
}

function parseVTTTranscript(vtt: string): string {
  // Remove WEBVTT header and timing lines, keep only dialogue
  const lines = vtt.split('\n');
  const textLines = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    
    // Skip empty lines, headers, and timing lines
    if (!line || line.startsWith('WEBVTT') || line.includes('-->') || /^\d+$/.test(line)) {
      continue;
    }
    
    textLines.push(line);
  }
  
  return textLines.join('\n');
}

// ==================== OPENAI FUNCTIONS ====================

async function extractMeetingSummary(transcript: string, meetingTitle: string) {
  if (!OPENAI_API_KEY) {
    console.log('⚠️  No OpenAI API key - skipping AI summary');
    return null;
  }

  try {
    const prompt = `You are analyzing a transcript from a "${meetingTitle}" meeting for Missouri Young Democrats.

Extract the following sections from the transcript:

1. **Executive Recap**: A brief 2-3 sentence overview of the entire meeting
2. **Agenda Reviewed**: List the main topics/agenda items discussed
3. **Discussion Highlights**: Key points from discussions (bullet points)
4. **Decisions & Rationales**: Important decisions made and why (bullet points)
5. **Action Items**: Specific action items with assignees if mentioned (bullet points)
6. **Risks & Open Questions**: Any concerns, blockers, or unresolved questions (bullet points)

Format your response as JSON with these exact keys:
{
  "executive_recap": "string",
  "agenda_reviewed": "string",
  "discussion_highlights": "string",
  "decisions_rationales": "string",
  "action_items": "string",
  "risks_open_questions": "string"
}

If a section has no relevant content, use null.

TRANSCRIPT:
${transcript.slice(0, 15000)}`; // Limit to ~15k chars to stay within token limits

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        messages: [
          {
            role: 'system',
            content: 'You are a meeting minutes expert. Extract structured information from transcripts accurately and concisely.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.3,
        response_format: { type: 'json_object' }
      })
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(`OpenAI API error: ${JSON.stringify(error)}`);
    }

    const data = await response.json();
    const content = data.choices[0].message.content;
    
    return JSON.parse(content);

  } catch (error) {
    console.error('Error extracting summary:', error);
    return null;
  }
}

async function inferMeetingHost(transcript: string, meetingTitle: string, participantNames: string[]) {
  if (!OPENAI_API_KEY) {
    console.log('⚠️  No OpenAI API key - skipping host inference');
    return null;
  }

  try {
    const prompt = `You are analyzing a meeting transcript to identify the host/chair/leader.

Meeting: "${meetingTitle}"
Participants: ${participantNames.join(', ')}

Based on the transcript, who was most likely the meeting host/chair? Look for:
- Who called the meeting to order
- Who facilitated discussions
- Who managed the agenda
- Who had the most speaking time in leadership capacity

Respond with ONLY the person's name from the participant list, or "UNKNOWN" if unclear.

TRANSCRIPT START:
${transcript.slice(0, 8000)}
TRANSCRIPT END`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: OPENAI_MODEL,
        messages: [
          {
            role: 'system',
            content: 'You are an expert at analyzing meeting dynamics. Identify the meeting host accurately.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        temperature: 0.1,
        max_tokens: 50
      })
    });

    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const data = await response.json();
    const inferredHost = data.choices[0].message.content.trim();
    
    if (inferredHost === 'UNKNOWN' || inferredHost.length === 0) {
      return null;
    }

    return inferredHost;

  } catch (error) {
    console.error('Error inferring host:', error);
    return null;
  }
}

// ==================== FILTER FALSE STARTS ====================

function filterFalseStarts(meetings: any[], minDurationMinutes: number) {
  console.log('\n🔍 Filtering false starts and duplicate meetings...');
  
  // Group meetings by meeting ID + date (to find duplicates/false starts)
  const meetingGroups = new Map<string, any[]>();
  
  for (const meeting of meetings) {
    const meetingId = meeting.id || meeting.uuid;
    const meetingDate = new Date(meeting.start_time).toDateString();
    const key = `${meetingId}_${meetingDate}`;
    
    if (!meetingGroups.has(key)) {
      meetingGroups.set(key, []);
    }
    meetingGroups.get(key)!.push(meeting);
  }

  const filteredMeetings = [];
  let falseStartsRemoved = 0;
  let duplicatesRemoved = 0;

  for (const [key, group] of meetingGroups) {
    if (group.length === 1) {
      const meeting = group[0];
      
      // Check if it's too short to be a real meeting
      if (meeting.duration && meeting.duration < minDurationMinutes) {
        console.log(`⏭️  Skipping false start: "${meeting.topic}" (${meeting.duration} min, ID: ${meeting.id})`);
        falseStartsRemoved++;
        continue;
      }
      
      filteredMeetings.push(meeting);
    } else {
      // Multiple meetings with same ID on same day - keep the longest one
      console.log(`\n🔄 Found ${group.length} instances of "${group[0].topic}":`);
      
      // Sort by duration (longest first)
      group.sort((a, b) => (b.duration || 0) - (a.duration || 0));
      
      for (let i = 0; i < group.length; i++) {
        const meeting = group[i];
        const duration = meeting.duration || 0;
        
        if (i === 0) {
          // Keep the longest one
          if (duration >= minDurationMinutes) {
            console.log(`   ✓ Keeping: ${duration} min (ID: ${meeting.id})`);
            filteredMeetings.push(meeting);
          } else {
            console.log(`   ⏭️  All instances too short, skipping (longest: ${duration} min)`);
            falseStartsRemoved++;
          }
        } else {
          // Skip shorter duplicates
          console.log(`   ⏭️  Skipping duplicate: ${duration} min (false start)`);
          duplicatesRemoved++;
        }
      }
    }
  }

  console.log('\n📊 Filter results:');
  console.log(`   • False starts removed: ${falseStartsRemoved}`);
  console.log(`   • Duplicates removed: ${duplicatesRemoved}`);
  console.log(`   • Valid meetings: ${filteredMeetings.length}\n`);

  return filteredMeetings;
}

// ==================== HELPER FUNCTIONS (FROM EXISTING FUNCTION) ====================

function normalizeString(str: string): string {
  return str
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]/g, '')
    .trim();
}

function normalizeEmail(email: string): string {
  return email.toLowerCase().trim();
}

function filterIgnoredAttendees(participants: any[]) {
  return participants.filter(p => {
    const email = p.user_email || p.email || p.participant_email;
    const name = p.name || p.user_name || p.participant_name || '';

    if (email && IGNORED_ATTENDEES.emails.some(ignored => 
      email.toLowerCase().includes(ignored.toLowerCase())
    )) {
      return false;
    }

    if (IGNORED_ATTENDEES.names.some(ignored => 
      name.toLowerCase().includes(ignored.toLowerCase())
    )) {
      return false;
    }

    return true;
  });
}

function deduplicateParticipants(participants: any[]) {
  const participantMap = new Map();

  for (const participant of participants) {
    const participantName = participant.name || participant.user_name || participant.participant_name;
    if (!participantName || participantName.trim().length === 0) continue;
    if (participant.status === 'in_waiting_room') continue;

    const participantEmail = participant.user_email || participant.email || participant.participant_email;
    const joinTime = participant.join_time || new Date().toISOString();
    const leaveTime = participant.leave_time || new Date().toISOString();
    const duration = participant.duration || 0;

    const nameKey = normalizeString(participantName);

    if (participantMap.has(nameKey)) {
      const existing = participantMap.get(nameKey);
      existing.totalDuration += duration;
      existing.numberOfJoins += 1;
      
      if (participantEmail && !existing.email) {
        existing.email = participantEmail;
      }
      
      if (new Date(joinTime) < new Date(existing.firstJoin)) {
        existing.firstJoin = joinTime;
      }
      if (new Date(leaveTime) > new Date(existing.lastLeave)) {
        existing.lastLeave = leaveTime;
      }
    } else {
      participantMap.set(nameKey, {
        name: participantName,
        email: participantEmail || undefined,
        totalDuration: duration,
        firstJoin: joinTime,
        lastLeave: leaveTime,
        numberOfJoins: 1,
        isHost: false
      });
    }
  }

  return Array.from(participantMap.values());
}

async function storeTranscript(supabaseClient: any, meetingTitle: string, meetingDate: string, transcriptText: string) {
  const date = new Date(meetingDate);
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const year = date.getFullYear();

  const cleanTitle = meetingTitle.replace(/[^a-zA-Z0-9\s-]/g, '').trim();
  const fileName = `transcripts/${cleanTitle}/${month}/${day}/${year}.txt`;

  const encoder = new TextEncoder();
  const data = encoder.encode(transcriptText);

  const { error: uploadError } = await supabaseClient.storage
    .from('meetings')
    .upload(fileName, data, {
      contentType: 'text/plain',
      upsert: true
    });

  if (uploadError) {
    throw new Error(`Failed to store transcript: ${uploadError.message}`);
  }

  return fileName;
}

// Copy the host identification and attendance processing functions from your existing code
// (identifyAndMatchHost, processAttendance, findMemberWithFallback, etc.)
// These are exactly the same as in your working function

async function identifyAndMatchHost(supabaseClient: any, hostHint: string, meetingTitle: string, participants: any[]) {
  // [Copy the full implementation from your existing function]
  // ... (same code as in process-meeting/index.ts)
  console.log(`Host identification for: ${hostHint}`);
  const normalizedHint = normalizeString(hostHint);
  
  const { data: allMembers } = await supabaseClient
    .from('members')
    .select('id, name, email, school_email, committee');

  if (!allMembers || allMembers.length === 0) return null;

  const matchingMembers = [];
  
  for (const member of allMembers) {
    const normalizedName = normalizeString(member.name);
    if (normalizedName === normalizedHint || 
        normalizedName.includes(normalizedHint) || 
        normalizedHint.includes(normalizedName)) {
      matchingMembers.push({ member, score: 1.0 });
    }
  }

  if (matchingMembers.length === 0) return null;

  const selectedMember = matchingMembers[0].member;
  
  // Find matching participant
  let matchedParticipant = null;
  for (const participant of participants) {
    if (participant.email) {
      const participantEmail = normalizeEmail(participant.email);
      if ((selectedMember.email && participantEmail === normalizeEmail(selectedMember.email)) ||
          (selectedMember.school_email && participantEmail === normalizeEmail(selectedMember.school_email))) {
        matchedParticipant = participant;
        break;
      }
    }
    
    if (normalizeString(participant.name) === normalizeString(selectedMember.name)) {
      matchedParticipant = participant;
      break;
    }
  }

  return {
    memberId: selectedMember.id,
    memberName: selectedMember.name,
    memberEmail: selectedMember.email || selectedMember.school_email || null,
    participant: matchedParticipant
  };
}

async function processAttendance(supabaseClient: any, meetingId: string, participants: any[]) {
  const results = [];

  for (const participant of participants) {
    try {
      let member = null;
      
      if (participant.memberId) {
        member = {
          id: participant.memberId,
          name: participant.name,
          matched_by: 'host_identified'
        };
      } else {
        member = await findMemberWithFallback(supabaseClient, participant.name, participant.email);
      }

      if (!member) {
        results.push({
          name: participant.name,
          email: participant.email,
          status: 'no_match',
          duration: Math.round(participant.totalDuration / 60),
          is_host: participant.isHost || false
        });
        continue;
      }

      const { data: existingAttendance } = await supabaseClient
        .from('meeting_attendance')
        .select('id')
        .eq('meeting_id', meetingId)
        .eq('member_id', member.id)
        .maybeSingle();

      if (existingAttendance) {
        if (participant.isHost) {
          await supabaseClient
            .from('meeting_attendance')
            .update({ is_host: true })
            .eq('id', existingAttendance.id);
        }
        results.push({
          name: participant.name,
          matched_member: member.name,
          status: 'already_recorded',
          is_host: participant.isHost || false
        });
        continue;
      }

      const { error: attendanceError } = await supabaseClient
        .from('meeting_attendance')
        .insert({
          meeting_id: meetingId,
          member_id: member.id,
          total_duration_minutes: Math.round(participant.totalDuration / 60),
          first_join_time: participant.firstJoin,
          last_leave_time: participant.lastLeave,
          number_of_joins: participant.numberOfJoins,
          zoom_display_name: participant.name,
          zoom_email: participant.email || null,
          matched_by: member.matched_by,
          is_host: participant.isHost || false
        });

      if (!attendanceError) {
        results.push({
          name: participant.name,
          matched_member: member.name,
          member_id: member.id,
          matched_by: member.matched_by,
          duration_minutes: Math.round(participant.totalDuration / 60),
          is_host: participant.isHost || false,
          status: 'success'
        });
      }
    } catch (error) {
      results.push({
        name: participant.name,
        status: 'error',
        error: error.message
      });
    }
  }

  return results;
}

async function findMemberWithFallback(supabaseClient: any, zoomName: string, zoomEmail: string) {
  if (zoomEmail && zoomEmail.trim().length > 0) {
    const normalizedEmail = normalizeEmail(zoomEmail);
    
    const { data: emailMatch } = await supabaseClient
      .from('members')
      .select('id, name, email')
      .eq('email', normalizedEmail)
      .limit(1)
      .maybeSingle();

    if (emailMatch) {
      return { ...emailMatch, matched_by: 'email' };
    }
  }

  const { data: nameMatch } = await supabaseClient
    .from('members')
    .select('id, name, email')
    .ilike('name', zoomName.trim())
    .limit(1)
    .maybeSingle();

  if (nameMatch) {
    return { ...nameMatch, matched_by: 'name' };
  }

  return null;
}