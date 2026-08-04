# BlueBubbles CRM Integration - Complete Implementation Instructions


## Engineering principles (set by Andrew, apply everywhere)

- Do not preserve backward compatibility. Remove obsolete paths instead of
  adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements.
  Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to
  end, and add each new capability on top of a product that already works.
  Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall
  complexity or improve reliability. Do not reimplement common functionality
  without a clear reason.
- Lean on the dependencies already in the project before writing your own
  implementation or adding packages. Do not assume a library lacks a capability
  without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that
  only works for now and is meant to be replaced later.

Ship the smallest thing that genuinely works end to end. That is not a licence
to sit on finished work: if a change is verified, ship it; if it is not, finish
it rather than parking it.

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

Every one of the fourteen SUPABASE-PLATFORM-3 events, 2026-07-24 07:05 through
2026-08-03 15:45 UTC, reads

    sentry-log-relay failure: Error: logs query failed 502: <!DOCTYPE html>

`0d2963e` landed at 2026-07-31 02:31:19 UTC, and seven of the fourteen are
after it: 07-31 23:40, 08-01 08:05, 08-02 at 06:20, 09:55 and 13:10, and 08-03
at 15:35 and 15:45 UTC. The 07-31 00:30 event is two hours before the commit
and belongs to the other seven. This was read from the per-event `message`
field, not the group title, which is not a per-event record and cannot be
trusted for this.

Enumerate this group from the per-event list over the full range. Do not take
the previous note's count and add whatever the last 24 hours produced. The
2026-08-03 18:00 UTC run did exactly that, reached eleven and four, and missed
the three 08-02 events completely, because a 24 hour issue search returns only
the newest pair. The issue's own Occurrences field already read 14 in that same
run's tool output and went unreconciled. An adversarial auditor caught it as a
BLOCKER by querying Sentry directly, which is the only reason the wrong census
is not in this file.

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
serving as of the 2026-08-03 15:45 UTC event, not that one is serving now: the
relay only emits here on roughly 1 percent of runs, so no later event is not
evidence of anything, and a hand deploy at any point after 15:45 falsifies the
present tense while these events stay on the record. It also assumes no second
deployment of this source under another function name, which is possible
because `logger` and `server_name` are hard-coded constants in the file rather
than deployment identity. `supabase functions list` remains the check for
current state and for that assumption. And it is one function: it does not
establish the state of any other, though it is consistent with the two cases
above.

What the 08-02 and 08-03 events add is duration rather than a new mechanism.
The fix has now been committed and undeployed for three days, across seven
failures it would most likely have absorbed, five of them since the note above
was written. Most likely rather than certainly, because the fix retries three
times over roughly three seconds, so a CDN 502 episode outlasting that window
still fails and still lands here. The shape argues it usually would not: the
08-03 events sit in the 15:35 and 15:45 five-minute slots with 15:40 clean, and
the 08-02 three are hours apart, which is the intermittent CDN 502 that
`0d2963e` was written for and not a sustained upstream outage. So this is the
same finding as before rather than a new one, and the only action it supports
is the hand deploy:
`npx supabase functions deploy sentry-log-relay --project-ref <ref>`, then read
the next event in this group to confirm the message shape changed. Deploy that
one function, not everything: the bulk-deploy hazard recorded at the end of this
section still applies, and the endorsement-vote functions must not be swept up
in it while ballots are open.

Do not rate this higher than it is. A failed run does not lose the window,
because the watermark update sits after the sends inside the same `try`, so a
throw leaves `last_end` where it was and the next run re-reads the same span
under the 60 minute cap. The cost of leaving it undeployed is a recurring Sentry
issue and a delayed rollup, not missing platform errors. That is the reason this
stays a report rather than an escalation.

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

It recurred on 2026-08-03 in a form the paragraphs above do not quite cover,
and the difference is the part worth reading. The stale ref that did the damage
was not `master`. It was `origin/master`, the remote-tracking ref, which the
container presented at `5d8a5b0` while the real `refs/heads/master` was two
commits further on at `dfc890d`. Nothing about that is visible from
`git rev-parse origin/master`, `git log origin/master`, or `git status`: a
remote-tracking ref is a local cache, it is only as fresh as the last fetch,
and in a container that has never fetched it answers confidently and wrongly.
`git status` reported "up to date with origin/master" the entire time, which is
true and useless, because it compares two local refs.

The `git ls-remote` check prescribed above is the right check and would have
caught it in one command. It was simply not run, because `origin/master` looked
like an answer. So the rule is not a new check, it is: `origin/<branch>` is not
evidence about the remote until you have fetched in this container. Fetch
first, then reason.

What it cost is the reason this is recorded rather than shrugged off. The run
found two commits sitting on a detached `HEAD` that it believed were unpushed
and about to be lost, and built a whole plan on that belief: it squashed them
to keep an already-redacted meeting title out of public history, wrote a long
commit message arguing the case, and spent a full adversarial audit round on
it. All of it was answering a question that was already moot: both commits are
reachable from the real remote head, so the unredacted blob is published and no
squash could have changed that.

Be exact about what that does and does not establish, because the sloppy
version of it is the same error twice. What is established is reachability now,
plus commit dates of 02:44 and 08:44 UTC that precede this run. When the push
actually happened is NOT established and cannot be from here; git records no
push time. The commits may have been pushed before this run began or by
something concurrent with it. Either way the conclusion holds, which is why the
distinction is safe to state plainly rather than paper over.

The push refusal was what surfaced it, and only because `-u` compared against a
freshly fetched ref. The wasted work was the good outcome; the bad one was
available, and it was to read that refusal as something to force past.

Two smaller things fell out of it, both worth keeping. Committing on the wrong
base does not necessarily mean re-doing the work: the corrected commit here was
verified by comparing `git write-tree` against the audited commit's tree hash,
which proved the content was unchanged and let a clean audit stand across the
rebase. And an audit conclusion is only as good as the premises handed to the
auditor. That reviewer verified every claim it was given and returned CLEAN,
correctly, while the framing it was given was false, because nobody had checked
the one fact the framing rested on. Give an auditor the premises to check, not
just the diff.

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

## READ FOURTH: SUPABASE-PLATFORM-1 holds eight message shapes, not three

SUPABASE-PLATFORM-1 is a 5 minute rollup of raw Postgres log lines. Its per
event title, `Postgres errors: N (ERROR level)` or `N (includes FATAL)`, is a
count and a severity flag. It is not the content. The content is in
`by_message`. Two events with identical titles routinely carry completely
different errors, so a title scan cannot decompose this group. Read
`by_message` on every event in the window, never on a sample.

That is not advice, it is the record of two consecutive failures in one run on
2026-08-03. The run first read titles, concluded the group held three shapes
and that all three were already handled. An adversarial auditor falsified
that. The corrected note said six. A second auditor falsified that too, by
reading `by_message` on events the corrected pass had skipped because their
titles looked redundant. Only the third pass, a mechanical sweep of all 74
events whose per shape totals were reconciled against the sum of the per event
`count` fields, produced the list below. Two of the eight shapes are titled
`Postgres errors: 1 (ERROR level)`, the same title the hourly uuid line
carries, so they are invisible to any title based method by construction.

Enumerated across all 74 events in the window 2026-08-02 20:05:04 UTC
exclusive to 2026-08-03 20:05:04 UTC inclusive. The per shape totals sum to
250, which equals the sum of every in window event `count` field, so this
decomposition is complete rather than merely longer than the last one.

Two caveats on that reconciliation, so a future run does not trust it further
than it goes. Shape 1 is the only total that is derived rather than read:
Sentry filters that message, so its `by_message` value is null and its 83 is a
per event residual of `by_severity` FATAL minus the startup packet and
protocol lines. That component of the sum therefore cannot fail, so
completeness rests on the sweep of `by_message` keys across all 74 events and
the reconciliation together, not on the arithmetic alone. And both window
boundaries land on seconds that carry events, so the counts hold only under
the exclusive start and inclusive end convention stated above; at millisecond
precision the start boundary admits a 75th event and the totals move.

1. `password authentication failed for user "?"`, 83 lines across 48 events,
   FATAL, body `[Filtered]` since `50bba91`. Scan noise. Total derived, see
   the caveat above.
2. `duplicate key value violates unique constraint
   "legislation_bill_sponsors_unique"`, 128 lines, exactly 32 in each of four
   cycles a day at 00, 06, 12 and 18 UTC. Fixed in `e79339b`, committed and
   undeployed.
3. `invalid input syntax for type uuid: "cron"`, 23 lines, once an hour at
   HH:00, in 23 of the 24 window hours. Fixed in `1cdb96e`, committed and
   undeployed.
4. `unsupported frontend protocol N.N`, 10 lines across 6 events, FATAL. Scan
   noise. Values observed are 255.255, 0.0, 65363.19778 and 16.0; the value
   varies per probe, so do not treat any list of them as exhaustive.
5. `no PostgreSQL user name specified in startup packet`, 3 lines, FATAL.
   Scan noise, same probe family as 4.
6. `invalid input value for enum committee_type: "-"`, 1 line, ERROR,
   2026-08-03 00:40:04 UTC.
7. `column v.id does not exist`, 1 line, ERROR, 2026-08-02 21:25:40 UTC.
8. `operator does not exist: text = integer`, 1 line, ERROR, 2026-08-02
   21:30:53 UTC.

Shapes 4 and 5 matter mostly because earlier sections of this file named the
password line as though it were the only FATAL. It is not. It is one of three
probe shapes, and a future run that greps for the password line alone will
under count the scan traffic.

Hour 16 on 2026-08-03 is the one window hour carrying no uuid line, and it has
no :05 rollup at all, so the hourly cron either did not run or was not
captured in that window. One gap in 24 hours proves nothing by itself. It is
recorded so the next run does not read "once an hour" as a guarantee and then
treat a gap as a fix.

### Shapes 7 and 8, a hand query pair, unattributed

One occurrence each, five minutes and thirteen seconds apart, in consecutive
rollup windows on 2026-08-02, and the only two lines of their kind anywhere in
the window. A missing column on an alias `v` followed by a text to integer
comparison failure is the shape of somebody iterating on a query by hand
rather than of a scheduled job, because a job repeats on its next tick and
neither of these has recurred since. That reading is an inference from timing
and message shape and is not established. No emitter is attributed for either
in this repo, and nothing was changed for them. If they recur on a schedule, a
future run should revisit that inference rather than inherit it.

### The committee_type enum error, recorded 2026-08-03, not fixed

One occurrence, 2026-08-03 00:40:04.481 UTC, ERROR level, carried inside the
00:45 rollup event. No commit in either repo names it and no earlier section
of this file mentions it. Shapes 7 and 8 are equally unrecorded, so this is
one of three previously undocumented errors in this window rather than the
only new thing in it.

It is not scan noise. The probe family in shapes 4 and 5 opens malformed
connections and never reaches SQL; this is a statement that reached the
planner and failed an enum cast, so something authenticated wrote it.

It is also not ours to fix from here, and that is checked rather than assumed.
No code in either repo writes `committee_type`. Every code reference in this
repo reads it: `lib/models/crm/mec_committee.dart`,
`lib/screens/crm/candidate_detail_screen.dart`,
`lib/screens/crm/tabs/committees_tab.dart` and
`lib/screens/crm/mec_committee_picker.dart`, and the RPC in
`supabase/migrations/20260423_01_backfill_orphan_rpcs.sql` returns the column
as `text` rather than as the enum. Three planning documents under `docs/` also
mention the column, one of them sketching it as `committee_type TEXT`; none of
the three is a writer. The `moyoungdemocrats` repo does not contain the string
at all. No `CREATE TYPE ... committee_type` DDL exists in either repo. So the
emitting writer and the enum definition both live outside these two repos and
no fix is available from this container. Do not invent a local mechanism to
explain it, and do not change a read path to make it go away.

The value that failed to cast is a single hyphen. That is what a blank or
placeholder cell looks like coming out of a CSV or a scrape, so the likely
shape is an importer passing an empty field into an enum column instead of a
NULL. That is a hint about the input, not a diagnosis, and the importer is not
in this repo to check.

Offered as correlation and explicitly not as proof: the two 2026-08-03
SUPABASE-PLATFORM-4 storage 400s land at 00:41:20 and 00:41:33 UTC, 76 and 89
seconds after this error, and the READ THIRD note records them as coming from
a single source address. One human session tripping both is consistent with
that timing and is not established by it. If a real executive hit a failed
write and then two failed transcript reads inside ninety seconds, that is one
broken workflow rather than three unrelated log lines, and that is the reading
a future run should test rather than inherit.

### The Sentry project census is eight, not five

`endorsement-scorer`, `flutter`, `mautic`, `moydforms`, `n8n`,
`supabase-edge`, `supabase-platform`, `website`. The 2026-08-03 run reported
that "website, flutter and mautic were silent" and did not know the other
three existed. All three were in fact silent, so the conclusion held by luck.
`moydforms` is the archived duplicate that must never be touched, but it still
has a Sentry project and can still fire. A census that does not know its own
denominator is not a census; list the projects before claiming a set was
quiet.

### The 2026-08-04 window: the method held, and an inherited guess survived a test

Swept the same way as the 74 event sweep above: `by_message` read on all 71
events in the 24 hours to 2026-08-04 00:20 UTC, never on a sample. The per
shape numeric totals sum to 164, the password residual is 83, and 164 plus 83
is 247, which equals the sum of every in window event `count` field. The same
caveat as before applies unchanged and is the reason this is a reconciliation
rather than a proof: shape 1 is a residual of `by_severity` and not a direct
read, because Sentry filters that message, so that component cannot fail
arithmetically. Completeness rests on the key sweep and the arithmetic
together.

Eight shapes again, but not the same eight, and the difference is the useful
part.

Unchanged and still firing at an unchanged rate, both committed and both
undeployed, which is the whole finding of this window:

- `duplicate key value violates unique constraint "?"`, 128 lines, exactly 32
  in each of four cycles at 00, 06, 12 and 18 UTC. Fixed in `e79339b`.
- `invalid input syntax for type uuid: "?"`, 23 lines, once an hour. Fixed in
  `1cdb96e`.

Both counts are identical to the previous window, and that is much weaker
evidence than it sounds, so do not quote it as confirmation. The two windows
OVERLAP. The previous one ran 2026-08-02 20:05 to 2026-08-03 20:05 and this one
runs 2026-08-03 00:20 to 2026-08-04 00:20, which is 19 hours 45 minutes of
shared ground and only 4 hours 15 minutes of genuinely new observation. Three
of the four dup key cycles, 96 of the 128 lines, and about 19 of the 23 uuid
lines are the SAME log lines counted twice. Identical totals are therefore
close to guaranteed by construction. The real new data is one 32 line cycle at
2026-08-04 00:00 and about four uuid lines.

Whoever writes the next one of these: a rolling 24 hour window against a note
written 4 hours ago mostly re-measures the previous measurement. State the
overlap explicitly or the numbers will read as independent agreement when they
are not.

`1cdb96e` landed on 2026-07-26 and `e79339b` on 2026-07-27, nine and eight days
before this window closed, and neither emitter has changed behaviour across any
of it. That part does rest on the full nine days rather than on this window, so
it survives the overlap. Nothing here adds a new mechanism for either; it adds
duration.

Scan noise, unchanged in character: the filtered password FATAL at 83 lines,
`unsupported frontend protocol N.N` at 8 lines, and `no PostgreSQL user name
specified in startup packet` at 2 lines. The protocol values seen this window
are `65363.19778`, `255.255`, `0.0` and `16.0`, which is the same set the
section above already lists and adds nothing new. That is not evidence the set
is closed, and the instruction above not to treat any list of them as
exhaustive still stands.

`invalid input value for enum committee_type: "?"` appears once, at
2026-08-03 00:40:04 UTC. That is the SAME occurrence already recorded in the
section above, not a recurrence: it sits inside the 00:45 rollup, which falls
in both windows. It has not fired again in the day since. Do not count it
twice.

THE TEST OF THE INHERITED GUESS, WHICH IS WHY THIS SECTION EXISTS
Nothing was falsified. A prediction was tested and it held, which is a weaker
and more ordinary result, and the section is worth reading for how little it
proves as much as for what it found.

The section above recorded shapes 7 and 8 as a hand query pair and said
explicitly: if they recur on a schedule, revisit that inference rather than
inherit it. That test has now been run and the inference survives, but only
because of what did NOT happen.

`operator does not exist: text = integer` did not appear at all. Its key is
absent from all 71 events. Be exact about what that buys, on two axes rather
than one.

On schedule: this window adds only 4 hours 15 minutes of new observation, per
the overlap above, so it does not on its own clear a daily emitter. What does
is the continuous silence since the single occurrence at 2026-08-02 21:30:53,
which is about 26.8 hours across the two windows together. Make that combined
argument explicitly, because neither window makes it alone.

On conditionality, which is the axis the first draft of this note missed
entirely: even 26.8 hours of silence only rules out a job that executes the
offending statement on EVERY tick. A daily or faster job that reaches the
statement on a data dependent branch can stay silent indefinitely and then fire
once. The committee_type finding above is exactly that shape. So silence
narrows the field and settles nothing.

The `column ... does not exist` family did recur, but NOT as the same line.
The previous window carried `column v.id does not exist`, qualified by an
alias and unquoted. This window carries `column "email" does not exist`,
unqualified and quoted, which is a different statement and not a repeat of the
same one. Postgres renders those two forms differently, so the distinction is
readable from the message alone.

And a family appears that no earlier section records at all:
`relation "public.forms" does not exist`, once, at 2026-08-03 23:51:39 UTC.
The `column "email"` line lands 13.9 seconds later at 23:51:53, in the same
rollup window.

So the pattern is a changing set of one-off schema errors rather than a fixed
set repeating, which is what ad hoc querying looks like and is not what any
scheduled job looks like. Two different bad identifiers fourteen seconds apart,
at 23:51 UTC, on no boundary, is somebody iterating on a query by hand. That
remains an inference from timing and message shape. It is now a better
supported one than when it was written, because the prediction it made was
tested and held.

WHAT IS CHECKED, AND WHAT IS ONLY INFERRED
The two new lines are NOT equally well established. An earlier draft of this
note ran them together under a heading claiming both were checked. They were
not. Keep them apart.

The `relation "public.forms"` line is checked. There is no table named `forms`
in either repo. Enumerating every `.from('...')` call in both gives eight
distinct form tables: the website uses `form_schemas`, `form_submissions`,
`form_analytics`, `form_field_analytics`, `form_files` and `form_events`, and
the CRM uses all of those except `form_files`, plus `form_drafts` and
`form_templates`. None is `forms`. Read the scope of that sweep correctly,
because it is narrower than "every table reference" in two ways.

It matches string literals, so it misses a `.from()` whose target is a
variable, and those exist here: `quickLinksTable`, `_boardsTable`,
`_connectionsTable`, `_nodesTable`, `_emailTable`, `_universalLayoutTable`,
`_applicantView`, `_fieldView`, `targetTable` in `meeting_repository.dart`,
`source` in `member_repository.dart`, which iterates
`_dashboardMetricsSources`, and the several separate constants each named
`_table`. All were resolved to their literals and none is `forms`. Read that
as the set found rather than as a closed one, which is the same caveat this
paragraph is making about the grep. Storage bucket name variables are left out
on purpose: a bucket is not a relation and cannot raise this error.

One trap if you repeat that check: a naive grep for `.from(<identifier>)` in
Dart also matches `List.from`, `Map.from` and `Set.from`, which are language
constructors and not database calls. They are the large majority of the
apparent hits and they resolve to nothing. Do not read that noise as unaudited
table access.

It also covers only `.from()`, so it misses RPC paths. The website reaches
`form_drafts` through SECURITY DEFINER RPCs called from its site-forms draft
hook rather than through `.from()`, so the per repo split above describes
`.from()` calls and is not a complete map. Neither gap moves the conclusion,
since `form_drafts` is still not `forms`, but a future run should not repeat
the phrase "every table reference" for a literal grep.

The RPC names and the file path are deliberately not written down here. This
repo is public and the sibling is not; the methodological point survives
without naming callable endpoints of the other system, so it is not named.

The `'forms'` string literals in `quick_links_screen.dart` and
`quick_links_dialog.dart`, nine instances across eight lines, are the quick
links category value. Be exact about them rather than waving them away: that
value IS written to SQL, as `quick_links.category` data in
`quick_links_repository.dart`, and it is ordered on there too. What it never is
is a relation identifier, and only a relation identifier can raise this error.
A bound data value cannot.

The `column "email"` line is NOT checked to that standard. No column level
enumeration was done at all. The sweep above is over table names, which gives
this line no cover whatever, and `email` columns are common in both repos. So
the honest position is that no emitter has been attributed to it, not that none
exists.

The rate argument covers both lines, and it is weaker than it first looks. A
planner error is raised on every execution of the offending statement, so a
statement in a hot path would fire far more than once a day. That reasoning
does not reach a cold one. An admin only screen opened once, a one off
migration, a branch taken only on an error, or any daily job all produce
exactly one line a day. This file's own committed emitters make the point:
the uuid line fires once an hour and the dup key burst four times a day. So
the rate makes a hot path unlikely and says nothing about a cold path.

That leaves an open question rather than a closed one, and the next run should
inherit it as open. One instruction here is safe either way and is the only one
worth treating as firm: do not change a working query to make one of these go
away. If either line recurs, the check that was skipped this time is a column
level search for the offending identifier.

Left alone deliberately on 2026-08-04. No code change anywhere this run: every
real defect in this window was already fixed in git and is waiting on a hand
deploy, and neither new shape has an emitter attributed to it, which for the
`column "email"` line means unchecked rather than cleared.

## READ FIFTH: the 02:25 UTC sweep, and an ignored issue that hides a project

Swept the 24 hours to 2026-08-04 02:25 UTC. No code change anywhere this run.
Read the overlap warning in the section above before quoting any number here,
because at a two hour cadence it is now close to total: this window shares 22
of its 24 hours with the one that closed at 00:20 UTC, and only 2 hours 5
minutes of it is new observation. Nothing below is independent confirmation of
anything above it.

THE CENSUS TRAP, WHICH IS THE FINDING WORTH INHERITING
The section above says to list the projects before claiming a set was quiet.
That is necessary and it is not sufficient. A search for `is:unresolved`
returns three issues, all in `supabase-platform`, and on that evidence a run
would report the other seven projects silent. They were not.
`endorsement-scorer` emitted 360 events in this window, roughly five times the
whole of `supabase-platform`, and none of them appear in an unresolved search
because ENDORSEMENT-SCORER-4 is set to ignored in Sentry.

Ignored is not silent. Census by EVENT count per project rather than by issue
status: an errors dataset aggregate over `project` with `count()` and an empty
query shows both projects at once. Do not filter that query by `level` either.
The first attempt here returned only `supabase-platform` at 55, because a
NATURAL LANGUAGE query string ("all error events in the last 24 hours grouped
by project") was rewritten by the tool into the filter `level:error`, and the
rollups that carry ERROR level Postgres lines are themselves tagged
`level=warning`. Be precise about the trigger: an actually empty query string
was NOT rewritten when an auditor retried it, so the hazard is phrasing the
request in prose, not the tool rewriting unconditionally. Two different
filters, `is:unresolved` and `level:error`, each independently hid a real part
of the picture.

ENDORSEMENT-SCORER-4 is the expected n8n watchdog and is correctly ignored. It
stays ignored. The point here is the method, not that issue.

The event census reconciles exactly and is recorded so the next run can check
whether it moved: `supabase-platform` 76, `endorsement-scorer` 360, and
`website`, `flutter`, `mautic`, `moydforms`, `n8n` and `supabase-edge` at zero.
The 76 splits 73 plus 2 plus 1 across SUPABASE-PLATFORM-1, -3 and -4. That 73
read 72 when the sweep started and 73 twenty minutes later, so a census taken
twice in one run will not match itself. The rolling window moves under you.

SUPABASE-PLATFORM-1: EIGHT NEW EVENTS, ZERO NEW SHAPES
`by_message` was read on all eight events after 00:20 UTC rather than sampled,
per the method the sections above prescribe. Sixteen log lines: the filtered
password FATAL 11 times across five events, `invalid input syntax for type
uuid: "cron"` twice at 01:00 and 02:00, `unsupported frontend protocol N.N`
twice and `no PostgreSQL user name specified in startup packet` once, the last
two both inside the 01:35 rollup. Every one is a shape the sections above
already enumerate.

Specifically absent: `invalid input value for enum committee_type`,
`column "email" does not exist`, `relation "public.forms" does not exist` and
`column v.id does not exist` did not recur. That extends the silence on the ad
hoc query family and it settles nothing, for exactly the conditionality reason
the section above gives. Do not read it as those lines being resolved.

The sponsors dup key burst is absent from this window only because its 00:00
UTC cycle landed in the 00:05 rollup, which belongs to the previous window. It
has not stopped. The two committed and undeployed defects, `1cdb96e` and
`e79339b`, are unchanged at nine and eight days.

SUPABASE-PLATFORM-4 HAS MOVED TO A DIFFERENT BUCKET
This is the one genuinely new thing this run, and READ THIRD does not cover it.
Every request in that section is against `meetings`. The single new request, at
2026-08-04 02:03:37 UTC inside the 02:05 rollup, is not:

    GET /storage/v1/object/public/events/event_611ce4aa-e5f1-4e64-8575-  400

The path is truncated at that length in the rollup sample, so the object name
is not recoverable from Sentry.

The key shape is attributed and the emitter is not. `uploadEventImage` in
`lib/services/crm/event_repository_impl.dart` writes
`event_$eventId/<social_share or website_image>-<millis><ext>` into the
`events` bucket and stores `getPublicUrl(path)` on the event row. The observed
first path segment is CONSISTENT WITH that shape rather than confirmed to be
it: the sample truncates in the middle of the UUID, at the fourth group, so the
remaining characters were never observed. Do not upgrade that to a match.

Record the scope of the writer survey, per the standard READ FOURTH sets,
because "the key shape is attributed" is easy to inherit as "this is the only
writer" and that is false. The `events` bucket has THREE writers across the two
repos, and only the first mints an `event_` prefix:

1. `uploadEventImage` in this repo, keys `event_<uuid>/...`, described above.
2. `src/app/site-events/api/event-image/route.ts` in the sibling repo, a
   service-role upload with keys `event-submissions/<millis>-<sanitized-name>`.
3. `submitEventWithImage` in `src/app/site-members/lib/portal-api.ts`, keys
   `member-events/<memberId>-<millis>-<index>.<ext>`.

Writer 3 also carries the only in-repo DELETE against this bucket, a
`storage.from('events').remove(...)` cleanup that runs when one upload in a
batch fails. That is directly relevant to the deleted-object hypothesis below
and it does not support it: the cleanup removes only the `member-events/` keys
it just wrote in that same call, so it cannot delete an `event_` object. No
code in either repo deletes an `event_` key.

Both render paths read the stored URL verbatim rather than rebuilding it:
`getStorageImageUrl` in the public `site-events` event page returns
`image.url || image.storage_url`, and the members dashboard reaches
`getPublicUrl` only when no stored URL field is present at all. So no code here
constructs a wrong URL, and the 400 is about the object rather than the link.

DO NOT TREAT THIS AS A PERMISSIONS PROBLEM, BECAUSE IT IS NOT ONE
`events` is a public bucket. The pre-migration audit snapshot in
`supabase/migrations/20260424_03_storage_rls.sql` records it as `public = t`,
and that migration explicitly KEEPS the `Public can view event files` SELECT
policy for `public` while dropping only the mislabelled write policies. A
public read of this bucket is allowed by design and already works. There is
nothing to widen, and the standing prohibition on widening a bucket flag or an
RLS policy to clear a storage error is not even in tension here.

WHAT IS NOT ESTABLISHED
What the 400 stands for, and therefore whether the object exists. READ THIRD
already warns against building a diagnosis on an assumed meaning for this
status code, and that warning applies here unchanged. A stale row pointing at a
deleted object, an upload that never landed, a malformed key, and a crawler
replaying an old URL are all consistent with what Sentry shows, and the rollup
sample carries only ip, method, path, status and timestamp, with no user agent
and no authentication information to separate them. One request in 24 hours
with 0 users impacted is weak evidence either way: a broken image on a live
event page would be fetched repeatedly, which argues against a hot path and
says nothing about a cold one. The source address is a single datacenter range
address and is not reproduced here.

Left alone deliberately on 2026-08-04. No code change: the shape of the URL is
established, the emitter is not, and the two checks that would settle it are a
storage listing under the `event_611ce4aa` prefix and the event row's stored
image metadata, neither of which is reachable from this container. Do not
resolve SUPABASE-PLATFORM-4, and do not "fix" a render path that is passing a
stored value through correctly.

THE DISCLOSURE TRADE, WEIGHED RATHER THAN ASSUMED
READ THIRD says to weigh this every time instead of inheriting it, so: this
repo is public and the sibling is private. Committed here are a truncated event
UUID, the `events` bucket name, the `Public can view event files` policy name,
and two render helper names in the private repo. Each is judged acceptable and
not by default. The event ID is cut mid-UUID with at least twelve hex
characters unrecoverable, and it names an object in a deliberately public
bucket that is already served on a public event page, so it discloses nothing
that a visitor to the site cannot see. The bucket and policy names are already
committed in this repo's own `20260424_03_storage_rls.sql` audit snapshot, so
naming them here adds no reach. The render helpers are display side functions
rather than callable endpoints, which is the distinction READ FOURTH drew when
it deliberately withheld RPC names, and that withholding still stands. The
source address is not reproduced, no credential or raw upstream error text
appears, and nothing here widens access to anything.

## READ SIXTH: the 04:20 UTC sweep, and the ad hoc query family becomes readable

Swept the 24 hours to 2026-08-04 04:20 UTC. No code change anywhere this run.
The reason is at the bottom of this section rather than assumed at the top.

Read the overlap warning in READ FOURTH before quoting any number here. At a two
hour cadence the overlap is now almost total: this window shares about 22 of its
24 hours with the sweep that closed at 02:25 UTC, and roughly 1 hour 55 minutes
of it is new observation. Nothing below is independent confirmation of anything
above it.

THE SCOPE OF THIS SWEEP, WHICH IS NARROWER THAN THE TWO ABOVE
READ FOURTH prescribes reading `by_message` on every event in the window rather
than on a sample, and it is right. This run did not do that, so do not read the
section below as a decomposition of the kind the 74 and 71 event sweeps
produced. It read `by_message` on 4 of the 75 events.

What those 4 were chosen to cover is the part that makes the result usable.
Every ERROR level rollup in the window that is NOT a `:05` rollup was read:
04:15, 03:25 and 23:55, all three of them. Every previously undocumented shape
in this family has arrived in exactly that kind of event, because the hourly
uuid line and the four times daily dup key burst both land on `:05` rollups. One
of those bursts, 00:05, was read as a control and is unchanged at 32 dup key
lines plus 1 uuid line. The remaining 71 events were classified by title and
timestamp against shapes READ FOURTH already enumerates. 4 read plus 71
classified is the full 75; an earlier draft of this paragraph said 70 and did
not reconcile, which in a note about coverage is the exact error READ FOURTH
warns about.

State the hole this leaves, because it is a real one. Events tagged as including
FATAL were not read, and those events carry ERROR lines as well as scan noise:
the 12:05 burst is titled `includes FATAL` and certainly contains that cycle's 32
dup key lines. So a genuinely new ERROR shape sitting inside a FATAL tagged
rollup would be invisible to this sweep. That is a weaker guarantee than the two
sweeps above give, it is recorded as weaker, and a run that needs completeness
should redo the full sweep rather than inherit this one.

THE DENSEST BURST THIS FAMILY HAS PRODUCED
Six ERROR lines inside one 5 minute window, 2026-08-04 04:09:02 to 04:14:01 UTC,
carried by the 04:15 rollup:

    operator does not exist: text = uuid    2   (04:13:45, 04:13:27)
    column d.decision does not exist        1   (04:13:33)
    column d.form_id does not exist         1   (04:09:49)
    column fs.is_active does not exist      1   (04:09:56)
    column s.form_schema_id does not exist  1   (no timestamp, see below)

The five timestamps come from the rollup `sample`, which carries only five
entries. `s.form_schema_id` is present as a `by_message` key and the counts
reconcile to six, so the line is real, but its timestamp was never observed. Do
not infer where in the window it fell.

Plus one more 48 minutes earlier, in the 03:25 rollup: `column "full_name" does
not exist`, at 03:21:27, unqualified and quoted.

Every previous appearance of this family was one or two lines. Six inside four
minutes is a change in density rather than in kind.

Count it correctly, because an earlier draft of this section did not and the
commit that introduced it repeats the error in its message, where it cannot be
corrected. Six LINES, five DISTINCT shapes: `operator does not exist: text =
uuid` occurs twice, as the table above shows. Any claim that all six differ is
false against this section's own table. The density argument does not depend on
it and is unaffected.

WHAT IS ACTUALLY NEW: THE MISMATCH IS NOW READABLE FROM THE IDENTIFIERS
Every earlier note on this family rested on timing and message shape, and said
so. This window is the first where the identifiers themselves carry the
argument, because for two of them this repo's own committed migrations name the
correct column:

- `s.form_schema_id`. The real column on `form_submissions` is `form_id`. Two
  committed policies in `20260422_00_endorsement_questionnaire_link.sql` and
  `20260422_05_rls_phase2.sql` both join on it. The string `form_schema_id`
  appeared nowhere in either repo before this note was written. Grep it now and
  you will hit this section. For the clean negative, read `AGENTS.md` at the
  PARENT of the commit that introduced READ SIXTH; do not use `HEAD~1`, which
  stops being that commit as soon as the next sweep appends its own section.
  The same caveat applies to `public.forms` in READ FOURTH.
- `fs.is_active`. The real column on `form_schemas` is `status`; the committed
  `form_submissions_public_insert_active` policy tests `fs.status = 'active'`.
  There is no `is_active` on `form_schemas` anywhere in either repo.
- and from the previous window, `relation "public.forms"`, where the real tables
  are `form_schemas` and `form_submissions`, per the eight table enumeration in
  READ FOURTH.

That is a consistent signature rather than three coincidences: each wrong name
is the plausible guess for the right one. `form_schema_id` for `form_id`,
`is_active` for `status`, `forms` for `form_schemas`. Code that shipped against
this schema does not guess; it either matches or fails on every execution.

WHY IT IS NOT EITHER APP'S DATA LAYER, AND WHAT THAT DOES NOT MEAN
The aliases are the second half of it. `d`, `fs` and `s` are hand chosen short
aliases on a multi table join. Both applications reach Postgres through
PostgREST, the website through supabase-js and the CRM through the
`supabase_flutter` Dart client, and PostgREST does not emit that form. So the
statements are raw SQL from something that is not either app's data layer.

Be careful about how far that goes, because it is narrower than "not this repo".
What it rules out is the two applications' data layers. It does not identify who
IS emitting, and one candidate is closer to home than the others: this repo
itself ships direct to Postgres psycopg scripts with hand written SQL in exactly
this style, including single letter aliases, under `scripts/voter_file/`. A
session adapted from that established workflow would produce precisely the shape
observed. A psql or SQL editor session, a migration being drafted by hand, the
`endorsement-scorer` service and an n8n workflow are all equally consistent, and
none of them is reachable from this container. `endorsement-scorer` was checked
and is not reporting SQL errors of its own: its only Sentry issue in this window
is the ignored n8n watchdog, at 359 events. That is an absence of evidence and
not evidence of absence, since a service need not report its database errors.

The literal failing statements are still attributable to no code in either repo,
but state that precisely, because the loose version of it is false. It is NOT
that these identifiers exist nowhere in either tree. Several of the bare names
do exist: `form_id` is the real column this section documents, `is_active`
appears in both trees on unrelated tables, on several of them in this repo and
on exactly one in the website, and `full_name` is common in both.
What no committed statement in either tree does is make these QUALIFIED
references, the column on that particular table. That combination is what rules
the repos out, and nothing weaker does. The psycopg point does not weaken it
either; it widens the set of humans and scripts that could have typed them.

Alias `d` on `decision` and `form_id` is most likely `endorsement_decisions`.
Nothing was changed for those two lines and nothing should be: a SELECT that
fails on a guessed column name never reaches execution, so it neither reads nor
writes a row.

WHAT IS NOT ESTABLISHED
Who is running these, and whether the six lines at 04:09 to 04:13 are one
session or several. The rollup carries message, severity and timestamp only,
with no client address, user or application name, so the events cannot be
attributed from Sentry and the code is not in this container. The reasoning that
this is hand iteration is now better supported than it was, but it is still an
inference from identifiers, aliases and burst timing, not an attribution.

The `column "full_name"` line is unchecked to the standard READ FOURTH set for
`column "email"`: no column level enumeration was done, and `full_name` is
common in both repos. No emitter is attributed to it.

Left alone deliberately on 2026-08-04. No code change: no committed statement in
either repo makes any of these qualified references, per the precision note
above, so there is nothing here to fix, and the standing instruction not to
change a working query to make one of these go away applies unchanged. The two
real defects in this window, `1cdb96e` and `e79339b`, are
still committed and undeployed at nine and eight days, and both are hand deploy
work per READ FIRST. `0d2963e` is in the same state, which is why
SUPABASE-PLATFORM-3 fired again at 2026-08-03 15:45.

SUPABASE-PLATFORM-4 carried exactly one request this window, the 02:03:37 UTC
`events` bucket 400 that READ FIFTH already documents in full. Same occurrence,
not a recurrence. Do not count it twice and do not resolve the issue.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Count what is actually named above rather than waving at
it, which is what the first draft of this paragraph did wrong: three table names
(`form_schemas`, `form_submissions`, `endorsement_decisions`), two real column
names (`form_id`, `status`), one policy name
(`form_submissions_public_insert_active`) and one script directory
(`scripts/voter_file/`). All seven are already committed in this repo's own
migrations, Dart sources or tree, so naming them here adds no reach.

Most of the failed identifiers describe nothing real, since they name columns
that do not exist. Do not state that as a blanket rule, because it is not one:
`full_name` is a real and common column in both repos, and it is only the
absence of a table qualifier on that line that leaves it uninformative.

Deliberately NOT written down here, and this is a change of practice worth
inheriting rather than an oversight: the state of any live endorsement vote, and
the operational read on who might be running these statements. This file is
public and the unattributed party can read it too, so anything that amounts to
telling them what has been noticed goes to Andrew directly instead. Record the
log lines, not the surveillance.

No source address, no credential, no RPC name, no database DSN and no raw
upstream error text appears, and nothing here widens access to anything.

## READ SEVENTH: the 06:25 UTC sweep, a real defect in the newsletter form, and the FATAL rollup hole closed

Swept the 24 hours to 2026-08-04 06:25 UTC.

Read the overlap warning in READ FOURTH before quoting any number here. This
window shares about 22 of its 24 hours with the sweep that closed at 04:20 UTC,
so only about 2 hours 5 minutes of it is new observation. Nothing below is
independent confirmation of anything above it.

THE COVERAGE HOLE READ SIXTH LEFT IS NOW CLOSED, AND IT WAS A REAL ONE
READ SIXTH read `by_message` on 4 of 75 events and recorded honestly that it
could not see inside rollups tagged `includes FATAL`. This run read
`by_message` on ALL 10 events after 04:20 UTC, FATAL tagged ones included. The
hole was not theoretical. The 05:40 rollup, titled `Postgres errors: 4
(includes FATAL)`, carries two filtered password FATALs AND two ERROR lines of
the ad hoc query family: `column "first_name" does not exist` at 05:35:32 and
`column "current_page" does not exist` at 05:34:58. A sweep that reads only
ERROR titled rollups misses both. Read every event, as READ FOURTH says.

THE NEW SHAPE, AND IT IS THE FIRST DEFECT THESE SWEEPS HAVE FOUND IN OUR OWN
APPLICATION CODE RATHER THAN IN AN UNDEPLOYED FIX OR SOMEBODY ELSE'S SESSION
`duplicate key value violates unique constraint "subscribers_email_unique"`, 2
lines, at 2026-08-04 04:30:49 and 04:34:12 UTC, inside the 04:35 and 04:40
rollups. It is absent from every decomposition in READ FOURTH, READ FIFTH and
READ SIXTH, so it is new to the record.

The mechanism is established from the sibling repo, not guessed. The contact
page newsletter form posts through a client component that does a bare
`.insert()` into `public.subscribers` on the anon key, and `subscribers.email`
carries a unique constraint. A supporter who is already on the list and submits
again gets 23505; the component threw on any error at all, and the catch showed
a generic "Something went wrong. Please try again" message. So an existing
subscriber was told the form was broken and invited to retry, which could never
succeed. The two lines are 3 minutes 23 seconds apart, which is what that
retry looks like.

Fixed in the sibling repo in `be458c9` by treating 23505, and only 23505, as
success. The INSERT statement itself is unchanged. Unlike the edge function
work in READ FIRST, this one IS deployed by CI: Vercel builds the Next.js site
from `main`, and per the sibling repo's own `AGENTS.md` the deploy block that
held every build between 2026-07-29 and 2026-08-04 was cleared on 2026-08-04.
Check the deployment rather than the commit, per the usual rule.

BE HONEST ABOUT WHAT THAT FIX DOES NOT DO
It does not stop the log line. The INSERT still fails at the database, so the
ERROR is still written and SUPABASE-PLATFORM-1 still carries it. That is
deliberate, because both ways of silencing it are worse. An `ON CONFLICT`
clause cannot be verified from a container with no database access, and if the
real unique object is composite or an expression index then
`onConflict: 'email'` raises 42P10 at PLAN time and breaks EVERY newsletter
signup rather than only the duplicate ones. A pre-read of `subscribers` to
check first is both an email enumeration vector and a read the anon role does
not have.

That first version was in fact written and then killed by an adversarial
auditor, which is the part worth inheriting. It used
`.upsert(..., { onConflict: 'email', ignoreDuplicates: true })` and justified
itself as "the same pattern the RSVP route already uses on the anon key". That
premise was FALSE. The RSVP route builds its client with the SERVICE ROLE key,
and the sibling repo's own `service.ts` says in as many words that the anon
role has no UPDATE grant on `subscribers`. There is no proven anon
`ON CONFLICT` precedent anywhere in either repo. Check which client a
precedent actually uses before citing it as one, because a precedent from a
privileged client is not a precedent for an unprivileged one.

DO NOT WRITE `Fixes SUPABASE-PLATFORM-1` IN A COMMIT MESSAGE
SUPABASE-PLATFORM-1 is the catch all rollup for every Postgres ERROR and FATAL
line, over 2000 occurrences since 2026-07-24 and still firing. Resolving it
would auto close an issue that also carries the sponsors dup key burst, the
hourly uuid line, the scan noise and the ad hoc query family. READ FIFTH
already records what it costs when a whole project's errors hide behind one
issue's status. Name the mechanism in the commit message instead.

THE AD HOC QUERY FAMILY HAS INTENSIFIED SHARPLY
READ SIXTH called six lines in four minutes the densest this family had
produced. This window beats it: 14 ERROR lines between 04:52 and 05:35 UTC,
every one of them read directly from a rollup `sample` rather than inferred.

    04:52:58.336  column "name" does not exist
    04:54:14.656  column "ordinality" does not exist
    04:54:45.072  "array_agg" is an aggregate function
    04:54:45.654  column "slug" does not exist
    04:56:31.580  "array_agg" is an aggregate function
    05:28:11.514  column "created_at" does not exist
    05:28:14.746  column "email" does not exist
    05:28:45.049  syntax error at or near "minute"
    05:32:25.048  column "email" does not exist
    05:32:42.146  column s.first_name does not exist
    05:32:57.208  column d.full_name does not exist
    05:33:27.279  "array_agg" is an aggregate function
    05:34:58.057  column "current_page" does not exist
    05:35:32.103  column "first_name" does not exist

Two of these are new in kind rather than merely new identifiers, and both
sharpen the hand iteration reading instead of just repeating it. `syntax error
at or near "minute"` is what `interval 1 minute` produces when the literal is
left unquoted, which is a typing mistake rather than something a deployed
statement does. `"array_agg" is an aggregate function` is raised when an
aggregate is used where a set returning function belongs, and it appears three
times alongside `column "ordinality" does not exist` in the same five minute
window, which is the shape of somebody trying to write
`FROM array_agg(...) WITH ORDINALITY` and iterating on it.

The aliases `d` and `s` recur, consistent with READ SIXTH. Nothing was changed
for any of these lines and nothing should be: no committed statement in either
repo makes these qualified references, and the standing instruction not to
change a working query to make one of these go away applies unchanged.

THE CENSUS
By event count per project, per READ FIFTH, rather than by `is:unresolved`:
`endorsement-scorer` 360, `supabase-platform` 83, and `website`, `flutter`,
`mautic`, `moydforms`, `n8n` and `supabase-edge` at zero. The 83 splits 80 plus
2 plus 1 across SUPABASE-PLATFORM-1, -3 and -4. `endorsement-scorer` is the
expected n8n watchdog, correctly ignored, and it stays ignored.

STILL COMMITTED AND UNDEPLOYED, UNCHANGED
`e79339b` (the 32 line sponsors dup key burst, seen again in the 06:00 cycle),
`1cdb96e` (the hourly uuid line, seen at 05:00 and 06:00) and `0d2963e` (the
relay 502 behind SUPABASE-PLATFORM-3, last fired 2026-08-03 15:45). All three
are hand deploy work per READ FIRST, now at nine, eight and nine days.

SUPABASE-PLATFORM-4 carried the same single `events` bucket 400 from 02:03:37
UTC that READ FIFTH documents in full. Same occurrence, not a recurrence. Do
not count it twice and do not resolve the issue.

BOTH LOCAL BRANCH REFS WERE STALE AGAIN, IN BOTH REPOS AT ONCE
READ SECOND's trap was live in this container. `git ls-remote` against
`git rev-parse`:

    my-bluebubbles-web  local master  5d8a5b0   real refs/heads/master  22117fd
    moyoungdemocrats    local main    77d879f   real refs/heads/main    bc8b12e

In both repos the detached `HEAD` the container started on was ALREADY at the
true tip and the named branch ref was behind it, so `git checkout master` would
have moved BACKWARD onto a stale base. That is now the third run to meet this.
Treat it as expected rather than as something to check for once.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Named above: the `subscribers` table and its `email`
column, the constraint name `subscribers_email_unique`, and the fact that the
sibling repo's RSVP path uses a service role client. The table and column are
already committed in this repo's own
`20260422_06_rls_phase2_1_tighten_anon_writes.sql` and
`20260423_01_backfill_orphan_rpcs.sql`, and the constraint name is already
published verbatim in the Sentry error text. No credential, no DSN, no source
address, no RPC name, no policy body and no raw upstream error appears, and
nothing here widens access to anything. Deliberately not written down, per the
practice READ SIXTH set: the state of any live endorsement vote, and the
operational read on who is running the ad hoc statements. Both go to Andrew
directly.

## READ EIGHTH: the 08:20 UTC sweep, and the resolved-issue blind spot that hid a real defect

Swept the 24 hours to 2026-08-04 08:20 UTC.

Per the overlap warning in READ FOURTH: this window shares about 22 hours with
the sweep that closed at 06:25 UTC, so only about 1 hour 55 minutes of it is
new observation. Nothing below independently confirms anything above it.

THE CENSUS TRAP READ FIFTH DESCRIBED IS WORSE THAN `is:ignored`
READ FIFTH established that filtering `is:unresolved` hides a whole project
behind one ignored issue. This run found the same trap has a second door:
RESOLVED issues that are still firing. An unfiltered issue query over 24h
returned SEVEN issues where `is:unresolved` returned four. The two extra were
both in `flutter` and both marked resolved:

    FLUTTER-8  resolved  last seen 08:22 UTC  (227 occurrences, 8 users)
    FLUTTER-2  resolved  last seen 07:24 UTC  (1 event this window)

FLUTTER-2 carried the only real application defect found this run. A sweep
that reads `is:unresolved` would have shipped nothing. Query issues with NO
status filter and reconcile against the per-project census.

THE DEFECT: A LIVE QUERY FILTERS ON TWO COLUMNS THAT DO NOT EXIST
`CandidateRepository.findPossibleMemberMatches` name fallback issued

    from('members').ilike('first_name', fn).ilike('last_name', ln)

against `public.members`, which stores the whole name in a single `name`
column. Postgres raised `column members.first_name does not exist`, PostgREST
returned 400, and the function's own catch turned that into `return []`.

The correlation is to the second and is the reason this is attributed rather
than guessed: the FLUTTER-2 event is timestamped 2026-08-04T07:24:26Z with tag
`crm.section=candidates`, and the SUPABASE-PLATFORM-1 rollup carries
`column members.first_name does not exist` at 07:24:26.445+00. Same second,
same executive session.

Evidence the columns do not exist, none of it from the error text alone:
`MemberRepository.listingColumns` in `member_repository.dart` enumerates the
table and holds `name` with no first/last; no migration in
`supabase/migrations/` adds them; the roster ingest edge function
`process-membership-roster` writes a single composed `name`; and the sibling
`findMemberByEmailOrName`, in `candidate_repository.dart` itself, already
name-matches with `.ilike('name', '$fn $ln')`. The one `first_name` select
elsewhere in `candidate_repository.dart` targets `legislation_legislators`,
not `members`.

WHY NOBODY REPORTED IT
The correct sibling is DEAD CODE. `findMemberByEmailOrName` has no callers
anywhere in `lib/`. The broken one is the live path, reached from
`_possibleMatchPanel` in `candidate_detail_screen.dart`. On the 400 the panel
renders "No matching MOYD member found by name or email.", which is a
confident false negative rather than an error, so it looks like a true answer.

Worse than a missing fallback: the throw escapes AFTER the email lookup has
already appended its hits to `results`, so a candidate whose email DID match a
member still rendered as no match. The email path was collateral.

Fixed by pointing the filter at `name`. The statement, the select list, the
limit and the dedupe are unchanged.

WHAT WAS DELIBERATELY NOT FIXED
The catch still returns `[]` on any failure, discarding partial email results.
That is a second and smaller defect, it is pre-existing, and it is not what
fired. One issue per commit.

DO NOT WRITE `Fixes FLUTTER-2`
Same trap as SUPABASE-PLATFORM-1. Per `292da5a`, FLUTTER-2 is a catch-all:
every SentryHttpClientError carries the same SDK frames, so Sentry buckets all
failed HTTP requests together regardless of URL or status. The group still
holds unfixed 403s on `get_fec_spending_by_purpose` and
`get_fec_recent_expenditures` that need a grant change made by hand. Closing
the group would hide them. Use `Refs`.

FLUTTER-1 IS NOT A DEFECT AND IS IN THE PROTECTED SURFACE
Three events at 07:25:04, all one Mobile Safari session, against THREE
different tables: `endorsement_votes`, `candidates` and `endorsement_decisions`.
Three tables failing in the same second is transport, not a query defect.
`Load failed` is Safari's generic fetch failure and the mechanism tag is
`SentryHttpClient`, which captures every failed request independently of app
handling. The app already does the right thing: `load()` catches, reports
deliberately, sets `VoteLoadState.failed` so the board shows a retry card
instead of a fully populated board on which nobody has voted, and re-subscribes
so a later channel join self-heals. Nothing to fix, and it sits inside the
endorsement voting surface, so nothing may ship there autonomously anyway.

SUPABASE-PLATFORM-1: TWELVE ROLLUPS READ, ZERO NEW FAMILIES
Read `by_message` on all twelve rollups after 06:25, FATAL-tagged included, per
READ FOURTH. Every line falls in a family already recorded: the ad hoc hand SQL
family, the filtered password FATALs, and the two undeployed fixes. New
IDENTIFIERS, not new shapes: `user_id`, `is_active`, `s.fields`, `claim_url`,
`fs.form_schema_id`, `m.first_name`, `members.first_name`,
`relation "public.legislators"`, `syntax error at or near "desc"`, and the uuid
literals `999` and `SOMEID`. One is arguably new in kind and is recorded for
the next run rather than acted on: `cannot get array length of a non-array` at
07:59:00, which is a jsonb/array function error rather than a missing column or
a syntax slip.

`members.first_name` is the exception that matters: it is the ONLY line in that
family this run traced to committed application code rather than to somebody
typing SQL. Do not assume the whole family is hand iteration. Check the
timestamp against the `flutter` project before classifying.

BOTH UNDEPLOYED FIXES STILL FIRING ON SCHEDULE, PER READ FIRST
`invalid input syntax for type uuid: "cron"` landed at 07:00:05 and 08:00:08,
hourly on the hour, so `1cdb96e` is still not deployed at nine days.
`duplicate key value violates unique constraint "legislation_bill_sponsors_unique"`
landed 32 times at 06:00:32, unchanged size, so `e79339b` is still not deployed
at eight days. SUPABASE-PLATFORM-3 produced NO new events; its two events this
window are the 2026-08-03 15:35 and 15:45 pair READ SEVENTH already counted,
and both still carry the pre-fix `Error: ` prefix, so `0d2963e` is still not
deployed at nine days. Do not count that pair twice.

SUPABASE-PLATFORM-4: A SECOND SHAPE, AND THIS ONE IS NOT OURS
READ FIFTH documents a 400 on `/storage/v1/object/public/events/event_611ce4aa-`.
The new event at 06:39:35 UTC is a DIFFERENT request from a different source
address:

    GET /storage/v1/object/public/events/    400

No object key at all, just the bucket root with a trailing slash. None of the
three `events` writers in READ FIFTH can produce a keyless path, and neither
render path builds one. A keyless object GET is malformed and Supabase answers
400 regardless of bucket permissions, so this needs no permission reasoning and
it is not evidence about the 02:03:37 request. Left alone. Do not resolve
SUPABASE-PLATFORM-4 and do not widen anything.

FLUTTER-8 REGRESSED EXACTLY AS `dd2a052` PREDICTED
Firing again at 08:22:23, `in_foreground: false`, lifecycle `hidden`.
`dd2a052` said in as many words that FLUTTER-8 would regress on the next
contact fetch and deliberately did not auto-close it, because the residual
event is one per fetch from the shared `ApiInterceptor` and the real repair is
that `messages.moydchat.org` is dead, which is infrastructure. Someone resolved
it anyway. Nothing to do in this repo. Do not re-fix it and do not re-resolve it.

ENDORSEMENT-SCORER-4 is the expected n8n watchdog at 360 events, still ignored,
stays ignored.

THE CONTAINER HAD NO FLUTTER AND NO DART
Neither binary exists on this image and there is no pub cache. The verify gate
is not skippable, so the SDK was installed from the URL `netlify-build.sh`
already uses, pinned to 3.41.8. It resolved to revision 02085feb3f with Dart
3.11.5, matching the deployed build's own tags exactly. Budget about 15s for a
1.4G download plus extraction, and `flutter pub get` before `flutter analyze`.
`pub get` rewrites five generated plugin registrant files under `linux/`,
`macos/` and `windows/`; discard them before committing. Running the tool as
root also needs `git config --global --add safe.directory` on the SDK path.

BOTH LOCAL BRANCH REFS WERE STALE AGAIN, THE FOURTH RUN RUNNING
`my-bluebubbles-web` local `master` was 11 commits behind `origin/master`, and
`moyoungdemocrats` local `main` was 13 behind `origin/main`. Both containers
started on a detached HEAD. Fetch and hard reset to the remote ref before
reading anything, and re-read READ SECOND.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Named above: the `members` table and its `name`,
`first_name` and `last_name` columns, and the `events` bucket. All three are
already committed here, `members` and its columns throughout
`member_repository.dart` and `candidate_repository.dart`, and the bucket in
READ FIFTH. No credential, no DSN, no source address, no policy body and no raw
upstream error appears, and nothing here widens access to anything. The storage
source address is deliberately not reproduced, per READ FIFTH. Deliberately not
written down, per the practice READ SIXTH set: the state of the live
endorsement vote, the identity of the executive whose session produced the
FLUTTER-1 and FLUTTER-2 events, and the operational read on who is running the
ad hoc statements. Those go to Andrew directly.

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
