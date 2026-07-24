// supabase/functions/process-chartering-submission/index.ts
// ============================================================================
// CHARTERING FORM SUBMISSION PROCESSOR
// ============================================================================
// - Creates chapter record
// - Creates contact as member
// - Processes officers list (required) - adds to members table with officer fields
// - Processes membership list (optional)
// - Converts governing documents and stores in governing-documents bucket
// - Generates chapter-specific membership form when "upload later" selected
// - Smart social media handle to URL conversion
//
// v34 (2026-04-14): support contact_first_name + contact_last_name in
// addition to the legacy contact_name single-field. moydforms' schema was
// split earlier today so new submissions send the split fields; old
// submissions still send contact_name. Both paths must work.
// ============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import mammoth from "https://esm.sh/mammoth@1.6.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

const cloudConvertApiKey = Deno.env.get("CLOUDCONVERT_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function convertToSocialUrl(input: string | null, platform: string): string | null {
  if (!input || input.trim() === '') return null;
  let cleaned = input.trim();
  if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
    if (cleaned.startsWith('http://')) cleaned = cleaned.replace('http://', 'https://');
    return cleaned;
  }
  if (cleaned.startsWith('@')) cleaned = cleaned.substring(1);
  cleaned = cleaned
    .replace(/^(www\.)?twitter\.com\/?/i, '')
    .replace(/^(www\.)?x\.com\/?/i, '')
    .replace(/^(www\.)?instagram\.com\/?/i, '')
    .replace(/^(www\.)?facebook\.com\/?/i, '')
    .replace(/^(www\.)?threads\.net\/?@?/i, '')
    .replace(/^(www\.)?threads\.com\/?@?/i, '')
    .replace(/^(www\.)?tiktok\.com\/?@?/i, '')
    .replace(/^bsky\.app\/profile\/?/i, '')
    .replace(/^(www\.)?/i, '');
  cleaned = cleaned.replace(/\/+$/, '');
  if (cleaned.startsWith('@')) cleaned = cleaned.substring(1);
  if (!cleaned) return null;
  switch (platform.toLowerCase()) {
    case 'twitter':
    case 'x':
      return `https://x.com/${cleaned}`;
    case 'instagram':
      return `https://www.instagram.com/${cleaned}/`;
    case 'facebook':
      return `https://www.facebook.com/${cleaned}`;
    case 'threads':
      return `https://www.threads.net/@${cleaned}`;
    case 'tiktok':
      return `https://www.tiktok.com/@${cleaned}`;
    case 'bluesky':
      if (!cleaned.includes('.')) cleaned = `${cleaned}.bsky.social`;
      return `https://bsky.app/profile/${cleaned}`;
    case 'website':
      if (!cleaned.includes('://')) return `https://${cleaned}`;
      return cleaned;
    default:
      return cleaned;
  }
}

function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .trim()
    .substring(0, 50);
}

function generateAbbreviation(chapterName: string, schoolName: string | null, chapterType: string): string {
  if (chapterType === 'county') {
    const countyName = (chapterName || '')
      .replace(' County Young Democrats', '')
      .replace(' County', '')
      .replace(' City', '')
      .trim();
    const firstLetter = countyName.charAt(0).toUpperCase();
    return `${firstLetter}CYD`;
  }
  if (!schoolName) return chapterName.substring(0, 10);
  const words = schoolName.split(' ');
  if (words.length === 1) return schoolName;
  if (schoolName.includes('University of Missouri')) return 'Mizzou';
  if (schoolName.includes('Washington University')) return 'WashU';
  const skipWords = ['university', 'college', 'of', 'the', 'at', 'community', 'state', 'high', 'school'];
  for (const word of words) {
    if (!skipWords.includes(word.toLowerCase())) return word;
  }
  return words[0];
}

function replaceTemplateVariables(obj: any, variables: Record<string, string>): any {
  if (typeof obj === 'string') {
    let result = obj;
    for (const [key, value] of Object.entries(variables)) {
      result = result.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), value);
    }
    return result;
  }
  if (Array.isArray(obj)) return obj.map(item => replaceTemplateVariables(item, variables));
  if (obj !== null && typeof obj === 'object') {
    const result: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      result[key] = replaceTemplateVariables(value, variables);
    }
    return result;
  }
  return obj;
}

interface GoverningDocResult {
  filePath: string;
  publicUrl: string;
  documentType: string;
  fileSize: number;
  originalFilename: string;
}

async function processGoverningDocument(
  fileData: Blob,
  fileName: string,
  chapterType: string,
  chapterName: string
): Promise<GoverningDocResult> {
  const lowerFileName = fileName.toLowerCase();
  const chapterSlug = slugify(chapterName);
  const today = new Date().toISOString().split('T')[0];
  let docType = 'constitution';
  if (lowerFileName.includes('bylaw')) docType = 'bylaws';
  else if (lowerFileName.includes('charter')) docType = 'charter';
  const targetFileName = `${docType}-${today}.pdf`;
  const targetPath = `${chapterType}/${chapterSlug}/${targetFileName}`;
  let finalBlob: Blob;
  let contentType: string;
  if (lowerFileName.endsWith('.pdf')) {
    finalBlob = fileData;
    contentType = 'application/pdf';
  } else {
    const result = await convertDocumentToPDF(fileData, fileName);
    finalBlob = result.blob;
    contentType = result.contentType;
  }
  const { error: uploadError } = await supabase.storage
    .from('governing-documents')
    .upload(targetPath, finalBlob, { contentType: contentType, upsert: true });
  if (uploadError) throw new Error(`Failed to upload governing document: ${uploadError.message}`);
  const publicUrl = `${supabaseUrl}/storage/v1/object/public/governing-documents/${targetPath}`;
  return {
    filePath: targetPath,
    publicUrl: publicUrl,
    documentType: docType,
    fileSize: finalBlob.size,
    originalFilename: fileName,
  };
}

async function convertDocumentToPDF(
  fileData: Blob,
  fileName: string
): Promise<{ blob: Blob; contentType: string }> {
  if (cloudConvertApiKey) {
    try {
      const pdfBlob = await convertWithCloudConvert(fileData, fileName);
      return { blob: pdfBlob, contentType: 'application/pdf' };
    } catch (error) {
      console.error('CloudConvert failed:', error);
    }
  }
  const lowerFileName = fileName.toLowerCase();
  if (lowerFileName.endsWith('.docx') || lowerFileName.endsWith('.doc')) {
    try {
      const mdBlob = await convertWordToMarkdown(fileData, fileName);
      return { blob: mdBlob, contentType: 'text/markdown' };
    } catch (error) {
      console.error('Word to Markdown conversion failed:', error);
    }
  }
  return { blob: fileData, contentType: 'application/octet-stream' };
}

async function convertWithCloudConvert(fileData: Blob, fileName: string): Promise<Blob> {
  const createJobResponse = await fetch('https://api.cloudconvert.com/v2/jobs', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${cloudConvertApiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      tasks: {
        'import-file': { operation: 'import/upload' },
        'convert': { operation: 'convert', input: 'import-file', output_format: 'pdf' },
        'export-file': { operation: 'export/url', input: 'convert' },
      },
    }),
  });
  if (!createJobResponse.ok) throw new Error(`CloudConvert job creation failed: ${createJobResponse.statusText}`);
  const jobData = await createJobResponse.json();
  const uploadTask = jobData.data.tasks.find((t: any) => t.name === 'import-file');
  const formData = new FormData();
  formData.append('file', fileData, fileName);
  const uploadResponse = await fetch(uploadTask.result.form.url, { method: 'POST', body: formData });
  if (!uploadResponse.ok) throw new Error(`CloudConvert upload failed: ${uploadResponse.statusText}`);
  let attempts = 0;
  const maxAttempts = 30;
  let exportUrl: string | null = null;
  while (attempts < maxAttempts) {
    await new Promise(resolve => setTimeout(resolve, 2000));
    const statusResponse = await fetch(`https://api.cloudconvert.com/v2/jobs/${jobData.data.id}`, {
      headers: { 'Authorization': `Bearer ${cloudConvertApiKey}` },
    });
    const statusData = await statusResponse.json();
    if (statusData.data.status === 'finished') {
      const exportTask = statusData.data.tasks.find((t: any) => t.name === 'export-file');
      if (exportTask?.result?.files?.[0]?.url) {
        exportUrl = exportTask.result.files[0].url;
        break;
      }
    } else if (statusData.data.status === 'error') {
      throw new Error('CloudConvert conversion failed');
    }
    attempts++;
  }
  if (!exportUrl) throw new Error('CloudConvert timed out');
  const pdfResponse = await fetch(exportUrl);
  return await pdfResponse.blob();
}

async function convertWordToMarkdown(fileData: Blob, fileName: string): Promise<Blob> {
  const arrayBuffer = await fileData.arrayBuffer();
  const result = await mammoth.extractRawText({ arrayBuffer });
  if (!result.value || result.value.trim().length === 0) {
    throw new Error('Could not extract text from Word document');
  }
  const header = `# ${fileName.replace(/\.(docx?|doc)$/i, '')}\n\n_Converted from Word document on ${new Date().toISOString().split('T')[0]}_\n\n---\n\n`;
  const markdown = header + result.value;
  return new Blob([markdown], { type: 'text/markdown' });
}

async function createChapterMembershipForm(
  chapterId: string,
  chapterName: string,
  chapterType: string,
  schoolName: string | null
): Promise<{ formId: string; formSlug: string; formUrl: string }> {
  const { data: template, error: templateError } = await supabase
    .from('form_templates')
    .select('*')
    .eq('name', 'Chapter Membership Registration')
    .eq('is_system', true)
    .single();

  if (templateError || !template) {
    throw new Error('Chapter membership form template not found.');
  }

  const baseSlug = `join-${slugify(chapterName)}`;
  const { data: existingForm } = await supabase
    .from('form_schemas')
    .select('slug')
    .eq('slug', baseSlug)
    .single();
  const finalSlug = existingForm ? `${baseSlug}-${Date.now().toString(36)}` : baseSlug;

  const variables = {
    chapter_id: chapterId,
    chapter_name: chapterName,
    chapter_type: chapterType,
    school_name: schoolName || chapterName,
  };

  const templateSchema = typeof template.schema === 'string'
    ? JSON.parse(template.schema)
    : template.schema;
  const templateSettings = typeof template.settings === 'string'
    ? JSON.parse(template.settings)
    : template.settings;

  const populatedSchema = replaceTemplateVariables(templateSchema, variables);
  const populatedSettings = replaceTemplateVariables(templateSettings, variables);

  let formTitle: string;
  let formDescription: string;
  if (chapterType === 'college') {
    formTitle = `Join ${chapterName}`;
    formDescription = `<p>Congratulations\u2014<strong>${chapterName}</strong> is now officially chartered with Missouri Young Democrats!</p>\n<p>By completing this form, you'll be registered as a member of ${chapterName} and officially join the Missouri Young Democrats statewide network.</p>`;
  } else if (chapterType === 'highschool') {
    formTitle = `Join ${chapterName}`;
    formDescription = `<p><strong>${chapterName}</strong> is officially chartered with Missouri Young Democrats!</p>\n<p>Complete this form to become an official member and join our statewide network.</p>`;
  } else {
    formTitle = `Join ${chapterName}`;
    formDescription = `<p>Welcome to <strong>${chapterName}</strong>, your local chapter of Missouri Young Democrats!</p>\n<p>Complete this form to become an official member.</p>`;
  }

  const { data: newForm, error: createError } = await supabase
    .from('form_schemas')
    .insert({
      title: formTitle,
      description: formDescription,
      form_type: 'registration',
      schema: populatedSchema,
      settings: {
        ...populatedSettings,
        chapter_id: chapterId,
        chapter_name: chapterName,
        chapter_type: chapterType,
        school_name: schoolName,
        generated_from_template: template.id,
        generated_at: new Date().toISOString(),
      },
      status: 'active',
      slug: finalSlug,
      require_login: false,
      one_submission_per_user: true,
      show_back_button: true,
      page_count: 1,
    })
    .select('id, slug')
    .single();

  if (createError) {
    throw new Error(`Failed to create chapter membership form: ${createError.message}`);
  }

  await supabase
    .from('form_templates')
    .update({ use_count: (template.use_count || 0) + 1 })
    .eq('id', template.id);

  const formUrl = `https://forms.moyoungdemocrats.org/${finalSlug}`;
  return { formId: newForm.id, formSlug: finalSlug, formUrl: formUrl };
}

function coalesceName(formData: Record<string, unknown>): string | null {
  const legacy = (formData.contact_name as string | undefined)?.trim();
  if (legacy) return legacy;
  const first = (formData.contact_first_name as string | undefined)?.trim();
  const last = (formData.contact_last_name as string | undefined)?.trim();
  const combined = [first, last].filter(Boolean).join(' ').trim();
  return combined || null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers: corsHeaders });
  }

  try {
    const { submission_id, form_data, files } = await req.json();

    console.log("=== CHARTERING SUBMISSION START ===");
    console.log("Submission ID:", submission_id);

    if (!submission_id || !form_data) {
      return new Response(
        JSON.stringify({ error: "Missing submission_id or form_data" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const chapterType = form_data.chapter_type;
    const chapterName = form_data.chapter_name;
    // Name handling supports both the legacy contact_name and the 2026-04-14
    // schema split into contact_first_name + contact_last_name.
    const contactName = coalesceName(form_data);
    const contactEmail = form_data.contact_email;
    const contactPhone = form_data.contact_phone;

    console.log("Chapter Type:", chapterType);
    console.log("Chapter Name:", chapterName);
    console.log("Contact:", contactName, contactEmail);

    let schoolName: string | null = null;
    let city: string | null = null;
    let zip: string | null = null;
    let streetAddress: string | null = null;
    let county: string | null = null;

    if (chapterType === 'county') {
      const countySelection = form_data.county_selection;
      county = countySelection === 'other'
        ? (form_data.county_other_specify || 'Unknown County')
        : countySelection;
      schoolName = chapterName;
      streetAddress = form_data.county_street_address || null;
      city = form_data.county_city || null;
      zip = form_data.county_zip || null;
    } else if (chapterType === 'highschool') {
      schoolName = form_data.hs_school_name;
      city = form_data.hs_city;
      zip = form_data.hs_zip;
      streetAddress = form_data.hs_street_address;
    } else if (chapterType === 'college') {
      schoolName = form_data.college_name;
      city = form_data.college_city;
      zip = form_data.college_zip;
      streetAddress = form_data.college_street_address;
    } else {
      throw new Error(`Invalid chapter type: ${chapterType}`);
    }

    let membershipUploadChoice = 'upload_later';
    if (chapterType === 'county') {
      membershipUploadChoice = form_data.county_membership_upload_choice || 'upload_later';
    } else if (chapterType === 'highschool') {
      membershipUploadChoice = form_data.hs_membership_upload_choice || 'upload_later';
    } else {
      membershipUploadChoice = form_data.college_membership_upload_choice || 'upload_later';
    }

    let governingDocsFilePath: string | null = null;
    let governingDocsFileName: string | null = null;
    let officersFilePath: string | null = null;
    let membershipFilePath: string | null = null;

    if (files && Array.isArray(files)) {
      for (const file of files) {
        const fieldId = (file.field_id || '').toLowerCase();
        if (fieldId.includes('governing') || fieldId.includes('bylaws') || fieldId.includes('constitution')) {
          governingDocsFilePath = file.storage_path;
          governingDocsFileName = file.file_name;
        } else if (fieldId.includes('officer')) {
          officersFilePath = file.storage_path;
        } else if (fieldId.includes('member') && !fieldId.includes('officer')) {
          membershipFilePath = file.storage_path;
        }
      }
    }

    const abbreviation = generateAbbreviation(chapterName, schoolName, chapterType);
    let standardizedName: string;
    if (chapterType === 'county') standardizedName = `${county} County Young Democrats`;
    else if (chapterType === 'highschool') standardizedName = `${schoolName} High School Democrats`;
    else standardizedName = `${schoolName} College Democrats`;

    const socialTwitter = convertToSocialUrl(form_data.social_twitter, 'twitter');
    const socialInstagram = convertToSocialUrl(form_data.social_instagram, 'instagram');
    const socialFacebook = convertToSocialUrl(form_data.social_facebook, 'facebook');
    const socialThreads = convertToSocialUrl(form_data.social_threads, 'threads');
    const socialTiktok = convertToSocialUrl(form_data.social_tiktok, 'tiktok');
    const socialBluesky = convertToSocialUrl(form_data.social_bluesky, 'bluesky');
    const socialWebsite = convertToSocialUrl(form_data.social_website, 'website');

    const { data: existingChapter } = await supabase
      .from('chapters')
      .select('id, chapter_name')
      .eq('chapter_name', chapterName)
      .single();

    let chapterId: string;

    if (existingChapter) {
      const { data: updatedChapter, error: updateError } = await supabase
        .from('chapters')
        .update({
          standardized_name: standardizedName,
          school_name: schoolName,
          county_name: county,
          charter_date: new Date().toISOString().split('T')[0],
          status: 'pending',
          is_chartered: false,
          contact_email: contactEmail,
          street_address: streetAddress,
          city: city,
          zip: zip,
          state: 'MO',
          twitter: socialTwitter,
          instagram: socialInstagram,
          facebook: socialFacebook,
          threads: socialThreads,
          tiktok: socialTiktok,
          bluesky: socialBluesky,
          website: socialWebsite,
          name_abbreviation: abbreviation,
          last_updated: new Date().toISOString(),
        })
        .eq('chapter_name', chapterName)
        .select('id')
        .single();
      if (updateError) throw updateError;
      chapterId = updatedChapter.id;
    } else {
      const { data: newChapter, error: createError } = await supabase
        .from('chapters')
        .insert({
          chapter_name: chapterName,
          standardized_name: standardizedName,
          school_name: schoolName,
          county_name: county,
          chapter_type: chapterType,
          charter_date: new Date().toISOString().split('T')[0],
          status: 'pending',
          is_chartered: false,
          contact_email: contactEmail,
          street_address: streetAddress,
          city: city,
          zip: zip,
          state: 'MO',
          twitter: socialTwitter,
          instagram: socialInstagram,
          facebook: socialFacebook,
          threads: socialThreads,
          tiktok: socialTiktok,
          bluesky: socialBluesky,
          website: socialWebsite,
          name_abbreviation: abbreviation,
        })
        .select('id')
        .single();
      if (createError) throw createError;
      chapterId = newChapter.id;
    }

    let governingDocsPath: string | null = null;
    let governingDocsResult: GoverningDocResult | null = null;
    if (governingDocsFilePath) {
      try {
        const { data: govDocData, error: govDocError } = await supabase.storage
          .from('form-uploads')
          .download(governingDocsFilePath);
        if (!govDocError && govDocData) {
          governingDocsResult = await processGoverningDocument(
            govDocData,
            governingDocsFileName || 'document.pdf',
            chapterType,
            chapterName
          );
          governingDocsPath = governingDocsResult.filePath;
          await supabase
            .from('chapter_documents')
            .upsert({
              chapter_name: chapterName,
              document_type: governingDocsResult.documentType,
              file_path: governingDocsResult.filePath,
              public_url: governingDocsResult.publicUrl,
              original_filename: governingDocsResult.originalFilename,
              file_size: governingDocsResult.fileSize,
              uploaded_at: new Date().toISOString(),
              uploaded_by: contactEmail,
            }, { onConflict: 'chapter_name,document_type' });
        }
      } catch (error) {
        console.error('Error processing governing documents:', error);
      }
    }

    const committee = chapterType === 'college'
      ? ['College Democrats']
      : chapterType === 'highschool'
        ? ['High School Democrats']
        : null;

    const memberData: Record<string, any> = {
      name: contactName,
      email: contactEmail,
      phone: contactPhone,
      chapter_name: chapterName,
      current_chapter_member: 'Yes',
      date_joined: new Date().toISOString().split('T')[0],
    };
    if (committee) memberData.committee = committee;
    if (chapterType === 'college') {
      memberData.college = schoolName;
      memberData.in_school = 'Yes';
      memberData.school_name = schoolName;
    } else if (chapterType === 'highschool') {
      memberData.high_school = schoolName;
      memberData.in_school = 'Yes';
      memberData.school_name = schoolName;
    } else if (county) {
      memberData.county = county;
    }

    const { error: memberError } = await supabase
      .from('members')
      .upsert(memberData, { onConflict: 'email' })
      .select('id')
      .single();
    if (memberError) console.error("Error creating/updating member:", memberError);

    let officersResult: any = null;
    if (officersFilePath) {
      try {
        const { data, error } = await supabase.functions.invoke('process-membership-roster', {
          body: {
            chapter_id: chapterId,
            chapter_name: chapterName,
            chapter_type: chapterType,
            school_name: schoolName,
            county: county,
            file_path: officersFilePath,
            is_officers_list: true,
            submission_date: new Date().toISOString().split('T')[0],
          },
        });
        officersResult = data;
        if (error) console.error("Officers processing error:", error);
      } catch (e) {
        console.error("Error invoking process-membership-roster for officers:", e);
      }
    }

    let membershipResult: any = null;
    let membershipFormUrl: string | null = null;
    let membershipFormSlug: string | null = null;
    let membershipFormId: string | null = null;

    if (membershipUploadChoice === 'upload_now' && membershipFilePath) {
      try {
        const { data, error } = await supabase.functions.invoke('process-membership-roster', {
          body: {
            chapter_id: chapterId,
            chapter_name: chapterName,
            chapter_type: chapterType,
            school_name: schoolName,
            county: county,
            file_path: membershipFilePath,
            is_officers_list: false,
            submission_date: new Date().toISOString().split('T')[0],
          },
        });
        membershipResult = data;
        if (error) console.error("Membership processing error:", error);
      } catch (e) {
        console.error("Error invoking process-membership-roster for members:", e);
      }
    } else {
      try {
        const formResult = await createChapterMembershipForm(chapterId, chapterName, chapterType, schoolName);
        membershipFormId = formResult.formId;
        membershipFormSlug = formResult.formSlug;
        membershipFormUrl = formResult.formUrl;
        await supabase
          .from('chapters')
          .update({
            membership_form_slug: membershipFormSlug,
            membership_form_url: membershipFormUrl,
          })
          .eq('id', chapterId);
      } catch (e) {
        console.error("Error generating membership form:", e);
        const params = new URLSearchParams({
          chapter: chapterId,
          type: chapterType,
          name: chapterName,
        });
        if (schoolName) params.set('school', schoolName);
        membershipFormUrl = `https://forms.moyoungdemocrats.org/join-chapter?${params.toString()}`;
      }
    }

    const officersCount = officersResult?.data?.processed || officersResult?.data?.created || 0;
    const membersCount = membershipResult?.data?.processed || membershipResult?.data?.created || 0;

    await supabase
      .from('form_submissions')
      .update({
        status: 'processed',
        page_data: {
          chapter_id: chapterId,
          chapter_name: chapterName,
          membership_form_url: membershipFormUrl,
          membership_form_slug: membershipFormSlug,
          membership_form_id: membershipFormId,
          officers_processed: officersCount,
          members_processed: membersCount,
          governing_docs_path: governingDocsPath,
          processed_at: new Date().toISOString(),
        },
      })
      .eq('id', submission_id);

    let message: string;
    if (membershipFormUrl) {
      message = `🎉 ${chapterName} has been submitted for chartering!\n\n` +
        `📋 Share this link with your members:\n${membershipFormUrl}\n\n` +
        `✅ ${officersCount} officers processed\n` +
        `📄 Governing documents received\n\n` +
        `We will review your application within 5-7 business days.`;
    } else {
      message = `🎉 ${chapterName} has been submitted for chartering!\n\n` +
        `✅ ${officersCount} officers processed\n` +
        `✅ ${membersCount} members processed\n` +
        `📄 Governing documents received\n\n` +
        `We will review your application within 5-7 business days.`;
    }

    console.log("=== CHARTERING SUBMISSION COMPLETE ===");

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          chapter_id: chapterId,
          chapter_name: chapterName,
          chapter_type: chapterType,
          status: 'pending_review',
          membership_form_url: membershipFormUrl,
          membership_form_slug: membershipFormSlug,
          membership_form_id: membershipFormId,
          officers_processed: officersCount,
          members_processed: membersCount,
          governing_docs_path: governingDocsPath,
          message: message,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("=== CHARTERING SUBMISSION ERROR ===", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
