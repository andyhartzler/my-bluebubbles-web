"""Download the PSR voter file zip from Google Drive via the backend-everything service account."""
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseDownload
from pathlib import Path

KEY = '/Users/moyd/Desktop/MOYD/backend-everything-a599411a62b5.json'
FILE_ID = '1Q0c-43RkiwwBCRCwIpouysdFRitjf8Zg'
DEST = Path('/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_psr_raw.zip')

creds = (
    service_account.Credentials.from_service_account_file(
        KEY, scopes=['https://www.googleapis.com/auth/drive.readonly']
    ).with_subject('andrew@moyoungdemocrats.org')
)
drive = build('drive', 'v3', credentials=creds, cache_discovery=False)

meta = drive.files().get(fileId=FILE_ID, fields='name,size').execute()
print(f"Downloading: {meta['name']} ({int(meta['size'])/1024/1024:.1f} MB)")

req = drive.files().get_media(fileId=FILE_ID)
with DEST.open('wb') as f:
    downloader = MediaIoBaseDownload(f, req, chunksize=25 * 1024 * 1024)
    done = False
    while not done:
        status, done = downloader.next_chunk()
        print(f"  {int(status.progress() * 100)}%")

print(f"Saved {DEST} ({DEST.stat().st_size/1024/1024:.1f} MB)")
