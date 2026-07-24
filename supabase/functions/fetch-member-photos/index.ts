// fetch-member-photos/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const supabase = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"));
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID");
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET");
const GOOGLE_REFRESH_TOKEN = Deno.env.get("GOOGLE_REFRESH_TOKEN");
async function getGoogleAccessToken() {
  console.log("🔍 Starting token refresh...");
  console.log({
    client_id: GOOGLE_CLIENT_ID,
    client_secret: GOOGLE_CLIENT_SECRET ? "present ✅" : "missing ❌",
    refresh_token: GOOGLE_REFRESH_TOKEN ? "present ✅" : "missing ❌"
  });
  const body = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    client_secret: GOOGLE_CLIENT_SECRET,
    refresh_token: GOOGLE_REFRESH_TOKEN,
    grant_type: "refresh_token"
  });
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body
  });
  const text = await res.text();
  console.log("🔁 Token refresh raw response:", text);
  let data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    console.error("⚠️ Failed to parse token response JSON:", e);
    throw new Error("Invalid JSON in token response");
  }
  if (!res.ok) {
    console.error("❌ Token refresh failed:", data);
    throw new Error(`Failed to refresh token: ${JSON.stringify(data)}`);
  }
  console.log("✅ Token refresh succeeded!");
  return data.access_token;
}
async function fetchContactPhoto(email, accessToken) {
  const endpoint = `https://people.googleapis.com/v1/people:searchContacts?query=${encodeURIComponent(email)}&readMask=photos,names,emailAddresses`;
  console.log(`📨 Fetching contact photo for ${email}`);
  const res = await fetch(endpoint, {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });
  const text = await res.text();
  console.log("🧾 Google People API raw response:", text);
  let data;
  try {
    data = JSON.parse(text);
  } catch  {
    console.error(`⚠️ Could not parse response for ${email}`);
    return null;
  }
  const photoUrl = data?.results?.[0]?.person?.photos?.[0]?.url || null;
  return photoUrl;
}
async function uploadPhotoToStorage(photoUrl, fileName) {
  console.log(`🖼️ Downloading and uploading ${fileName}`);
  try {
    const res = await fetch(photoUrl);
    if (!res.ok) throw new Error(`Failed to download ${photoUrl}`);
    const arrayBuffer = await res.arrayBuffer();
    const { error } = await supabase.storage.from("member-photos").upload(fileName, arrayBuffer, {
      contentType: "image/jpeg",
      upsert: true
    });
    if (error) throw error;
    console.log(`✅ Uploaded ${fileName} successfully`);
  } catch (err) {
    console.error(`❌ Upload failed for ${fileName}:`, err.message);
  }
}
Deno.serve(async (req)=>{
  console.log("🚀 Starting fetch-member-photos function");
  try {
    const accessToken = await getGoogleAccessToken();
    console.log("✅ Google access token acquired");
    const { data: members, error } = await supabase.from("members").select("id, full_name, email");
    if (error) {
      console.error("❌ Error fetching members:", error);
      return new Response(JSON.stringify({
        error: error.message
      }), {
        status: 500
      });
    }
    console.log(`📇 Found ${members.length} members`);
    for (const member of members){
      if (!member.email) continue;
      const photoUrl = await fetchContactPhoto(member.email, accessToken);
      if (photoUrl) {
        const monthYear = new Date().toISOString().slice(0, 7).replace("-", "");
        const fileName = `${member.full_name.replace(/\s+/g, "_")}-${monthYear}.jpg`;
        await uploadPhotoToStorage(photoUrl, fileName);
        const { error: updateError } = await supabase.from("members").update({
          photo_url: fileName
        }).eq("id", member.id);
        if (updateError) console.error(`⚠️ DB update failed:`, updateError);
        else console.log(`✅ Linked photo for ${member.full_name}`);
      } else {
        console.log(`⚠️ No photo found for ${member.email}`);
      }
    }
    console.log("🎉 Sync complete");
    return new Response(JSON.stringify({
      success: true
    }), {
      status: 200
    });
  } catch (err) {
    console.error("❌ Top-level error:", err.message);
    return new Response(JSON.stringify({
      error: err.message
    }), {
      status: 500
    });
  }
});
