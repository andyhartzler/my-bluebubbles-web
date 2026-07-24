#!/usr/bin/env python3
"""Import candidate-submitted headshots from Google Drive into legislator-photos bucket."""
import io, json, os, re, subprocess, sys, urllib.request

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload

SA_KEY = "/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json"
IMPERSONATE = "andrew@moyoungdemocrats.org"
SCOPES = ["https://www.googleapis.com/auth/drive.readonly"]
SUPABASE_URL = "https://faajpcarasilbfndzkmd.supabase.co"
SR_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
PSQL = "/opt/homebrew/opt/libpq/bin/psql"
WORKDIR = "/tmp/headshot-import/files"

creds = service_account.Credentials.from_service_account_file(
    SA_KEY, scopes=SCOPES, subject=IMPERSONATE)
drive = build("drive", "v3", credentials=creds, cache_discovery=False)


def psql(sql, params=None):
    # params are passed as psql -v bindings and must be referenced in `sql` as
    # :'name' (auto-quoted + escaped by psql), which is injection-safe — never
    # f-string a value straight into the SQL text.
    env = dict(os.environ, PGPASSWORD=os.environ["SUPABASE_DB_PASSWORD"])
    cmd = [PSQL, "-h", "db.faajpcarasilbfndzkmd.supabase.co",
           "-U", "postgres", "-d", "postgres", "-At", "-F", "\t"]
    for k, v in (params or {}).items():
        cmd += ["-v", f"{k}={v}"]
    cmd += ["-c", sql]
    r = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    return r.stdout.strip()


rows = psql("SELECT id, name, headshot_source_url FROM public.candidates "
            "WHERE headshot_source_url IS NOT NULL AND (photo_url IS NULL OR photo_url='') ORDER BY name;")

imported, skipped = [], []

for line in rows.splitlines():
    cid, name, urls = line.split("\t", 2)
    file_ids = re.findall(r"[?&]id=([\w-]+)", urls)
    if not file_ids:
        skipped.append((name, "no Drive file id parseable from: " + urls[:80]))
        continue

    success = False
    last_err = None
    for fid in file_ids:
        try:
            meta = drive.files().get(fileId=fid, supportsAllDrives=True,
                                     fields="id,name,mimeType,size").execute()
            mime = meta.get("mimeType", "")
            if not mime.startswith("image/"):
                last_err = f"not an image (mimeType={mime})"
                continue
            buf = io.BytesIO()
            req = drive.files().get_media(fileId=fid, supportsAllDrives=True)
            dl = MediaIoBaseDownload(buf, req)
            done = False
            while not done:
                _, done = dl.next_chunk()
            data = buf.getvalue()
            if len(data) < 5 * 1024:
                last_err = f"file too small ({len(data)} bytes)"
                continue

            # determine extension / convert HEIC
            local = os.path.join(WORKDIR, f"{cid}_raw")
            with open(local, "wb") as f:
                f.write(data)
            ftype = subprocess.run(["file", "-b", "--mime-type", local],
                                   capture_output=True, text=True).stdout.strip()

            if ftype in ("image/heic", "image/heif") or mime in ("image/heic", "image/heif"):
                out = os.path.join(WORKDIR, f"candidate_{cid}.jpg")
                r = subprocess.run(["sips", "-s", "format", "jpeg", local, "--out", out],
                                   capture_output=True, text=True)
                if r.returncode != 0:
                    last_err = "HEIC conversion failed: " + r.stderr.strip()
                    continue
                ext, ctype = "jpg", "image/jpeg"
                path = out
            elif ftype == "image/png":
                ext, ctype = "png", "image/png"
                path = local
            elif ftype == "image/jpeg":
                ext, ctype = "jpg", "image/jpeg"
                path = local
            elif ftype == "image/webp":
                # convert webp to jpg for consistency with convention (jpg/png only seen)
                out = os.path.join(WORKDIR, f"candidate_{cid}.jpg")
                r = subprocess.run(["sips", "-s", "format", "jpeg", local, "--out", out],
                                   capture_output=True, text=True)
                if r.returncode != 0:
                    last_err = "webp conversion failed: " + r.stderr.strip()
                    continue
                ext, ctype = "jpg", "image/jpeg"
                path = out
            else:
                last_err = f"unsupported file type ({ftype})"
                continue

            if os.path.getsize(path) < 5 * 1024:
                last_err = f"converted file too small ({os.path.getsize(path)} bytes)"
                continue

            objname = f"candidate_{cid}.{ext}"
            with open(path, "rb") as f:
                body = f.read()
            req2 = urllib.request.Request(
                f"{SUPABASE_URL}/storage/v1/object/legislator-photos/{objname}",
                data=body, method="POST",
                headers={"Authorization": f"Bearer {SR_KEY}",
                         "Content-Type": ctype,
                         "x-upsert": "true"})
            try:
                resp = urllib.request.urlopen(req2)
                resp.read()
            except urllib.error.HTTPError as e:
                last_err = f"upload failed: {e.code} {e.read().decode()[:200]}"
                continue

            public_url = f"{SUPABASE_URL}/storage/v1/object/public/legislator-photos/{objname}"
            psql("UPDATE public.candidates SET photo_url = :'purl', updated_at = now() "
                 "WHERE id = :'cid';",
                 {"purl": public_url, "cid": cid})
            imported.append((name, public_url, len(body)))
            print(f"OK  {name}: {public_url} ({len(body)} bytes, src {mime})")
            success = True
            break
        except Exception as e:
            last_err = str(e)[:200]
            continue

    if not success:
        skipped.append((name, last_err or "unknown"))
        print(f"SKIP {name}: {last_err}")

print("\n=== SUMMARY ===")
print(f"imported: {len(imported)}")
print(f"skipped: {len(skipped)}")
for n, r in skipped:
    print(f"  - {n}: {r}")
json.dump({"imported": imported, "skipped": skipped},
          open("/tmp/headshot-import/result.json", "w"), indent=2)
