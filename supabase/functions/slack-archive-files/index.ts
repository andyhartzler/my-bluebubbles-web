// ============================================
// EDGE FUNCTION: slack-archive-files
// Downloads Slack files and stores in Supabase
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Download file from Slack
async function downloadSlackFile(url: string, slackToken: string): Promise<ArrayBuffer | null> {
  try {
    const response = await fetch(url, {
      headers: {
        "Authorization": `Bearer ${slackToken}`,
      },
    });

    if (!response.ok) {
      console.error(`Failed to download file: ${response.status} ${response.statusText}`);
      return null;
    }

    return await response.arrayBuffer();
  } catch (error) {
    console.error("Error downloading file:", error);
    return null;
  }
}

// Get file extension from mimetype
function getExtension(mimetype: string, filename: string): string {
  // Try to get from filename first
  const filenameExt = filename.split('.').pop()?.toLowerCase();
  if (filenameExt && filenameExt.length <= 5) {
    return filenameExt;
  }

  // Fall back to mimetype
  const mimeMap: Record<string, string> = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'application/pdf': 'pdf',
    'text/plain': 'txt',
    'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
  };

  return mimeMap[mimetype] || 'bin';
}

// Archive files for a single message
async function archiveMessageFiles(
  message: any,
  supabase: any,
  slackToken: string,
  supabaseUrl: string
): Promise<{ success: boolean; archived: number; errors: number }> {
  const files = message.files || [];
  const archivedFiles: any[] = [];
  let errors = 0;

  for (const file of files) {
    try {
      // Skip if no URL
      if (!file.url_private) {
        console.log(`No url_private for file ${file.id}`);
        errors++;
        continue;
      }

      // Download from Slack
      console.log(`Downloading file: ${file.name} (${file.id})`);
      const fileData = await downloadSlackFile(file.url_private, slackToken);

      if (!fileData) {
        console.error(`Failed to download file ${file.id}`);
        errors++;
        archivedFiles.push({
          ...file,
          archive_error: "Failed to download from Slack",
          archived_at: null,
        });
        continue;
      }

      // Generate storage path: slack-files/{channel_id}/{file_id}.{ext}
      const extension = getExtension(file.mimetype, file.name);
      const storagePath = `${message.slack_channel_id}/${file.id}.${extension}`;

      // Upload to Supabase storage
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from("slack-files")
        .upload(storagePath, fileData, {
          contentType: file.mimetype,
          upsert: true,
        });

      if (uploadError) {
        console.error(`Failed to upload file ${file.id}:`, uploadError);
        errors++;
        archivedFiles.push({
          ...file,
          archive_error: uploadError.message,
          archived_at: null,
        });
        continue;
      }

      // Get public URL
      const { data: publicUrlData } = supabase.storage
        .from("slack-files")
        .getPublicUrl(storagePath);

      // Add archived info
      archivedFiles.push({
        ...file,
        supabase_path: storagePath,
        supabase_url: publicUrlData.publicUrl,
        archived_at: new Date().toISOString(),
      });

      console.log(`Archived file ${file.id} to ${storagePath}`);

      // Small delay to avoid rate limits
      await new Promise((resolve) => setTimeout(resolve, 100));
    } catch (error: any) {
      console.error(`Error processing file ${file.id}:`, error);
      errors++;
      archivedFiles.push({
        ...file,
        archive_error: error.message,
        archived_at: null,
      });
    }
  }

  // Update the message with archived file info
  const { error: updateError } = await supabase
    .from("slack_messages")
    .update({
      files_archived: archivedFiles,
      files_archived_at: new Date().toISOString(),
    })
    .eq("id", message.id);

  if (updateError) {
    console.error(`Failed to update message ${message.id}:`, updateError);
    return { success: false, archived: 0, errors: files.length };
  }

  return {
    success: true,
    archived: archivedFiles.filter((f) => f.supabase_url).length,
    errors,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const slackToken = Deno.env.get("SLACK_BOT_TOKEN");
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    if (!slackToken) {
      throw new Error("Missing SLACK_BOT_TOKEN");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    let body: any = {};
    try {
      const text = await req.text();
      if (text) body = JSON.parse(text);
    } catch (e) {
      // Use defaults
    }

    const messageId = body.messageId; // Optional: process specific message
    const batchSize = body.batchSize || 20;

    let query = supabase
      .from("slack_messages")
      .select("id, slack_channel_id, files, has_files")
      .eq("has_files", true)
      .is("files_archived_at", null)
      .not("files", "is", null)
      .order("posted_at", { ascending: false })
      .limit(batchSize);

    // If specific message requested
    if (messageId) {
      query = supabase
        .from("slack_messages")
        .select("id, slack_channel_id, files, has_files")
        .eq("id", messageId);
    }

    const { data: messages, error: fetchError } = await query;

    if (fetchError) {
      throw fetchError;
    }

    if (!messages || messages.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No messages with unarchived files found",
          processed: 0,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Processing ${messages.length} messages with files`);

    const results = {
      processed: 0,
      totalFilesArchived: 0,
      totalErrors: 0,
      messages: [] as any[],
    };

    for (const message of messages) {
      const result = await archiveMessageFiles(message, supabase, slackToken, supabaseUrl);

      results.processed++;
      results.totalFilesArchived += result.archived;
      results.totalErrors += result.errors;
      results.messages.push({
        id: message.id,
        ...result,
      });

      // Rate limiting between messages
      await new Promise((resolve) => setTimeout(resolve, 200));
    }

    return new Response(
      JSON.stringify({
        success: true,
        ...results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Error in slack-archive-files:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});