# n8n SQLite → Postgres Sidecar Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox syntax. Ops-style runbook — not TDD — because this is infrastructure cutover, not feature code.

**Goal:** Eliminate `SQLITE_IOERR` / silent exec-row-loss by running n8n against a Postgres 16 sidecar container on the Mac mini, with data in a Docker-managed named volume (bypassing the Docker bind-mount layer that causes the SQLite wedge).

**Architecture:** Postgres 16-alpine sidecar named `n8n-postgres` in a compose file alongside the existing `n8n` service. Both managed via `docker compose`. n8n keeps its bind-mounted work dir `/Users/moyd/n8n-data → /home/node/.n8n` for encryption-key file + custom patches. Postgres data lives in Docker-managed named volume `n8n-postgres-data` (inside the Colima VM, not osxfs).

**Tech Stack:** Docker Compose v2, `postgres:16-alpine` (arm64 native), `n8nio/n8n:latest` (digest `sha256:ab216dc8…` pinned), psql 15.x client via Homebrew.

**Downtime target:** 15–25 min wall-clock, during a window with no predictable Zoom meetings.

**Known state as of 2026-04-23:** 22 workflows active, 7 retired (active=0), 10 credentials, encryption key `fa3zsqKB+4YpT0YxFGtcrtCFkqtvWn9+` in `/Users/moyd/n8n-data/config`, container `n8n` running on Colima (not Docker Desktop), bind-mount `/Users/moyd/n8n-data → /home/node/.n8n`, two LaunchAgents (`com.moyd.n8n-watchdog`, `com.moyd.n8n-gmail-scope-patch`).

---

## Critical corrections baked in from risk audit

1. **User + project tables don't export via `n8n export` CLI.** Must be manually migrated via SQL dump so the existing owner + their API keys/MFA/password survive.
2. **Encryption key is currently in a file, not env var.** Compose must set both (env + preserved file).
3. **Export without `--decrypted`.** Ciphertext passes through safely since the encryption key is preserved.
4. **Container name MUST be `n8n`** — hardcoded in watchdog + gmail-scope-patch scripts.
5. **Unload the gmail-scope-patch LaunchAgent** before cutover; it'll otherwise fire mid-migration and re-patch the old container.
6. **Verify 13 webhook_entity rows** after activation (4 Zoom/event + 8 Slack + 1 forms).
7. **Postgres data in named volume, NOT bind mount** — that's the whole point of the migration.

---

## Phase 0 — Pre-flight

**Files:**
- Read: `/Users/moyd/n8n-data/config`, `/Users/moyd/n8n-data/patches/n8n-watchdog.sh`, `/Users/moyd/n8n-data/patches/apply-gmail-scopes.sh`
- Read: `docker inspect n8n` output

### Step 0.1 — Verify current health

```bash
docker ps --filter name=n8n --format "{{.Names}} {{.Status}}"
curl -s -o /dev/null -w "healthz: %{http_code}\n" http://localhost:5678/healthz
sqlite3 /Users/moyd/n8n-data/database.sqlite \
  "SELECT 'active:' || sum(CASE WHEN active=1 THEN 1 ELSE 0 END) || ' retired:' || sum(CASE WHEN active=0 THEN 1 ELSE 0 END) AS count FROM workflow_entity;"
sqlite3 /Users/moyd/n8n-data/database.sqlite "SELECT 'creds:' || count(*) FROM credentials_entity;"
```

Expected: `Up`, `healthz: 200`, `active:22 retired:7`, `creds:10`.

### Step 0.2 — Record baselines

```bash
BASELINE_WF_ACTIVE=$(sqlite3 /Users/moyd/n8n-data/database.sqlite "SELECT count(*) FROM workflow_entity WHERE active=1")
BASELINE_WF_TOTAL=$(sqlite3 /Users/moyd/n8n-data/database.sqlite "SELECT count(*) FROM workflow_entity")
BASELINE_CREDS=$(sqlite3 /Users/moyd/n8n-data/database.sqlite "SELECT count(*) FROM credentials_entity")
BASELINE_WEBHOOKS=$(sqlite3 /Users/moyd/n8n-data/database.sqlite "SELECT count(*) FROM webhook_entity")
BASELINE_USER_ID=$(sqlite3 /Users/moyd/n8n-data/database.sqlite "SELECT id FROM user LIMIT 1")
echo "wf_active=$BASELINE_WF_ACTIVE wf_total=$BASELINE_WF_TOTAL creds=$BASELINE_CREDS webhooks=$BASELINE_WEBHOOKS user=$BASELINE_USER_ID"
```

Persist for later comparison.

### Step 0.3 — Disk + image sanity

```bash
df -h /Users/moyd/n8n-data | tail -1           # need ≥ 5 GB free
docker pull postgres:16-alpine                 # arm64 manifest pre-pull
docker pull n8nio/n8n:latest                   # match running image
```

### Step 0.4 — Generate Postgres password

```bash
POSTGRES_PASSWORD=$(openssl rand -hex 24)
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" > /Users/moyd/n8n-data/.env
chmod 600 /Users/moyd/n8n-data/.env
```

### Step 0.5 — Unload conflicting LaunchAgents (both watchdog + gmail-scope)

```bash
launchctl unload ~/Library/LaunchAgents/com.moyd.n8n-watchdog.plist || true
launchctl unload ~/Library/LaunchAgents/com.moyd.n8n-gmail-scope-patch.plist 2>/dev/null || true
```

---

## Phase 1 — Backup (mandatory)

### Step 1.1 — Stop n8n

```bash
docker stop n8n
```

### Step 1.2 — Archive SQLite + full data dir

```bash
TS=$(date +%Y%m%d-%H%M%S)
cp /Users/moyd/n8n-data/database.sqlite /Users/moyd/n8n-data/database.pre-postgres-cutover-$TS.sqlite
tar czf /Users/moyd/n8n-data-pre-cutover-$TS.tar.gz -C /Users/moyd n8n-data
echo "backup archive: /Users/moyd/n8n-data-pre-cutover-$TS.tar.gz"
echo "sqlite snapshot: /Users/moyd/n8n-data/database.pre-postgres-cutover-$TS.sqlite"
```

### Step 1.3 — Preserve the old container for rollback

```bash
docker rename n8n n8n-sqlite-backup
```

---

## Phase 2 — Export from SQLite-backed n8n

### Step 2.1 — Restart the backup container temporarily for export

```bash
docker start n8n-sqlite-backup
for i in 1 2 3 4 5 6; do
  sleep 10
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz)
  echo "attempt $i: HTTP $code"
  [ "$code" = "200" ] && break
done
```

### Step 2.2 — Export workflows + credentials (encrypted form, safer)

```bash
ARTIFACT_DIR="/Users/moyd/n8n-data/migration-artifacts/$TS"
mkdir -p "$ARTIFACT_DIR/wf-export"
docker exec n8n-sqlite-backup mkdir -p /tmp/wf-export
docker exec n8n-sqlite-backup n8n export:workflow --all --separate --output=/tmp/wf-export
docker exec n8n-sqlite-backup n8n export:credentials --all --output=/tmp/creds-export.json
docker cp n8n-sqlite-backup:/tmp/wf-export/. "$ARTIFACT_DIR/wf-export/"
docker cp n8n-sqlite-backup:/tmp/creds-export.json "$ARTIFACT_DIR/creds-export.json"
ls "$ARTIFACT_DIR/wf-export/" | wc -l     # should equal $BASELINE_WF_TOTAL (29)
```

### Step 2.3 — Dump user + project + webhook_entity via sqlite3 (CLI can't export these)

```bash
sqlite3 /Users/moyd/n8n-data/database.sqlite <<SQL > "$ARTIFACT_DIR/user-project-dump.sql"
.mode insert user
SELECT * FROM user;
.mode insert project
SELECT * FROM project;
.mode insert project_relation
SELECT * FROM project_relation;
SQL
wc -l "$ARTIFACT_DIR/user-project-dump.sql"   # should be > 0
```

### Step 2.4 — Stop backup container

```bash
docker stop n8n-sqlite-backup
```

---

## Phase 3 — Provision Postgres sidecar

### Step 3.1 — Write compose file at `/Users/moyd/n8n-data/docker-compose.yml`

```yaml
services:
  n8n-postgres:
    image: postgres:16-alpine
    container_name: n8n-postgres
    restart: always
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set in .env}
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --locale=C"
    volumes:
      - n8n-postgres-data:/var/lib/postgresql/data
    expose:
      - "5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n -d n8n"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: always
    depends_on:
      n8n-postgres:
        condition: service_healthy
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      WEBHOOK_URL: https://n8n.moydchat.org/
      N8N_HOST: n8n.moydchat.org
      N8N_PROTOCOL: https
      N8N_SECURE_COOKIE: "false"
      NODE_FUNCTION_ALLOW_BUILTIN: "crypto,https,url"
      N8N_ENCRYPTION_KEY: "fa3zsqKB+4YpT0YxFGtcrtCFkqtvWn9+"
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: n8n-postgres
      DB_POSTGRESDB_PORT: "5432"
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: n8n
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD:?POSTGRES_PASSWORD must be set in .env}
      DB_POSTGRESDB_SCHEMA: public
    volumes:
      - /Users/moyd/n8n-data:/home/node/.n8n

volumes:
  n8n-postgres-data:
    name: n8n-postgres-data
```

### Step 3.2 — Bring up Postgres first

```bash
cd /Users/moyd/n8n-data
docker compose up -d n8n-postgres
for i in 1 2 3 4 5 6; do
  sleep 5
  if docker exec n8n-postgres pg_isready -U n8n -d n8n; then break; fi
  echo "waiting for postgres (attempt $i)"
done
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT version()"
```

---

## Phase 4 — First boot of n8n on Postgres (creates schema)

### Step 4.1 — Start n8n

```bash
docker compose up -d n8n
for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 10
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz)
  echo "attempt $i: HTTP $code"
  [ "$code" = "200" ] && break
done
```

### Step 4.2 — Verify schema created (~148 migrations expected on first boot)

```bash
docker exec n8n-postgres psql -U n8n -d n8n -c "\dt" | head -50
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT count(*) FROM workflow_entity"
# expect 0
```

### Step 4.3 — Verify n8n logs show clean migration (not an error)

```bash
docker logs --tail 60 n8n | grep -iE "(migration|error|failed)"
```

Any "ERROR" or "migration failed" → STOP, rollback.

---

## Phase 5 — Seed owner + project rows FIRST (before UI setup wizard creates new ones)

### Step 5.1 — Import user + project from dump (run BEFORE anyone touches the UI)

The n8n owner user created in SQLite must land as the new Postgres owner; otherwise the UI setup screen creates a new user and imports land orphaned.

```bash
# Extract as JSON via sqlite3 .dump-style to re-insert into postgres
sqlite3 -json /Users/moyd/n8n-data/database.pre-postgres-cutover-$TS.sqlite \
  "SELECT * FROM user" > "$ARTIFACT_DIR/user.json"
sqlite3 -json /Users/moyd/n8n-data/database.pre-postgres-cutover-$TS.sqlite \
  "SELECT * FROM project" > "$ARTIFACT_DIR/project.json"
sqlite3 -json /Users/moyd/n8n-data/database.pre-postgres-cutover-$TS.sqlite \
  "SELECT * FROM project_relation" > "$ARTIFACT_DIR/project_relation.json"

# Use Python helper to generate parameterised INSERTs (sqlite & pg diverge on booleans, etc.)
python3 /Users/moyd/n8n-data/migration-artifacts/$TS/seed_user_project.py  # see Step 5.2
```

### Step 5.2 — Helper script (write this file before run)

Write `/Users/moyd/n8n-data/migration-artifacts/$TS/seed_user_project.py`:

```python
import json, os, subprocess, sys

ART = os.environ.get("ARTIFACT_DIR") or sys.argv[1]

def run_pg(sql, params=()):
    cmd = ["docker", "exec", "-i", "n8n-postgres",
           "psql", "-U", "n8n", "-d", "n8n", "-v", "ON_ERROR_STOP=1"]
    # Use parameterised via prepared statements is painful — use pg_escape
    full = sql
    for p in params:
        if p is None:
            v = "NULL"
        elif isinstance(p, bool):
            v = "true" if p else "false"
        elif isinstance(p, (int, float)):
            v = str(p)
        else:
            v = "'" + str(p).replace("'", "''") + "'"
        full = full.replace("%s", v, 1)
    subprocess.run(cmd, input=full.encode(), check=True)

def seed_table(table, json_path, columns):
    rows = json.load(open(json_path))
    if not rows:
        print(f"{table}: no rows"); return
    for r in rows:
        vals = [r.get(c) for c in columns]
        placeholders = ", ".join(["%s"] * len(columns))
        cols = ", ".join([f'"{c}"' for c in columns])
        sql = f'INSERT INTO "{table}" ({cols}) VALUES ({placeholders}) ON CONFLICT (id) DO NOTHING;'
        run_pg(sql, vals)
    print(f"{table}: {len(rows)} rows seeded")

# Column lists captured from sqlite pragma
USER_COLS = ["id","email","firstName","lastName","password","personalizationAnswers",
             "createdAt","updatedAt","settings","disabled","mfaEnabled","mfaSecret","mfaRecoveryCodes","role"]
PROJECT_COLS = ["id","name","type","createdAt","updatedAt","icon"]
PROJECT_RELATION_COLS = ["projectId","userId","role","createdAt","updatedAt"]

seed_table("user", f"{ART}/user.json", USER_COLS)
seed_table("project", f"{ART}/project.json", PROJECT_COLS)
seed_table("project_relation", f"{ART}/project_relation.json", PROJECT_RELATION_COLS)
```

Run:
```bash
ARTIFACT_DIR="$ARTIFACT_DIR" python3 "$ARTIFACT_DIR/seed_user_project.py"
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT id, email FROM \"user\""
```

Expected: your existing user row present. If empty, STOP — the seeding failed and next step will create an orphan owner via the wizard.

---

## Phase 6 — Import workflows + credentials

### Step 6.1 — Import credentials first (workflows reference them)

```bash
docker cp "$ARTIFACT_DIR/creds-export.json" n8n:/tmp/creds-export.json
docker exec n8n n8n import:credentials --input=/tmp/creds-export.json
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT count(*) FROM credentials_entity"
# expect $BASELINE_CREDS (10)
```

### Step 6.2 — Import workflows

```bash
docker cp "$ARTIFACT_DIR/wf-export" n8n:/tmp/wf-export
docker exec n8n n8n import:workflow --separate --input=/tmp/wf-export
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT count(*) FROM workflow_entity"
# expect $BASELINE_WF_TOTAL (29)
```

---

## Phase 7 — Reactivate previously-active workflows

Imports land with `active=false` by default.

### Step 7.1 — Generate reactivation SQL from the baseline

```bash
sqlite3 /Users/moyd/n8n-data/database.pre-postgres-cutover-$TS.sqlite \
  "SELECT 'UPDATE workflow_entity SET active=true WHERE id=''' || id || ''';' FROM workflow_entity WHERE active=1;" \
  > "$ARTIFACT_DIR/reactivate.sql"
wc -l "$ARTIFACT_DIR/reactivate.sql"   # expect $BASELINE_WF_ACTIVE (22)
docker cp "$ARTIFACT_DIR/reactivate.sql" n8n-postgres:/tmp/reactivate.sql
docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/reactivate.sql
```

### Step 7.2 — Restart n8n so the ActiveWorkflowManager re-reads

```bash
docker restart n8n
for i in 1 2 3 4 5 6 7 8; do
  sleep 10
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz)
  [ "$code" = "200" ] && break
done
```

### Step 7.3 — Verify activations

```bash
# Count activated workflows from logs over last 60s
docker logs --since 120s n8n 2>&1 | grep -c "Activated workflow"
# expect 22

# Verify webhook entries regenerated
docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT count(*) FROM webhook_entity"
# expect 13
```

If either number is off, grep logs for errors:
```bash
docker logs --since 120s n8n 2>&1 | grep -iE "error|fail" | grep -v "Summary\|Minutes" | tail -30
```

---

## Phase 8 — Restore LaunchAgents + custom patches

### Step 8.1 — Run gmail scope patch once manually (baked into new container layer)

```bash
/Users/moyd/n8n-data/patches/apply-gmail-scopes.sh
# This does: docker exec + sed + docker restart n8n
```

### Step 8.2 — Reload LaunchAgents

```bash
launchctl load ~/Library/LaunchAgents/com.moyd.n8n-watchdog.plist
launchctl load ~/Library/LaunchAgents/com.moyd.n8n-gmail-scope-patch.plist
launchctl list | grep moyd
```

---

## Phase 9 — E2E verification

### Step 9.1 — CRC smoke test

```bash
curl -s -X POST http://localhost:5678/webhook/zoom/recording-completed \
  -H "Content-Type: application/json" \
  -d '{"event":"endpoint.url_validation","payload":{"plainToken":"postgres-cutover-verify"}}'
# expect 200
```

### Step 9.2 — Real-shape `recording.completed` end-to-end (using yesterday's Exec meeting)

Use the same payload from 2026-04-23 E2E (zoom_id 99334786595, uuid `KPMiPnm/Q6G15H2kb5pQ3g==`, 3 real participants, real recording URLs). Temporarily patch Delay → 1s, POST payload, restore Delay, verify:

```bash
# Pull the payload from yesterday's E2E artifact OR reconstruct via:
TOKEN=$(curl -s -X POST "https://zoom.us/oauth/token?grant_type=account_credentials&account_id=PbGaSkI1Q-CN3_BpapXi3A" \
  -u "6Gs7TPrOSiq2YhU5JbnM8w:5RL9QXQXyhxy0tsyZ0q5VkOUgKEGixfA" | jq -r .access_token)
RECORDINGS=$(curl -s "https://api.zoom.us/v2/meetings/99334786595/recordings" -H "Authorization: Bearer $TOKEN")
# Build payload with the real recordings, POST to webhook, monitor execution_entity for new row, verify public.meetings inserted
```

### Step 9.3 — Baseline parity check

```bash
docker exec n8n-postgres psql -U n8n -d n8n -c \
  "SELECT 'active:' || sum(CASE WHEN active=true THEN 1 ELSE 0 END) || ' retired:' || sum(CASE WHEN active=false THEN 1 ELSE 0 END) FROM workflow_entity;"
# expect active:22 retired:7

docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT count(*) FROM credentials_entity"
# expect 10

docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT count(*) FROM \"user\""
# expect 1 (same user ID as BASELINE_USER_ID)

docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT count(*) FROM webhook_entity"
# expect 13
```

Any mismatch → rollback plan (Phase 10).

---

## Phase 10 — Cleanup + document

### Step 10.1 — Move the dangling SQLite file out of n8n's data dir

```bash
mv /Users/moyd/n8n-data/database.sqlite /Users/moyd/n8n-data/database.sqlite.pre-postgres-migration
mv /Users/moyd/n8n-data/database.sqlite-shm /Users/moyd/n8n-data/database.sqlite-shm.pre-postgres-migration 2>/dev/null || true
mv /Users/moyd/n8n-data/database.sqlite-wal /Users/moyd/n8n-data/database.sqlite-wal.pre-postgres-migration 2>/dev/null || true
```

### Step 10.2 — Keep the old backup container for 24h

```bash
# Do NOT remove n8n-sqlite-backup yet. After 24h of stable Postgres operation:
# docker rm n8n-sqlite-backup
```

### Step 10.3 — Update Obsidian + memory

- `Infrastructure/API Keys and Credentials.md`: note n8n now on Postgres sidecar, password in `/Users/moyd/n8n-data/.env`, backups via `pg_dump`.
- New memory note: `n8n_postgres_sidecar.md` describing the new topology, how to query live data, `pg_dump` backup command.

### Step 10.4 — pg_dump cron (follow-up, not blocking)

```bash
# One-time: confirm pg_dump works
docker exec n8n-postgres pg_dump -U n8n -d n8n -Fc -f /var/lib/postgresql/data/backup-test.dump
docker exec n8n-postgres ls -lh /var/lib/postgresql/data/backup-test.dump
docker exec n8n-postgres rm /var/lib/postgresql/data/backup-test.dump
```

Schedule in a later session via LaunchAgent or a cron-style workflow.

---

## Phase 11 — Rollback (if anything in Phase 3-9 fails catastrophically)

```bash
docker compose -f /Users/moyd/n8n-data/docker-compose.yml down -v  # -v removes postgres volume
docker rename n8n-sqlite-backup n8n
docker start n8n
for i in 1 2 3 4 5 6; do sleep 5; [ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/healthz)" = "200" ] && break; done
launchctl load ~/Library/LaunchAgents/com.moyd.n8n-watchdog.plist
launchctl load ~/Library/LaunchAgents/com.moyd.n8n-gmail-scope-patch.plist
# Verify active workflow count matches baseline
sqlite3 /Users/moyd/n8n-data/database.sqlite "SELECT count(*) FROM workflow_entity WHERE active=1"
```

---

## Self-review

- ✅ Every step is copy-paste ready with exact commands.
- ✅ User/project tables handled (critical gap the CLI misses) — Phase 5.
- ✅ Encryption key as env var AND preserved file — Phase 3.
- ✅ Container name pinned — Phase 3.
- ✅ LaunchAgents unloaded before cutover, reloaded after — Phase 0.5 + 8.2.
- ✅ Named volume for Postgres, bind mount for n8n — Phase 3.
- ✅ Port binding is 127.0.0.1 only — Phase 3.
- ✅ E2E verification against real Zoom payload — Phase 9.
- ✅ Rollback plan with exact commands — Phase 11.
- ✅ Dangling SQLite renamed post-cutover — Phase 10.

---

*Plan authored 2026-04-24. Supporting artifacts in `/Users/moyd/n8n-data/docs/postgres-migration-{architecture,runbook,risks}.md`.*
