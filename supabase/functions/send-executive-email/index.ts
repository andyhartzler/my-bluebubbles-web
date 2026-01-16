import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const GMAIL_USER = Deno.env.get("GMAIL_USER");
const GMAIL_APP_PASSWORD = Deno.env.get("GMAIL_APP_PASSWORD");
const GMAIL_FROM = Deno.env.get("GMAIL_FROM");
const HOOK_SECRET = Deno.env.get("SEND_EMAIL_HOOK_SECRET")?.replace("v1,whsec_", "");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

async function sendViaSMTP(to: string, subject: string, htmlBody: string) {
  const conn = await Deno.connect({
    hostname: "smtp.gmail.com",
    port: 587
  });

  const encoder = new TextEncoder();
  const decoder = new TextDecoder();

  async function send(data: string) {
    await conn.write(encoder.encode(data + "\r\n"));
  }

  async function read() {
    const buf = new Uint8Array(1024);
    const n = await conn.read(buf);
    return decoder.decode(buf.subarray(0, n || 0));
  }

  try {
    await read();
    await send(`EHLO localhost`);
    await read();
    await send("STARTTLS");
    await read();

    const tlsConn = await Deno.startTls(conn, {
      hostname: "smtp.gmail.com"
    });

    async function tlsSend(data: string) {
      await tlsConn.write(encoder.encode(data + "\r\n"));
    }

    async function tlsRead() {
      const buf = new Uint8Array(1024);
      const n = await tlsConn.read(buf);
      return decoder.decode(buf.subarray(0, n || 0));
    }

    await tlsSend("EHLO localhost");
    await tlsRead();
    await tlsSend("AUTH LOGIN");
    await tlsRead();
    await tlsSend(btoa(GMAIL_USER!));
    await tlsRead();
    await tlsSend(btoa(GMAIL_APP_PASSWORD!));
    const authResponse = await tlsRead();

    if (!authResponse.includes("235")) {
      throw new Error("Authentication failed");
    }

    await tlsSend(`MAIL FROM:<${GMAIL_FROM}>`);
    await tlsRead();
    await tlsSend(`RCPT TO:<${to}>`);
    await tlsRead();
    await tlsSend("DATA");
    await tlsRead();

    const emailContent = [
      `From: Missouri Young Democrats <${GMAIL_FROM}>`,
      `To: ${to}`,
      `Subject: ${subject}`,
      "MIME-Version: 1.0",
      "Content-Type: text/html; charset=UTF-8",
      "",
      htmlBody,
      "."
    ].join("\r\n");

    await tlsSend(emailContent);
    await tlsRead();
    await tlsSend("QUIT");
    tlsConn.close();

    return true;
  } catch (error) {
    conn.close();
    throw error;
  }
}

Deno.serve(async (req) => {
  if (!GMAIL_USER || !GMAIL_APP_PASSWORD || !GMAIL_FROM || !HOOK_SECRET || !SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    return new Response(JSON.stringify({ error: "Configuration error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }

  const payload = await req.text();
  const headers = Object.fromEntries(req.headers);
  const wh = new Webhook(HOOK_SECRET);

  try {
    const { user, email_data } = wh.verify(payload, headers) as {
      user: { email: string };
      email_data: {
        token_hash: string;
        token: string;
        email_action_type: string;
        redirect_to: string;
      };
    };

    console.log(`Email request for: ${user.email}`);
    console.log(`Redirect to: ${email_data.redirect_to}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Determine which app is requesting login
    const isExecutiveApp = email_data.redirect_to?.includes('moyd.app');
    const isJobPosterApp = email_data.redirect_to?.includes('jobs.moyoungdemocrats.org/poster');
    const isMembersApp = email_data.redirect_to?.includes('members.moyoungdemocrats.org');

    // === MOYD.APP (Executive + Committee Members) ===
    if (isExecutiveApp) {
      console.log('MOYD.app - checking permissions');

      // Fetch member with committee info
      const { data: member } = await supabase
        .from('members')
        .select('executive_committee, committee')
        .ilike('email', user.email)
        .single();

      if (!member) {
        console.log('Email not found in database');
        return new Response(JSON.stringify({
          error: {
            http_code: 403,
            message: 'This email is not associated with a Missouri Young Democrats member. If this is a mistake, please use the email from your Interest Form. For help, contact info@moyoungdemocrats.org'
          }
        }), {
          status: 403,
          headers: { "Content-Type": "application/json" }
        });
      }

      // Check if executive - they get full access
      const isExecutive = member.executive_committee === true;

      // Check if committee member (has any valid committee)
      let isCommitteeMember = false;
      let validCommittees: string[] = [];

      if (!isExecutive && member.committee && Array.isArray(member.committee)) {
        // Query the committees table to see which of user's committees are valid AND have workspace enabled
        const { data: committees } = await supabase
          .from('committees')
          .select('name, workspace_enabled')
          .in('name', member.committee)
          .eq('is_active', true);

        if (committees && committees.length > 0) {
          // Filter to only committees with workspace_enabled = true
          const enabledCommittees = committees.filter(c => c.workspace_enabled === true);

          if (enabledCommittees.length > 0) {
            // At least one committee has workspace enabled
            isCommitteeMember = true;
            validCommittees = enabledCommittees.map(c => c.name);
            console.log(`Committee member verified. Enabled committees: ${validCommittees.join(', ')}`);
          } else {
            // Member has committees, but NONE have workspace enabled
            console.log(`All committees disabled for member: ${user.email}. Committees: ${committees.map(c => c.name).join(', ')}`);
            return new Response(JSON.stringify({
              error: {
                http_code: 403,
                message: 'Your Committee Leaders have not enabled this workspace for you. Please contact us if you believe this message is in error.'
              }
            }), {
              status: 403,
              headers: { "Content-Type": "application/json" }
            });
          }
        }
      }

      // Reject if neither executive nor committee member
      if (!isExecutive && !isCommitteeMember) {
        console.log('Not executive or committee member');
        return new Response(JSON.stringify({
          error: {
            http_code: 403,
            message: 'Access to the MOYD portal requires executive committee membership or active committee participation. If you believe this is an error, contact info@moyoungdemocrats.org'
          }
        }), {
          status: 403,
          headers: { "Content-Type": "application/json" }
        });
      }

      if (isExecutive) {
        console.log('Executive member verified');
      }
    }

    // === JOB POSTER PORTAL ===
    if (isJobPosterApp) {
      console.log('Job poster portal - checking for job submissions (submitter_email OR contact_email)');

      const { data: jobs, error: jobError } = await supabase
        .from('jobs')
        .select('id')
        .or(`submitter_email.ilike.${user.email},contact_email.ilike.${user.email}`)
        .limit(1);

      if (jobError) {
        console.error('Error checking jobs:', jobError);
        return new Response(JSON.stringify({
          error: {
            http_code: 500,
            message: 'An error occurred while verifying your account. Please try again.'
          }
        }), {
          status: 500,
          headers: { "Content-Type": "application/json" }
        });
      }

      if (!jobs || jobs.length === 0) {
        console.log('No job submissions found for this email (checked both submitter_email and contact_email)');
        return new Response(JSON.stringify({
          error: {
            http_code: 403,
            message: 'No job postings found for this email address. Please use the same email you used when submitting your job posting or the contact email listed on the posting. If you haven\'t submitted a job yet, visit jobs.moyoungdemocrats.org/submit to post an opportunity.'
          }
        }), {
          status: 403,
          headers: { "Content-Type": "application/json" }
        });
      }

      console.log('Job poster verified - found job submissions');
    }

    // === MEMBERS PORTAL ===
    if (isMembersApp) {
      console.log('Members portal - checking membership');

      const { data: member, error: memberError } = await supabase
        .from('members')
        .select('id, name')
        .ilike('email', user.email)
        .single();

      if (memberError || !member) {
        console.log('Email not found in members table:', user.email);
        return new Response(JSON.stringify({
          error: {
            http_code: 403,
            message: 'This email is not associated with a Missouri Young Democrats member. The Members Portal is exclusively for registered members. If you believe this is an error, please contact info@moyoungdemocrats.org for assistance.'
          }
        }), {
          status: 403,
          headers: { "Content-Type": "application/json" }
        });
      }

      console.log(`Member verified: ${member.name} (${member.id})`);
    }

    // Build the magic link
    const magicLink = `https://faajpcarasilbfndzkmd.supabase.co/auth/v1/verify?token=${email_data.token_hash}&type=${email_data.email_action_type}&redirect_to=${email_data.redirect_to}`;

    // Set email content based on app type
    let subject: string;
    let appName: string;
    let html: string;

    if (isExecutiveApp) {
      subject = "MOYD Portal Login";
      appName = "MOYD Portal";
      html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; background: #f9fafc; border: 1px solid #e0e0e0; border-radius: 8px;">
          <h2 style="color: #004aad; text-align: center; margin-bottom: 20px;">${subject}</h2>
          <p style="font-size: 16px; color: #333;">
            Hi there,
          </p>
          <p style="font-size: 16px; color: #333;">
            You requested a secure login link to access the <strong>${appName}</strong>.
            Click the button below to continue:
          </p>
          <p style="text-align: center; margin: 32px 0;">
            <a href="${magicLink}" style="background: #004aad; color: #fff; text-decoration: none; padding: 14px 28px; font-size: 16px; font-weight: bold; border-radius: 6px; display: inline-block;">
              Log In to ${appName}
            </a>
          </p>
          <p style="font-size: 14px; color: #666; text-align: center;">
            <strong>Or enter this code:</strong> <span style="font-family: monospace; font-size: 18px; color: #004aad; font-weight: bold;">${email_data.token}</span>
          </p>
          <p style="font-size: 14px; color: #666;">
            This link will expire in 1 hour for security reasons. If you didn't request this, you can safely ignore this email.
          </p>
          <hr style="margin: 24px 0; border: none; border-top: 1px solid #ddd;">
          <p style="font-size: 12px; color: #999; text-align: center;">
            Missouri Young Democrats • <a href="https://moyoungdemocrats.org" style="color: #004aad; text-decoration: none;">moyoungdemocrats.org</a>
          </p>
        </div>
      `;
    } else if (isJobPosterApp) {
      subject = "Manage Your Listing";
      appName = "Opportunity Poster Dashboard";
      html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; background: #f9fafc; border: 1px solid #e0e0e0; border-radius: 8px;">
          <h2 style="color: #273351; text-align: center; margin-bottom: 20px;">Opportunity Portal Login</h2>
          <p style="font-size: 16px; color: #333;">
            Hi there,
          </p>
          <p style="font-size: 16px; color: #333;">
            You requested access to manage your posting(s) on the Missouri Young Democrats opportunity board.
            Click the button below to view your listings and applicants:
          </p>
          <p style="text-align: center; margin: 32px 0;">
            <a href="${magicLink}" style="background: #273351; color: #fff; text-decoration: none; padding: 14px 28px; font-size: 16px; font-weight: bold; border-radius: 6px; display: inline-block;">
              Access Your Dashboard
            </a>
          </p>
          <p style="font-size: 14px; color: #666; text-align: center;">
            <strong>Or enter this code:</strong> <span style="font-family: monospace; font-size: 18px; color: #273351; font-weight: bold;">${email_data.token}</span>
          </p>
          <p style="font-size: 14px; color: #666;">
            This link will expire in 1 hour for security reasons. If you didn't request this, you can safely ignore this email.
          </p>
          <hr style="margin: 24px 0; border: none; border-top: 1px solid #ddd;">
          <p style="font-size: 12px; color: #999; text-align: center;">
            Missouri Young Democrats • <a href="https://jobs.moyoungdemocrats.org" style="color: #273351; text-decoration: none;">jobs.moyoungdemocrats.org</a>
          </p>
        </div>
      `;
    } else if (isMembersApp) {
      subject = "Missouri Young Democrats Members Login";
      appName = "Members Area";
      html = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; background: #f9fafc; border: 1px solid #e0e0e0; border-radius: 8px;">
          <h2 style="color: #004aad; text-align: center; margin-bottom: 20px;">${subject}</h2>
          <p style="font-size: 16px; color: #333;">
            Hi there,
          </p>
          <p style="font-size: 16px; color: #333;">
            You requested a secure login link to access the <strong>${appName}</strong>.
            Click the button below to continue:
          </p>
          <p style="text-align: center; margin: 32px 0;">
            <a href="${magicLink}" style="background: #004aad; color: #fff; text-decoration: none; padding: 14px 28px; font-size: 16px; font-weight: bold; border-radius: 6px; display: inline-block;">
              Log In to ${appName}
            </a>
          </p>
          <p style="font-size: 14px; color: #666; text-align: center;">
            <strong>Or enter this code:</strong> <span style="font-family: monospace; font-size: 18px; color: #004aad; font-weight: bold;">${email_data.token}</span>
          </p>
          <p style="font-size: 14px; color: #666;">
            This link will expire in 1 hour for security reasons. If you didn't request this, you can safely ignore this email.
          </p>
          <hr style="margin: 24px 0; border: none; border-top: 1px solid #ddd;">
          <p style="font-size: 12px; color: #999; text-align: center;">
            Missouri Young Democrats • <a href="https://moyoungdemocrats.org" style="color: #004aad; text-decoration: none;">moyoungdemocrats.org</a>
          </p>
        </div>
      `;
    } else {
      console.log('Unknown redirect_to, rejecting request:', email_data.redirect_to);
      return new Response(JSON.stringify({
        error: {
          http_code: 400,
          message: 'Invalid login request. Please try again from the correct portal.'
        }
      }), {
        status: 400,
        headers: { "Content-Type": "application/json" }
      });
    }

    await sendViaSMTP(user.email, subject, html);

    return new Response(JSON.stringify({}), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });

  } catch (error) {
    console.error('Error:', error);
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : 'Unknown error'
    }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
});
