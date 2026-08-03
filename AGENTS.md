# BlueBubbles CRM Integration - Complete Implementation Instructions

## READ FIRST: edge functions are not deployed by CI

No automation in either repo deploys anything under `supabase/functions/`.
Netlify builds only the Flutter web app (`netlify.toml` runs
`netlify-build.sh` and publishes `build/web`); there is no `.github`
directory in this repo at all, and no script anywhere in it runs
`supabase functions deploy`. The same is true of the `moyoungdemocrats` repo,
where Vercel builds only the Next.js site. The repo docs deploy functions by
hand with `npx supabase functions deploy <name> --project-ref <ref>`.

That is a verified negative about these two repos, not a positive claim about
how deploys actually happen. A dashboard-side Supabase GitHub integration, or
some external system, would be invisible from here.

Consequence: committing and pushing a change to an edge function does NOT put
that change in production. It changes the source of record and nothing else.
Do not read a merged commit as evidence that the behaviour it describes is
live, and do not treat a Sentry issue as handled because a commit names it.

This was established on 2026-07-30 from the production error stream, not
assumed. Two separate defects had a correct fix committed and were still
firing at an unchanged rate days later:

- `invalid input syntax for type uuid: "cron"`, once an hour on the hour.
  Fixed in `1cdb96e` on 2026-07-26 by returning a NULL actor instead of the
  string `"cron"` in `sync-google-calendar`. That string no longer exists on
  any uuid path in either repo, so the running function cannot be the
  committed one. Still firing hourly on 2026-07-30.
- `duplicate key value violates unique constraint
  "legislation_bill_sponsors_unique"`, exactly 32 per six-hour cycle. The
  emitter is `runSponsorsFromCacheTask` in `openstates-orchestrator`, not the
  per-bill loop in `openstates-sync-tracked-bills`: the lines land 17 to 19 ms
  apart, which is a tight probe-and-insert loop, and `e79339b` had already
  identified the same signature at 13 to 17 ms. That orchestrator write was
  switched to ON CONFLICT DO NOTHING in `e79339b` on 2026-07-27, with
  `2c401bf`, `d6db9cb`, `708ff55` and `b61d6cb` covering the dedupe, probe and
  delete-guard work around it. `913decb` made the matching change in
  `openstates-sync-tracked-bills`, which this timing evidence exonerates.
  Since `e79339b` the burst has run about twelve more cycles at an unchanged
  size: the three sampled directly (2026-07-29 18:00, 2026-07-30 00:00 and
  06:00 UTC) each still carried exactly 32 of these lines, and the seven-day
  aggregate shows no downward step at any point.

The second case is strong evidence but not proof, and the cheap checks that
would settle it were not run. A live ON CONFLICT whose target does not match
any unique index raises `42P10 no unique or exclusion constraint matching the
ON CONFLICT specification` rather than a duplicate-key error, and no `42P10`
line appears in the stream. That argues the new statement is not running, but
it assumes the constraint named `legislation_bill_sponsors_unique` covers
exactly `(bill_id, name, sponsorship_classification)`, which is inferred from
an ON CONFLICT list in `20260423_01_backfill_orphan_rpcs.sql` and is not
confirmed anywhere in this repo. Two queries settle it:
`select indexdef from pg_indexes where tablename = 'legislation_bill_sponsors';`
and, decisively, the deployed-version timestamps from `supabase functions list`.
The hourly `"cron"` case is the stronger leg, because it has no alternative
mechanism at all.

A third case reaches the same conclusion for one function without needing any
of those queries, because `0d2963e` on 2026-07-31 changed the error text
itself. That commit changed 62 lines in `sentry-log-relay/index.ts`; two sites
matter for the fingerprint. The thrown error went from

    throw new Error(`logs query failed ${res.status}: ${(await res.text()).slice(0, 300)}`);

to a `LogsQueryError` whose message is

    `logs query failed ${status} after ${attempts} attempt(s)`

and the outer catch that builds the Sentry title went from

    message: `sentry-log-relay failure: ${String(err).slice(0, 300)}`,

to

    const reason = err instanceof Error ? err.message : String(err);
    message: `sentry-log-relay failure: ${reason.slice(0, 300)}`,

Every one of the nine SUPABASE-PLATFORM-3 events, 2026-07-24 07:05 through
2026-08-01 08:05 UTC, reads

    sentry-log-relay failure: Error: logs query failed 502: <!DOCTYPE html>

Exactly two of those landed after the commit, at 2026-07-31 23:40 and
2026-08-01 08:05 UTC. This was read from the per-event `message` field, not the
group title, which is not a per-event record and cannot be trusted for this.

Two independent things in that string are pre-fix, and the second is the
load-bearing one. The retry wording is specific to the logs-query path. The
`Error: ` prefix is not. `String(err)` renders `${err.name}: ${err.message}`,
and every pre-fix throw site in this file constructs a plain `new Error`, whose
name is `Error`; the post-fix line uses `err.message`, which carries no name
prefix at all. The prefix is the error's name, not a constant, which this file
demonstrates on itself: `LogsQueryError` sets `this.name`, so `String()` of one
would render `LogsQueryError: `.

So a post-fix build cannot produce that prefix from any throw site in this
file. Stating it as a universal about JavaScript would be wrong: an `Error`
whose own message already begins with `Error: `, or a non-Error throw that
stringifies that way, would reproduce it. Neither can arise here. The only two
sites that wrap an upstream message, the state-read throw and the
watermark-update throw, prepend their own fixed text, so even a PostgREST
message that happened to contain this string would render as
`failure: state read failed: Error: ...` and not match. Nothing in the file
throws a non-Error.

That distinction matters because this fingerprint is a catch-all. `0d2963e`
says so itself: the `relay-failure` fingerprint also collects state-read and
watermark-update failures. So the `extra` shape does NOT discriminate builds
here. `extra.error` is always set, and `upstream_status` and `upstream_body`
are spread in only for a `LogsQueryError`, so a post-fix build failing on a
state read emits an `extra` with only `error` in it, exactly like a pre-fix
build. The observed events do carry that shape and it is consistent with the
reading, but it is not evidence for it. The message text is the whole proof.

Message shape fingerprints the build rather than the failure, so unlike a rate
argument this needs no assumption about DDL, cron timing or how often the CDN
502s. No code path in the post-fix function constructs that title. Grep finds
`logs query failed` only in this function, as the `LogsQueryError` message and
as a substring of the `postgres_logs query failed` console.error that never
reaches a title, and in this document. A GitHub code search across the account,
which indexes default branches only, returns this one file.

Scope this claim carefully. It establishes that a pre-`0d2963e` build was
serving as of the 2026-08-01 08:05 UTC event, not that one is serving now: the
relay only emits here on roughly 1 percent of runs, so no later event is not
evidence of anything, and a hand deploy at any point after 08:05 falsifies the
present tense while these events stay on the record. It also assumes no second
deployment of this source under another function name, which is possible
because `logger` and `server_name` are hard-coded constants in the file rather
than deployment identity. `supabase functions list` remains the check for
current state and for that assumption. And it is one function: it does not
establish the state of any other, though it is consistent with the two cases
above.

The method generalizes and is cheap, with one condition that is easy to get
wrong. When a fix changes a string that the event itself carries, the next
event in that group tells you which build answered, with no database or CLI
access. The condition is that the observed event must demonstrably have taken
the changed code path. For a catch-all fingerprint like this one it usually has
not, so prefer a discriminator that every path through the handler shares, the
way the `Error: ` prefix does here. The absence of an added `extra` key is
never a discriminator on its own: absence is also what an older path, a
different error type or a skipped branch produces. When writing a fix to a
function you cannot verify is deployed, deliberately change something
observable on every path, for exactly this reason.

Not explained by any of this, and still firing: a FATAL
`password authentication failed` roughly once every five minutes, continuously.
Nothing committed in either repo emits it, and it is most likely scan traffic,
but that last part is inference. See below, including how to settle it.

An earlier revision of this file said no code in either repo opens a direct
Postgres connection. That was wrong. The scripts under `scripts/voter_file/`
connect straight to `db.<ref>.supabase.co:5432` as the `postgres` superuser
via psycopg. They are still not the emitter: they are hand-run one-off
matching jobs with no scheduler behind them, and nothing runs them every five
minutes. So the conclusion stands, but for a different reason than the one
originally given.

Two separate things are known about that FATAL, and they are not equally
certain. Keep them apart. What is ESTABLISHED is that port 5432 is reachable
from the open internet and is being scanned. What is INFERRED, and not proven,
is that the password failures are that same scan traffic. The established part
comes from a second FATAL that landed in the same five-minute rollup window on
2026-07-31:

    unsupported frontend protocol 65363.19778: server supports 3.0 to 3.0

A Postgres startup packet is a 4-byte length followed by a 4-byte protocol
version, which the server logs as two 16-bit halves. 65363 is 0xFF53 and
19778 is 0x4D42, so the four version bytes it actually read were FF 53 4D 42,
the sequence `\xFFSMB`, which is the SMB1 protocol identifier.

The byte offsets line up exactly, which is what takes this past coincidence.
SMB1 over TCP is framed by a 4-byte NetBIOS session header, and `\xFFSMB`
begins at offset 4, precisely where Postgres expects the protocol version to
start. An SMB negotiate request sent to port 5432 produces this exact log
line and this exact pair of numbers. No Postgres client library can emit that
byte sequence, and nothing in either repo speaks SMB at all, so the sender is
a generic port scanner walking the host. That is the established part: the
direct-connect endpoint is reachable from the open internet and is taking
unsolicited traffic.

That was a single observation when it was written, which left open the reading
that one stray packet had been over-interpreted. It is not a one-off. A second
burst landed on 2026-07-31 in the 15:44 to 15:49 rollup window, carrying three
rejected startup packets across a 50 millisecond span:

    15:48:38.586  unsupported frontend protocol 0.0: server supports 3.0 to 3.0
    15:48:38.608  unsupported frontend protocol 255.255: server supports 3.0 to 3.0
    15:48:38.636  no PostgreSQL user name specified in startup packet

Decode those the same way as the SMB line above, major half then minor half.
0.0 is four version bytes of 00 00 00 00. 255.255 is 00 FF 00 FF, and it is
worth being exact about that rather than calling it all ones: an all-ones
version would log as 65535.65535. So the second one is a repeated 0x00FF
pattern, not a ones-complement sentinel. Both are impossible protocol versions
that no client library would ask for. The third line is a structurally valid
startup packet whose user field is empty or absent; Postgres logs that same
line either way and the two cases cannot be told apart from it.

Three different rejected handshakes 22 and 28 ms apart is what one client
enumerating the port looks like, and the unscrubbed source addresses in the log
explorer are what would confirm it. It is poorly explained by a misconfigured
client of ours retrying: no client in these repos configures an empty user, and
libpq-family clients default it to the OS account, so an empty user field is
not a plausible misconfiguration of anything committed here. That argument
reaches only as far as committed clients, for the reason given below.

So the exposure finding is now a recurring pattern with two independent
fingerprint families: SMB framing in the 10:05 UTC rollup window, recorded in
commit e72e361, and this protocol probing at 15:48, about five and three
quarter hours apart on the same day.

It does not settle the attribution, and it should not be read as if it did. The
fourth FATAL in that window is the password failure, identified by elimination
rather than read directly, because Sentry scrubs that line: the window carried
four FATALs, the three above are named, and the rollup's message table lists
exactly one other message family, the scrubbed password-failure line. Its
timestamp is not scrubbed and reads 15:48:20.127, roughly 18 seconds before
the burst, so it is still tied to the scan only by sharing a window and is
still not part of the burst itself. The two-field check in the log explorer
described below remains the thing that settles it. What this does change is
that the exposure is a recurring pattern rather than a single observation,
which strengthens the case for the deferred remediation recorded below. It is
not on its own a reason to escalate past what that paragraph already says.

The inferred part is the step from there to the password failures. A steady
low rate of failed authentication against a port in that condition is what
credential-stuffing scan traffic looks like, and that is the most economical
reading, but the two lines are correlated only by sharing a rollup window. Do
not write it down as fact until the check below is run.

The arrival times rule out one specific suspect, and it is worth doing
because this repo does have a `*/5 * * * *` pg_cron job whose period matches
"once every five minutes" exactly: job `mail-poll-fallback-5min`, which POSTs
the `mail-poll` function, in
`supabase/migrations/20260425_07_mail_phase5_cron.sql`. It is not the source,
nor is any other boundary-aligned scheduler. pg_cron fires on the boundary, so
its log lines cluster a few seconds past `:00`, `:05` and `:10`. Ten FATAL
timestamps sampled across 2026-07-31 00:50 to 10:13 UTC sit at 56, 60, 85,
139, 164, 196, 216, 233, 244 and 285 seconds into their five-minute window:
spread over 229 seconds of the available 300, with no clustering anywhere in
that sample; for a later window that does cluster, see the 2026-08-01 burst
recorded below. The 244 and the 60 fall in adjacent windows in that order,
which puts those two arrivals 116 seconds apart, and a job with a 300 second
period cannot produce that. So "roughly every five minutes" is a rate, not a
schedule.

Be careful how far that argument reaches. It eliminates pg_cron and anything
else firing on a fixed period. It does NOT eliminate every emitter of ours,
and the reason is the whole point of the section at the top of this file: a
stale deployed function, a retired box, or a third-party integration still
retrying an old DSN would be a misconfigured client of ours, would not be on a
boundary, and is invisible from these repos. Nothing here rules that out.

The 2026-08-01 rollup adds a shape the sampling above did not see, and it is
worth recording because that sampling is where "no clustering anywhere" comes
from. The 15:09 to 15:14 UTC window carried seven FATALs, all of the
password-failure family and no other message: `by_severity` reads FATAL 7 and
`by_message` carries exactly one key, which a 15-key tally cannot have
truncated. The rollup samples only five of the seven, so two timestamps are
unknown, but the five it does carry land between 15:12:16.775 and
15:12:18.836, spaced 692, 388, 585 and 396 ms apart. At least five attempts
inside 2.1 seconds is a burst, not a drip.

For scale: across the relay events from 14:00 to 15:55 UTC that day, every
other rollup carried one or two Postgres errors, and each was titled "includes
FATAL", which the relay sets only when some row is FATAL or PANIC. This one
carried seven, and nothing else in the sampled range approaches it. Four
five-minute slots in that stretch produced no rollup at all.

Do not read those four as proven-empty windows, and it is worth spelling out
why, because the obvious reading is wrong. No rollup means only that the run
sent nothing, and this relay has two paths that send nothing while still
advancing the watermark: a failed `postgres_logs` query is caught non-fatally
and substitutes an empty row set, and `sendSentryEvent` returns null on a
failed ingest without throwing. Either hides real errors permanently, because
the watermark moves on regardless. What IS established about the slot before
the burst is that a run completed near 15:10, since the burst rollup's
`window_start` of 15:09:01.451 gives it a clean five-minute window and a
skipped or failed run would have left a wider one. Whether that run saw
nothing or swallowed something needs the runtime logs, which were not checked.

What that rules out is narrower than it first looks, and the temptation to
overclaim here is the reason this paragraph is worded so carefully. It is a
poor fit for exactly one alternative: a single stale client retrying on a
timer does not fire five times inside two seconds. It is NOT evidence for the
scanning reading over the rest of the alternative class, because a connection
pool cold-starting against a stale credential produces this same shape, and
that is squarely the "stale deployed function, retired box, or third-party
integration" case the paragraph above preserves. Sub-second spacing is
ordinary for any serially reconnecting client and is not a fingerprint of
anything on its own. So the burst removes one sub-variant and leaves the two
readings that actually matter exactly where they were. The two unscrubbed
fields named below remain the only thing that settles it.

So: the exposure is proven, the attribution is not. The Supabase dashboard log
explorer keeps the unscrubbed lines that Sentry strips, and two fields settle
it in about a minute. Many source addresses attempting names like `admin` or
`root` is scanning. One address attempting the `postgres` role is the leaked
credential in use, and is an incident. A single address attempting one of our
own role names is the stale-client case above, and is a config fix.

Scanning being the answer is not the same as nothing to do. If 5432 does not
need to be open to the world, closing it is the actual remediation: Supabase
network restrictions, or dropping the direct-connect endpoint in favour of the
pooler. That is deferred rather than dismissed, because the
`scripts/voter_file/` jobs connect directly and would need an allowed source
first.

One more line appeared in the rollup on 2026-07-31 and is recorded here only
so the next run does not spend itself rediscovering it:

    invalid input syntax for type integer: "2019.5"

ERROR level, once in 24 hours, at 02:56:46 UTC. A search of both repos for
code that writes a fractional value into an integer column came back empty:
the year `RangeSlider`s in `call_time_tab.dart` and `mec_research_tab.dart`
`.round()` before they reach `p_year_from` and `p_year_to`, and the
`birth_year` and `estimated_age` writers in `scripts/voter_file/` are `int`
typed or `::int` cast. Nothing is scheduled at 02:56 either.

The likeliest remaining candidate, and the reason a repo search cannot clear
this, is `graduation_year`. It is text, inferred from the `!= ''` comparison
in `supabase/migrations/20260423_01_backfill_orphan_rpcs.sql` and from the
text-typed Dart model, since no DDL for it exists in this repo. Being text is
what makes it interesting rather than what clears it: a text column is the
only way a string like `2019.5` gets stored at all, member-supplied with no
numeric validation on either write path
(`supabase/functions/process-member-info-update/index.ts` and
`zapier-webhook/index.ts`), and `2019.5` reads exactly like a graduation year.
A write to it cannot raise this error, but a later `graduation_year::int` cast
raises precisely this error. No such cast exists in this repo, which given the
deployment drift documented at the top of this file clears very little: a
deployed-only RPC casting that column is exactly the emitter a repo search
cannot see.

Left alone deliberately anyway. One log line a day with no stack trace does
not justify guessing, and the guess above is a hypothesis for the next run to
test, not a diagnosis. If it becomes frequent, the Supabase log explorer has
the statement that threw.

Those scripts carried the production `postgres` password as a hardcoded
literal, in a repo that is public. See the commit that replaced it with the
required `MOYD_DB_DSN` environment variable. Removing the literal does not
revoke it: it stayed in the published history and has to be assumed harvested
until the password is rotated in the Supabase dashboard. Read the scan finding
above the right way round. It does not make that rotation less urgent. It
makes it more urgent, because it establishes that the port this credential
opens is being actively probed from the open internet.

The same commit scrubbed a second published credential: the shared
`crm@moyoungdemocrats.org` workspace mailbox password, which was sitting in
plaintext in `docs/superpowers/handoff/2026-04-25-mail-client-phase1.md`. It
needs rotating on the same assumption and for the same reason. Both now point
at the Obsidian credentials file instead of inlining the value. Do not inline
a secret in this repo again: it is public.

Before deploying, note that the deployed and committed versions of many
functions have diverged for an unknown period. Deploying them all at once
pushes that entire backlog live in one step. Deploy the specific function you
changed, and check what else has drifted before running a bulk deploy.

The endorsement-vote functions are a separate hazard in the other direction.
`verify-member-for-vote` and `send-endorsement-thankyou` have no commits other
than the ones that rescued their already-deployed source into git, so there is
no known committed-newer-than-deployed drift to push. What a bulk deploy would
do instead is overwrite whatever is live for them, including any out-of-band
dashboard edit, and their live state has never been compared against git. That
is a bad thing to do while sixteen people are casting real ballots.

## READ SECOND: check where the local branch refs point before committing

Check where `master` actually points before you commit anything. In the
2026-08-01 triage container both repos presented a local branch ref a week
behind the real remote head:

    local master                      f17be39   2026-07-26 UTC
    local origin/master               f17be39   stale copy of the same
    refs/heads/master on the remote   5c4d3ac   2026-08-01 UTC

`f17be39` is a plain ancestor of `5c4d3ac`, so the local ref was behind rather
than divergent. The same shape was present in `moyoungdemocrats`: local `main`
at `d2c3cd7` from 2026-07-26 UTC against a real `refs/heads/main` of `77d879f`.

How the container arrives in that state is NOT established, and the reflogs
argue against the obvious guess that it clones with `HEAD` detached at the true
tip: in both repos the earliest recorded `HEAD` is the stale tip, and the
detached checkout at the true tip appears later. Two observations inside one
container is also not enough to call it a property of the clone. Treat this as
something to check, not something known to recur.

Why it matters more than an inconvenience: `git checkout master` silently moves
you onto the stale tip, and a commit made there is based on a tree missing
every triage commit since the stale date. The push is then refused as a
non-fast-forward, because the remote head is not an ancestor of your new
commit. That refusal is the good case. The bad case is reading it as something
to force past. Never force-push here to resolve it.

The check is `git ls-remote --heads origin <branch>` compared against
`git rev-parse <branch>`. The repair is:

    git fetch origin <branch>
    git checkout -B <branch> FETCH_HEAD

`-B` moves the branch ref and will discard any local commits already sitting on
it, including one made on the stale base, recoverable afterwards only through
the reflog. Commit or stash first, then rebase or cherry-pick your own work
onto the new tip rather than assuming `-B` carried it across.

One more trap in the same area: the clone is shallow, 51 commits here, so
history ends at a graft point, and ancestry questions across that boundary do
not give a trustworthy negative. If the far commit is absent locally,
`git merge-base --is-ancestor` fails outright rather than answering; if it is
present but the graft cuts connectivity, the answer can be a wrong NO. Neither
case means history has diverged.

This was found by a stash pop conflicting during the 2026-08-01 run, not by
looking for it.

## READ THIRD: storage 400s on the private `meetings` bucket, and the fix that must never be made

SUPABASE-PLATFORM-4 is the storage category of the 5-minute Supabase log
rollup. It fired 6 times between 2026-07-25 15:05 and 2026-08-03 00:45 UTC,
carrying 9 failed requests in total, and Sentry records 0 users impacted.
Every one of the nine is status 400 against the `meetings` bucket from a
single source address, which is not reproduced here. For five of the nine, and
the only recurring shape among them, the only code that ever minted that URL
shape was removed in `af1ca85`, so no further code follows. This note exists so
the next run does not rediscover that, and above all so it does not reach for
the obvious fix, which is forbidden.

THE FIX THAT MUST NEVER BE MADE
Do not flip `meetings` public, and do not widen the storage read policy to
clear this. That bucket holds the verbatim transcripts of executive committee
and all-members meetings. Per the comment in `storage_uri_resolver.dart`, it
was public until `050_meetings_transcript_access.sql` in the `moyd-ops` repo
took it private and gated reads on `public.is_executive()`. That SQL lives in
a third repo and cannot be verified from here, but the direction of travel is
not in doubt. A 400 on an unauthenticated read of this bucket is the system
doing its job. The resolver says the same thing in its own words: a dead link
is the correct outcome, a working unauthenticated one is not.

WHAT THE KEYS MEAN, SO NOBODY "FIXES" THEM
The observed keys look like a mangled filename and are not. `storeTranscript`
in both `meetings-zap` and `import-historical-meetings` writes
`transcripts/${cleanTitle}/${month}/${day}/${year}.txt`, so
`transcripts/<title>/07/15/2026.txt` is one path segment
per date component by design. Both writers return that key and store it
verbatim in `meetings.transcript_file_path`. Do not add encoding, and do not
collapse the date segments.

THE NINE REQUESTS
    2026-07-25 15:00:58  GET  /object/public/meetings/transcripts/<title>.vtt
    2026-07-25 15:53:29  POST /object/sign/meetings/transcripts/<title>/07/15/2026.txt
    2026-07-25 16:33:47  POST /object/sign/meetings/transcripts/<title>/07/15/2026.txt
    2026-07-26 14:45:13  GET  /object/public/meetings/transcripts/<title>/07/15/2026.txt
    2026-07-26 14:45:14  GET  /object/public/meetings/transcripts/<title>/06/17/2026.txt
    2026-07-26 14:45:14  GET  /object/public/meetings/transcripts/<title>/05/20/2026.txt
    2026-07-27 08:39:50  GET  /object/public/meetings/
    2026-08-03 00:41:20  GET  /object/public/meetings/transcripts/<title>/07/15/2026.txt
    2026-08-03 00:41:33  GET  /object/meetings/transcripts/<title>/07/15/2026.txt

WHERE THE FIVE RECURRING REQUESTS COME FROM, AND WHY NO CODE FOLLOWS
Read the resolver as it stood before `af1ca85`, at
`af1ca85^:lib/services/crm/storage_uri_resolver.dart`: for a relative path
starting `transcripts/`, `recordings/` or `documents/` it built
`storage/v1/object/public/meetings/$relativePath` and returned it.

That branch accounts for five of the nine requests. Four are in the writers'
exact key shape, the 07-26 trio and the 08-03 00:41:20 request, and it
reproduces their URLs character for character once percent-encoding is applied.
The fifth is the 07-25 15:00:58 `.vtt`, which is not a shape either writer
produces but does begin `transcripts/`, so the same branch turns a stored value
of that form into exactly the URL observed. So the mechanism is not a mystery
and is not something a person had to construct by hand: it is the old build
doing exactly what it was written to do, against a bucket that has since gone
private.

`af1ca85`, 2026-07-25 16:48 UTC, replaced that branch with a signing branch
and added `_privateBuckets`, so the current build signs these and returns null
on failure rather than emitting a public URL. Both 07-25 signing requests
predate it, and no signing request appears anywhere in the group afterwards.

Why the shape still appeared on 08-03, nine days after the fix, is NOT
established, and two explanations survive that cannot be told apart from here.
One is a stale client: `netlify.toml` records that `main.dart.js` and the
`*.part.js` chunks are NOT content-hashed, and a reload picks up the new build,
but a CRM tab left open since before the 07-25 deploy keeps running the old
resolver out of memory. Nine days is a long time for one tab. The other needs
no tab at all: these URLs worked while the bucket was public, so a bookmark, a
saved link or one pasted into a document reproduces the identical GET forever.

Do not collapse those two. The 08-03 pair argues against the tab reading if
anything: the 00:41:33 request on the bare `/object/` endpoint landed 13
seconds after the 00:41:20 public GET, from the same source, and nothing in
this repo constructs the bare form. One actor emitting an old-build-shaped URL
and a no-build-shaped URL 13 seconds apart fits someone replaying and editing a
link at least as well as it fits a nine-day-old tab.

Note also that the 07-26 trio landed inside 0.5 seconds, at 14:45:13.915, .199
and .406, which is faster than anyone clicks through three meeting screens.
That is what a browser session restore looks like. No surface in this repo
bulk-resolves transcripts: both resolver call sites,
`meeting_detail_screen.dart` and `global_crm_search_dialog.dart`, are
click-driven and resolve one path each.

WHAT THE CURRENT SOURCE DOES AND DOES NOT RULE OUT
For a transcript path in the writers' shape, that is one beginning
`transcripts/`, the current resolver has no path that produces a public URL:
it signs, and `_privateBuckets` refuses the public fallback for `meetings`.
That is a claim about writer-shaped values only, and it is NOT a claim that
the current app can never emit one. Two pass-throughs survive in the current
file. An absolute `https://` value is returned untouched, and a relative value
already beginning `storage/v1/object/` is resolved against the project URL and
returned. Either would reproduce the public-GET shape, and either is reachable
today, because `meeting_edit_sheet.dart` exposes `transcript_file_path` as a
free-text field. The 07-25 15:00 request names `transcripts/<title>.vtt`, a
shape neither writer produces, so rows outside the convention likely exist. The
request alone cannot prove one does, since a saved or hand-typed URL needs no
row behind it, and that is exactly why you check the row rather than the code
before concluding the current build is innocent of some future occurrence.

For completeness on the endpoints: `/object/sign/` is not the only storage
endpoint the current app touches for this bucket. `global_search_service.dart`
also calls `/object/list/` against `meetings` on every global document search.
A list failure would not present as a public-object GET, so it does not
explain anything here, but do not repeat the claim that signing is the only
call.

WHAT REMAINS UNESTABLISHED
Why the two signing requests returned 400. That is the half that could still
be a live defect, because a failed sign puts an exec on "Unable to open
transcript link". A 400 there is consistent with the key not existing and with
the read being refused, and nothing in this repo distinguishes them. Do not
build a diagnosis on an assumed meaning for that status code. The other two
one-off shapes, the bare bucket root and the 08-03 `/object/` GET, are also
unexplained, and nothing in this repo constructs either. Do not describe those
two as unauthenticated: the rollup sample carries no authentication
information at all, only ip, method, path, status and timestamp, and on the
bare `/object/` endpoint an anonymous caller, an
authenticated non-executive and an executive with a bad key are
indistinguishable from that.

Two checks in the Supabase dashboard settle the signing question, and neither
can be run from this container: list the `meetings` bucket under
`transcripts/<title>/07/15/` and see whether `2026.txt` is
there, and read the unscrubbed storage log line for either 07-25 signing
request, which carries the error the 400 stands for. The unredacted title is
in the SUPABASE-PLATFORM-4 event sample in Sentry, which is where it belongs.

Left alone deliberately on 2026-08-03. No code change: the only recurring
mechanism was already fixed in `af1ca85`, the residue is consistent with a
stale client or an old saved link and cannot be attributed from here, and the
signing 400 is not established well enough to act on. Do not resolve
SUPABASE-PLATFORM-4 in Sentry. Nothing was fixed this run.

One disclosure judgement, made deliberately rather than by accident: this repo
is PUBLIC, confirmed against the GitHub API on 2026-08-03, not private. This
note commits the issue ID, the object key prefix and three executive meeting
dates to it. None of that is a secret, none of it widens read access, and the
source address is withheld. The meeting title is redacted to `<title>`
everywhere in this note, including in the dashboard-check instruction; it adds
nothing a future run needs and it is the one identifying part. Weigh this same
trade rather than assume it, and check the visibility rather than assume it:
the sibling `moyoungdemocrats` repo is private and this one is not, so the
habit of reasoning about "the repo" as one thing is itself the trap.

## Table of Contents
1. [Overview](#overview)
2. [Architecture Analysis](#architecture-analysis)
3. [Integration Principles](#integration-principles)
4. [Step-by-Step Implementation](#step-by-step-implementation)
5. [File Structure](#file-structure)
6. [Detailed Implementation](#detailed-implementation)
7. [UI Customization](#ui-customization)
8. [Bulk Messaging System](#bulk-messaging-system)
9. [Testing Strategy](#testing-strategy)
10. [Deployment Checklist](#deployment-checklist)

--- //NEW
### 🎨 Missouri Young Democrats Brand Colors

#### Primary Colors
- **Unity Blue** — `#273351`
- **Momentum Blue** — `#32A6DE`

#### Secondary Colors
- **Sunrise Gold** — `#FDB813`
- **Action Red** — `#E63946`
- **Justice Purple** — `#6A1B9A`
- **Grassroots Green** — `#43A047`

## Overview

### Goal
Integrate Missouri Young Democrats CRM functionality into the existing BlueBubbles web app without breaking any existing messaging infrastructure. The system must:
- Pull member data from Supabase
- Display member information in chat contexts
- Enable bulk individual messaging based on filters (county, congressional district, committee, age, etc.)
- Maintain ALL existing BlueBubbles functionality unchanged

### Critical Constraint
**DO NOT MODIFY OR MIGRATE** the existing BlueBubbles conversation/message storage system (ObjectBox). This is working perfectly and must remain untouched.

### Technology Stack
- **Existing:** Flutter/Dart, ObjectBox (local storage), BlueBubbles Private API
- **New:** Supabase (member data only), Supabase Flutter SDK

---

## Architecture Analysis

### Current BlueBubbles Structure

```
BlueBubbles Storage (ObjectBox - DO NOT TOUCH):
├── Chat (conversations)
│   ├── guid (unique identifier)
│   ├── chatIdentifier (phone/email)
│   ├── displayName
│   ├── participants (List<Handle>)
│   └── messages (relationship)
├── Message (individual messages)
│   ├── guid
│   ├── text
│   ├── dateCreated
│   ├── isFromMe
│   └── chat (relationship)
├── Handle (contacts/participants)
│   ├── address (phone number)
│   ├── formattedAddress
│   ├── service (iMessage/SMS)
│   └── contact (relationship)
└── Contact (local contact info)
    ├── id
    ├── displayName
    ├── phones
    └── emails
```

### New CRM Layer (Supabase Integration)

```
CRM Layer (Supabase - NEW):
└── members (Supabase table)
    ├── All demographic fields
    ├── phone_e164 (KEY: links to Handle.address)
    └── committee, county, congressional_district (filters)

Integration Point:
Handle.address (BlueBubbles) ←→ member.phone_e164 (Supabase)
```

**Key Insight:** We link BlueBubbles Handles to Supabase Members via phone number (E.164 format). This allows us to:
1. Show member data when viewing any chat
2. Start new chats from the CRM member list
3. Send bulk messages by filtering members, then creating individual chats

---

## Integration Principles

### Core Rules
1. **Never modify ObjectBox models** (Chat, Message, Handle, Contact, Attachment)
2. **Never migrate conversation data** to Supabase
3. **Add, don't replace** - all new code should be additive
4. **Use existing messaging APIs** - don't create new message sending logic
5. **Preserve all UI flows** - existing users should see no breaking changes

### Integration Pattern
```
User Action (CRM) → Filter Members (Supabase) → 
Map to phone_e164 → Find/Create Handles (BlueBubbles) → 
Use existing sendMessage() API → Individual messages sent
```

---

## Step-by-Step Implementation

### Step 1: Add Dependencies

**File: `pubspec.yaml`**

Add to dependencies section:
```yaml
dependencies:
  # Existing dependencies remain unchanged
  
  # NEW CRM DEPENDENCIES
  supabase_flutter: ^2.3.4
```

Run:
```bash
flutter pub get
```

---

### Step 2: Create Supabase Configuration

**File: `lib/config/crm_config.dart`** (NEW FILE)

```dart
/// CRM Configuration - Supabase connection details
/// IMPORTANT: Never commit real credentials to Git
class CRMConfig {
  // TODO: Replace with environment variables in production
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Feature flags
  static const bool crmEnabled = true;
  static const bool bulkMessagingEnabled = true;
  
  // Rate limiting for bulk messages
  static const int messagesPerMinute = 30;
  static const Duration messageDelay = Duration(seconds: 2);
}
```

---

### Step 3: Initialize Supabase Service

**File: `lib/services/crm/supabase_service.dart`** (NEW FILE)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/crm_config.dart';

/// Singleton service for Supabase connection
/// This is the ONLY place that interacts with Supabase
class CRMSupabaseService {
  static final CRMSupabaseService _instance = CRMSupabaseService._internal();
  factory CRMSupabaseService() => _instance;
  CRMSupabaseService._internal();

  SupabaseClient? _client;
  bool _initialized = false;

  /// Initialize Supabase connection
  /// Call this once during app startup
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      await Supabase.initialize(
        url: CRMConfig.supabaseUrl,
        anonKey: CRMConfig.supabaseAnonKey,
      );
      
      _client = Supabase.instance.client;
      _initialized = true;
      print('✅ CRM Supabase initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize CRM Supabase: $e');
      rethrow;
    }
  }

  /// Get Supabase client instance
  SupabaseClient get client {
    if (!_initialized || _client == null) {
      throw Exception('CRMSupabaseService not initialized. Call initialize() first.');
    }
    return _client!;
  }

  bool get isInitialized => _initialized;
}
```

---

### Step 4: Create Member Data Model

**File: `lib/models/crm/member.dart`** (NEW FILE)

```dart
/// Member model - maps to Supabase 'members' table
/// This is a separate model from BlueBubbles Contact/Handle
class Member {
  final String id;
  final DateTime? createdAt;
  final String name;
  final String? email;
  final String? phone;
  final String? phoneE164; // KEY FIELD - links to Handle.address
  final DateTime? dateOfBirth;
  final String? preferredPronouns;
  final String? genderIdentity;
  final String? address;
  final String? county;
  final String? congressionalDistrict;
  final String? race;
  final String? sexualOrientation;
  final String? desireToLead;
  final String? hoursPerWeek;
  final String? educationLevel;
  final bool? registeredVoter;
  final String? inSchool;
  final String? schoolName;
  final String? employed;
  final String? industry;
  final bool? hispanicLatino;
  final String? accommodations;
  final String? communityType;
  final String? languages;
  final String? whyJoin;
  final DateTime? lastContacted;
  final bool optOut;
  final List<String>? committee;
  final String? notes;
  final DateTime? introSentAt;
  final String? optOutReason;
  final DateTime? optOutDate;
  final DateTime? optInDate;
  final String? disability;
  final String? politicalExperience;
  final String? currentInvolvement;
  final String? religion;
  final String? instagram;
  final String? tiktok;
  final String? x;
  final String? zodiacSign;
  final String? leadershipExperience;
  final DateTime? dateJoined;
  final String? goalsAndAmbitions;
  final String? qualifiedExperience;
  final String? referralSource;
  final String? passionateIssues;
  final String? whyIssuesMatter;
  final String? areasOfInterest;

  Member({
    required this.id,
    this.createdAt,
    required this.name,
    this.email,
    this.phone,
    this.phoneE164,
    this.dateOfBirth,
    this.preferredPronouns,
    this.genderIdentity,
    this.address,
    this.county,
    this.congressionalDistrict,
    this.race,
    this.sexualOrientation,
    this.desireToLead,
    this.hoursPerWeek,
    this.educationLevel,
    this.registeredVoter,
    this.inSchool,
    this.schoolName,
    this.employed,
    this.industry,
    this.hispanicLatino,
    this.accommodations,
    this.communityType,
    this.languages,
    this.whyJoin,
    this.lastContacted,
    this.optOut = false,
    this.committee,
    this.notes,
    this.introSentAt,
    this.optOutReason,
    this.optOutDate,
    this.optInDate,
    this.disability,
    this.politicalExperience,
    this.currentInvolvement,
    this.religion,
    this.instagram,
    this.tiktok,
    this.x,
    this.zodiacSign,
    this.leadershipExperience,
    this.dateJoined,
    this.goalsAndAmbitions,
    this.qualifiedExperience,
    this.referralSource,
    this.passionateIssues,
    this.whyIssuesMatter,
    this.areasOfInterest,
  });

  /// Create Member from Supabase JSON response
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      phoneE164: json['phone_e164'] as String?,
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.parse(json['date_of_birth'] as String) 
          : null,
      preferredPronouns: json['preferred_pronouns'] as String?,
      genderIdentity: json['gender_identity'] as String?,
      address: json['address'] as String?,
      county: json['county'] as String?,
      congressionalDistrict: json['congressional_district'] as String?,
      race: json['race'] as String?,
      sexualOrientation: json['sexual_orientation'] as String?,
      desireToLead: json['desire_to_lead'] as String?,
      hoursPerWeek: json['hours_per_week'] as String?,
      educationLevel: json['education_level'] as String?,
      registeredVoter: json['registered_voter'] as bool?,
      inSchool: json['in_school'] as String?,
      schoolName: json['school_name'] as String?,
      employed: json['employed'] as String?,
      industry: json['industry'] as String?,
      hispanicLatino: json['hispanic_latino'] as bool?,
      accommodations: json['accommodations'] as String?,
      communityType: json['community_type'] as String?,
      languages: json['languages'] as String?,
      whyJoin: json['why_join'] as String?,
      lastContacted: json['last_contacted'] != null 
          ? DateTime.parse(json['last_contacted'] as String) 
          : null,
      optOut: json['opt_out'] as bool? ?? false,
      committee: json['committee'] != null 
          ? List<String>.from(json['committee'] as List) 
          : null,
      notes: json['notes'] as String?,
      introSentAt: json['intro_sent_at'] != null 
          ? DateTime.parse(json['intro_sent_at'] as String) 
          : null,
      optOutReason: json['opt_out_reason'] as String?,
      optOutDate: json['opt_out_date'] != null 
          ? DateTime.parse(json['opt_out_date'] as String) 
          : null,
      optInDate: json['opt_in_date'] != null 
          ? DateTime.parse(json['opt_in_date'] as String) 
          : null,
      disability: json['disability'] as String?,
      politicalExperience: json['political_experience'] as String?,
      currentInvolvement: json['current_involvement'] as String?,
      religion: json['religion'] as String?,
      instagram: json['instagram'] as String?,
      tiktok: json['tiktok'] as String?,
      x: json['x'] as String?,
      zodiacSign: json['zodiac_sign'] as String?,
      leadershipExperience: json['leadership_experience'] as String?,
      dateJoined: json['date_joined'] != null 
          ? DateTime.parse(json['date_joined'] as String) 
          : null,
      goalsAndAmbitions: json['goals_and_ambitions'] as String?,
      qualifiedExperience: json['qualified_experience'] as String?,
      referralSource: json['referral_source'] as String?,
      passionateIssues: json['passionate_issues'] as String?,
      whyIssuesMatter: json['why_issues_matter'] as String?,
      areasOfInterest: json['areas_of_interest'] as String?,
    );
  }

  /// Convert to JSON for Supabase updates
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt?.toIso8601String(),
      'name': name,
      'email': email,
      'phone': phone,
      'phone_e164': phoneE164,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
      'preferred_pronouns': preferredPronouns,
      'gender_identity': genderIdentity,
      'address': address,
      'county': county,
      'congressional_district': congressionalDistrict,
      'race': race,
      'sexual_orientation': sexualOrientation,
      'desire_to_lead': desireToLead,
      'hours_per_week': hoursPerWeek,
      'education_level': educationLevel,
      'registered_voter': registeredVoter,
      'in_school': inSchool,
      'school_name': schoolName,
      'employed': employed,
      'industry': industry,
      'hispanic_latino': hispanicLatino,
      'accommodations': accommodations,
      'community_type': communityType,
      'languages': languages,
      'why_join': whyJoin,
      'last_contacted': lastContacted?.toIso8601String(),
      'opt_out': optOut,
      'committee': committee,
      'notes': notes,
      'intro_sent_at': introSentAt?.toIso8601String(),
      'opt_out_reason': optOutReason,
      'opt_out_date': optOutDate?.toIso8601String(),
      'opt_in_date': optInDate?.toIso8601String(),
      'disability': disability,
      'political_experience': politicalExperience,
      'current_involvement': currentInvolvement,
      'religion': religion,
      'instagram': instagram,
      'tiktok': tiktok,
      'x': x,
      'zodiac_sign': zodiacSign,
      'leadership_experience': leadershipExperience,
      'date_joined': dateJoined?.toIso8601String().split('T')[0],
      'goals_and_ambitions': goalsAndAmbitions,
      'qualified_experience': qualifiedExperience,
      'referral_source': referralSource,
      'passionate_issues': passionateIssues,
      'why_issues_matter': whyIssuesMatter,
      'areas_of_interest': areasOfInterest,
    };
  }

  /// Helper: Get age from date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  /// Helper: Check if member can be contacted
  bool get canContact => !optOut && phoneE164 != null && phoneE164!.isNotEmpty;

  /// Helper: Format committees as string
  String get committeesString => committee?.join(', ') ?? 'None';

  /// Copy with method for updates
  Member copyWith({
    String? id,
    DateTime? createdAt,
    String? name,
    String? email,
    String? phone,
    String? phoneE164,
    DateTime? dateOfBirth,
    String? preferredPronouns,
    String? genderIdentity,
    String? address,
    String? county,
    String? congressionalDistrict,
    String? race,
    String? sexualOrientation,
    String? desireToLead,
    String? hoursPerWeek,
    String? educationLevel,
    bool? registeredVoter,
    String? inSchool,
    String? schoolName,
    String? employed,
    String? industry,
    bool? hispanicLatino,
    String? accommodations,
    String? communityType,
    String? languages,
    String? whyJoin,
    DateTime? lastContacted,
    bool? optOut,
    List<String>? committee,
    String? notes,
    DateTime? introSentAt,
    String? optOutReason,
    DateTime? optOutDate,
    DateTime? optInDate,
    String? disability,
    String? politicalExperience,
    String? currentInvolvement,
    String? religion,
    String? instagram,
    String? tiktok,
    String? x,
    String? zodiacSign,
    String? leadershipExperience,
    DateTime? dateJoined,
    String? goalsAndAmbitions,
    String? qualifiedExperience,
    String? referralSource,
    String? passionateIssues,
    String? whyIssuesMatter,
    String? areasOfInterest,
  }) {
    return Member(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneE164: phoneE164 ?? this.phoneE164,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredPronouns: preferredPronouns ?? this.preferredPronouns,
      genderIdentity: genderIdentity ?? this.genderIdentity,
      address: address ?? this.address,
      county: county ?? this.county,
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      race: race ?? this.race,
      sexualOrientation: sexualOrientation ?? this.sexualOrientation,
      desireToLead: desireToLead ?? this.desireToLead,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      educationLevel: educationLevel ?? this.educationLevel,
      registeredVoter: registeredVoter ?? this.registeredVoter,
      inSchool: inSchool ?? this.inSchool,
      schoolName: schoolName ?? this.schoolName,
      employed: employed ?? this.employed,
      industry: industry ?? this.industry,
      hispanicLatino: hispanicLatino ?? this.hispanicLatino,
      accommodations: accommodations ?? this.accommodations,
      communityType: communityType ?? this.communityType,
      languages: languages ?? this.languages,
      whyJoin: whyJoin ?? this.whyJoin,
      lastContacted: lastContacted ?? this.lastContacted,
      optOut: optOut ?? this.optOut,
      committee: committee ?? this.committee,
      notes: notes ?? this.notes,
      introSentAt: introSentAt ?? this.introSentAt,
      optOutReason: optOutReason ?? this.optOutReason,
      optOutDate: optOutDate ?? this.optOutDate,
      optInDate: optInDate ?? this.optInDate,
      disability: disability ?? this.disability,
      politicalExperience: politicalExperience ?? this.politicalExperience,
      currentInvolvement: currentInvolvement ?? this.currentInvolvement,
      religion: religion ?? this.religion,
      instagram: instagram ?? this.instagram,
      tiktok: tiktok ?? this.tiktok,
      x: x ?? this.x,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      leadershipExperience: leadershipExperience ?? this.leadershipExperience,
      dateJoined: dateJoined ?? this.dateJoined,
      goalsAndAmbitions: goalsAndAmbitions ?? this.goalsAndAmbitions,
      qualifiedExperience: qualifiedExperience ?? this.qualifiedExperience,
      referralSource: referralSource ?? this.referralSource,
      passionateIssues: passionateIssues ?? this.passionateIssues,
      whyIssuesMatter: whyIssuesMatter ?? this.whyIssuesMatter,
      areasOfInterest: areasOfInterest ?? this.areasOfInterest,
    );
  }
}
```

---

### Step 5: Create Member Repository

**File: `lib/services/crm/member_repository.dart`** (NEW FILE)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/crm/member.dart';
import 'supabase_service.dart';

/// Repository for member CRUD operations
/// All Supabase queries for members go through here
class MemberRepository {
  final CRMSupabaseService _supabase = CRMSupabaseService();

  /// Get all members (with optional filters)
  Future<List<Member>> getAllMembers({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    int? minAge,
    int? maxAge,
    bool? optedOut,
  }) async {
    try {
      var query = _supabase.client.from('members').select();

      // Apply filters
      if (county != null && county.isNotEmpty) {
        query = query.eq('county', county);
      }
      
      if (congressionalDistrict != null && congressionalDistrict.isNotEmpty) {
        query = query.eq('congressional_district', congressionalDistrict);
      }
      
      if (committees != null && committees.isNotEmpty) {
        query = query.overlaps('committee', committees);
      }
      
      if (optedOut != null) {
        query = query.eq('opt_out', optedOut);
      }

      final response = await query as List<dynamic>;
      
      List<Member> members = response
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();

      // Apply age filter in-memory (since calculated field)
      if (minAge != null || maxAge != null) {
        members = members.where((member) {
          final age = member.age;
          if (age == null) return false;
          if (minAge != null && age < minAge) return false;
          if (maxAge != null && age > maxAge) return false;
          return true;
        }).toList();
      }

      return members;
    } catch (e) {
      print('❌ Error fetching members: $e');
      rethrow;
    }
  }

  /// Get member by ID
  Future<Member?> getMemberById(String id) async {
    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('id', id)
          .single();

      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by ID: $e');
      return null;
    }
  }

  /// Get member by phone number (E.164 format)
  /// This is the KEY lookup for linking to BlueBubbles Handles
  Future<Member?> getMemberByPhone(String phoneE164) async {
    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .eq('phone_e164', phoneE164)
          .maybeSingle();

      if (response == null) return null;
      return Member.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Error fetching member by phone: $e');
      return null;
    }
  }

  /// Get all unique counties (for filter UI)
  Future<List<String>> getUniqueCounties() async {
    try {
      final response = await _supabase.client
          .from('members')
          .select('county')
          .not('county', 'is', null);

      final counties = (response as List<dynamic>)
          .map((item) => item['county'] as String)
          .toSet()
          .toList();
      
      counties.sort();
      return counties;
    } catch (e) {
      print('❌ Error fetching counties: $e');
      return [];
    }
  }

  /// Get all unique congressional districts (for filter UI)
  Future<List<String>> getUniqueCongressionalDistricts() async {
    try {
      final response = await _supabase.client
          .from('members')
          .select('congressional_district')
          .not('congressional_district', 'is', null);

      final districts = (response as List<dynamic>)
          .map((item) => item['congressional_district'] as String)
          .toSet()
          .toList();
      
      districts.sort();
      return districts;
    } catch (e) {
      print('❌ Error fetching congressional districts: $e');
      return [];
    }
  }

  /// Get all unique committees (for filter UI)
  Future<List<String>> getUniqueCommittees() async {
    try {
      final response = await _supabase.client
          .from('members')
          .select('committee')
          .not('committee', 'is', null);

      // Flatten array of arrays
      final allCommittees = <String>{};
      for (var item in response as List<dynamic>) {
        final committees = item['committee'] as List<dynamic>?;
        if (committees != null) {
          allCommittees.addAll(committees.map((c) => c.toString()));
        }
      }
      
      final sortedCommittees = allCommittees.toList();
      sortedCommittees.sort();
      return sortedCommittees;
    } catch (e) {
      print('❌ Error fetching committees: $e');
      return [];
    }
  }

  /// Update member's last contacted timestamp
  Future<void> updateLastContacted(String memberId) async {
    try {
      await _supabase.client
          .from('members')
          .update({'last_contacted': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating last contacted: $e');
    }
  }

  /// Update member's intro sent timestamp
  Future<void> markIntroSent(String memberId) async {
    try {
      await _supabase.client
          .from('members')
          .update({'intro_sent_at': DateTime.now().toIso8601String()})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error marking intro sent: $e');
    }
  }

  /// Update member's opt-out status
  Future<void> updateOptOutStatus(
    String memberId, 
    bool optOut, 
    {String? reason}
  ) async {
    try {
      final data = {
        'opt_out': optOut,
        optOut ? 'opt_out_date' : 'opt_in_date': DateTime.now().toIso8601String(),
      };
      
      if (reason != null) {
        data['opt_out_reason'] = reason;
      }

      await _supabase.client
          .from('members')
          .update(data)
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating opt-out status: $e');
    }
  }

  /// Update member notes
  Future<void> updateNotes(String memberId, String notes) async {
    try {
      await _supabase.client
          .from('members')
          .update({'notes': notes})
          .eq('id', memberId);
    } catch (e) {
      print('❌ Error updating notes: $e');
    }
  }

  /// Search members by name or phone
  Future<List<Member>> searchMembers(String query) async {
    try {
      final response = await _supabase.client
          .from('members')
          .select()
          .or('name.ilike.%$query%,phone.ilike.%$query%,phone_e164.ilike.%$query%');

      return (response as List<dynamic>)
          .map((json) => Member.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ Error searching members: $e');
      return [];
    }
  }

  /// Get member statistics
  Future<Map<String, dynamic>> getMemberStats() async {
    try {
      // Total members
      final totalResponse = await _supabase.client
          .from('members')
          .select('id', const FetchOptions(count: CountOption.exact));
      final total = totalResponse.count ?? 0;

      // Opted out
      final optedOutResponse = await _supabase.client
          .from('members')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('opt_out', true);
      final optedOut = optedOutResponse.count ?? 0;

      // Has phone
      final withPhoneResponse = await _supabase.client
          .from('members')
          .select('id', const FetchOptions(count: CountOption.exact))
          .not('phone_e164', 'is', null);
      final withPhone = withPhoneResponse.count ?? 0;

      return {
        'total': total,
        'optedOut': optedOut,
        'contactable': total - optedOut,
        'withPhone': withPhone,
      };
    } catch (e) {
      print('❌ Error fetching member stats: $e');
      return {
        'total': 0,
        'optedOut': 0,
        'contactable': 0,
        'withPhone': 0,
      };
    }
  }
}
```

---

### Step 6: Create Message Filter Model

**File: `lib/models/crm/message_filter.dart`** (NEW FILE)

```dart
/// Filter criteria for bulk messaging
/// Used to select which members receive a message
class MessageFilter {
  final String? county;
  final String? congressionalDistrict;
  final List<String>? committees;
  final int? minAge;
  final int? maxAge;
  final bool excludeOptedOut;
  final bool excludeRecentlyContacted;
  final Duration? recentContactThreshold;

  MessageFilter({
    this.county,
    this.congressionalDistrict,
    this.committees,
    this.minAge,
    this.maxAge,
    this.excludeOptedOut = true,
    this.excludeRecentlyContacted = false,
    this.recentContactThreshold = const Duration(days: 7),
  });

  /// Check if any filters are active
  bool get hasActiveFilters =>
      county != null ||
      congressionalDistrict != null ||
      (committees != null && committees!.isNotEmpty) ||
      minAge != null ||
      maxAge != null;

  /// Get human-readable description of filters
  String get description {
    final parts = <String>[];
    
    if (county != null) parts.add('County: $county');
    if (congressionalDistrict != null) parts.add('District: $congressionalDistrict');
    if (committees != null && committees!.isNotEmpty) {
      parts.add('Committees: ${committees!.join(", ")}');
    }
    if (minAge != null || maxAge != null) {
      if (minAge != null && maxAge != null) {
        parts.add('Age: $minAge-$maxAge');
      } else if (minAge != null) {
        parts.add('Age: $minAge+');
      } else {
        parts.add('Age: up to $maxAge');
      }
    }
    
    if (excludeOptedOut) parts.add('Excluding opted-out');
    if (excludeRecentlyContacted) {
      parts.add('Not contacted in ${recentContactThreshold!.inDays} days');
    }

    return parts.isEmpty ? 'All members' : parts.join(' • ');
  }

  MessageFilter copyWith({
    String? county,
    String? congressionalDistrict,
    List<String>? committees,
    int? minAge,
    int? maxAge,
    bool? excludeOptedOut,
    bool? excludeRecentlyContacted,
    Duration? recentContactThreshold,
  }) {
    return MessageFilter(
      county: county ?? this.county,
      congressionalDistrict: congressionalDistrict ?? this.congressionalDistrict,
      committees: committees ?? this.committees,
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      excludeOptedOut: excludeOptedOut ?? this.excludeOptedOut,
      excludeRecentlyContacted: excludeRecentlyContacted ?? this.excludeRecentlyContacted,
      recentContactThreshold: recentContactThreshold ?? this.recentContactThreshold,
    );
  }
}
```

---

### Step 7: Create CRM Message Service

**File: `lib/services/crm/crm_message_service.dart`** (NEW FILE)

```dart
import 'dart:async';
import '../../models/crm/member.dart';
import '../../models/crm/message_filter.dart';
import '../crm/member_repository.dart';
// TODO: Import existing BlueBubbles message service
// Example: import '../messages/message_service.dart';

/// Bridge between CRM and BlueBubbles messaging
/// Handles bulk messaging by creating individual chats
class CRMMessageService {
  final MemberRepository _memberRepo = MemberRepository();
  
  // Rate limiting
  static const int messagesPerMinute = 30;
  static const Duration delayBetweenMessages = Duration(seconds: 2);

  /// Get filtered members for messaging
  Future<List<Member>> getFilteredMembers(MessageFilter filter) async {
    try {
      var members = await _memberRepo.getAllMembers(
        county: filter.county,
        congressionalDistrict: filter.congressionalDistrict,
        committees: filter.committees,
        minAge: filter.minAge,
        maxAge: filter.maxAge,
        optedOut: filter.excludeOptedOut ? false : null,
      );

      // Filter by recent contact
      if (filter.excludeRecentlyContacted) {
        final threshold = DateTime.now().subtract(
          filter.recentContactThreshold ?? const Duration(days: 7)
        );
        members = members.where((m) {
          return m.lastContacted == null || m.lastContacted!.isBefore(threshold);
        }).toList();
      }

      // Only return members with valid phone numbers
      members = members.where((m) => m.canContact).toList();

      return members;
    } catch (e) {
      print('❌ Error getting filtered members: $e');
      return [];
    }
  }

  /// Send individual messages to filtered members
  /// Returns: Map of member ID to success/failure status
  Future<Map<String, bool>> sendBulkMessages({
    required MessageFilter filter,
    required String messageText,
    Function(int current, int total)? onProgress,
  }) async {
    final results = <String, bool>{};
    
    try {
      // Get filtered members
      final members = await getFilteredMembers(filter);
      final total = members.length;

      if (total == 0) {
        print('⚠️ No members match the filter criteria');
        return results;
      }

      print('📤 Sending messages to $total members...');

      // Send messages with rate limiting
      for (int i = 0; i < members.length; i++) {
        final member = members[i];
        
        try {
          // TODO: Replace with actual BlueBubbles message sending
          // Example:
          // final success = await MessageService.sendMessage(
          //   address: member.phoneE164!,
          //   text: messageText,
          // );
          
          // PLACEHOLDER - replace with actual implementation
          final success = await _sendSingleMessage(
            phoneNumber: member.phoneE164!,
            message: messageText,
          );

          results[member.id] = success;

          if (success) {
            // Update last contacted timestamp
            await _memberRepo.updateLastContacted(member.id);
          }

          // Report progress
          onProgress?.call(i + 1, total);

          // Rate limiting: wait between messages
          if (i < members.length - 1) {
            await Future.delayed(delayBetweenMessages);
          }

        } catch (e) {
          print('❌ Failed to send message to ${member.name}: $e');
          results[member.id] = false;
        }
      }

      final successCount = results.values.where((v) => v).length;
      print('✅ Successfully sent $successCount/$total messages');

      return results;
    } catch (e) {
      print('❌ Error in bulk message sending: $e');
      return results;
    }
  }

  /// PLACEHOLDER: Send single message via BlueBubbles
  /// TODO: Replace this with actual BlueBubbles API call
  Future<bool> _sendSingleMessage({
    required String phoneNumber,
    required String message,
  }) async {
    // IMPLEMENTATION NEEDED:
    // 1. Find or create Handle for this phone number in BlueBubbles
    // 2. Find or create Chat for this Handle
    // 3. Use existing BlueBubbles sendMessage() API
    // 4. Return true if successful, false otherwise
    
    print('📨 Would send to $phoneNumber: $message');
    
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 100));
    
    // TODO: Replace with actual implementation
    return true;
  }

  /// Preview: Get count of members that would receive message
  Future<int> previewBulkMessage(MessageFilter filter) async {
    final members = await getFilteredMembers(filter);
    return members.length;
  }

  /// Get member info for a phone number (for displaying in chat)
  Future<Member?> getMemberByPhone(String phoneE164) async {
    return await _memberRepo.getMemberByPhone(phoneE164);
  }
}
```

---

### Step 8: Initialize CRM on App Startup

**File: `lib/main.dart`** (MODIFY EXISTING)

Find the `main()` function and add CRM initialization:

```dart
import 'package:flutter/material.dart';
// ... existing imports ...

// NEW IMPORTS
import 'services/crm/supabase_service.dart';
import 'config/crm_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... existing initialization code ...
  
  // NEW: Initialize CRM Supabase
  if (CRMConfig.crmEnabled) {
    try {
      await CRMSupabaseService().initialize();
      print('✅ CRM system initialized');
    } catch (e) {
      print('⚠️ CRM system failed to initialize: $e');
      // Continue app startup even if CRM fails
    }
  }
  
  runApp(MyApp());
}
```

---

### Step 9: Create Members List Screen

**File: `lib/screens/crm/members_list_screen.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import '../../models/crm/member.dart';
import '../../services/crm/member_repository.dart';
import 'member_detail_screen.dart';

/// Screen showing all CRM members with search and filters
class MembersListScreen extends StatefulWidget {
  const MembersListScreen({Key? key}) : super(key: key);

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  bool _loading = true;
  String _searchQuery = '';
  
  // Filter state
  String? _selectedCounty;
  String? _selectedDistrict;
  List<String>? _selectedCommittees;
  
  // Available filter options
  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      // Load members and filter options in parallel
      final results = await Future.wait([
        _memberRepo.getAllMembers(),
        _memberRepo.getUniqueCounties(),
        _memberRepo.getUniqueCongressionalDistricts(),
        _memberRepo.getUniqueCommittees(),
      ]);

      setState(() {
        _members = results[0] as List<Member>;
        _filteredMembers = _members;
        _counties = results[1] as List<String>;
        _districts = results[2] as List<String>;
        _committees = results[3] as List<String>;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading members: $e');
      setState(() => _loading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredMembers = _members.where((member) {
        // Search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesName = member.name.toLowerCase().contains(query);
          final matchesPhone = member.phone?.toLowerCase().contains(query) ?? false;
          if (!matchesName && !matchesPhone) return false;
        }

        // County filter
        if (_selectedCounty != null && member.county != _selectedCounty) {
          return false;
        }

        // District filter
        if (_selectedDistrict != null && 
            member.congressionalDistrict != _selectedDistrict) {
          return false;
        }

        // Committee filter
        if (_selectedCommittees != null && _selectedCommittees!.isNotEmpty) {
          if (member.committee == null) return false;
          final hasCommittee = _selectedCommittees!.any(
            (c) => member.committee!.contains(c)
          );
          if (!hasCommittee) return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCounty = null;
      _selectedDistrict = null;
      _selectedCommittees = null;
      _filteredMembers = _members;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Members'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              // TODO: Navigate to bulk message screen
              // Navigator.push(context, MaterialPageRoute(
              //   builder: (_) => BulkMessageScreen(),
              // ));
            },
            tooltip: 'Bulk Message',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _searchQuery = '');
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // County filter
                FilterChip(
                  label: Text(_selectedCounty ?? 'County'),
                  selected: _selectedCounty != null,
                  onSelected: (selected) {
                    _showCountyFilter();
                  },
                ),
                const SizedBox(width: 8),

                // District filter
                FilterChip(
                  label: Text(_selectedDistrict ?? 'District'),
                  selected: _selectedDistrict != null,
                  onSelected: (selected) {
                    _showDistrictFilter();
                  },
                ),
                const SizedBox(width: 8),

                // Committee filter
                FilterChip(
                  label: Text(_selectedCommittees == null || _selectedCommittees!.isEmpty
                      ? 'Committee'
                      : '${_selectedCommittees!.length} committees'),
                  selected: _selectedCommittees != null && _selectedCommittees!.isNotEmpty,
                  onSelected: (selected) {
                    _showCommitteeFilter();
                  },
                ),
                const SizedBox(width: 8),

                // Clear filters
                if (_selectedCounty != null || 
                    _selectedDistrict != null || 
                    (_selectedCommittees != null && _selectedCommittees!.isNotEmpty))
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                    onPressed: _clearFilters,
                  ),
              ],
            ),
          ),

          const Divider(),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Showing ${_filteredMembers.length} of ${_members.length} members',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

          // Members list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No members found',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          return _buildMemberTile(member);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Member member) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(member.name[0].toUpperCase()),
      ),
      title: Text(member.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (member.phone != null) Text(member.phone!),
          if (member.county != null || member.congressionalDistrict != null)
            Text(
              [
                if (member.county != null) member.county!,
                if (member.congressionalDistrict != null) 'CD-${member.congressionalDistrict}',
              ].join(' • '),
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.optOut)
            const Chip(
              label: Text('Opted Out', style: TextStyle(fontSize: 10)),
              backgroundColor: Colors.red,
              labelStyle: TextStyle(color: Colors.white),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailScreen(member: member),
          ),
        );
      },
    );
  }

  void _showCountyFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by County'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Counties'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedCounty,
                  onChanged: (value) {
                    setState(() => _selectedCounty = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
              ..._counties.map((county) => ListTile(
                    title: Text(county),
                    leading: Radio<String?>(
                      value: county,
                      groupValue: _selectedCounty,
                      onChanged: (value) {
                        setState(() => _selectedCounty = value);
                        _applyFilters();
                        Navigator.pop(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistrictFilter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Congressional District'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('All Districts'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedDistrict,
                  onChanged: (value) {
                    setState(() => _selectedDistrict = value);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
              ),
              ..._districts.map((district) => ListTile(
                    title: Text('District $district'),
                    leading: Radio<String?>(
                      value: district,
                      groupValue: _selectedDistrict,
                      onChanged: (value) {
                        setState(() => _selectedDistrict = value);
                        _applyFilters();
                        Navigator.pop(context);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommitteeFilter() {
    final tempSelected = List<String>.from(_selectedCommittees ?? []);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Committee'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setDialogState) => ListView(
              shrinkWrap: true,
              children: _committees.map((committee) {
                final isSelected = tempSelected.contains(committee);
                return CheckboxListTile(
                  title: Text(committee),
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        tempSelected.add(committee);
                      } else {
                        tempSelected.remove(committee);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCommittees = tempSelected.isEmpty ? null : tempSelected;
              });
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
```

---

### Step 10: Create Member Detail Screen

**File: `lib/screens/crm/member_detail_screen.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/crm/member.dart';
import '../../services/crm/member_repository.dart';

/// Detailed view of a single member
class MemberDetailScreen extends StatefulWidget {
  final Member member;

  const MemberDetailScreen({
    Key? key,
    required this.member,
  }) : super(key: key);

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  late Member _member;
  final TextEditingController _notesController = TextEditingController();
  bool _editingNotes = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _notesController.text = _member.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    try {
      await _memberRepo.updateNotes(_member.id, _notesController.text);
      setState(() {
        _member = _member.copyWith(notes: _notesController.text);
        _editingNotes = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving notes: $e')),
        );
      }
    }
  }

  Future<void> _toggleOptOut() async {
    final newOptOutStatus = !_member.optOut;
    
    try {
      await _memberRepo.updateOptOutStatus(
        _member.id,
        newOptOutStatus,
        reason: newOptOutStatus ? 'Manually opted out' : null,
      );

      setState(() {
        _member = _member.copyWith(
          optOut: newOptOutStatus,
          optOutDate: newOptOutStatus ? DateTime.now() : _member.optOutDate,
          optInDate: !newOptOutStatus ? DateTime.now() : _member.optInDate,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newOptOutStatus ? 'Member opted out' : 'Member opted in'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating opt-out status: $e')),
        );
      }
    }
  }

  void _startChat() {
    if (_member.phoneE164 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    // TODO: Integrate with BlueBubbles to start/open chat
    // Example:
    // Navigator.push(context, MaterialPageRoute(
    //   builder: (_) => ConversationView(
    //     chat: findOrCreateChat(_member.phoneE164!),
    //   ),
    // ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Would start chat with ${_member.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _member.canContact ? _startChat : null,
            tooltip: 'Start Chat',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header with avatar
          Center(
            child: CircleAvatar(
              radius: 50,
              child: Text(
                _member.name[0].toUpperCase(),
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Center(
            child: Text(
              _member.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 8),

          // Opt-out status
          if (_member.optOut)
            Center(
              child: Chip(
                label: const Text('OPTED OUT'),
                backgroundColor: Colors.red,
                labelStyle: const TextStyle(color: Colors.white),
              ),
            ),

          const SizedBox(height: 24),

          // Contact Information
          _buildSection(
            'Contact Information',
            [
              if (_member.phone != null)
                _buildInfoRow('Phone', _member.phone!, 
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _member.phone!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Phone copied')),
                      );
                    },
                  ),
                ),
              if (_member.email != null)
                _buildInfoRow('Email', _member.email!,
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _member.email!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Email copied')),
                      );
                    },
                  ),
                ),
              if (_member.address != null)
                _buildInfoRow('Address', _member.address!),
            ],
          ),

          // Political Information
          _buildSection(
            'Political Information',
            [
              if (_member.county != null)
                _buildInfoRow('County', _member.county!),
              if (_member.congressionalDistrict != null)
                _buildInfoRow('Congressional District', 'CD-${_member.congressionalDistrict}'),
              if (_member.committee != null && _member.committee!.isNotEmpty)
                _buildInfoRow('Committees', _member.committeesString),
              if (_member.registeredVoter != null)
                _buildInfoRow('Registered Voter', _member.registeredVoter! ? 'Yes' : 'No'),
              if (_member.politicalExperience != null)
                _buildInfoRow('Political Experience', _member.politicalExperience!),
              if (_member.currentInvolvement != null)
                _buildInfoRow('Current Involvement', _member.currentInvolvement!),
            ],
          ),

          // Personal Information
          _buildSection(
            'Personal Information',
            [
              if (_member.age != null)
                _buildInfoRow('Age', '${_member.age} years old'),
              if (_member.preferredPronouns != null)
                _buildInfoRow('Pronouns', _member.preferredPronouns!),
              if (_member.genderIdentity != null)
                _buildInfoRow('Gender Identity', _member.genderIdentity!),
              if (_member.race != null)
                _buildInfoRow('Race', _member.race!),
              if (_member.hispanicLatino != null)
                _buildInfoRow('Hispanic/Latino', _member.hispanicLatino! ? 'Yes' : 'No'),
            ],
          ),

          // Notes
          _buildSection(
            'Notes',
            [
              if (!_editingNotes && (_member.notes == null || _member.notes!.isEmpty))
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add notes'),
                  onPressed: () => setState(() => _editingNotes = true),
                ),
              if (!_editingNotes && _member.notes != null && _member.notes!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_member.notes!),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () => setState(() => _editingNotes = true),
                    ),
                  ],
                ),
              if (_editingNotes)
                Column(
                  children: [
                    TextField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Add notes about this member...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _notesController.text = _member.notes ?? '';
                            setState(() => _editingNotes = false);
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveNotes,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),

          // Metadata
          _buildSection(
            'Metadata',
            [
              if (_member.lastContacted != null)
                _buildInfoRow('Last Contacted', _formatDate(_member.lastContacted!)),
              if (_member.introSentAt != null)
                _buildInfoRow('Intro Sent', _formatDate(_member.introSentAt!)),
              if (_member.dateJoined != null)
                _buildInfoRow('Date Joined', _formatDate(_member.dateJoined!)),
              if (_member.createdAt != null)
                _buildInfoRow('Added to System', _formatDate(_member.createdAt!)),
            ],
          ),

          const SizedBox(height: 24),

          // Actions
          ElevatedButton.icon(
            icon: Icon(_member.optOut ? Icons.check_circle : Icons.block),
            label: Text(_member.optOut ? 'Opt In' : 'Opt Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _member.optOut ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _toggleOptOut,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: Text(value)),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
```

---

### Step 11: Add Navigation to CRM

**File: `lib/layouts/navigation/navigation.dart`** (MODIFY EXISTING)

Find where navigation items are defined and add CRM tab:

```dart
// Add to navigation items list:
NavigationItem(
  icon: Icons.people,
  label: 'CRM',
  route: '/crm',
  screen: const MembersListScreen(),
),
```

---

## Bulk Messaging System

### Step 12: Create Bulk Message Screen

**File: `lib/screens/crm/bulk_message_screen.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import '../../models/crm/member.dart';
import '../../models/crm/message_filter.dart';
import '../../services/crm/crm_message_service.dart';
import '../../services/crm/member_repository.dart';

/// Screen for sending bulk individual messages
class BulkMessageScreen extends StatefulWidget {
  const BulkMessageScreen({Key? key}) : super(key: key);

  @override
  State<BulkMessageScreen> createState() => _BulkMessageScreenState();
}

class _BulkMessageScreenState extends State<BulkMessageScreen> {
  final CRMMessageService _messageService = CRMMessageService();
  final MemberRepository _memberRepo = MemberRepository();
  final TextEditingController _messageController = TextEditingController();
  
  // Filter state
  MessageFilter _filter = MessageFilter();
  List<Member> _previewMembers = [];
  bool _loadingPreview = false;
  bool _sending = false;
  int _currentProgress = 0;
  int _totalMessages = 0;
  
  // Available filter options
  List<String> _counties = [];
  List<String> _districts = [];
  List<String> _committees = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _updatePreview();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    final results = await Future.wait([
      _memberRepo.getUniqueCounties(),
      _memberRepo.getUniqueCongressionalDistricts(),
      _memberRepo.getUniqueCommittees(),
    ]);

    setState(() {
      _counties = results[0];
      _districts = results[1];
      _committees = results[2];
    });
  }

  Future<void> _updatePreview() async {
    setState(() => _loadingPreview = true);

    try {
      final members = await _messageService.getFilteredMembers(_filter);
      setState(() {
        _previewMembers = members.take(5).toList();
        _totalMessages = members.length;
        _loadingPreview = false;
      });
    } catch (e) {
      print('❌ Error updating preview: $e');
      setState(() => _loadingPreview = false);
    }
  }

  Future<void> _sendMessages() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    if (_totalMessages == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members match the filter')),
      );
      return;
    }

    // Confirm before sending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Message'),
        content: Text(
          'Send message to $_totalMessages members?\n\n'
          'This will send individual messages at a rate of 30 per minute.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _sending = true;
      _currentProgress = 0;
    });

    try {
      final results = await _messageService.sendBulkMessages(
        filter: _filter,
        messageText: _messageController.text,
        onProgress: (current, total) {
          setState(() {
            _currentProgress = current;
            _totalMessages = total;
          });
        },
      );

      final successCount = results.values.where((v) => v).length;
      
      setState(() => _sending = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bulk Message Complete'),
            content: Text(
              'Successfully sent $successCount of $_totalMessages messages',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _sending = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending messages: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Message'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Message input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _messageController,
                          maxLines: 5,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            hintText: 'Enter your message here...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Filters
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filters',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),

                        // County dropdown
                        DropdownButtonFormField<String?>(
                          value: _filter.county,
                          decoration: const InputDecoration(
                            labelText: 'County',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Counties')),
                            ..._counties.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(county: value);
                            });
                            _updatePreview();
                          },
                        ),

                        const SizedBox(height: 12),

                        // District dropdown
                        DropdownButtonFormField<String?>(
                          value: _filter.congressionalDistrict,
                          decoration: const InputDecoration(
                            labelText: 'Congressional District',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Districts')),
                            ..._districts.map((d) => DropdownMenuItem(
                              value: d,
                              child: Text('District $d'),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(congressionalDistrict: value);
                            });
                            _updatePreview();
                          },
                        ),

                        const SizedBox(height: 12),

                        // Age range
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Min Age',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final age = int.tryParse(value);
                                  setState(() {
                                    _filter = _filter.copyWith(minAge: age);
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Max Age',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final age = int.tryParse(value);
                                  setState(() {
                                    _filter = _filter.copyWith(maxAge: age);
                                  });
                                  _updatePreview();
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Checkboxes
                        CheckboxListTile(
                          title: const Text('Exclude opted-out members'),
                          value: _filter.excludeOptedOut,
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(excludeOptedOut: value ?? true);
                            });
                            _updatePreview();
                          },
                        ),

                        CheckboxListTile(
                          title: const Text('Exclude recently contacted (7 days)'),
                          value: _filter.excludeRecentlyContacted,
                          onChanged: (value) {
                            setState(() {
                              _filter = _filter.copyWith(excludeRecentlyContacted: value ?? false);
                            });
                            _updatePreview();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Preview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),

                        if (_loadingPreview)
                          const Center(child: CircularProgressIndicator()),

                        if (!_loadingPreview)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Will send to $_totalMessages members',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _filter.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (_previewMembers.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                const Text('First 5 recipients:'),
                                ..._previewMembers.map((m) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.person, size: 16),
                                      title: Text(m.name, style: const TextStyle(fontSize: 14)),
                                      subtitle: Text(m.phone ?? 'No phone', style: const TextStyle(fontSize: 12)),
                                    )),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Send button / progress
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: _sending
                ? Column(
                    children: [
                      LinearProgressIndicator(
                        value: _totalMessages > 0 ? _currentProgress / _totalMessages : 0,
                      ),
                      const SizedBox(height: 8),
                      Text('Sending $_currentProgress of $_totalMessages...'),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: Text('Send to $_totalMessages Members'),
                      onPressed: _messageController.text.trim().isEmpty || _totalMessages == 0
                          ? null
                          : _sendMessages,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
```

---

## UI Customization

### Step 13: Add Member Info Panel to Chat View

**File: `lib/layouts/conversation/widgets/crm_member_panel.dart`** (NEW FILE)

```dart
import 'package:flutter/material.dart';
import '../../../models/crm/member.dart';
import '../../../services/crm/crm_message_service.dart';

/// Side panel showing CRM member info in chat view
class CRMMemberPanel extends StatefulWidget {
  final String phoneNumber; // E.164 format from Handle

  const CRMMemberPanel({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<CRMMemberPanel> createState() => _CRMMemberPanelState();
}

class _CRMMemberPanelState extends State<CRMMemberPanel> {
  final CRMMessageService _messageService = CRMMessageService();
  Member? _member;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMember();
  }

  Future<void> _loadMember() async {
    setState(() => _loading = true);
    
    try {
      final member = await _messageService.getMemberByPhone(widget.phoneNumber);
      setState(() {
        _member = member;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading member: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_member == null) {
      return const Center(
        child: Text('No CRM data for this contact'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Header
        Center(
          child: CircleAvatar(
            radius: 40,
            child: Text(_member!.name[0].toUpperCase(), style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _member!.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        
        if (_member!.optOut)
          Center(
            child: Chip(
              label: const Text('OPTED OUT'),
              backgroundColor: Colors.red,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),

        const Divider(height: 32),

        // Quick info
        if (_member!.county != null)
          _buildInfoTile(Icons.location_on, 'County', _member!.county!),
        
        if (_member!.congressionalDistrict != null)
          _buildInfoTile(Icons.account_balance, 'District', 'CD-${_member!.congressionalDistrict}'),
        
        if (_member!.committee != null && _member!.committee!.isNotEmpty)
          _buildInfoTile(Icons.group, 'Committees', _member!.committeesString),
        
        if (_member!.age != null)
          _buildInfoTile(Icons.cake, 'Age', '${_member!.age} years old'),

        if (_member!.lastContacted != null)
          _buildInfoTile(Icons.schedule, 'Last Contacted', 
            _formatDate(_member!.lastContacted!)),

        const Divider(height: 32),

        // Notes
        if (_member!.notes != null && _member!.notes!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(_member!.notes!),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value),
      dense: true,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
```

---

### Step 14: Integrate Member Panel into Chat View

**Find existing conversation view file** (typically something like `lib/layouts/conversation/conversation_view.dart`) and add:

```dart
// Add import
import 'widgets/crm_member_panel.dart';

// In the build method, add a side panel button/drawer:
IconButton(
  icon: const Icon(Icons.info_outline),
  onPressed: () {
    // Show member panel in a drawer or modal
    showModalBottomSheet(
      context: context,
      builder: (context) => CRMMemberPanel(
        phoneNumber: chat.participants.first.address, // Adjust based on your Chat model
      ),
    );
  },
  tooltip: 'Member Info',
),
```

---

## Testing Strategy

### Step 15: Testing Checklist

```
PHASE 1: Setup & Connection
[ ] Supabase service initializes successfully
[ ] Can fetch all members from Supabase
[ ] Member model correctly parses all fields
[ ] Filter options load (counties, districts, committees)

PHASE 2: Member Display
[ ] Members list screen shows all members
[ ] Search works correctly
[ ] Filters apply correctly (county, district, committee)
[ ] Member detail screen shows all information
[ ] Can view member notes

PHASE 3: Messaging Integration
[ ] Can find member by phone number (E.164)
[ ] Member panel displays in chat view
[ ] "Start Chat" button works from member detail
[ ] BlueBubbles creates/finds correct Handle and Chat

PHASE 4: Bulk Messaging
[ ] Filter preview shows correct member count
[ ] Preview members list is accurate
[ ] Bulk send creates individual messages
[ ] Rate limiting works (30/minute, 2sec delay)
[ ] Progress indicator updates correctly
[ ] Last contacted timestamp updates after send
[ ] Opted-out members are excluded

PHASE 5: Edge Cases
[ ] Handles members without phone numbers
[ ] Handles opted-out members correctly
[ ] Works with empty filter results
[ ] Handles Supabase connection errors gracefully
[ ] Works when CRM is disabled (feature flag)
```

---

## Deployment Checklist

### Step 16: Production Preparation

```
SECURITY
[ ] Move Supabase credentials to environment variables
[ ] Enable Row Level Security (RLS) on Supabase members table
[ ] Add authentication if needed
[ ] Review what member data is exposed in logs

PERFORMANCE
[ ] Add pagination to members list (if > 1000 members)
[ ] Add caching for filter options
[ ] Test with large member datasets
[ ] Optimize Supabase queries with proper indexes

MONITORING
[ ] Add error logging for Supabase operations
[ ] Track bulk message success/failure rates
[ ] Monitor API rate limits
[ ] Set up alerts for failed messages

DOCUMENTATION
[ ] Document Supabase table structure
[ ] Create user guide for CRM features
[ ] Document phone number format requirements (E.164)
[ ] Create troubleshooting guide

FEATURE FLAGS
[ ] Test with CRMConfig.crmEnabled = false
[ ] Test with CRMConfig.bulkMessagingEnabled = false
[ ] Ensure app works if Supabase is unavailable
```

---

## Critical Integration Notes

### BlueBubbles Messaging Integration

**THIS SECTION REQUIRES MANUAL IMPLEMENTATION** - you must integrate with the existing BlueBubbles message sending system. Look for:

1. **Find existing message service:**
   - Search for files like `message_service.dart` or `send_message.dart`
   - Find the function that sends messages (probably takes a phone number and text)

2. **Locate Handle/Chat creation:**
   - Find how BlueBubbles creates or finds a Handle for a phone number
   - Find how BlueBubbles creates or finds a Chat for a Handle

3. **Replace placeholder in `CRMMessageService._sendSingleMessage()`:**
   ```dart
   Future<bool> _sendSingleMessage({
     required String phoneNumber,
     required String message,
   }) async {
     // REPLACE THIS WITH ACTUAL BLUEBUBBLES CODE:
     
     // Step 1: Find or create Handle
     // final handle = await HandleService.findOrCreate(phoneNumber);
     
     // Step 2: Find or create Chat
     // final chat = await ChatService.findOrCreate(handle);
     
     // Step 3: Send message
     // final success = await MessageService.send(chat, message);
     
     // return success;
   }
   ```

### Phone Number Format

**CRITICAL:** All phone numbers must be in E.164 format in Supabase:
- Format: `+[country code][number]`
- Example: `+15551234567` (US number)
- NO spaces, dashes, parentheses

Make sure your Supabase `phone_e164` field matches BlueBubbles `Handle.address` format exactly.

---

## File Structure Summary

```
lib/
├── config/
│   └── crm_config.dart                    # NEW: Configuration
├── models/
│   └── crm/                               # NEW: CRM models
│       ├── member.dart
│       ├── message_filter.dart
│       └── campaign.dart
├── services/
│   └── crm/                               # NEW: CRM services
│       ├── supabase_service.dart
│       ├── member_repository.dart
│       └── crm_message_service.dart
├── screens/
│   └── crm/                               # NEW: CRM screens
│       ├── members_list_screen.dart
│       ├── member_detail_screen.dart
│       └── bulk_message_screen.dart
└── layouts/
    └── conversation/
        └── widgets/
            └── crm_member_panel.dart      # NEW: Chat integration widget
```

---

## Environment Variables

Create `.env` file (DO NOT COMMIT):
```
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Update `lib/config/crm_config.dart` to read from environment:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CRMConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  // ...
}
```

---

## Next Steps After Implementation

1. **Test locally first**
   - Use a small subset of test members
   - Verify all features work end-to-end

2. **Set up Row Level Security (RLS) on Supabase**
   - Protect member data appropriately
   - Configure authentication if needed

3. **Add analytics tracking**
   - Track message delivery success rates
   - Monitor member engagement
   - Log opt-out/opt-in events

4. **Create user documentation**
   - How to use bulk messaging
   - How to manage members
   - Best practices for political outreach

5. **Consider future enhancements**
   - Message templates
   - Campaign scheduling
   - Response tracking
   - Automated follow-ups

---

## Support & Troubleshooting

### Common Issues

**"CRMSupabaseService not initialized"**
- Ensure `CRMSupabaseService().initialize()` is called in `main()`
- Check Supabase URL and key are correct

**"No members found" when members exist**
- Check phone_e164 format matches E.164 standard
- Verify Supabase table permissions (RLS)
- Check network connectivity

**Messages not sending**
- Verify BlueBubbles integration in `_sendSingleMessage()`
- Check Handle.address format matches member.phoneE164
- Ensure BlueBubbles API is connected

**Member panel not showing in chat**
- Verify phone number lookup is working
- Check that member.phoneE164 matches Handle.address
- Ensure integration point is correct in conversation view

---

## Conclusion

This integration adds powerful CRM functionality to BlueBubbles without touching any existing infrastructure. All conversation data remains in ObjectBox, all messaging goes through existing BlueBubbles APIs, and the CRM layer operates as a pure addition.

The key to success is:
1. Never modifying ObjectBox models
2. Using phone_e164 as the integration point
3. Leveraging existing BlueBubbles message sending
4. Keeping CRM and messaging concerns separate

Good luck with your implementation! 🎉
