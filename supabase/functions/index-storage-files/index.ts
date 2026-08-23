// Wave 4 access-audit 2026-04-24: user-JWT + is_staff() gate OR x-cron-secret + audit_log.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { geminiText } from "../_shared/gemini.ts";
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const supabase = createClient(supabaseUrl, supabaseServiceKey);
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret"
};

async function requireAuthorized(req) {
  const cronSecret = Deno.env.get("CRON_SECRET");
  const presented = req.headers.get("x-cron-secret") ?? "";
  if (cronSecret && presented && presented === cronSecret) {
    return { actorId: null, actorRole: "service_role" };
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer /i, "").trim();
  if (!jwt) {
    return {
      error: new Response(JSON.stringify({ error: "Missing Authorization header or x-cron-secret" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } }
  });
  const { data: userData, error: authErr } = await userClient.auth.getUser(jwt);
  if (authErr || !userData?.user) {
    return {
      error: new Response(JSON.stringify({ error: "Invalid or expired JWT" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  const { data: staffCheck, error: staffErr } = await userClient.rpc("is_staff");
  if (staffErr || staffCheck !== true) {
    return {
      error: new Response(JSON.stringify({ error: "Forbidden — staff access required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    };
  }
  return { actorId: userData.user.id, actorRole: "authenticated" };
}
// Max file sizes for OCR model processing (images are memory-heavy due to base64 overhead)
const MAX_IMAGE_SIZE_MB = 4; // Images: PNG, JPG, GIF, WEBP - very memory intensive
const MAX_PDF_SIZE_MB = 10; // PDFs can be a bit larger
const MAX_OTHER_SIZE_MB = 20; // Text files, etc.
function getMaxSizeForExtension(extension) {
  const imageExtensions = [
    "png",
    "jpg",
    "jpeg",
    "gif",
    "webp"
  ];
  if (imageExtensions.includes(extension)) {
    return MAX_IMAGE_SIZE_MB;
  }
  if (extension === "pdf") {
    return MAX_PDF_SIZE_MB;
  }
  return MAX_OTHER_SIZE_MB;
}
async function extractTextWithModel(fileData, fileName, mediaType) {
  try {
    const arrayBuffer = await fileData.arrayBuffer();
    const uint8Array = new Uint8Array(arrayBuffer);
    const fileSizeMB = uint8Array.length / (1024 * 1024);
    const ext = fileName.split('.').pop()?.toLowerCase() || '';
    const maxSize = getMaxSizeForExtension(ext);
    // Skip files too large for memory
    if (fileSizeMB > maxSize) {
      console.log(`File too large for processing: ${fileName} (${fileSizeMB.toFixed(2)}MB > ${maxSize}MB limit for ${ext})`);
      return null;
    }
    const base64Data = base64Encode(uint8Array);
    // GIF IS DELIBERATELY REFUSED HERE AND ANTHROPIC USED TO ACCEPT IT.
    //
    // Gemini's inline image types are png, jpeg, webp, heic and heif. gif is not
    // one of them, so a gif that used to be OCR'd will now be skipped with this
    // line in the log rather than 400ing inside the model call. That is the one
    // capability this migration loses, and it is named out loud rather than
    // left to be discovered from an error rate.
    //
    // Nothing else changes: pdf, png, jpg/jpeg and webp all carry over, and heic
    // is still refused exactly as before.
    let modelMediaType = mediaType;
    if (ext === 'pdf') {
      modelMediaType = 'application/pdf';
    } else if (ext === 'png') {
      modelMediaType = 'image/png';
    } else if (ext === 'jpg' || ext === 'jpeg') {
      modelMediaType = 'image/jpeg';
    } else if (ext === 'webp') {
      modelMediaType = 'image/webp';
    } else if (ext === 'gif') {
      console.log(`GIF is not a supported inline type for OCR, skipping: ${fileName}`);
      return null;
    } else if (ext === 'heic') {
      console.log(`HEIC format not supported for OCR: ${fileName}`);
      return null;
    }
    const isPdf = modelMediaType === 'application/pdf';
    const isImage = modelMediaType.startsWith('image/');
    if (!isPdf && !isImage) {
      console.log(`Unsupported media type for OCR: ${modelMediaType}`);
      return null;
    }
    // A contentType passed through from storage can still be a type the model
    // rejects, for example image/gif or image/svg+xml on a file whose extension
    // did not match any branch above. Refuse those here rather than in the model.
    const ALLOWED_IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp'];
    if (isImage && !ALLOWED_IMAGE_TYPES.includes(modelMediaType)) {
      console.log(`Unsupported image type for OCR: ${modelMediaType} (${fileName})`);
      return null;
    }
    console.log(`Sending for OCR: ${fileName} (${fileSizeMB.toFixed(2)}MB, ${modelMediaType})`);
    const prompt = isPdf
      ? "Extract ALL text content from this PDF document. Include all headings, paragraphs, lists, tables, and any other text. Preserve the structure as much as possible. Return ONLY the extracted text, no commentary."
      : "Extract ALL text visible in this image. This may be a screenshot, document scan, or photo containing text. Return ONLY the extracted text exactly as it appears, preserving structure. If there is no readable text, respond with 'NO_TEXT_FOUND'.";
    let extractedText;
    try {
      extractedText = await geminiText({
        prompt,
        media: [{ mimeType: modelMediaType, data: base64Data }],
        maxTokens: 8192,
        // OCR is transcription, not composition. The reply should be what is on
        // the page and nothing invented around it.
        temperature: 0
      });
    } catch (apiErr) {
      // Preserved from the Anthropic version: a failed extraction returns null
      // and the file is indexed without OCR text rather than failing the run.
      // callGemini also throws on an empty reply, which is the case the image
      // OCR prompt's NO_TEXT_FOUND answer is supposed to cover, so both land
      // here and both mean the same thing to the caller.
      console.error(`OCR model error for ${fileName}:`, apiErr instanceof Error ? apiErr.message : String(apiErr));
      return null;
    }
    extractedText = extractedText.trim();
    if (extractedText === "NO_TEXT_FOUND" || !extractedText) {
      console.log(`No text found in: ${fileName}`);
      return null;
    }
    console.log(`Extracted ${extractedText.length} chars from ${fileName}`);
    return extractedText;
  } catch (err) {
    console.error(`Error extracting text for OCR:`, err);
    return null;
  }
}
async function extractTextFromFile(bucket, path, contentType, fileSize) {
  try {
    const fileName = path.split("/").pop() || path;
    const extension = fileName.split(".").pop()?.toLowerCase() || "";
    // Check file size before downloading for images/PDFs
    const fileSizeMB = (fileSize || 0) / (1024 * 1024);
    const maxSize = getMaxSizeForExtension(extension);
    if ([
      "png",
      "jpg",
      "jpeg",
      "gif",
      "webp",
      "pdf"
    ].includes(extension) && fileSizeMB > maxSize) {
      console.log(`Skipping large file before download: ${path} (${fileSizeMB.toFixed(2)}MB > ${maxSize}MB for ${extension})`);
      return null;
    }
    const { data, error } = await supabase.storage.from(bucket).download(path);
    if (error || !data) {
      console.error(`Failed to download ${bucket}/${path}:`, error);
      return null;
    }
    // Plain text files - read directly
    if (contentType?.includes("text") || [
      "txt",
      "md",
      "csv"
    ].includes(extension)) {
      return await data.text();
    }
    // Spreadsheets - store metadata for now
    if ([
      "xls",
      "xlsx"
    ].includes(extension)) {
      return `Spreadsheet: ${fileName}\nPath: ${path}\nBucket: ${bucket}\nSize: ${data.size} bytes\n\n(Spreadsheet text extraction pending)`;
    }
    // PDFs - use the OCR model for extraction
    if (contentType?.includes("pdf") || extension === "pdf") {
      console.log(`Extracting PDF text: ${path}`);
      const text = await extractTextWithModel(data, fileName, "application/pdf");
      if (text) {
        return `PDF: ${fileName}\n\n${text}`;
      }
      return null;
    }
    // Word docs - placeholder
    if ([
      "docx",
      "doc"
    ].includes(extension)) {
      return `Word Document: ${fileName}\nPath: ${path}\nBucket: ${bucket}\nSize: ${data.size} bytes\n\n(Word document - text extraction pending)`;
    }
    // Images - use the OCR model
    if (contentType?.startsWith("image/") || [
      "png",
      "jpg",
      "jpeg",
      "gif",
      "webp"
    ].includes(extension)) {
      console.log(`Extracting image text with OCR: ${path}`);
      const text = await extractTextWithModel(data, fileName, contentType || `image/${extension}`);
      if (text) {
        return `Image: ${fileName}\n\n${text}`;
      }
      return null;
    }
    if (extension === "heic") {
      console.log(`Skipping HEIC file (not supported): ${path}`);
      return null;
    }
    return null;
  } catch (err) {
    console.error(`Error extracting text from ${bucket}/${path}:`, err);
    return null;
  }
}
async function listAllFiles(bucket, folder = "", allFiles = []) {
  const { data, error } = await supabase.storage.from(bucket).list(folder, {
    limit: 1000
  });
  if (error) {
    console.error(`Error listing ${bucket}/${folder}:`, error);
    return allFiles;
  }
  for (const item of data || []){
    const itemPath = folder ? `${folder}/${item.name}` : item.name;
    if (item.id === null) {
      await listAllFiles(bucket, itemPath, allFiles);
    } else {
      allFiles.push({
        ...item,
        fullPath: itemPath
      });
    }
  }
  return allFiles;
}
function simpleHash(str) {
  let hash = 0;
  for(let i = 0; i < str.length; i++){
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash;
  }
  return Math.abs(hash).toString(16).padStart(8, "0");
}
async function upsertDocument(sourceType, sourceTable, sourceId, title, content, metadata, sourceBucket, sourceFilePath) {
  if (!content || content.trim().length < 10) {
    return null;
  }
  const contentHash = simpleHash(content);
  let existingQuery = supabase.from("knowledge_documents").select("id, content_hash").eq("chunk_index", 0);
  if (sourceBucket && sourceFilePath) {
    existingQuery = existingQuery.eq("source_bucket", sourceBucket).eq("source_file_path", sourceFilePath);
  } else if (sourceTable && sourceId) {
    existingQuery = existingQuery.eq("source_type", sourceType).eq("source_table", sourceTable).eq("source_id", sourceId);
  }
  const { data: existing } = await existingQuery.maybeSingle();
  if (existing) {
    if (existing.content_hash === contentHash) {
      return existing.id;
    }
    await supabase.from("knowledge_documents").update({
      title,
      content,
      content_hash: contentHash,
      metadata,
      embedding_status: "pending",
      embedding: null,
      updated_at: new Date().toISOString()
    }).eq("id", existing.id);
    await supabase.from("knowledge_embedding_queue").upsert({
      document_id: existing.id,
      priority: 50,
      status: "pending"
    }, {
      onConflict: "document_id"
    });
    return existing.id;
  }
  const { data: newDoc, error: insertError } = await supabase.from("knowledge_documents").insert({
    source_type: sourceType,
    source_table: sourceTable,
    source_id: sourceId,
    source_bucket: sourceBucket,
    source_file_path: sourceFilePath,
    title,
    content,
    content_hash: contentHash,
    metadata
  }).select("id").single();
  if (insertError) {
    console.error("Insert error:", insertError);
    return null;
  }
  await supabase.from("knowledge_embedding_queue").insert({
    document_id: newDoc.id,
    priority: 100,
    status: "pending"
  });
  return newDoc.id;
}
async function processFile(bucket, file, config) {
  const filePath = file.fullPath || file.name;
  const fileName = filePath.split("/").pop() || filePath;
  const extension = fileName.split(".").pop()?.toLowerCase() || "";
  // 1. First check: extension allowed?
  if (!config.include_extensions.includes(extension)) {
    return {
      status: "skipped",
      reason: `extension_not_allowed: ${extension}`
    };
  }
  // 2. Build file hash for comparison
  const fileHash = `${file.metadata?.size || 0}-${file.updated_at || ""}-${filePath}`;
  // 3. Check if file already exists with same hash (BEFORE size check!)
  const { data: existing } = await supabase.from("knowledge_indexed_files").select("id, file_hash, status").eq("bucket_name", bucket).eq("file_path", filePath).maybeSingle();
  if (existing?.file_hash === fileHash) {
    // File unchanged - skip silently (don't even log, it's normal)
    return {
      status: "skipped",
      reason: "unchanged"
    };
  }
  // 4. Now check file size for images/PDFs
  const fileSizeMB = (file.metadata?.size || 0) / (1024 * 1024);
  const needsSizeCheck = [
    "png",
    "jpg",
    "jpeg",
    "gif",
    "webp",
    "pdf"
  ].includes(extension);
  const maxSize = getMaxSizeForExtension(extension);
  if (needsSizeCheck && fileSizeMB > maxSize) {
    console.log(`Skipping large ${extension}: ${filePath} (${fileSizeMB.toFixed(2)}MB > ${maxSize}MB)`);
    await supabase.from("knowledge_indexed_files").upsert({
      bucket_name: bucket,
      file_path: filePath,
      file_name: fileName,
      file_extension: extension,
      file_size_bytes: file.metadata?.size,
      file_hash: fileHash,
      status: "skipped",
      error_message: `File too large: ${fileSizeMB.toFixed(2)}MB > ${maxSize}MB limit for ${extension}`,
      content_type: file.metadata?.mimetype,
      last_modified_at: file.updated_at
    }, {
      onConflict: "bucket_name,file_path"
    });
    return {
      status: "skipped",
      reason: `file_too_large: ${fileSizeMB.toFixed(1)}MB > ${maxSize}MB`
    };
  }
  console.log(`Processing: ${bucket}/${filePath} (${extension}, ${fileSizeMB.toFixed(2)}MB)`);
  const content = await extractTextFromFile(bucket, filePath, file.metadata?.mimetype, file.metadata?.size);
  console.log(`Content extracted: ${content ? content.length + " chars" : "NULL"}`);
  if (!content || content.length < 10) {
    await supabase.from("knowledge_indexed_files").upsert({
      bucket_name: bucket,
      file_path: filePath,
      file_name: fileName,
      file_extension: extension,
      file_size_bytes: file.metadata?.size,
      file_hash: fileHash,
      status: "skipped",
      error_message: "No extractable content",
      content_type: file.metadata?.mimetype,
      last_modified_at: file.updated_at
    }, {
      onConflict: "bucket_name,file_path"
    });
    return {
      status: "skipped",
      reason: "no_content"
    };
  }
  const docId = await upsertDocument("storage_file", null, null, fileName, content, {
    bucket: bucket,
    path: filePath,
    extension: extension,
    size: file.metadata?.size,
    content_type: file.metadata?.mimetype
  }, bucket, filePath);
  if (!docId) {
    return {
      status: "failed",
      reason: "upsert_failed"
    };
  }
  console.log(`SUCCESS: Indexed ${filePath} as ${docId}`);
  await supabase.from("knowledge_indexed_files").upsert({
    bucket_name: bucket,
    file_path: filePath,
    file_name: fileName,
    file_extension: extension,
    file_size_bytes: file.metadata?.size,
    file_hash: fileHash,
    status: "completed",
    document_ids: [
      docId
    ],
    content_type: file.metadata?.mimetype,
    last_modified_at: file.updated_at
  }, {
    onConflict: "bucket_name,file_path"
  });
  return {
    status: "indexed",
    document_id: docId
  };
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  const gate = await requireAuthorized(req);
  if ("error" in gate) return gate.error;
  const { actorId, actorRole } = gate;
  try {
    let bucketName = null;
    let limit = 50;
    // Audit log (non-blocking)
    supabase.from("audit_log").insert({
      action: "EDGE_FN",
      actor_id: actorId,
      actor_role: actorRole,
      schema_name: "public",
      table_name: "edge_fn:index-storage-files",
      row_id: null,
      context: {
        event: "index-storage-files"
      }
    }).then(() => {}).catch((e) => console.error("[index-storage-files] audit_log insert failed:", e));
    if (req.method === "POST") {
      try {
        const body = await req.json();
        bucketName = body.bucketName || null;
        limit = body.limit || 50;
      } catch  {}
    }
    let configQuery = supabase.from("knowledge_bucket_config").select("*").eq("is_enabled", true);
    if (bucketName) {
      configQuery = configQuery.eq("bucket_name", bucketName);
    }
    const { data: configs, error: configError } = await configQuery;
    if (configError || !configs?.length) {
      return new Response(JSON.stringify({
        success: false,
        error: "No enabled bucket configs found"
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const results = {
      buckets: {},
      total_processed: 0,
      total_indexed: 0,
      total_skipped: 0,
      skip_reasons: {}
    };
    for (const config of configs){
      const bucket = config.bucket_name;
      results.buckets[bucket] = {
        files_found: 0,
        files_checked: 0,
        files_indexed: 0,
        files_skipped: 0,
        skip_reasons: {},
        errors: []
      };
      console.log(`Processing bucket: ${bucket}`);
      console.log(`Allowed extensions: ${config.include_extensions}`);
      const allFiles = await listAllFiles(bucket);
      results.buckets[bucket].files_found = allFiles.length;
      console.log(`Found ${allFiles.length} files in ${bucket}`);
      let processedCount = 0;
      for (const file of allFiles){
        if (processedCount >= limit) break;
        results.buckets[bucket].files_checked++;
        try {
          const result = await processFile(bucket, file, config);
          if (result.status === "indexed") {
            results.buckets[bucket].files_indexed++;
            results.total_indexed++;
          } else if (result.status === "skipped") {
            results.buckets[bucket].files_skipped++;
            results.total_skipped++;
            const reason = result.reason || "unknown";
            results.buckets[bucket].skip_reasons[reason] = (results.buckets[bucket].skip_reasons[reason] || 0) + 1;
            results.skip_reasons[reason] = (results.skip_reasons[reason] || 0) + 1;
          }
        } catch (err) {
          console.error(`Error processing ${file.fullPath}:`, err);
          results.buckets[bucket].errors.push(`${file.fullPath}: ${err.message}`);
        }
        processedCount++;
        results.total_processed++;
      }
      await supabase.from("knowledge_bucket_config").update({
        last_sync_at: new Date().toISOString(),
        files_indexed: results.buckets[bucket].files_indexed
      }).eq("bucket_name", bucket);
    }
    return new Response(JSON.stringify({
      success: true,
      ...results
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (err) {
    console.error("Error:", err);
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
