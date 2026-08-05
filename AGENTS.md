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

## READ NINTH: the 11:31 UTC sweep, and provenance timing beats a grep negative

Swept the 24 hours to 2026-08-04 11:31 UTC. No code change anywhere this run,
and the reason is at the bottom rather than assumed at the top.

Per the overlap warning in READ FOURTH: this window shares about 21 hours with
the sweep that closed at 08:20 UTC, so only about 3 hours 11 minutes of it is
new observation. Nothing below independently confirms anything above it.

SCOPE OF THIS SWEEP
`by_message` was read on all 13 SUPABASE-PLATFORM-1 events after 08:20 UTC,
FATAL tagged ones included, per READ SEVENTH. The remaining 73 events fall in
the window the previous two sweeps already decomposed. Two events returned an
HTTP 500 from the Sentry API on first request and were re-fetched successfully;
if that happens again, retry rather than classifying by title.

THE METHOD THAT IS NEW, AND IT IS STRONGER THAN THE ONE ABOVE IT
Every previous note on the ad hoc query family cleared our own code with a grep
negative: the identifier appears nowhere, therefore no committed statement makes
that reference. READ FOURTH is careful about how weak that is, because a
deployed-only RPC is exactly what a repo search cannot see.

This window supplies a better instrument for one line. At 09:24:33 UTC the
rollup carried `relation "public.elections" does not exist`. The sibling repo
DOES query a relation by that name, so the grep negative fails outright and an
earlier reading would have called this a live defect.

It is not, and the argument does not depend on a grep at all. Every reference to
that relation in the sibling repo was INTRODUCED by a single commit, and that
commit was authored at 09:44:50 UTC, 20 minutes AFTER the error fired. Code that
did not exist in the tree cannot have been running in production. Provenance of
the calling code, not presence of the identifier, is what settles it.

Prefer this check when it is available. `git log --diff-filter=A` or a parent
comparison on the calling file dates the CODE; a grep only tells you the state
of the tree right now. The two disagree exactly when a repo is moving fast,
which is when a sweep is most likely to be wrong.

Be honest about its reach. It establishes that no DEPLOYED build of that repo
emitted the line. It says nothing about a local checkout, a migration being
applied by hand, or a psql session, which is the reading the timing actively
supports.

THE FAMILY THIS WINDOW, EIGHT LINES IN UNDER TWO HOURS
    08:14:18  column "is_active" does not exist
    08:16:50  column "user_id" does not exist
    08:40:41  column "responses" does not exist
    09:05:49  relation "public.opportunities" does not exist
    09:24:33  relation "public.elections" does not exist
    09:29:14  invalid input syntax for type uuid: "pl"
    09:39:29  function "public.get_members_filtered(text,text,text,integer,integer)" does not exist
    10:03:05  relation "public.donor_master" does not exist

Three are cleared to the standard READ FOURTH sets, and each by a different
instrument, which is worth keeping straight:

- `public.elections`, by the provenance argument above.
- `public.get_members_filtered`, by ARITY rather than by absence. A function of
  that name is real and is defined in this repo's own migrations, taking two
  array arguments. The failing call passes five scalars. A deployed caller does
  not drift in arity; it either matches or fails on every execution. It also has
  no caller in either repo.
- `public.opportunities`, by grep, and the grep is clean: the sibling repo's
  opportunities surface reads differently named tables, and every occurrence of
  the word in this repo is documentation or UI copy, never a table name.

`public.donor_master` is not a relation either repo names; the nearest real one
differs. The three bare column names and the `"pl"` uuid are NOT cleared to that
standard. No column level enumeration was done, `user_id` and `is_active` are
common in both trees, and READ SIXTH's caveat about unqualified identifiers
applies unchanged. No emitter is attributed to any of the four.

The `"pl"` line deserves one note because it shares a message shape with a real
committed defect. `invalid input syntax for type uuid: "cron"` is the hourly
line that `1cdb96e` fixes and that is still undeployed. This one carries a
different value, is a one off, and lands at 09:29 in the middle of the burst
above. Do not merge the two on message shape; the value discriminates them.

WHAT ELSE FIRED, ALL OF IT ALREADY ON THE RECORD
- The hourly `uuid: "cron"` line at 09:00, 10:00 and 11:00. `1cdb96e` is
  committed and undeployed at nine days.
- The 32 line sponsors dup key burst is ABSENT from the new observation only
  because no 6 hour boundary falls inside it. It has not stopped. `e79339b` is
  committed and undeployed at eight days.
- SUPABASE-PLATFORM-3 produced no new events. Its two are the 2026-08-03 15:35
  and 15:45 pair READ SEVENTH already counted. `0d2963e` is committed and
  undeployed at nine days. Do not count that pair a third time.
- SUPABASE-PLATFORM-4 carried the 02:03:37 `events` bucket 400 and the 06:39:35
  keyless bucket root GET, documented in full by READ FIFTH and READ EIGHTH.
  Same occurrences, not recurrences. Do not resolve it.
- The filtered password FATALs continue at the usual rate. Scan noise.

THE FLUTTER PROJECT: FIVE EVENTS, ZERO NEW
FLUTTER-2 last fired at 07:24:26 and its fix `2a90af9` landed at 08:44:37, so
it has not fired since the fix. Handled, left alone, and deliberately not
re-resolved. FLUTTER-1's three events are the same 07:25:04 occurrence READ
EIGHTH classified as transport; they carry the same trace id as the FLUTTER-2
event 38 seconds earlier, so one session produced both. FLUTTER-8 fired once
and is the dead `messages.moydchat.org` host that `dd2a052` predicted would
regress. Nothing to do for any of the three.

ENDORSEMENT-SCORER-4 is the expected n8n watchdog at 360 events, still ignored,
stays ignored. `website`, `mautic`, `moydforms`, `n8n` and `supabase-edge` were
silent, verified by event count per project and not by an issue status filter,
per READ FIFTH.

THE BRANCH REF TRAP, FIFTH RUN RUNNING, PLUS A NEW WAY TO CAUSE IT
Both repos again presented a stale named branch with `HEAD` detached at the true
tip: this repo's `master` at `5d8a5b0` against a real `f95819a`, and the
sibling's `main` at `77d879f` against a real `91d368e`. Expected now, per READ
SECOND.

The new part is self inflicted and worth recording because it is easy to repeat.
The repair was run as a single shell line of the form
`cd repoA && git checkout -B main HEAD; echo ...; git checkout -B master HEAD`,
intending the second half to apply to repoB. There was no second `cd`. Both
commands ran in repoA, which left the sibling carrying a bogus `master` branch
at its own tip and left THIS repo unrepaired, while the output looked like
success. Bash tool cwd also persists between calls and was reset to `/home/user`
by an unrelated command in between, so reasoning about "the current repo" was
wrong twice for two different reasons.

Use `git -C <path>` for every git command in a two repo container. Do not rely
on `cd` persisting, and do not chain two repos' repairs in one line.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. Weighed rather than inherited.

Named above: the relation names `public.elections`, `public.opportunities` and
`public.donor_master`, none of which exist as written, so they describe nothing
real; the function name `public.get_members_filtered`, which is already
committed in this repo's own migrations, so naming it adds no reach; and four
bare column names, which are common words.

Deliberately withheld: the sibling repo's real table names behind its
opportunities surface, since the finding holds without them; the identity of the
executive whose session produced the FLUTTER events; the state of the live
endorsement vote; and the operational read on who is running the ad hoc
statements. Those go to Andrew directly.

No credential, no DSN, no source address, no policy body and no raw upstream
error appears, and nothing here widens access to anything.

## READ TENTH: the 12:27 UTC sweep, a 429 in the relay, and a permission burst that must not be granted away

Swept the 24 hours to 2026-08-04 12:27 UTC. One code change this run, `285a05f`,
described below.

Per the overlap warning in READ FOURTH: this window shares about 23 of its 24
hours with the sweep that closed at 11:31 UTC, so only about 56 minutes of it is
new observation. That is the narrowest new slice any of these sweeps has had.
Nothing below independently confirms anything above it, and the two genuinely new
findings both landed inside that 56 minutes.

SUPABASE-PLATFORM-3 HAS A SECOND UPSTREAM FAILURE MODE, AND IT IS FIXED IN GIT
Every prior note on this group describes one shape, the CDN 502. There are now
two. Enumerated over the full 14 day range rather than incremented, per READ
FIRST, the group holds 15 events: 14 of the 502 shape from 2026-07-24 07:05
through 2026-08-03 15:45, and one new event at 2026-08-04 12:10:02 reading

    logs query failed 429: {"message":"ThrottlerException: Too Many Requests"}

14 plus 1 reconciles against the issue's own Occurrences field of 15.

`0d2963e` added the retry loop for the 502s and classified every 4xx as non
retryable, with the comment "4xx is a bad token or a bad query: retrying cannot
change the answer." That is right for 400, 401, 403 and 404 and wrong for 429,
which is the one 4xx where the identical request succeeds once the window
clears. So the single throttle short circuited the loop on attempt 1 and killed
the run. Fixed in `285a05f`: 429 joins 5xx as retryable and waits on
`Retry-After`, floored at 5s so a zero or stale value cannot become an instant
retry back into the same throttle, capped at 30s so it cannot park the run into
the next cron tick.

Two things about that commit worth inheriting rather than rediscovering.

The first version routed 5xx through `Retry-After` too, and an adversarial
auditor killed it: a CDN error page carrying `Retry-After: 0` would have
collapsed the linear backoff to an immediate retry and regressed exactly what
`0d2963e` was written to produce. The shipped version reads the header only when
`res.status === 429`. When you widen a retry classification, check what else you
just put on the new code path.

The three concurrent `queryLogs` calls under `Promise.all` are a plausible cause
of being throttled at all, and were deliberately NOT changed, because sequencing
them is a behaviour change beyond this issue. The escalation trigger is defined:
if 429s recur AFTER this deploys, identifiable by a 429 status event carrying 3
attempts, that recurrence is the evidence the fan out is the mechanism and
sequencing becomes the next change. Note the discriminator carefully, because the
`after N attempt(s)` wording alone is not one: it already shipped in `0d2963e`.

This is undeployed like everything else under `supabase/functions`, per READ
FIRST, and the 12:10 event still carries the pre fix `Error: ` prefix and the pre
fix `${status}: ${body}` shape, so a pre `0d2963e` build was still serving as of
12:10:02 today. That extends the build drift finding, which READ FIRST scoped
only as far as 2026-08-03 15:45, to today.

VERIFYING A DENO FILE IN A CONTAINER WITH NO DENO
There is no `deno` binary on this image and `deno.land` is blocked by the
container network policy, which answers 403 to CONNECT. `flutter analyze` is not
a substitute and is not a gate here, because it does not read TypeScript under
`supabase/functions`; installing the 1.4G SDK as READ EIGHTH describes would have
verified nothing about this diff.

What worked, and is cheap to repeat: a DIFFERENTIAL type check. `npx tsc` is
available, and running it over the file at HEAD and over the working tree gives
byte identical diagnostic sets, 8 in each, all of them `Cannot find name 'Deno'`
and the remote `esm.sh` import. Deno noise cancels out and any new diagnostic
would stand out. The delay logic was then extracted into plain node and unit
tested across 17 cases, including the 5xx assertions that prove the untouched
path really is untouched. Prefer this over skipping the gate, and over claiming a
gate that does not apply to the file you changed.

THE NEW SHAPE IN SUPABASE-PLATFORM-1, AND THE FIX THAT MUST NEVER BE MADE
The 12:15 rollup, window 12:04:02 to 12:14:02, carries 18 ERROR lines. Twelve of
them are `permission denied for function <name>`, and they land in a tight run
around 12:13:35 at roughly 98 ms spacing. Alongside them sits one
`insufficient_privilege: staff role required`, which is a `RAISE EXCEPTION` from
the body of a stats RPC in `supabase/migrations_manual/20260722_stats_rpcs.sql`
guarding on `public.is_staff()`. The remaining lines are three `column reference
"?" is ambiguous`, one `field name must not be null`, and one `canceling
statement due to statement timeout`.

THE FIX THAT MUST NEVER BE MADE
Do not GRANT EXECUTE on these functions to make this go away. This is the
standing prohibition in the run instructions and in READ THIRD, and here it has
teeth: the denied set is the `count_*` and `get_*_filtered` admin family defined
in this repo's own campaign and segment builder migrations, and it reads members,
donors, subscribers and event attendees. Granting it to `authenticated` would
expose the entire member and donor file to every logged in user. A permission
denied on these is very likely the system working correctly.

WHY IT IS PROBABLY NOT A USER FACING BREAK, STATED AS THE INFERENCE IT IS
The two error classes together are the informative part. `permission denied for
function` is refused at the GRANT, before execution. `insufficient_privilege:
staff role required` means that one function DID execute and then failed its own
`is_staff()` guard. A caller with no privilege anywhere produces only the first
kind. So the caller is authenticated and not staff, and holds EXECUTE on some of
these and not others.

That, plus regular ~98 ms spacing across a systematic walk of paired `count_` and
`get_` functions, is what a permissions smoke test or audit script looks like,
not what a screen loading looks like. It is an inference from timing and error
mix, not an attribution, and the rollup carries no client address, user or
application name, so it cannot be attributed from Sentry.

Scope the code check honestly, because it is narrower than a clean negative. A
grep of `lib/` and of the sibling repo's `src/` finds NO caller for any of the
denied `count_*`/`get_*_filtered` names. The one exception is `search_donors_v3`,
which IS called from `mec_repository.dart` and which `20260427_11_donor_search_
security_definer.sql` grants to `authenticated`. If a real executive session hit
that denial, MEC research is broken for them, and that possibility is NOT
excluded by anything here. What argues against it is the company the line keeps:
a screen that needed donor search would not also call `get_available_api_key`,
which nothing but edge functions call. Left as an open question rather than a
closed one.

Nothing was changed for any of these lines.

WHAT ELSE FIRED, ALL OF IT ALREADY ON THE RECORD
- The 12:05 rollup is the 12:00 UTC cycle, read directly and unchanged: 32
  `legislation_bill_sponsors_unique` dup key lines plus 1 hourly uuid line, 33
  total. `e79339b` and `1cdb96e` are committed and undeployed at eight and nine
  days.
- SUPABASE-PLATFORM-4 carried the 02:03:37 `events` bucket 400 and the 06:39:35
  keyless bucket root GET, both documented in full by READ FIFTH and READ EIGHTH.
  Same occurrences, not recurrences. Do not count them again and do not resolve.
- FLUTTER-2 last fired 07:24:26 and its fix `2a90af9` landed 08:44:37, so it has
  not fired since the fix. Handled, left alone, deliberately not re-resolved.
- FLUTTER-1's three events are the same 07:25:04 transport occurrence, in the
  protected endorsement surface. FLUTTER-8 is the dead `messages.moydchat.org`
  host per `dd2a052`. Nothing to do for either.
- The filtered password FATALs continue at the usual rate. Scan noise.

THE CENSUS
By event count per project, per READ FIFTH, not by an issue status filter:
`endorsement-scorer` 360, `supabase-platform` 96, `flutter` 5, and `website`,
`mautic`, `moydforms`, `n8n` and `supabase-edge` at zero. `endorsement-scorer` is
the expected n8n watchdog, correctly ignored, and it stays ignored. Note the
issue list was queried with NO status filter, per READ EIGHTH, which is how the
two resolved `flutter` issues stayed visible.

THE SENTRY API 500s READ NINTH WARNED ABOUT ARE REAL
Two `search_issue_events` calls returned HTTP 500 and one `search_events` call
timed out at 60s. All succeeded on retry with a differently shaped query. Retry
rather than classifying by title, exactly as READ NINTH says.

THE BRANCH REF TRAP, SIXTH RUN RUNNING
Both repos again presented a stale named branch with `HEAD` detached at the true
tip: this repo's `master` at `5d8a5b0` against a real `b9ae4c5`, and the
sibling's `main` at `77d879f` against a real `f1ef9ab`. Repaired with
`git -C <path> checkout -B <branch> HEAD`, using `git -C` for every command per
READ NINTH's self inflicted lesson. This is no longer worth treating as a
surprise.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. Weighed rather than inherited.

Named above: the `count_*` and `get_*_filtered` admin RPC family, the stats RPC
guard string `insufficient_privilege: staff role required`, the
`migrations_manual/20260722_stats_rpcs.sql` path, `public.is_staff()`,
`search_donors_v3` and `20260427_11_donor_search_security_definer.sql`. Every one
is already committed in this repo's own migrations and Dart sources, so naming
them adds no reach. The individual function names are deliberately NOT
enumerated: the family name carries the finding and the instruction not to grant,
and a ready made list of admin endpoints that currently refuse an authenticated
caller is the one thing here that would be more useful to someone probing than to
the next run.

Deliberately withheld, per the practice READ SIXTH set: the state of the live
endorsement vote, the identity of any executive in the FLUTTER events, and the
operational read on who is running the ad hoc statements and the RPC walk. Those
go to Andrew directly.

No credential, no DSN, no source address, no policy body and no raw upstream
error appears, and nothing here widens access to anything.

## READ ELEVENTH: the 14:21 UTC sweep, a real chartering defect, and the burst decoded as negative testing

Swept the 24 hours to 2026-08-04 14:21 UTC. One code change this run, in the
SIBLING repo: `1f2bc35`, described below.

Per the overlap warning in READ FOURTH: this window shares about 22 of its 24
hours with the sweep that closed at 12:27 UTC, so only about 1 hour 54 minutes
of it is new observation. Nothing below independently confirms anything above it.

SCOPE OF THIS SWEEP
`by_message` was read on all 10 SUPABASE-PLATFORM-1 events after 12:19 UTC,
FATAL tagged ones included, per READ SEVENTH. The remaining 84 of the window's
94 events fall inside ground the previous three sweeps already decomposed and
were classified by title and timestamp against families those sweeps enumerate.
That is the weaker guarantee READ SIXTH describes, and it is recorded as weaker.
The window carried 94 rollup events holding 312 Postgres log lines, including
four 33 line cycles at 00:05, 06:05, 12:05 and 18:05, each 32 sponsors dup key
lines plus 1 hourly uuid line.

THE REAL DEFECT, AND IT IS IN THE PUBLIC FORMS STACK
`null value in column "name" of relation "members" violates not-null
constraint`, once, at 2026-08-04 12:30:29 UTC. No earlier section records it.

The mechanism is established from the sibling repo rather than guessed.
`coalesceName` in `process-chartering-submission` returns `string | null`, and
returns null when a chapter chartering submission carries neither the legacy
`contact_name` nor the `contact_first_name` / `contact_last_name` pair. Nothing
between its assignment and its use guards it, so the null was assigned to the
`name` key of the members upsert. `members.name` is NOT NULL, which the Sentry
line itself establishes by naming the column, so the statement was refused. NOT
NULL is checked against the proposed tuple before ON CONFLICT arbitration, so an
existing row for that email did not save it either.

The consequence was quiet rather than loud, which is why nobody reported it. The
error was logged and never thrown, so the chartering application still returned
success while the chapter contact was silently never recorded as a member.

Fixed in `1f2bc35` by skipping the member write when there is no contact name.
Nothing downstream reads the member row: the upsert's `.select('id')` result was
already discarded, and the officers roster, the membership roster, the
`form_submissions` update and the response body all key off the chapter id. This
is an edge function, so per READ FIRST no automation deploys it and it needs a
hand deploy of that one function.

Two things were deliberately NOT fixed, one issue per commit, both pre existing
and both found by the auditor rather than by the diff's author. `contact_email`
is unguarded in exactly the same way, so a submission carrying a name but no
email still fails or mints an email-less row. And an existing contact's name
could be recovered from the row this function already reads, which would
preserve the committee merge the skip gives up.

THE 12:30 TO 13:03 CLUSTER IS NEGATIVE TESTING, AND THAT READING IS NEW
Five separate error families landed inside 33 minutes, and read together they
decode in a way no single one of them does alone:

    12:30:29  null value in column "name" of relation "members"
    12:36:40  column reference "created_at" is ambiguous
    12:55:16  GET /storage/v1/object/form-uploads/probe/nonexistent-<date>.csv  400
    12:56:47  insert or update on a service-role-only provenance table in the
              sibling repo violates its submission foreign key
    13:02:56  permission denied for three admin RPCs, at 97 and 98 ms spacing

The storage request is the one that carries the argument, because its key is
literally named `probe/nonexistent-<date>.csv` with today's date in it. That is
not a stale link, a bookmark or a mangled filename, all of which READ THIRD had
to weigh at length for the `meetings` bucket. It is a request deliberately
constructed to name an object that does not exist, in order to observe the
error. Nothing in either repo constructs it.

Once one member of the cluster is a deliberate negative test, the others read as
the same thing: assert the NOT NULL holds, assert the foreign key holds, assert
an authenticated non-admin is refused the admin RPC family. Each of those errors
is the database correctly refusing something. That is a better fit for the RPC
walk than READ TENTH could reach on its own, and READ TENTH's reading that it is
"very likely the system working correctly" survives and strengthens.

Be exact about what this does and does not settle. It explains the SHAPE of the
cluster. It does not identify who is running it, and the rollup carries message,
severity and timestamp only, with no client address, user or application name.
Nor does it retire the chartering defect above: that one has a real code path
behind it, and whether the 12:30:29 line came from that path or from a test
asserting the constraint is NOT established either way. The fix stands on the
code being wrong, not on the attribution.

Do not grant EXECUTE on the admin RPC family to clear the permission lines. The
prohibition in READ TENTH applies unchanged and this run adds a reason for it:
if these are assertions, granting the permission makes the assertion fail.

A NEW FATAL SHAPE, AND IT IS SCAN NOISE
`expected SASL response, got message type 88`, once, at 13:00:05 UTC. Decode 88
the way READ FIRST decodes the protocol numbers: it is ASCII `X`, the Postgres
Terminate message. So a client opened a connection, was asked for SASL
authentication, and sent Terminate instead of answering. That is a port scanner
confirming something listens and hanging up, and it belongs with the
`unsupported frontend protocol` and `no PostgreSQL user name` families READ
FOURTH enumerates as shapes 4 and 5, not with the password failures. A run that
greps only for those two shapes will now undercount the probe traffic by a third
family.

STILL COMMITTED AND UNDEPLOYED, ALL FOUR, UNCHANGED
`1cdb96e` (hourly uuid line, seen at 13:00 and 14:00), `e79339b` (the 32 line
sponsors burst, seen in the 12:05 cycle), `0d2963e` and `285a05f` (both in
`sentry-log-relay`). SUPABASE-PLATFORM-3's newest event is the 12:10:02 429 that
READ TENTH documents, and `285a05f` landed at 12:43:21, AFTER it, so that issue
has not fired since its fix was committed. Same occurrence, not a recurrence.

THE FLUTTER PROJECT: NOTHING NEW
FLUTTER-2 last fired 07:24:26 and its fix `2a90af9` landed 08:44:37, so it has
not fired since. FLUTTER-1's three events are the same 07:25:04 transport
occurrence, and they carry the same trace id as the FLUTTER-2 event 38 seconds
earlier, so one session produced both, exactly as READ NINTH records. FLUTTER-8
is the dead `messages.moydchat.org` host per `dd2a052`. Nothing to do for any of
the three, and none was re-resolved.

THE CENSUS
By event count per project, per READ FIFTH, not by an issue status filter:
`endorsement-scorer` 360, `supabase-platform` 100, `flutter` 5, and `website`,
`mautic`, `moydforms`, `n8n` and `supabase-edge` at zero. The 100 splits 94 plus
3 plus 3 across SUPABASE-PLATFORM-1, -4 and -3. The issue list was queried with
NO status filter per READ EIGHTH, which is how the two resolved `flutter` issues
stayed visible. `endorsement-scorer` is the expected n8n watchdog, correctly
ignored, and it stays ignored.

TWO CONTAINER NOTES
The branch ref trap did NOT bite this run, which is the first time in six. Both
repos started on a detached HEAD that was ALREADY at the true remote tip, so
`git ls-remote` against `git rev-parse` agreed. Keep running the check, per READ
SECOND; the point is that it now sometimes passes, not that it has been fixed.

`node_modules` was absent in the sibling repo, so `npx tsc --noEmit` first
returned a wall of `Cannot find module` and `Cannot find name 'process'`. That is
the signature of a missing install, not of a type regression. Run `npm ci`
first. After it, `tsc` is clean and `npm run build` fails exactly as the sibling
repo's own notes record, at "Collecting page data" with `supabaseUrl is
required` on an unrelated route.

`npx` cannot reach the registry from this container, so the differential type
check READ TENTH describes must use the repo's own
`node_modules/.bin/tsc` rather than `npx typescript`. It was needed again here,
because `tsconfig.json` EXCLUDES `supabase/functions`, so the required `tsc`
gate does not read the changed file at all. Head versus working tree gave
identical diagnostic sets, 6 and 6, all Deno environment noise.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is not. Weighed rather than inherited.

Named above: the `members` table and its `name` column, already named in this
repo by READ EIGHTH; the `form-uploads` bucket, already committed in this repo's
own `20260424_03_storage_rls.sql` audit snapshot; the edge function
`process-chartering-submission` and the helper `coalesceName`, which follows the
practice this file already applies to a dozen other function names.

Deliberately withheld, and this is a judgement rather than an oversight: the
NAME of the service-role-only provenance table behind the 12:56:47 foreign key
line, and its constraint name. That table is the anti forgery mechanism for
progressive form sessions, it lives only in the private repo, and unlike
`subscribers_email_unique` in READ SEVENTH it is not already committed here. The
finding survives without it, so it is not named. Also withheld per the practice
READ SIXTH set: the storage source address, the state of the live endorsement
vote, the identity of the executive in the FLUTTER events, and the operational
read on who is running the negative tests. Those go to Andrew directly.

No credential, no DSN, no source address, no policy body and no raw upstream
error appears, and nothing here widens access to anything.

## READ TWELFTH: the 16:20 UTC sweep, a quiet window, and a census that cross foots

Swept the 24 hours to 2026-08-04 16:20 UTC. No code change this run, and no
defect to change: every line in the genuinely new observation belongs to a family
the sections above already enumerate. This section is deliberately short. A
sweep that finds nothing should cost the next run a minute, not an hour.

Per the overlap warning in READ FOURTH: this window shares about 22 hours with
the sweep that closed at 14:21 UTC, so only about 1 hour 59 minutes of it is new
observation. Nothing below independently confirms anything above it.

SCOPE, AND THE FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 8 SUPABASE-PLATFORM-1 events after 14:21 UTC, FATAL
tagged ones included, per READ SEVENTH. Thirteen log lines, which reconciles
against the sum of the eight per event `count` fields:

    6  password authentication failed for user "?"   FATAL, filtered
    3  unsupported frontend protocol N.N             FATAL, values 16.0, 255.255, 0.0
    2  no PostgreSQL user name specified in startup packet   FATAL
    2  invalid input syntax for type uuid: "cron"    ERROR, 15:00:10 and 16:00:06

The password total is the usual `by_severity` residual and not a direct read,
per the standing caveat in READ FOURTH.

Eleven of the thirteen are scan noise, at a rate consistent with every prior
window rather than elevated. Split them the way READ ELEVENTH insists rather
than lumping them: five are the two malformed startup packet families READ
FOURTH enumerates as shapes 4 and 5, and six are the filtered password family,
whose attribution to that same scan traffic is INFERRED and not established, per
READ FIRST. The third probe family, the SASL Terminate line READ ELEVENTH added,
is absent from this window.

The two remaining lines are the hourly `1cdb96e` line. So the new slice carried
ZERO ERROR level lines other than that one known emitter.

In particular the ad hoc hand SQL family produced nothing at all: no missing
column, no missing relation, no permission denied, no syntax error. That is
worth noticing, because READ SEVENTH counted 14 of those lines in a 43 minute
stretch this morning and READ ELEVENTH decoded a five family cluster at 12:30 to
13:03. Record it as an observation and not as a resolution: silence settles
nothing, for exactly the conditionality reason READ FOURTH gives, and a family
that is somebody typing SQL by hand is expected to stop when they stop typing.

The 32 line sponsors dup key burst is absent from the new slice only because no
6 hour boundary falls inside 14:21 to 16:20. It has not stopped.

CENSUS BY BOTH AXES, CROSS FOOTED
READ FIFTH says to census by event count per project rather than by issue
status, and READ EIGHTH says to query issues with no status filter. Do both and
cross foot them. It costs one extra call:

    by project   endorsement-scorer 360, supabase-platform 103, flutter 5   = 468
    by issue     ENDORSEMENT-SCORER-4 360                                   = 360
                 SUPABASE-PLATFORM-1 99, -4 3, -3 1                         = 103
                 FLUTTER-1 3, FLUTTER-8 1, FLUTTER-2 1                      =   5
                                                                              468

`website`, `mautic`, `moydforms`, `n8n` and `supabase-edge` at zero.

Be precise about what the equality buys, because it is less than it looks. Both
sides are drawn from the same event store, so agreement is not independent
corroboration of either. What it catches is an issue missing from the issue
list, which is the specific failure READ FIFTH hit with an ignored issue and
READ EIGHTH hit with two resolved ones. Treat it as evidence and not as proof
even for that: compensating errors, one issue over counted while another is
absent, would still sum correctly, and READ FIFTH records that the rolling
window moves between two calls inside one run. And it says nothing at all about
a project that emitted zero events while still being broken.

NOTHING FIRED THAT IS NOT ALREADY HANDLED
- SUPABASE-PLATFORM-4's newest event is the 12:55:16 `form-uploads` probe that
  READ ELEVENTH documents. Same occurrence, not a recurrence. Do not resolve it.
- SUPABASE-PLATFORM-3's only event is the 12:10:02 429. `285a05f` landed at
  12:43:21, after it, so it has not fired since its fix was committed.
- FLUTTER-2 last fired 07:24:26 and `2a90af9` landed 08:44:37. FLUTTER-1's three
  events are the same 07:25:04 transport occurrence inside the protected
  endorsement surface. FLUTTER-8 is the dead `messages.moydchat.org` host per
  `dd2a052`. None was re-resolved.
- ENDORSEMENT-SCORER-4 is the expected n8n watchdog, correctly ignored, and it
  stays ignored.

FOUR FIXES COMMITTED AND UNDEPLOYED, AND ONE INHERITED NUMBER CORRECTED
`1cdb96e` at 9 days, `e79339b` at 8, `0d2963e` at 4, and `285a05f` at under 4
hours. All four are hand deploy work per READ FIRST.

READ SEVENTH, READ EIGHTH and READ NINTH each put `0d2963e` at nine days. That
is wrong, and it propagated by being copied rather than computed. READ SIXTH is
NOT one of them, and the distinction is worth keeping
straight in a note whose whole point is not copying: it says only that `0d2963e`
is "in the same state", meaning committed and undeployed, and it attaches no day
count to that commit at all.
`0d2963e` landed 2026-07-31 02:31:19 UTC, which READ FIRST states correctly, so
on 2026-08-04 it is four days old. Compute these from `git show -s --format=%cI`
rather than carrying the previous section's figure forward.

WHY THE HAND DEPLOY IS BLOCKED, WHICH IS NOT THE REASON THE FILE HAS BEEN GIVING
Checked this run rather than inherited, and the inherited half was wrong. There
is no `supabase` binary on the image, which is true and is where the checking
used to stop. But the npm registry IS reachable from this container: `npm ping`
answers PONG from `registry.npmjs.org` in about 120 ms, `npm view supabase
version` returns 2.111.0, and an actual `npm install supabase` into the
scratchpad completes in seconds and yields a working binary. READ ELEVENTH's
"npx cannot reach the registry" was a true observation of its own container, and
this run's first draft inherited it as though it were a property of the image.
It is not one. Test it rather than inherit it; network policy differs per run.

So the CLI is installable and the blocker is exactly one thing: no Supabase
access token. Nothing matching `SUPABASE` or `PROJECT_REF` exists in the
environment, and `supabase functions deploy` refuses before doing any work
without a token, so the deploy is blocked on that credential alone. The project
ref is NOT part of the gap, and it is worth saying so rather than padding the
ask: it is the subdomain of the project URL, which is already committed
throughout this repo and is also carried in the `server_name` tag on every
Sentry event read above.

That narrows the ask to a single item, and it is the one thing worth putting in
front of Andrew. If a `SUPABASE_ACCESS_TOKEN` is placed in the triage
environment, a future run can close this loop itself with a targeted
`npx supabase functions deploy <name> --project-ref <ref>`. Deploy the one
function named in the commit, never everything: the bulk deploy hazard in READ
FIRST is unchanged, and the endorsement vote functions must not be swept up in
it while ballots are open.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Nothing new is named: every table, bucket, function, issue
id and commit above already appears in this file. The probe source address is
not reproduced. Withheld per the practice READ SIXTH set: the state of the live
endorsement vote, and the operational read on who is running the ad hoc
statements and the storage probes. No credential, no DSN, no source address, no
policy body and no raw upstream error appears, and nothing here widens access to
anything.

## READ THIRTEENTH: the 18:20 UTC sweep, one new identifier, and the deploy blocker re-checked

Swept the 24 hours to 2026-08-04 18:20 UTC. No code change: nothing in the new
observation is attributable to committed code in either repo. Short by design,
per READ TWELFTH.

Per the overlap warning in READ FOURTH: this window shares about 22 hours with
the sweep that closed at 16:20 UTC, so only about 2 hours of it is new
observation. Nothing below independently confirms anything above it.

SCOPE AND FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 7 SUPABASE-PLATFORM-1 events after 16:20 UTC, FATAL
tagged ones included, per READ SEVENTH. Forty one log lines, which reconciles
against the sum of the seven per event `count` fields:

    32  duplicate key value violates unique constraint "?"   the 18:00 cycle
     6  password authentication failed for user "?"          FATAL, filtered
     2  invalid input syntax for type uuid: "?"              17:00 and 18:00
     1  column "is_public" does not exist                    18:12:26

The password total is the usual `by_severity` residual and not a direct read,
per the standing caveat in READ FOURTH. The two malformed startup packet
families and the SASL Terminate line are all absent from this window; the only
probe shape present is the password family, whose attribution to scan traffic is
INFERRED and not established, per READ FIRST.

THE ONE NEW IDENTIFIER, AND WHAT THE SHAPE ARGUMENT ACTUALLY BUYS
`is_public` is unlike the rest of the ad hoc family in one respect worth
recording: it is a REAL committed column, so the usual grep negative does not
apply. Enumerate every occurrence rather than the two that make the argument,
because the next run will grep this and should not have to wonder. It sits on
`campaign_templates` in the policy body in
`migrations_manual/20260721_rls_initplan_wrap.sql` and in that file's ROLLBACK
twin; the CRM's form templates service carries it in the INSERT and UPDATE
payloads it sends to `form_templates`; the matching Dart model reads it in
`fromJson` and writes it in `toJson`; and the sibling repo declares it on a form
template interface that has no query call site anywhere in that tree.

What the message shape rules out is the two applications' data layers, and that
is all it rules out. Both apps reach Postgres through PostgREST, and a PostgREST
filter or order renders the TABLE QUALIFIED form, which is exactly what READ
EIGHTH's `column members.first_name does not exist` line looked like. The
observed line is bare and quoted, and no read path in either repo filters or
orders on this column at all. The write payloads cannot reach Postgres with an
unknown key either, but not for the reason a first draft of this note gave: it
is not that Postgres would name the relation, it is that PostgREST rejects the
key against its schema cache as PGRST204 and emits NO Postgres log line at all.
The model methods parse returned rows and never reach SQL. The `flutter` project
also emitted nothing near 18:12, its newest event being 07:24:26, which is READ
EIGHTH's discriminator and points the same way.

Do NOT read that as "not ours", which is the overclaim an adversarial auditor
caught in the first draft of this section. Two channels produce the bare
unqualified form and neither is hand typing: a deployed only RPC or function
body carrying an unqualified `is_public` reference, which is precisely the
emitter READ FIRST and READ FOURTH say a repo search cannot see, and a policy,
view or trigger being created against a table lacking the column. This repo
carries a committed UNQUALIFIED reference of exactly that kind, in the
hand applied migration named above, so READ SIXTH's standard, that no committed
statement makes the QUALIFIED reference, does not clear this line the way it
cleared earlier ones.

So the honest position is READ SIXTH's: not either app's data layer, emitter
unattributed. Hand iteration remains the best fit given the company it keeps,
and it is an inference. Nothing was changed, and the standing instruction not to
change a working query to make one of these go away applies unchanged.

NOTHING ELSE FIRED THAT IS NOT ALREADY HANDLED
- SUPABASE-PLATFORM-4's three events are the 02:05, 06:45 and 13:00 rollups
  carrying the 02:03:37, 06:39:35 and 12:55:16 requests that READ FIFTH, READ
  EIGHTH and READ ELEVENTH document in full. Same occurrences, not recurrences.
  Do not count them again and do not resolve the issue.
- SUPABASE-PLATFORM-3's only event is the 12:10:02 429. `285a05f` landed at
  12:43:21, after it, so it has not fired since its fix was committed.
- FLUTTER-2's only event is 07:24:26 and `2a90af9` landed 08:44:37, so it has
  not fired since its fix. FLUTTER-1's three events are the same 07:25:04
  transport occurrence inside the protected endorsement surface. FLUTTER-8 is
  the dead `messages.moydchat.org` host per `dd2a052`. None was re-resolved.
- ENDORSEMENT-SCORER-4 is the expected n8n watchdog at 359 events, correctly
  ignored, and it stays ignored.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 102, flutter 5  = 466
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 98, -4 3, -3 1                        = 102
                 FLUTTER-1 3, FLUTTER-8 1, FLUTTER-2 1                     =   5
                                                                             466

`website`, `mautic`, `moydforms`, `n8n` and `supabase-edge` at zero. The issue
list was queried with NO status filter per READ EIGHTH, which is how the ignored
watchdog and the two resolved `flutter` issues stayed visible. Read READ
TWELFTH's caveat on what the equality does and does not buy before quoting it.

FOUR FIXES COMMITTED AND UNDEPLOYED
`1cdb96e` at 9 days, `e79339b` at 8, `0d2963e` at 4, and `285a05f` at under 6
hours. Computed from `git show -s --format=%cI` rather than carried forward. All
four are hand deploy work per READ FIRST.

THE DEPLOY BLOCKER IS UNCHANGED, AND WAS RE-CHECKED RATHER THAN INHERITED
READ TWELFTH says network policy differs per run and to test rather than
inherit, so: `npm ping` answers PONG from the registry in about 340 ms, which
means the CLI is still installable in this container. There is still no Supabase
access token. Nothing matching `SUPABASE`, `PROJECT_REF` or a Supabase key
prefix exists in the environment. The single item ask in READ TWELFTH stands
unchanged, and it is the whole reason four fixes are sitting undeployed.

Record the absence and stop there. An earlier draft went on to inventory what
credential the container DOES carry, which is a new fact about the pipeline that
serves nobody but someone probing it, and the finding does not need it.

THE BRANCH REF TRAP, SEVENTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `ce6d895`, and the
sibling's `main` at `77d879f` against a real `1f2bc35`. Repaired with
`git -C <path> checkout -B <branch> HEAD`, using `git -C` for every command per
READ NINTH.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Named above: the `form_templates` and `campaign_templates`
tables, the `is_public` column, and the migrations_manual path holding the
policy. All are already committed in this repo's own Dart sources and migration
files, so naming them adds no reach; the policy BODY is not reproduced, only the
file it lives in. The sibling repo's form template interface is described rather
than named, per the practice READ FOURTH set for private repo internals, and no
credential the container carries is inventoried, per the paragraph above. No
credential, no DSN, no source address and no raw upstream
error appears, and nothing here widens access to anything. Withheld per the
practice READ SIXTH set: the state of the live endorsement vote, and the
operational read on who is running the ad hoc statements.

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

## READ FOURTEENTH: the 20:20 UTC sweep, three issues that are one request, and a "dead" host that answered

Swept the 24 hours to 2026-08-04 20:20 UTC. One code change this run, `6ff6a45`,
in THIS repo, and unlike everything in READ FIRST it is deployed by CI: Netlify
builds the Flutter web app from `master`. Check the deployment rather than the
commit, per the usual rule.

Per the overlap warning in READ FOURTH: this window shares about 22 hours with
the sweep that closed at 18:20 UTC, so only about 2 hours is new observation.
Nothing below independently confirms anything above it. The `flutter` finding
lands entirely inside that new slice.

THE FINDING: THREE SENTRY ISSUES, ONE REQUEST, THREE EVENTS PER CHAT OPENED
`flutter` went from 5 events to 38. All of it is ONE executive session: every
event in FLUTTER-8, FLUTTER-B, FLUTTER-X, FLUTTER-5, FLUTTER-6 and FLUTTER-Y
carries trace id `b499754a7fca476b933272f434f2a8c3`. The newest events of the
first three land within 0.01s of each other at 19:34:33 UTC.

`MessagesViewState.initState` calls `getFocusState()` for every 1:1 iMessage chat
opened. That issues GET `/api/v1/handle/<address>/focus`, and the server answers
500 with a Private API body of "Selector not found!", meaning its helper cannot
read Focus status at all. One failed request files THREE Sentry events: the
sentry_dio `FailedRequestInterceptor` at interceptor index 0, `ApiInterceptor`'s
own `Logger.error` (the "Failed Request: [GET]" line that IS FLUTTER-8), and the
`.catchError` in `getFocusState` (which is FLUTTER-B). FLUTTER-X is the
DioException shape.

`6ff6a45` stops asking once the server has said it cannot answer, which is the
pattern `ece34e3` and `dd2a052` already set here. Residual volume after deploy is
precisely 3 events per session per tab load, from the first 1:1 open, down from 3
per conversation opened. None of the three issues was auto-closed and none should
be resolved.

CORRECTION TO READ EIGHTH, READ NINTH, READ TENTH, READ ELEVENTH AND READ TWELFTH
Every one of them calls FLUTTER-8 "the dead `messages.moydchat.org` host per
`dd2a052`". That is now STALE and it cost this run real time before the event
body was read. The host is not dead. It answered an HTTP 500 with a structured
JSON body at 19:34:33 today, and FLUTTER-8's current title names the focus
endpoint rather than the contacts endpoint `dd2a052` was about. `dd2a052` was
correct when written; FLUTTER-8 is a catch-all whose CONTENTS changed underneath
the note. Read the newest event's body before inheriting any group's diagnosis.

THE TRAP THAT NEARLY SHIPPED A NO-OP, AND IT GENERALISES
The first version of the fix tested `error is DioException`. That would have been
dead code, and the reasoning is worth keeping because it is not obvious from the
call site. `ApiInterceptor.onError` does
`if (err.response != null && err.response!.data is Map) return handler.resolve(err.response!)`.
A 500 whose body is a Map is therefore RESOLVED, so `dio.get` never throws;
`returnSuccessOrError` is what rejects, with a RAW dio `Response`. App code
downstream of this interceptor receives a `Response`, not a `DioException`, for
every error response carrying a Map body. The 502-Cloudflare branch in
`runApiGuarded` already assumed this and is the tell.

Production proved it independently: FLUTTER-B's title is the response body JSON,
which is what stringifying a `Response` with a Map body produces. When a Sentry
title looks like a data structure rather than a message, it is telling you the
runtime type of the thing that was logged.

Two more edges on the same interceptor. It mints 500s of its OWN: a timeout
forged as `type: timeout`, and a non-Map upstream body wrapped as `type: Error`.
So a bare `statusCode == 500` test would let one transient timeout disable a
working feature for a whole session. The shipped predicate positively requires
the server's own `type: Server Error`.

Two other Dart gotchas this run: `Response` is exported by BOTH `package:dio` and
`package:get`, so an unprefixed dio import is a hard `ambiguous_import` ERROR in
any file importing get; use `as dio`, as `oauth_panel.dart` already does. And
`flutter pub get` rewrites five generated plugin registrant files under `linux/`,
`macos/` and `windows/` on every run, per READ EIGHTH; discard them before every
commit, not just the first.

LEFT ALONE, DELIBERATELY
FLUTTER-6 and FLUTTER-Y are the same defect under two groups:
`RenderBox was not laid out` raised inside Flutter's own
`selectable_region.dart`, at
`MultiSelectableSelectionContainerDelegate._compareScreenOrder` sorting
selectables before layout. ZERO first-party frames in either stack; they differ
only in whether the microtask or the frame-callback path got there. One is
`crm.section=dashboard`, the other `conversations`, so it is not one screen. No
mechanism is establishable from this repo plus the event, so nothing was changed.
Do not guess at a SelectionArea to "fix".

FLUTTER-5 is `Failed to fetch` on `mail-identities-get`, mechanism
`SentryHttpClient`, no stacktrace, same session and same trace id. That is
browser-level transport, the class READ EIGHTH established for FLUTTER-1, and it
is captured independently of app handling. Not a defect.

SUPABASE-PLATFORM-1: FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 13 events after 18:20 UTC, FATAL tagged ones included,
per READ SEVENTH. Twenty log lines, reconciling against the sum of the thirteen
per event `count` fields:

     9  the ad hoc hand SQL family (ERROR)
     9  password authentication failed for user "?"   FATAL, filtered
     2  invalid input syntax for type uuid: "cron"    19:00 and 20:00

The password total is the usual `by_severity` residual, per the standing caveat
in READ FOURTH. The malformed startup packet families and the SASL Terminate line
are all absent; the password family is the only probe shape present this window.

The ad hoc family, which READ TWELFTH recorded as silent, is active again:

    20:09:21  syntax error at or near "union"
    20:06:25  column "updated_at" does not exist
    20:03:00  column "updated_at" does not exist
    19:34:13  missing FROM-clause entry for table "req"
    19:23:17  column "opens_at" does not exist
    19:18:14  column "election_year" does not exist
    19:18:14  column "is_public" does not exist
    19:13:50  "array_agg" is an aggregate function
    18:35:47  column "slug" does not exist

`missing FROM-clause entry for table "req"` is new in kind: it is what referencing
an alias absent from the FROM produces, which is a typing mistake rather than
anything a deployed statement does. `array_agg` and `slug` recur from READ
SEVENTH. Nothing was changed for any of them and nothing should be; the standing
instruction not to change a working query to make one of these go away applies.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 108, flutter 38 = 505
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 104, -4 3, -3 1                       = 108
                 FLUTTER-8 11, -B 10, -X 9, -1 3, -5 2, -Y 1, -6 1, -2 1   =  38
                                                                             505

`website`, `mautic`, `moydforms`, `n8n` and `supabase-edge` at zero. Queried with
NO status filter per READ EIGHTH, which is how the ignored watchdog and the three
resolved `flutter` issues stayed visible. Read READ TWELFTH's caveat on what the
equality does and does not buy.

FOUR FIXES STILL COMMITTED AND UNDEPLOYED
Computed from `git show -s --format=%cI`, not carried forward: `1cdb96e` at 9
days, `e79339b` at 8, `0d2963e` at 4, `285a05f` at under 8 hours. All four are
hand deploy work per READ FIRST, still blocked on a `SUPABASE_ACCESS_TOKEN` in the
triage environment, re-checked and still absent this run. The single item ask in
READ TWELFTH stands unchanged.

THE BRANCH REF TRAP HAS A SECOND HALF: THE REMOTE MOVES MID RUN
Both repos started with `HEAD` detached at the true remote tip and the named
branch stale, the shape READ THIRTEENTH describes, repaired with
`git -C <path> checkout -B <branch> HEAD`.

The new lesson is that checking once is not enough. `refs/heads/master` moved from
`286403e` to `74f6fc2` WHILE this run was working, and the only reason that was
caught is that `git ls-remote` was run again immediately before committing rather
than only at the start. Committing on the start-of-run tip would have produced a
non-fast-forward push and the temptation READ SECOND warns about. Re-run
`git ls-remote` immediately before you commit, every time, and rebase onto the
real tip. `286403e` was a plain ancestor of `74f6fc2`, so a stash, `checkout -B`
to FETCH_HEAD, and stash pop was sufficient, and `74f6fc2` touched only edge
functions, so the audit of this diff survived the move unchanged. Check that last
point rather than assume it: a base commit touching your file invalidates the
audit.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Named above: the focus endpoint path shape, the upstream
BlueBubbles server error text "Selector not found!", the host
`messages.moydchat.org`, and the file and symbol names in the diff. The host and
the endpoint are already published verbatim in this file by READ EIGHTH and by
`dd2a052`, and the error text is the open source BlueBubbles server's own
published string rather than anything about this deployment. The recipient phone
number that appears in the Sentry title is deliberately NOT reproduced. No
credential, no DSN, no probe source address, no policy body and no internal path
appears, and nothing here widens access to anything. Withheld per the practice
READ SIXTH set: the state of the live endorsement vote, the identity of the
executive whose session produced all six `flutter` issues, and the operational
read on who is running the ad hoc statements.

## READ FIFTEENTH: the 22:20 UTC sweep, a quiet slice, and a 404 shape recorded rather than fixed

Swept the 24 hours to 2026-08-04 22:20 UTC. No code change: nothing in the
genuinely new observation is a defect. Short by design, per READ TWELFTH.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 20:20 UTC, so only 2 hours is new observation. Nothing
below independently confirms anything above it.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 6 SUPABASE-PLATFORM-1 events after 20:20 UTC, FATAL
tagged ones included, per READ SEVENTH. Eight log lines, reconciling against the
sum of the six per event `count` fields:

    6  password authentication failed for user "?"   FATAL, filtered
    2  invalid input syntax for type uuid: "cron"    21:00:07 and 22:00:05

The password total is the usual `by_severity` residual and not a direct read,
per the standing caveat in READ FOURTH. The malformed startup packet families
and the SASL Terminate line are absent; the password family is the only probe
shape this slice. The ad hoc hand SQL family produced NOTHING, which settles
nothing, for the conditionality reason READ FOURTH gives. The 32 line sponsors
burst is absent only because no 6 hour boundary falls inside 20:20 to 22:20.

THE ONE THING THE PREVIOUS SWEEP MISSED, AND WHY IT IS STILL NOT FIXED
READ FOURTEENTH decomposes the focus endpoint failure as a 500 carrying
"Selector not found!". There is a SECOND shape in the same group that it does
not mention, inside its own window: at 19:17:58 UTC the server answered
`GET /api/v1/handle/57564/focus` with 404 and a body of `Handle not found!`,
filing a FLUTTER-8 event and a FLUTTER-B event.

The mechanism is established rather than guessed. `getFocusState` passes
`chat.participants.first.address` verbatim, and `57564` is a five digit SMS
shortcode rather than a phone address, so the server's own handle table has no
row for it and answers 404. No identifier is being constructed wrongly; the
lookup simply cannot succeed for that recipient.

`6ff6a45` does not cover it and should not: its flag arms only on a 500 whose
body carries `type: Server Error`, because that describes the SERVER and
justifies disabling the lookup session wide. A 404 describes ONE recipient, so
the same flag would be wrong and a per address negative cache would be the
correct shape.

Not built, deliberately. A search of the full 14 day retention returns exactly
two events, which is this ONE request, so the residual is one chat opened once
rather than a recurring cost. Adding session state keyed by address to absorb
two events in two weeks is speculative complexity. Recorded so the next run
recognises the shape instead of rediscovering it, and so that if it ever
becomes frequent the fix is already specified.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 108, flutter 38 = 505
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 104, -4 3, -3 1                       = 108
                 FLUTTER-8 11, -B 10, -X 9, -1 3, -5 2, -Y 1, -6 1, -2 1   =  38
                                                                             505

`website`, `mautic`, `moydforms`, `n8n` and `supabase-edge` at zero. Queried
with NO status filter per READ EIGHTH. Read READ TWELFTH's caveat on what the
equality does and does not buy: these totals are identical to the 20:20 sweep's,
and that is close to guaranteed by a 22 hour overlap rather than corroboration.

NOTHING FIRED THAT IS NOT ALREADY HANDLED
- The newest `flutter` event of any kind is 19:34:33, which is 76 minutes BEFORE
  `6ff6a45` landed at 20:50:30. So none of FLUTTER-8, -B or -X has fired since
  the fix. Do not read that as the fix being confirmed in production: no CRM
  session has opened a conversation in that window either, so the quiet is
  equally well explained by nobody using it. None was resolved.
- FLUTTER-Y and FLUTTER-6 are the `RenderBox was not laid out` pair with zero
  first party frames, left alone per READ FOURTEENTH. FLUTTER-1 and FLUTTER-5
  are browser transport. FLUTTER-2 last fired 07:24:26 and `2a90af9` landed
  08:44:37.
- SUPABASE-PLATFORM-3's only event is the 12:10:02 429; `285a05f` landed at
  12:43:21, after it. SUPABASE-PLATFORM-4's three events are the 02:03:37,
  06:39:35 and 12:55:16 requests READ FIFTH, READ EIGHTH and READ ELEVENTH
  document in full. Same occurrences, not recurrences. Do not resolve either.
- ENDORSEMENT-SCORER-4 is the expected n8n watchdog, correctly ignored.

FOUR FIXES COMMITTED AND UNDEPLOYED
Computed from `git show -s --format=%cI`, not carried forward: `1cdb96e` at 9
days, `e79339b` at 8, `0d2963e` at 4, `285a05f` at under 10 hours. All four are
hand deploy work per READ FIRST. Re-checked rather than inherited, per READ
TWELFTH: nothing matching `SUPABASE` or `PROJECT_REF` is in this container's
environment, so the single item ask stands unchanged. The hourly uuid line
firing at 21:00 and 22:00 today is `1cdb96e` still not deployed.

THE BRANCH REF TRAP, EIGHTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `6dcfca5`, and the
sibling's `main` at `77d879f` against a real `df8c8d9`. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH, and `git ls-remote`
re-run immediately before committing per READ FOURTEENTH.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Named above: the focus endpoint path shape, the host, and
the upstream BlueBubbles server strings, all already published verbatim in this
file by READ FOURTEENTH. The shortcode `57564` is a public commercial SMS sender
ID rather than anything identifying a person, and no recipient phone number is
reproduced. No credential, no DSN, no probe source address and no policy body
appears, and nothing here widens access to anything. Withheld per the practice
READ SIXTH set: the state of the live endorsement vote, the identity of the
executive in the `flutter` session, and the operational read on who is running
the ad hoc statements.

## READ SIXTEENTH: the 00:20 UTC sweep, and the prober starts labelling its own output

Swept the 24 hours to 2026-08-05 00:20 UTC. One code change this run, in the
SIBLING repo: `918d3ac`, described below. That one IS deployed by CI, since
Vercel builds the Next.js site from `main`; check the deployment, not the commit.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 22:20 UTC, so only 2 hours is new observation. Everything
genuinely new below lands inside that slice.

THE AD HOC SQL FAMILY IS NOT ANONYMOUS ANY MORE, AND IT NEVER WAS HAND ITERATION
Every section from READ SIXTH onward reads this family as somebody typing SQL by
hand, inferred from identifiers, aliases and burst timing, and each says plainly
that it is an inference. This window replaces the inference with the emitter's
own words. Four lines, all ERROR level, all inside 23:47 to 00:10:

    23:49:30  PROBE_RESULTS >>> A_FAILED 23503 :: insert or update on table
              "members" violates foreign key constraint "members_user_id_fkey"
              ||| B_INSERT_SUCCEEDED id=<uuid> ||| C_FAILED 23502 :: null value
              in column "name" of relation "members" violates not-null
              constraint ||| D_INSERT_SUCCEEDED
    23:54:35  CASE_PROBE >>> DUPLICATE_LOWERCASE_MEMBER_CREATED for a member
              whose stored email is mixed-case
    23:55:45  TIMING >>> no_social=ok (130ms) | with_instagram=ok (14ms)
    00:07:14  ROLLBACK_PROBE sqlstate=23503 msg=insert or update on table
              "members" violates foreign key constraint "members_user_id_fkey"

These are RAISE output, not statements that failed. Something with write access
is running a structured harness against member intake and reporting its findings
into the Postgres log. READ ELEVENTH decoded the 12:30 cluster as negative
testing from a `probe/nonexistent-<date>.csv` storage key; this is the same
practice, now self-labelled, and it retires the hand-typing reading rather than
confirming it.

Two of the lines report INSERTs that SUCCEEDED into `members`, so this harness
WRITES to the production member file. In the same window MAUTIC-H fired three
POSTs to the Mautic contacts endpoint for an `@example.com` probe address,
failing the leads email unique constraint, so it reaches production Mautic too.

Attribution is still not available and was not attempted. The rollup carries
message, severity and timestamp only, with no client address, user or
application name. The timing fits an audit of the member intake work that landed
in the sibling repo the same day, and that is a hypothesis for the next run
rather than a finding.

THE PROBE NAMED A REAL DEFECT IN OUR CODE, AND IT IS FIXED
`CASE_PROBE >>> DUPLICATE_LOWERCASE_MEMBER_CREATED` is not noise. The sibling
repo's live membership intake route lowercases the submitted address, then
looked the member up with a case-sensitive `.eq('email', ...)` and INSERTs on a
miss. Stored addresses are not all lowercase: the events RSVP route,
`process-chartering-submission`, `zapier-webhook` and `slack-initial-sync` each
write the submitted address verbatim. So a member stored mixed-case was
invisible to the lookup and got a second row. Production carries a plain
byte-comparison unique index on `members(email)`, applied outside version
control, which is why the duplicate INSERT succeeded rather than raising 23505.

Fixed in `918d3ac`: exact match first, since it is the only lookup that can use
that index, then a case-insensitive candidate query whose results are confirmed
in JS by lowercased equality, so over-matching can never merge two people.

THREE THINGS FROM THE AUDIT WORTH INHERITING
The first draft discarded the error on both lookups. On a duplicate-prevention
change that is self-defeating: any transient failure falls through to INSERT and
mints the exact duplicate. Check the error on a lookup whose whole purpose is to
decide between UPDATE and INSERT.

The pattern was unescaped. The underscore in an ordinary address like
`first_last@example.com` is a LIKE wildcard, so an unescaped ilike over-matches
and can push the genuine row outside the row limit, and a submitted `%` hands a
public unauthenticated endpoint a whole-table wildcard match. Escape `\ % _`.

PostgREST rewrites `*` to `%` on its own side, where no escaping in application
code can reach it. That is not a Postgres behaviour and it is easy to miss;
`postgrest-js` passes the value through untouched, so the aliasing is server
side. An address carrying one now skips the fallback entirely.

WHAT ELSE FIRED, ALL ALREADY ON THE RECORD
The 00:00 sponsors dup key cycle at 32 lines and the hourly uuid line at 00:00,
01:00 and 02:00 equivalents. `e79339b` and `1cdb96e` are committed and
undeployed at 8 and 9 days. `0d2963e` at 4 days and `285a05f` at under 12 hours,
same state. All four are hand deploy work per READ FIRST and all four are still
blocked on a `SUPABASE_ACCESS_TOKEN`, re-checked and still absent from this
container's environment, per READ TWELFTH's instruction to test rather than
inherit.

The rest of the ad hoc family this window: `column "is_active"`,
`column "mautic_contact_id"`, `column "district"`, `column "start_time"`,
`column "new_data"`, `column "submitted_at"`, `column "created_at"`,
`column fs.processed_at`, `relation "public.mo_zip_county"` and
`syntax error at or near ":="`. No committed statement in either repo makes
these references. Nothing changed for any of them.

Scan noise unchanged: the filtered password FATALs, `unsupported frontend
protocol 255.255` and `no PostgreSQL user name specified in startup packet`.

FLUTTER-8, -B and -X have not fired since `6ff6a45` landed at 20:50:30, the
newest event of any kind in that project being 19:34:33. Do not read that as the
fix confirmed: no CRM session has opened a conversation since either, so the
quiet is equally well explained by nobody using it. None was re-resolved.
SUPABASE-PLATFORM-3 and -4 carried no new occurrences. ENDORSEMENT-SCORER-4 is
the expected n8n watchdog at 359 events, correctly ignored.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 111, flutter 38,
                 mautic 3                                                  = 511
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 107, -4 3, -3 1                       = 111
                 FLUTTER-8 11, -B 10, -X 9, -1 3, -5 2, -Y 1, -6 1, -2 1   =  38
                 MAUTIC-H 3                                                =   3
                                                                             511

`website`, `moydforms`, `n8n` and `supabase-edge` at zero. `mautic` had been at
zero in every prior sweep, which is why the per project census is worth running
even when the issue list looks familiar. Queried with NO status filter per READ
EIGHTH. Read READ TWELFTH's caveat on what the equality does and does not buy.

THE BRANCH REF TRAP, NINTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `ad11c6a`, and the
sibling's `main` at `77d879f` against a real `df8c8d9`. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH, and `git ls-remote`
re-run immediately before committing per READ FOURTEENTH.

ONE CONTAINER NOTE
A subagent's transcript file size is NOT a progress signal. It sat at 110 bytes
through a run that completed and returned a full report, which nearly caused a
perfectly healthy auditor to be abandoned as unavailable and replaced. Wait for
the completion notification instead of inferring from the file.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Named above: the `members` table, its `name` and `email`
columns and the `members_user_id_fkey` constraint, all already committed here by
READ EIGHTH and READ ELEVENTH; the probe log lines, which name no person; and
the sibling repo's intake paths by role. Deliberately withheld: the member id
the probe reported inserting, the probe contact address, the state of the live
endorsement vote, and the operational read on who is running the harness. Those
went to Andrew directly. No credential, no DSN, no source address, no policy
body and no raw upstream error appears, and nothing here widens access to
anything.

## READ SEVENTEENTH: the 02:20 UTC sweep, and the prober is identified from its own commits

Swept the 24 hours to 2026-08-05 02:20 UTC. No code change: nothing in the
genuinely new observation is a defect, and the one thing that changed is an
attribution rather than a mechanism.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 00:20 UTC, so only 2 hours is new observation. Everything
below lands inside that slice.

THE AD HOC SQL FAMILY IS ANDREW'S OWN MEMBERSHIP AUDIT
Every section from READ SIXTH onward carries this family as unattributed, read
as hand iteration from identifiers, aliases and burst timing, and each says
plainly that it is an inference. READ SIXTEENTH got as far as the emitter
labelling its own output and offered "an audit of the member intake work" as a
hypothesis for the next run to TEST rather than inherit. That test has now been
run and the hypothesis holds.

The decisive evidence is the commits' own prose, which no earlier sweep thought
to read for this purpose. `1b7d10d` in the sibling repo says verbatim that its
migrations were "applied to production while auditing the membership signup
path", and `2490cd7` in this repo describes its defects as found the same way.
The emitter says who it is in git, not only in the log.

Three further strands corroborate, and they matter because each is a content
match rather than a coincidence of clock:

1. The 01:24 to 01:29 rollup carries a probe line reporting that a duplicate
   was refused by a case insensitive unique constraint on the member email.
   READ SIXTEENTH records the opposite state two hours earlier: a plain byte
   comparison index, which is exactly why the duplicate it observed SUCCEEDED.
   `1b7d10d` ships the migration that creates the case insensitive one, and
   that migration's own filename timestamp is 01:26:31, INSIDE the probe
   rollup window and seventeen minutes before the commit carrying it was
   published. State what that establishes and no more: the constraint was
   applied before it was tripped, and the probe was exercising a schema that
   did not exist in any published commit at the time. A filename timestamp is
   file creation time rather than proven apply time, and the rollup window
   fixes the trip only to within five minutes, so do not compute a gap from
   the two.
2. The probe's two INSERT_SUCCEEDED lines both report linking to an existing
   auth account, which is the exact mechanism `1b7d10d` describes rescuing,
   and `column "state_house_district" does not exist` at 01:13:22 sits inside
   the district work `2490cd7` landed at 01:35:13.
3. READ SIXTEENTH's `A_FAILED 23503` and `C_FAILED 23502` probes, both real
   failures at the time, are the two defects `1b7d10d` and `1f2bc35` fix. The
   probes in THIS window report those same paths passing.

Be exact about what each strand does and does not carry, because the first
draft of this section overstated it and an auditor caught it. The constraint
name ALONE identifies nobody: Postgres reports it in the 23505 error to any
client that trips it, so it establishes only that the migration was live before
01:29. It is the conjunction that attributes the session, and the schema state
is a timing fact rather than a replacement for one. What makes the conjunction
strong is that the self labelled harness, the freshly applied schema, the
probed defects and the commit prose all point one way.

Scope it correctly rather than over reading it: this attributes THIS session
and the READ SIXTEENTH session. It does not retroactively attribute every
`column ... does not exist` line since READ SIXTH, and a future run should not
treat the family as pre cleared. What it retires is the standing worry about an
unattributed party holding write access to the member file. It does not retire
the standing method.

ANDREW IS DEPLOYING EDGE FUNCTIONS BY HAND AGAIN, WHICH CHANGES THE ASK
`2490cd7` states in its own message that `member-onboard`, `onboarding-followups`
and `lookup-districts` were deployed and re exercised. READ FIRST's hazard is
unchanged and so is the bulk deploy prohibition, but the practical consequence
is that the blocker recorded in READ TWELFTH and READ THIRTEENTH is no longer
the only route. The triage container still has no `SUPABASE_ACCESS_TOKEN`, re
checked this run, so THIS agent still cannot deploy. The missing binary is NOT
part of the blocker and a draft of this section wrongly listed it as one:
READ TWELFTH settled that, and it was re tested rather than inherited, `npm
ping` answering PONG in 173 ms, so the CLI remains installable in seconds. The
blocker is exactly one thing and it is the token. Andrew evidently can deploy
and is. The ask is therefore no longer only for a token; it
is that three fixes are still sitting undeployed while he is already in there
deploying neighbours of them.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 10 SUPABASE-PLATFORM-1 events after 00:20 UTC, FATAL
tagged ones included, per READ SEVENTH. Nineteen log lines, reconciling against
the sum of the ten per event `count` fields:

     9  the ad hoc family, now attributed as above (ERROR)
     6  password authentication failed for user "?"   FATAL, filtered
     2  invalid input syntax for type uuid: "?"       01:00:08 and 02:00:05
     1  canceling statement due to statement timeout  00:21:51
     1  a probe harness status line reporting a pass

The password total is the usual `by_severity` residual and not a direct read,
per the standing caveat in READ FOURTH. The malformed startup packet families
and the SASL Terminate line are absent; the password family is the only probe
shape this slice.

The nine ad hoc lines: `column s.fields`, `column s.form_data`,
`column "state_house_district"`, `column "submitted_at"`, `column "ordinality"`,
`"array_agg" is an aggregate function`, `column "name"`,
`column m.mautic_contact_id` and `column "phone_e164"`. Two of those name real
committed columns, `phone_e164` on the CRM member model and `name` on `members`,
so the grep negative does not clear them and READ THIRTEENTH's caveat applies;
what places them in this family is the bare unqualified form, which PostgREST
does not emit, plus the attribution above. Nothing was changed for any of them
and nothing should be.

`canceling statement due to statement timeout` recurs from READ TENTH. The
rollup carries no statement text, so it is not attributable from Sentry, and one
line is not a basis for action. Recorded, not acted on.

BOTH LONG STANDING UNDEPLOYED FIXES CONFIRMED STILL UNDEPLOYED, DIRECTLY
Not inferred from silence. The 00:00 UTC cycle carried exactly 32
`legislation_bill_sponsors_unique` lines, unchanged size, so `e79339b` is not
deployed. The hourly uuid line fired at 01:00:08 and 02:00:05, so `1cdb96e` is
not deployed.

Day counts as of the 02:20 UTC window close, FLOORED, which is the convention
READ TWELFTH established and which the first draft of this section got wrong in
three places by rounding up: `1cdb96e` at 9 days, `e79339b` at 8, `0d2963e` at
4, `285a05f` at under 14 hours. Compute these with `git show -s --format=%cI`
and floor them. Do not carry a previous section's figure forward, and do not
round: an age that reads 9 in one sweep and 10 in a sweep two hours later, with
no new commit in between, is arithmetic drift rather than elapsed time.

NOTHING ELSE FIRED THAT IS NOT ALREADY HANDLED
- The newest `flutter` event of any kind is 19:34:33 on 08-04, which is 76
  minutes BEFORE `6ff6a45` landed at 20:50:30. So FLUTTER-8, -B and -X have not
  fired since the fix. Do not read that as the fix confirmed in production: no
  CRM session has opened a conversation since either, so the quiet is equally
  well explained by nobody using it. None was re-resolved.
- FLUTTER-Y and FLUTTER-6 are the `RenderBox was not laid out` pair with zero
  first party frames, left alone per READ FOURTEENTH. FLUTTER-1 and FLUTTER-5
  are browser transport. FLUTTER-2's fix `2a90af9` landed 08-04 08:44:37.
- SUPABASE-PLATFORM-3's only event is the 12:10:02 429; `285a05f` landed at
  12:43:21, after it. SUPABASE-PLATFORM-4's two in window events are the 06:39:35
  keyless bucket root GET that READ EIGHTH documents and the 12:55:16
  `form-uploads` probe that READ ELEVENTH documents. The 02:03:37 request READ
  FIFTH covers has now aged out of the 24 hour window; do not cite READ FIFTH
  for this window's pair. Do not resolve either issue.
- MAUTIC-H is three probe harness POSTs at 00:05:35 and 00:05:47 using
  `@example.com` addresses, the same occurrences READ SIXTEENTH recorded, not
  recurrences. Mautic's own duplicate handling refusing a deliberately duplicated
  probe contact is the system working. No droplet access and nothing to fix.
- ENDORSEMENT-SCORER-4 is the expected n8n watchdog, correctly ignored.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 113, flutter 38,
                 mautic 3                                                  = 513
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 110, -4 2, -3 1                       = 113
                 FLUTTER-8 11, -B 10, -X 9, -1 3, -5 2, -Y 1, -6 1, -2 1   =  38
                 MAUTIC-H 3                                                =   3
                                                                             513

`website`, `moydforms`, `n8n` and `supabase-edge` at zero. `website` being at
zero is worth one line rather than none, because Andrew landed three commits in
the sibling repo inside the two hour slice and none produced an error event.
Queried with NO status filter per READ EIGHTH. Read READ TWELFTH's caveat on
what the equality does and does not buy.

THE BRANCH REF TRAP, TENTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `2490cd7`, and the
sibling's `main` at `77d879f` against a real `1b7d10d`. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH, and `git ls-remote`
re-run immediately before committing per READ FOURTEENTH.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. This window is the first where
the log lines themselves carry personal data, so this check did real work rather
than confirming a habit, and it caught two things in the first draft.

First, the probe output includes a member email address at a named university, a
second member email at a consumer domain, and the `member_id` and `user_id`
UUIDs of a real person. NONE is reproduced above, and the probe lines are
described by what they report rather than quoted. That is a change from the
practice of quoting log lines verbatim, and it is deliberate: the emitter
started putting member identifiers in its own messages, so verbatim quoting
stopped being safe. A future run reading these rollups should assume the same
and check before pasting.

Second, and this is the one worth inheriting as a method rather than a fact: the
first draft named the new unique constraint outright and justified it as
"already committed in the sibling repo". That justification is INVERTED. The
sibling is private, so "already in the sibling repo" is an argument for
withholding, not for publishing. The constraint name exists nowhere public, and
READ ELEVENTH set the precedent of withholding a private repo constraint name in
exactly this situation because the finding survives without it. It survives here
too, which is why the strand above describes the constraint rather than naming
it. Before citing prior publication as cover, check WHICH repo published it.

Named above and checked one at a time rather than waved through: the edge
functions `member-onboard`, `onboarding-followups` and `lookup-districts`, which
are already public in THIS repo's own tree and named in `2490cd7`'s message;
the `members` table and its `email`, `name` and `phone_e164` columns, already
named here by READ EIGHTH and READ ELEVENTH; and `legislation_bill_sponsors_unique`,
already published here since READ FIRST. No credential, no DSN, no probe source
address, no policy body, no migration filename and no raw upstream error
appears, and nothing here widens access to anything. Withheld per the practice
READ SIXTH set: the state of the live endorsement vote, and anything amounting
to an operational read on production sessions. Those go to Andrew directly.

## READ EIGHTEENTH: the 04:20 UTC sweep, nothing new, and one day count that really did advance

Swept the 24 hours to 2026-08-05 04:20 UTC. No code change: every line in the
genuinely new observation belongs to a family the sections above enumerate, and
outside SUPABASE-PLATFORM-1 and the ignored watchdog, no Sentry event fired in
the new slice at all. Short by design, per READ TWELFTH.

Be exact about that carve out rather than writing "nothing else fired", which an
auditor caught in the first draft of this section. ENDORSEMENT-SCORER-4 reads 359
here and read 359 in the two sweeps before it, and a FLAT rolling 24 hour count
of a periodic emitter means events kept landing as old ones aged out, not that it
stopped. On its own numbers roughly 30 watchdog events fired inside these two
hours. It is correctly ignored, so it is excluded on purpose, not absent.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 02:20 UTC, so only 2 hours is new observation. Nothing
below independently confirms anything above it.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 5 SUPABASE-PLATFORM-1 events after 02:20 UTC, the
FATAL tagged one included, per READ SEVENTH. Eight log lines, reconciling
against the sum of the five per event `count` fields:

    03:00:07  invalid input syntax for type uuid: "cron"        ERROR
    03:16:25  unsupported frontend protocol 0.0                 FATAL
    03:16:27  unsupported frontend protocol 255.255             FATAL
    03:16:28  no PostgreSQL user name specified in startup packet  FATAL
    03:16:38  column "is_active" does not exist                 ERROR
    03:44:50  column s.fields does not exist                    ERROR
    04:00:04  invalid input syntax for type uuid: "cron"        ERROR
    04:07:14  column "current_page" does not exist              ERROR

Two things about that list are worth one line each and no more.

The password authentication FATAL family is ABSENT from this slice, which is the
first ABSENCE any sweep has observed. Word it that way rather than as the first
slice without them: READ SIXTH read `by_message` on 4 of 75 events and says
outright it could not see inside FATAL tagged rollups, so its slice is silent on
this rather than evidence of presence. The three malformed startup packet
lines are present and sit inside 13 seconds of each other, which is the probe
family READ FOURTH enumerates as shapes 4 and 5 behaving exactly as usual. Do
not read the missing password lines as anything: two hours is far too short a
sample against a family that averages roughly six lines per two hour slice, and
READ FOURTH's caveat that shape 1 is a `by_severity` residual rather than a
direct read applies to its absence as much as to its presence.

All three ad hoc family identifiers are already on the record: `is_active` in
READ SIXTEENTH, `s.fields` in READ EIGHTH and READ SEVENTEENTH, `current_page`
in READ SEVENTH. READ SEVENTEENTH attributes this family to Andrew's own
membership audit from the commit prose, and nothing in this slice bears on that
either way. Nothing was changed for any of them.

The 32 line sponsors dup key burst is absent only because no 6 hour boundary
falls inside 02:20 to 04:20.

BOTH LONG STANDING UNDEPLOYED FIXES CONFIRMED STILL UNDEPLOYED, DIRECTLY
The hourly uuid line fired at 03:00:07 and 04:00:04, so `1cdb96e` is not
deployed. `e79339b` is not directly observable in this slice for the boundary
reason above, and READ SEVENTEENTH confirmed it directly at the 00:00 cycle.

Day counts as of the window close, computed with `git show -s --format=%cI` and
FLOORED, per READ TWELFTH: `1cdb96e` at 9 days, `e79339b` at 8, `0d2963e` at 5,
`285a05f` at under 16 hours.

`0d2963e` reads 5 here and 4 in READ SEVENTEENTH two hours ago. That one is
real elapsed time rather than the arithmetic drift READ SEVENTEENTH warns about:
it landed 2026-07-31T02:31:19 UTC, so it crossed its fifth day boundary at
02:31 today, between the two sweeps. Recompute rather than assume either way.

The deploy blocker is unchanged and was re-checked rather than inherited, per
READ TWELFTH: nothing matching `SUPABASE`, `PROJECT_REF` or a Supabase key
prefix is in this container's environment. The single item ask stands.

NOTHING ELSE FIRED, THE WATCHDOG ASIDE
The newest `flutter` event of any kind is still 2026-08-04 19:34:33, which is
76 minutes BEFORE `6ff6a45` landed at 20:50:30, so FLUTTER-8, -B and -X have
not fired since that fix. Do not read that as the fix confirmed in production:
no CRM session has opened a conversation in the 8 hours 45 minutes since either,
so the quiet is equally well explained by nobody using it. None was re-resolved,
and three of the `flutter` issues carry a resolved status somebody else set.
SUPABASE-PLATFORM-3's only event is the 12:10:02 429, which `285a05f` postdates.
SUPABASE-PLATFORM-4's two are the 06:39:35 and 12:55:16 requests READ EIGHTH and
READ ELEVENTH document; the 02:03:37 request has now aged out. MAUTIC-H's three
are the probe POSTs READ SIXTEENTH records, timestamped 00:05:35 and 00:05:47 in
READ SEVENTEENTH rather than in READ SIXTEENTH, which carries no times. Same
occurrences throughout, not recurrences. Nothing was resolved.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 110, flutter 38,
                 mautic 3                                                  = 510
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 107, -4 2, -3 1                       = 110
                 FLUTTER-8 11, -B 10, -X 9, -1 3, -5 2, -Y 1, -6 1, -2 1   =  38
                 MAUTIC-H 3                                                =   3
                                                                             510

`website`, `moydforms`, `n8n` and `supabase-edge` at zero. Queried with NO
status filter per READ EIGHTH, which is how the ignored watchdog and the three
resolved `flutter` issues stayed visible. Read READ TWELFTH's caveat on what the
equality does and does not buy.

THE BRANCH REF TRAP, ELEVENTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `57e96a0`, and the
sibling's `main` at `77d879f` against a real `1b7d10d`. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH, and `git ls-remote`
re-run immediately before committing per READ FOURTEENTH.

That same PAIR of stale values appears in READ SEVENTH, NINTH, TENTH,
THIRTEENTH, FIFTEENTH, SIXTEENTH and SEVENTEENTH. That enumeration is the claim;
do not upgrade it to a universal, and if you extend it, grep both hashes and map
the hits to section boundaries rather than trusting this list.

Two drafts of this paragraph were falsified by auditors, in the same way twice,
which is why it is worded so flatly. The first wrote "a fixed property of the
image rather than drift" and "every sweep since READ THIRTEENTH has reported",
and both are false: READ FOURTEENTH reports the trap while naming NEITHER STALE
VALUE, READ SECOND records a DIFFERENT pair on 2026-08-01, `f17be39` here and
`d2c3cd7` in the sibling, so the stale value has already changed once, and READ
ELEVENTH records a container where the trap did not bite. The second draft fixed
the wording and then omitted READ SEVENTH from its own list while calling that
list exhaustive, which is the denominator error READ FOURTH warns about, made
inside the correction to a denominator error. The third draft said READ
FOURTEENTH names "no values at all", which is wrong in the other direction: that
section names `286403e` and `74f6fc2`, the remote tip before and after it moved
mid run. Only the stale half is missing there, and only the stale half is what
this list is about. READ SECOND says the mechanism is NOT established. A run of
correlations does not overturn that. Keep running the check.

One more trap if you run the grep this paragraph asks for. READ SECOND carries
BOTH hashes, in mixed roles rather than as a stale pair: `5d8a5b0` as a stale
`origin/master` in its 2026-08-03 addendum, which predates READ SEVENTH, and
`77d879f` as a REAL `refs/heads/main` tip on 2026-08-01. That is why it is not in
the list of seven, and it is the hit most likely to make a future run think the
list is wrong.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Enumerated rather than waved at, which is the whole point of
this paragraph: named above are the three bare column identifiers `is_active`,
`s.fields` and `current_page`, all already on this record per the citations in
the decomposition; the commits `1cdb96e`, `e79339b`, `0d2963e`, `285a05f` and
`6ff6a45`; the issue ids and project names; the two stale git refs `5d8a5b0` and
`77d879f`; the two real remote tips `57e96a0` and `1b7d10d`; the four further
hashes `f17be39`, `d2c3cd7`, `286403e` and `74f6fc2` cited from READ SECOND and
READ FOURTEENTH; and the environment variable name patterns `SUPABASE` and
`PROJECT_REF`. All but one already appear elsewhere in this file. The exception
is `57e96a0`, which is this PUBLIC repo's own current tip and is therefore
already readable by anyone who can read this sentence.

Two successive auditors found this enumeration incomplete, each time in the
paragraph written to fix the previous incompleteness, and the second time in the
paragraph whose whole stated point was enumerating. That is the lesson worth
inheriting rather than the list: an enumeration that claims to be exhaustive is a
claim to CHECK, so re-read the section you just wrote and list every identifier
in it, rather than listing the ones you remember putting there.

Scope that enumeration deliberately, because a fourth auditor asked for the call
to be made explicitly rather than by omission. It covers IDENTIFIERS: hashes,
column and table names, env var names, file paths, issue ids, project names. It
does NOT cover quoted log CONTENT, which here means the uuid literal `"cron"`,
the protocol values `0.0` and `255.255`, and the Sentry rollup field names
`by_message`, `by_severity` and `count`. Those are the error text itself, every
one of them is published verbatim throughout this file from READ FIRST onward,
and no prior sweep has enumerated them either. If a future slice ever carries log
content that is NOT already public, that content is the thing to weigh, and this
carve out does not cover it.

No credential, no DSN, no probe source address, no policy body and no raw
upstream error appears, and nothing here widens access to anything.

Deliberately NOT written down, and this one was caught by an auditor as a BLOCKER
rather than by the author: anything describing the triage container's own
reporting or credential tooling. READ THIRTEENTH already ruled on exactly this
class, that an inventory of what the container carries "serves nobody but someone
probing it", and the first draft of this section published a fresh one anyway
while its disclosure paragraph asserted nothing new was named. Operational notes
about how this agent reaches Andrew go to Andrew. Also withheld per the practice
READ SIXTH set: the state of the live endorsement vote, and any operational read
on production sessions.

## READ NINETEENTH: the 06:22 UTC sweep, a slice with no probe traffic at all, and two checks that came back clean

Swept the 24 hours to 2026-08-05 06:22 UTC. No code change: every line in the
genuinely new observation belongs to a family the sections above enumerate, and
outside SUPABASE-PLATFORM-1 and the ignored watchdog, no Sentry event fired in
the new slice at all. Short by design, per READ TWELFTH.

Carve that out the way READ EIGHTEENTH insists rather than writing "nothing else
fired". ENDORSEMENT-SCORER-4 reads 359 here and read 359 in the three sweeps
before it, and a FLAT rolling 24 hour count of a periodic emitter means events
kept landing as old ones aged out, not that it stopped. It is correctly ignored,
so it is excluded on purpose, not absent.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 04:20 UTC, so only 2 hours is new observation. Nothing
below independently confirms anything above it.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 8 SUPABASE-PLATFORM-1 events after 04:20 UTC, per READ
SEVENTH. Forty four log lines, reconciling against the sum of the eight per
event `count` fields:

    04:26:59  column d.form_id does not exist                      ERROR
    04:35:29  column "form_id" does not exist                      ERROR
    04:49:36  column "updated_at" does not exist                   ERROR
    04:50:33  column "phone_e164" does not exist                   ERROR
    05:00:04  invalid input syntax for type uuid: "cron"           ERROR
    05:50:53  column "created_at" does not exist                   ERROR
    06:01:06  duplicate key value violates unique constraint  x32  ERROR
    (no ts)   invalid input syntax for type uuid: "cron"           ERROR
    06:02:52  column "state_house_district" does not exist         ERROR
    06:03:03  column "created_at" does not exist                   ERROR
    06:03:12  aggregate functions are not allowed in GROUP BY      ERROR
    06:07:04  column "name" does not exist                         ERROR
    06:13:06  column l.committee_name does not exist               ERROR

Thirteen rows, forty four lines: the dup key row carries 32 of them and every
other row carries one. The second cron row has NO observed timestamp, per READ
SIXTH's precedent for this: it is a `by_message` key in the 06:05 rollup that
did not make that rollup's five entry `sample`, so all that is established is
that it fell inside the rollup's window. Be exact about why, because a draft of
this paragraph said the burst had filled the sample and that is checkably false:
three of those five slots carry the non-burst lines timestamped 06:02:52,
06:03:03 and 06:03:12 in the table above, so at most two went to the burst. The
cron line simply missed the sample. Do not infer where in the window it landed,
and do not read its position in the table as an ordering.

EVERY EVENT IN THIS SLICE IS ERROR LEVEL, WHICH IS NEW AND MEANS LITTLE
Not one of the eight is tagged `includes FATAL`, so the filtered password family
is absent, and so are the two malformed startup packet families READ FOURTH
enumerates as shapes 4 and 5 AND the SASL Terminate line READ ELEVENTH adds.
Keep those three counted the way this file counts them: two malformed startup
packet families plus a third shape whose packet was valid and whose client hung
up at authentication, not three startup packet families. READ EIGHTEENTH
observed the first ABSENCE of the password lines any sweep has recorded, and
insists on that wording rather than "the first slice without them", because a
partially read slice cannot support a slice level universal. Keep it. This is
the second such absence running, and it is also the first sweep to record no
probe shape of any kind in a slice it read in full.

Do not read that as the scanning having stopped. Two hours is far too short a
sample against a family that averages roughly six lines per two hour slice, and
READ FOURTH's caveat that shape 1 is a `by_severity` residual rather than a
direct read applies to its absence exactly as it does to its presence. Recorded
so a future run notices if it becomes a trend, not as a finding.

THE AD HOC FAMILY IS ACTIVE, AND TWO IDENTIFIERS WERE CHECKED RATHER THAN WAVED
THROUGH
Count this in ROWS and say so, because counting the dup key burst as one line is
the "six lines, five shapes" error READ SIXTH had to correct after the fact. Of
the eleven non-cron rows, TEN are the family READ SEVENTEENTH attributes to
Andrew's own membership audit from the commit prose; the eleventh is the 32 line
dup key burst, which is the undeployed `e79339b`. As lines rather than rows the
family is ten of forty two, because the burst alone is 32.

Inherit that attribution at its stated scope and no wider. READ SEVENTEENTH
attributes ITS session and the READ SIXTEENTH session, and says plainly that a
future run must not treat the family as pre cleared.

This slice DOES bear on it, and an auditor had to point that out after a draft
of this paragraph asserted the opposite. The instrument READ NINTH describes,
dating the CALLING code rather than grepping the tree, is available here because
four sibling commits carry commit dates inside these two hours, at 04:39:36,
04:46:34, 05:04:56 and 05:10:26 UTC. All four are membership and roster work.
Their subject lines are deliberately not reproduced: the timing is what carries
the argument, the sibling is private, and paraphrasing them cost two audit
rounds over how exactly the paraphrases matched.

Some of the ad hoc rows interleave with them. `d.form_id` at 04:26:59 and `form_id` at
04:35:29 both PRECEDE the first commit, by roughly thirteen and four minutes;
they do not straddle it, and a draft of this paragraph said they sat either side
of it, which is false against the times printed three lines above. `updated_at`
at 04:49:36 and `phone_e164` at 04:50:33 land three and four minutes after the
second commit, and 05:00:04 falls between the second and the third. Nothing else
does: the last of the four commits is 05:10:26, so the 05:50:53 row and
everything from 06:02 onward is AFTER all of them, by forty minutes and more. A
draft claimed 05:50:53 fell between commits and it does not.

A COLUMN OVERLAP ARGUMENT WAS TRIED HERE AND IS DELIBERATELY ABANDONED
Three successive drafts claimed the failing column names are the columns that
membership work touches, each stating it more carefully than the last, and an
auditor falsified all four at successively finer granularity. Recorded once,
precisely, so nobody tries a fifth time:

    phone_e164              in changed lines
    name                    in changed lines, and matches trivially
    updated_at              unchanged context only
    formId                  hunk headers only; snake case form_id appears nowhere
    created_at              absent, despite carrying two of the ten family rows
    state_house_district    absent
    committee_name          absent

An overlap that includes `name`, a word this common, and excludes three names
carrying four of the ten rows, discriminates nothing. So this section does not
rely on it and a future run should not resurrect it.

The lesson is worth more than the strand was. A plausible looking overlap
between error identifiers and a diff is easy to assert and tedious to verify,
and every attempt here was wrong in a different way: wrong about which names,
then about changed lines versus context, then about casing. If you raise one,
grep the changed lines specifically, check the casing, and check whether the
matches are common words. Otherwise do not raise it.

Rate the TIMING, which is the strand that survived and not the abandoned overlap
above, as corroboration and not as proof, for the reason READ SECOND gives:
git records no push time, so a commit date establishes when the code EXISTED and
not when anything ran. Interleaving is consistent with the READ SEVENTEENTH
reading and is the same kind of timing strand that section used. It does not
newly attribute anything, and the family still must not be treated as pre
cleared.

`form_id`, `phone_e164` and `state_house_district` are membership and roster
shaped names, which is a topical observation and nothing stronger. Do not
upgrade it into a claim about the four sibling commits dated in the attribution
paragraph above; that was tried four times and never survived checking.

`aggregate functions are not allowed in GROUP BY` is a message shape no earlier
section records, but it is NOT a new family: it belongs with the `array_agg` and
`syntax error at or near "minute"` shapes READ SEVENTH already lists. New
identifier, same family. It is raised when an aggregate is written into the
GROUP BY list itself, which is a SQL authoring mistake rather than anything a
deployed statement does, which is the same reason those two belong here.

State the cover for the OTHER eight rows correctly before the two below, because
an earlier draft implied a grep negative cleared them and that instrument does
not apply to most of them. `form_id`, `phone_e164`, `name`, `created_at` and
`updated_at` are all real committed columns somewhere in one tree or the other.
READ SIXTH says so of `form_id` and READ SEVENTEENTH of `phone_e164` and `name`.
`created_at` and `updated_at` are common in both trees, and while several
earlier sections record them as failing log lines, no earlier section makes the
real-column claim for them, so that pair is asserted here rather than cited.

Those rows are covered by READ THIRTEENTH's discriminator instead: the BARE
unqualified form, which PostgREST does not emit, since a filter or order from
either app's data layer renders the table qualified name. Two of the eight are
NOT bare and need the other instrument, which an auditor caught after a draft
swept all eight under the same one. `d.form_id` is qualified, so it takes READ
SIXTH's standard, and that standard is satisfied: the string appears nowhere in
either repo outside this file. The GROUP BY row carries no column identifier at
all for either instrument to act on, and its family membership rests on the
authoring mistake argument above.

Neither instrument is as strong as a grep negative on a name that exists
nowhere, and the company these rows keep is doing real work in the reading.

Two lines named identifiers real enough that even that reading needed checking,
so both were checked:

- `l.committee_name`. `committee_name` IS a real committed column on
  `mec_committees`, so the bare grep negative does not apply. What clears it is
  the QUALIFIED form: the string `l.committee_name` appears nowhere in either
  repo outside this file, so no committed statement makes that reference. That
  is READ SIXTH's standard and it is the whole argument.

  Do NOT reach for an alias argument here. Two successive drafts did, each
  naming the set of aliases committed code uses for this table, and an auditor
  falsified BOTH against the migrations: the first was wrong outright, and the
  second was incomplete even after the correction. No alias set is restated
  here, deliberately, because any such list is a trap: a next run inheriting it
  would clear a line carrying an alias the list omits, or read a real one as
  ours. The qualified reference being absent is the whole argument and it needs
  no letters at all.
- `state_house_district`. Its only occurrence in either repo's application code
  is a `case` label in a switch that returns null, explicitly commented as not
  stored in the member model. A switch case is not a query and cannot raise
  this. The remaining hits are this file, one plan document and one progress
  tracker, none of them a query.

Nothing was changed for any of the ten, and nothing should be. The standing
instruction not to change a working query to make one of these go away applies
unchanged.

BOTH LONG STANDING UNDEPLOYED FIXES CONFIRMED STILL UNDEPLOYED, DIRECTLY
Not inferred from silence. The 06:00 UTC cycle carried exactly 32
`legislation_bill_sponsors_unique` lines, unchanged size, so `e79339b` is not
deployed. The hourly uuid line fired at 05:00:04 and inside the 06:05 rollup, so
`1cdb96e` is not deployed.

Day counts as of the window close, computed with `git show -s --format=%cI` and
FLOORED per READ TWELFTH: `1cdb96e` at 9 days, `e79339b` at 8, `0d2963e` at 5,
`285a05f` at under 18 hours. All four are hand deploy work per READ FIRST.

The blocker is unchanged and was re-checked rather than inherited, per READ
TWELFTH: nothing matching `SUPABASE` or `PROJECT_REF` is in this container's
environment. The single item ask in READ TWELFTH stands, and READ SEVENTEENTH's
sharper version of it stands too: Andrew is deploying edge functions by hand
already, and these four are neighbours of the ones he deployed.

NOTHING ELSE FIRED, THE WATCHDOG ASIDE
The newest `flutter` event of any kind is still 2026-08-04 19:34:33, which is 76
minutes BEFORE `6ff6a45` landed at 20:50:30, so FLUTTER-8, -B and -X have not
fired since that fix. Do not read that as the fix confirmed in production. The
quiet is equally well explained by nobody having opened a conversation in the 10
hours 47 minutes since, and note that Sentry cannot tell those two apart in
either direction: a WORKING fix emits nothing and an unused app emits nothing.
Earlier sections state the no-session half as fact, inherited from READ
FIFTEENTH; it is not establishable and is written as the alternative it is here.
None was re-resolved,
and three `flutter` issues carry a resolved status somebody else set.
FLUTTER-Y and FLUTTER-6 are the `RenderBox was not laid out` pair with zero
first party frames, left alone per READ FOURTEENTH. FLUTTER-1 and FLUTTER-5 are
browser transport. SUPABASE-PLATFORM-3's only event is the 12:10:02 429, which
`285a05f` postdates. SUPABASE-PLATFORM-4's two are the 06:39:35 and 12:55:16
requests READ EIGHTH and READ ELEVENTH document. MAUTIC-H's three are the probe
POSTs READ SIXTEENTH records. Same occurrences throughout, not recurrences.
Nothing was resolved.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 108, flutter 38,
                 mautic 3                                                  = 508
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 105, -4 2, -3 1                       = 108
                 FLUTTER-8 11, -B 10, -X 9, -1 3, -5 2, -Y 1, -6 1, -2 1   =  38
                 MAUTIC-H 3                                                =   3
                                                                             508

`website`, `moydforms`, `n8n` and `supabase-edge` at zero. Queried with NO status
filter per READ EIGHTH, which is how the ignored watchdog and the three resolved
`flutter` issues stayed visible. Read READ TWELFTH's caveat on what the equality
does and does not buy.

THE BRANCH REF TRAP, THIRTEENTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `b3d0302`, and the
sibling's `main` at `77d879f` against a real `9af7a94`. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH, and `git ls-remote`
re-run immediately before committing per READ FOURTEENTH. That is the same stale
PAIR READ EIGHTEENTH enumerates; per its instruction, this is one more
correlation and not a mechanism, so keep running the check.

AND THE REMOTE MOVED AGAIN MID RUN, WHICH IS WHY THAT RE-RUN IS NOT OPTIONAL
`b3d0302` was the real tip when this run started and was NOT the real tip when
it committed. The `git ls-remote` re-run immediately before committing returned
`8d922e9`, two commits further on, both authored by Andrew at 06:56:31 and
07:00:41 UTC while this sweep was working. That is the second time the hazard
READ FOURTEENTH records has actually bitten, and the check caught it both times.

Handled the way READ FOURTEENTH prescribes: stash, `checkout -B master`
FETCH_HEAD, pop, and then verify the moving base did not invalidate the audit.
It did not, and that is checked rather than assumed. The two commits touch only
`supabase/functions/` and two migrations; neither touches `AGENTS.md`, so this
diff is unaffected and the audit rounds behind it still stand.

One of the two is worth a line for the next run rather than for this one. Its
message says it records what production actually runs instead of the stale local
copy of an edge function, which is the deployment drift READ FIRST is about,
being closed by hand from the other direction. It is Andrew's work, not this
run's, and nothing here acts on it.

The ordinal is THIRTEENTH rather than twelfth, and it was recomputed rather than
carried forward, which is how the discrepancy surfaced. READ THIRTEENTH reads
SEVENTH and READ FIFTEENTH reads EIGHTH, but READ FOURTEENTH records a bite
between them that the running count never absorbed. Counting bites recorded in
this file rather than incrementing the previous section's number, this is the
thirteenth. Recompute it the same way next time; this is the drift READ TWELFTH
documents for day counts, in a different column.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Enumerated rather than waved at, per READ EIGHTEENTH, and
this is a claim to check rather than a habit: named above are the bare column
identifiers `form_id`, `updated_at`, `phone_e164`, `created_at`,
`state_house_district` and `name`, the camelCase symbol `formId`, and the
qualified `d.form_id` and
`l.committee_name`; the real column `committee_name` and its real table
`mec_committees`; the constraint `legislation_bill_sponsors_unique`; the commits
`1cdb96e`, `e79339b`, `0d2963e`, `285a05f` and `6ff6a45`; the issue ids and
project names; the stale refs `5d8a5b0` and `77d879f`, the start of run real
tips `b3d0302` and `9af7a94`, and this repo's mid run tip `8d922e9`; the
directory path `supabase/functions/`, published here since READ FIRST; and the
env var name patterns `SUPABASE` and
`PROJECT_REF`. Per READ EIGHTEENTH's carve out, quoted log CONTENT such as the
uuid literal `"cron"` and the Sentry rollup field names is error text already
published throughout this file from READ FIRST onward.

That carve out explicitly does NOT cover log content which is not already
public, and this slice carries exactly one such line, so weigh it rather than
sweep it in: `aggregate functions are not allowed in GROUP BY` appears nowhere
earlier in this file. It is kept. It is a generic Postgres planner message
carrying no identifier of any kind, no table, no column, no value and no
address, so it describes a SQL authoring mistake and nothing about this
deployment.

Newly published private repo content, weighed rather than passed over, because
an auditor caught the first version of this enumeration omitting it entirely:
four sibling commit TIMES appear in the attribution paragraph above, and three
of those commits are not named by hash at all. The times are kept, because the
timing argument is the finding and cannot be made without them, and a bare
timestamp names no table, route, RPC, person or credential.

An earlier draft also published paraphrased SUBJECT lines for those four
commits. They are gone. Two audit rounds went into how faithfully the
paraphrases tracked the originals, which was effort spent defending a disclosure
the finding never needed, and the private repo is the one place where the
cheapest correct answer is to publish less. The characterization that survives,
that all four are membership and roster work, says what the argument requires
and quotes nothing.

Two more need their cover stated correctly rather than in bulk, because an
auditor caught the bulk version getting it backwards. `b3d0302` and `8d922e9`
are THIS public repo's own tips, so they disclose nothing. `9af7a94` is the
PRIVATE sibling's tip and appears nowhere earlier in this file, so "already
published" is
NOT its cover: it is published here for the first time. It is kept because a bare
commit hash of a private repo names no table, route or person and this file has
published sibling hashes before, and it is recorded as a deliberate first
publication rather than smuggled in under a false justification. READ SEVENTEENTH
records this exact inversion as a caught defect: before citing prior publication
as cover, check WHICH repo published it. Everything else in the list is already
committed in this repo's own migrations, tree or this file.

Migration filenames are deliberately NOT enumerated here any more, and this
paragraph does not name the one that mattered. The earlier draft listed three,
and one of them carries the name of the RPC it defines in its filename, which
made the closing "no RPC name appears" claim false while it was named. Naming it
again to explain the correction would reintroduce exactly the thing being
removed. The finding survives without any of the three, so all three are gone and
the claim below is true as written.

No credential, no DSN, no probe source address, no policy body, no RPC name and
no raw upstream error appears, and nothing here widens access to anything.
Withheld per the practice READ SIXTH set: the state of the live endorsement vote,
any operational read on production sessions, and anything describing this
container's own reporting or credential tooling, which READ EIGHTEENTH records as
a BLOCKER class.

## READ TWENTIETH: the 08:20 UTC sweep, a check constraint doing its job, and two hours with no hourly line captured

Swept the 24 hours to 2026-08-05 08:20 UTC. No code change: the one new message
shape in this window is a constraint refusing an invalid write, which is the
system working, and everything else belongs to a family the sections above
enumerate. Short by design, per READ TWELFTH.

Carve out the watchdog the way READ EIGHTEENTH insists rather than writing
"nothing else fired". ENDORSEMENT-SCORER-4 reads 358 by project and 359 by
issue, against 359 in the four sweeps before it, and a FLAT rolling 24 hour
count of a periodic emitter means events kept landing as old ones aged out, not
that it stopped. It is correctly ignored, so it is excluded on purpose.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 06:22 UTC, so only 1 hour 58 minutes is new observation.
Nothing below independently confirms anything above it.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 5 SUPABASE-PLATFORM-1 events after 06:22 UTC, the
FATAL tagged one included, per READ SEVENTH. Seven log lines, reconciling
against the sum of the five per event `count` fields:

    06:33:44  column "status" does not exist                      ERROR
    06:36:38  new row for relation "slack_channel_membership_log"
              violates check constraint
              "slack_channel_membership_log_dispatch_check"       ERROR
    06:47:35  column "channel_name" does not exist                ERROR
    06:48:13  column "email" does not exist                       ERROR
    06:50:23  column "created_at" does not exist                  ERROR
    06:52:50  column "status" does not exist                      ERROR
    08:12:53  password authentication failed for user "?"         FATAL, filtered

Seven rows, seven lines. The password total is the usual `by_severity` residual
and not a direct read, per the standing caveat in READ FOURTH. The two
malformed startup packet families and the SASL Terminate line are absent, so
the password family is the only probe shape this slice, at one line where the
recent average is about six per two hour slice. That is the third slice running
with an unusual probe profile and it still means nothing at this sample size,
for the reason READ NINETEENTH gives. Recorded so a future run notices a trend,
not as a finding.

THE NEW SHAPE IS THE SLACK DISPATCH GATE REFUSING A BAD VALUE
No earlier section records this message. It is not a defect, and unusually for
this family the reasoning does not rest on timing at all.

The constraint is created by `20260805_01_slack_dispatch_gate.sql` in THIS
repo, committed in `b2ccf15`, and reads
`dispatch IS NULL OR dispatch IN ('approved', 'superseded', 'executed')`. The
gate exists because `slack_channel_membership_log` held a nine month backlog of
unsent committee changes that scheduling the drain would have mass invited at
real people; NULL is the default and means inert.

Every committed write of that column was enumerated rather than sampled. There
are FIVE write sites carrying TWO distinct values across THREE writers:
`sync_committees_to_slack` stamps `'approved'` at both of its INSERT sites,
`recordChannelInvite` in `_shared/onboarding.ts` writes `'executed'`, and
`slack-sync-to-slack` updates to `'executed'` at both of its post-attempt
sites. Count it in all three units and say which is which, because an earlier
draft called this "exactly three literals" while its own sentence described
five sites, which is READ SIXTH's "six lines, five shapes" error committed
again in a section that cites it. Nothing writes `'superseded'`, and no site
writes the column from a variable. Every value is inside the allowed set, and
every other insert site leaves the column unset, which is NULL and also
allowed.

So no committed statement in either repo can raise this error. Do NOT upgrade
that into "a stronger negative than the usual grep", which is what an earlier
draft claimed on the reasoning that the allowed set is small and closed. The
set being closed makes the enumeration complete over COMMITTED source and does
nothing about the blind spot READ FIRST and READ FOURTH exist to document: a
hand deployed draft of an edge function, or a draft of this trigger applied to
production before the committed version, raises the identical line and is
invisible from here. This very window supplies the counterexample, which is why
the overclaim is worth recording rather than just deleting: `8d922e9` proves a
DEPLOYED copy newer than the repo for one function, and it landed at 07:00:41,
four minutes after `b2ccf15` and about eight after the last of these lines.

Anchor an interval to the event you name, which the first correction of this
paragraph did not: an earlier draft said "four minutes after these lines
landed", and four minutes is the `b2ccf15` to `8d922e9` gap rather than
anything measured from the log lines. That is the same anchoring error this
section corrects twice elsewhere, committed a third time inside one of the
corrections.

The `source` check widened in the same migration was checked the same way:
`LOG_SOURCE_ONBOARDING` is the literal `"onboarding"`, which the widened
constraint admits, and the other three writers pass `'slack_event'`,
`'manual_sync'` and `'supabase_trigger'`. No mismatch there either.

At least THREE emitters remain, not one, and an earlier draft named only the
first: a hand INSERT asserting the gate holds, a draft of the trigger applied
to production ahead of the committed text, or a draft edge function deployed
the same way. Nothing here distinguishes them, and nothing needs to. All three
sit inside the same hand applied session, and both operative conclusions, that
committed code is not defective and that the constraint must not be relaxed,
hold under every one of them.

The best supported reading is still the negative testing practice READ ELEVENTH
decoded and READ SEVENTEENTH attributed. The company the line keeps supports it:
`channel_name` at 06:47:35 is a metadata key the trigger builds rather than a
column, and every line in the run precedes `b2ccf15`, which published the
migration defining the constraint being tripped. Be exact about that margin
rather than rounding it, because an earlier draft wrote that "the whole run
sits twenty minutes before" the commit: twenty minutes is true only of the
06:36:38 constraint line, and the last line of the run at 06:52:50 precedes
`b2ccf15` at 06:56:31 by under four minutes. What carries the argument is that
all of them precede it, not how far. Per READ NINTH, code that did not exist in
the tree cannot have been running in production, so this is the migration being
applied and exercised by hand before it was committed, exactly as READ
SEVENTEENTH records for the membership audit.

DO NOT RELAX THIS CONSTRAINT
It is not a permission, so the standing prohibition in READ THIRD and READ TENTH
does not literally cover it, and it should be covered anyway. Widening the
allowed set, or dropping the check to clear the log line, would reopen the door
`b2ccf15` was written to close, and if the write was an assertion then relaxing
the constraint makes the assertion pass while breaking the thing it asserts.
READ ELEVENTH makes the same point about the admin RPC denials.

NO HOURLY uuid LINE WAS CAPTURED AT 07:00 OR 08:00, AND THAT IS THE ONE THING
FOR THE NEXT SWEEP
`invalid input syntax for type uuid: "cron"` has been captured once an hour on
the hour in every sweep since READ FOURTH. It was not captured at 07:00 or at
08:00 today.

Word that as carefully as it is worded above, because the tempting phrasing is
already an inference. What was OBSERVED is that there is no rollup event at all
in the 07:05 or 08:05 slot. Whether the underlying statement fired and went
uncaptured, or did not fire, is NOT observable from Sentry, and the difference
is the whole finding. An earlier draft of this section said flatly that the line
"did NOT fire" and put "the hourly emitter stopped" in its own heading, which an
auditor caught: the body then spent a paragraph explaining why that is not
establishable, so the heading was contradicting the section under it, and a
heading is what a future run skims.

The `:05` slot carried a rollup in every hour from 02:05 through 06:05. The
06:05 rollup's `by_message` was read directly this run rather than inherited
from READ NINETEENTH, per READ FOURTEENTH's instruction not to inherit a
group's diagnosis: it carries the uuid key once, in window 05:59:06 to
06:04:01, so the last captured occurrence falls inside THAT WINDOW. Do not
tighten that to "in the 06:00 hour", which an earlier draft did: the window
opens 54 seconds BEFORE the 06 hour boundary, so it carries the last 54 seconds
of the 05 hour, and the hour placement follows only if you
assume the on-the-hour pattern, which is the very thing this finding is
questioning. READ NINETEENTH's precedent for this exact rollup key is not to
infer where in the window a line landed. The relay
itself is alive across the gap: it emitted at 06:35, 06:40, 06:50, 06:55 and
again at 08:15, so this is not a dead relay.

Do NOT read this as `1cdb96e` being deployed, however tempting that is after ten
days of it firing. READ FOURTH's caveat is the reason: no rollup means only that
the run sent nothing, and this relay has two paths that send nothing while still
advancing the watermark, a `postgres_logs` query failure caught non-fatally and
a failed ingest that returns null without throwing. Two consecutive silent runs
landing on the two `:05` slots would be a coincidence, which is why this is
worth recording, but a coincidence is not an exclusion. A disabled or
rescheduled cron job produces the identical observation and is not a deploy
either.

So this is an OBSERVATION with a cheap test attached, and the next sweep should
run it rather than inherit either reading: check whether a cron line appears at
09:00 and 10:00. Three or four consecutive misses is a step change worth
believing; two is not. If it has genuinely stopped, `1cdb96e` is the first of
the four undeployed fixes to clear, and the day count below stops mattering.

DAY COUNTS, RECOMPUTED AND NOT CARRIED FORWARD
Computed with `git show -s --format=%cI` and FLOORED against the 08:20 window
close, per READ TWELFTH: `1cdb96e` at 10 days, `e79339b` at 9, `0d2963e` at 5,
`285a05f` at under 20 hours.

The first two BOTH advanced since the 06:22 sweep, which read 9 and 8, and this
is the READ EIGHTEENTH case rather than the arithmetic drift READ SEVENTEENTH
warns about: `1cdb96e` landed at 06:29:38 UTC and `e79339b` at 06:39:23 UTC, so
both crossed a day boundary within eighteen minutes of the previous sweep
closing, at 7m38s and 17m23s after a 06:22 close. Two figures moving at once
between consecutive sweeps looks exactly like copied drift and is not.
Recompute rather than assume in either direction.

`e79339b` is not directly observable in this slice because no 6 hour boundary
falls inside 06:22 to 08:20; READ NINETEENTH confirmed it at the 06:00 cycle,
32 lines and unchanged.

The deploy blocker is unchanged and was re-checked rather than inherited, per
READ TWELFTH: nothing matching `SUPABASE` or `PROJECT_REF` is in this
container's environment. READ SEVENTEENTH's sharper version of the ask stands,
and this window strengthens it: `b2ccf15` and `8d922e9` show Andrew deploying
edge functions and comparing deployed against committed source by hand, and
`8d922e9` found the deployed copy NEWER than the repo for one function. These
four fixes are neighbours of the ones he is already in there deploying.

NOTHING ELSE FIRED, THE WATCHDOG ASIDE
Every other issue's newest event predates the new slice, so all of them are the
same occurrences the sections above document rather than recurrences, and none
was resolved.

FLUTTER-1 and FLUTTER-2 have now aged OUT of the 24 hour window, which is why
`flutter` reads 34 where the last five sweeps read 38: 38 minus FLUTTER-1's
three events and FLUTTER-2's one is exactly 34. Both were the 2026-08-04
07:24 to 07:25 session. That is the rolling window working, not a change in
behaviour, and a future sweep should expect the remaining `flutter` issues to
age out the same way tomorrow.

FLUTTER-8, -B and -X still have not fired since `6ff6a45` landed at 20:50:30,
their newest event of any kind being 19:34:33 on 08-04. Do not read that as the
fix confirmed in production: Sentry cannot tell a working fix from an unused app,
since both emit nothing, per READ NINETEENTH. FLUTTER-Y and FLUTTER-6 are the
`RenderBox was not laid out` pair with zero first party frames, left alone per
READ FOURTEENTH. FLUTTER-5 is browser transport. SUPABASE-PLATFORM-3's only
event is the 12:10:02 429, which `285a05f` postdates. MAUTIC-H's three are the
probe POSTs READ SIXTEENTH records.

SUPABASE-PLATFORM-4 IS DOWN TO ONE EVENT, AND THE AGING RULE HAS TO BE APPLIED
EVERYWHERE OR IT IS NOT A RULE
Its only in window event is the 12:55:16 `form-uploads` probe READ ELEVENTH
documents. The 06:39:35 keyless bucket root GET that READ EIGHTH documents has
now aged OUT, at 2026-08-04 06:39:35 against a window opening at 08:20.

That correction is recorded rather than quietly applied, because of how it was
caught. An earlier draft of this section said "two" and named both requests, a
phrase carried forward verbatim from READ NINETEENTH whose window still held
them, while this same section's own census read `-4 1` three paragraphs later.
The section contradicted itself, and it did so while correctly computing the
identical aging for FLUTTER-1 and FLUTTER-2 in the paragraph above. READ
EIGHTEENTH had already performed this exact correction for the 02:03:37
request. So this is not a new trap: it is READ TWELFTH's copied-not-computed
failure, in the one place the section forgot to recompute, surviving until an
adversarial auditor cross checked the prose against the census.

The lesson is cheap and worth more than the fact: the census is a computed
number and the prose is a remembered one, so when they disagree the prose is
wrong. Cross foot them against each other, not just the two census axes against
each other.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 358, supabase-platform 100, flutter 34,
                 mautic 3                                                  = 495
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 98, -4 1, -3 1                        = 100
                 FLUTTER-8 11, -B 10, -X 9, -5 2, -Y 1, -6 1               =  34
                 MAUTIC-H 3                                                =   3
                                                                             496

The two axes differ by ONE and the difference is entirely `endorsement-scorer`,
358 against 359. Do not paper over that: it is the rolling window moving between
two calls in one run, which READ FIFTH records happening inside a single sweep,
and the watchdog is the one emitter here firing often enough to gain or lose an
event in the seconds between them. Every other project agrees exactly. A
discrepancy in a project that fires roughly every four minutes is expected; the
same discrepancy in `supabase-platform` or `flutter` would not be, and would be
worth chasing.

`website`, `moydforms`, `n8n` and `supabase-edge` at zero. Queried with NO
status filter per READ EIGHTH, which is how the ignored watchdog and the
resolved `flutter` issues stayed visible. Read READ TWELFTH's caveat on what the
equality does and does not buy.

NAME the resolved ones rather than counting them, because an auditor could not
check the count against this file and neither will the next run. In THIS window
they are FLUTTER-8 and FLUTTER-5, both carrying a resolved status somebody else
set while still holding in window events. READ NINETEENTH counted three, and
that is not a discrepancy: its third was FLUTTER-2, which has since aged out.
Neither status was touched by this run, per READ EIGHTH's practice of not
re-resolving what somebody else set. Word it that way rather than "both remain
unresolved", which a draft said and which contradicts this paragraph's own
first sentence: they ARE resolved, by someone else. The act this run declined
was touching a status, not resolving an issue.

THE BRANCH REF TRAP, FOURTEENTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `2354a00`, and the
sibling's `main` at `77d879f` against a real `308ef92`. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH, and `git ls-remote`
re-run immediately before committing per READ FOURTEENTH. That is the same stale
PAIR READ EIGHTEENTH enumerates; per its instruction this is one more
correlation and not a mechanism, so keep running the check. The ordinal is
recomputed from bites recorded in this file rather than incremented, per READ
NINETEENTH.

ONE TOOL NOTE
`search_events` timed out at 60s twice in a row on the same issue-scoped query
with an `id` field, and `search_issue_events` answered the same question
immediately. That is the hazard READ NINTH and READ TENTH both record; retry
with a differently shaped query rather than classifying by title.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. Enumerated rather than waved at,
per READ EIGHTEENTH, and this is a claim to check rather than a habit.

Named above from the Slack work: the table `slack_channel_membership_log`, the
constraint `slack_channel_membership_log_dispatch_check`, the `dispatch` column
and its full allowed value set, the widened `source` value set, the trigger
`sync_committees_to_slack`, the migration filename
`20260805_01_slack_dispatch_gate.sql`, the helper `recordChannelInvite`, the
constant `LOG_SOURCE_ONBOARDING` and the functions `slack-sync-to-slack` and
`_shared/onboarding.ts`. Apply READ SEVENTEENTH's test rather than the lazy
version of it: every one of these is committed in THIS repo, the public one, by
`b2ccf15`, so naming them adds no reach. That test is the whole point, because
"already committed" would be an argument for withholding had they come from the
sibling.

Also named: the bare column identifiers `status`, `channel_name`, `email` and
`created_at`, all four already on this record or committed here; the real
column `slack_channel_name`, committed here in the same migration; the commits
`1cdb96e`, `e79339b`, `0d2963e`, `285a05f`, `6ff6a45`, `b2ccf15`, `8d922e9` and
`9af7a94`; the issue ids and project names; the stale refs `5d8a5b0` and
`77d879f`; this repo's real tip `2354a00`; and the env var name patterns
`SUPABASE` and `PROJECT_REF`. `9af7a94` is a private sibling hash whose cover
is READ NINETEENTH's recorded first publication, not this section's.

FIVE more are swept in rather than argued about, each caught by an auditor as
missing from an earlier draft of this list: the `form-uploads` bucket, already
published by READ ELEVENTH as committed in this repo's own storage RLS audit
snapshot; the `postgres_logs` dataset, published here since READ FIRST; and the
Sentry tool names `search_events` and `search_issue_events` with the `id` field
from the tool note, both tools already published in READ TENTH.

All five arguably sit outside the identifier scope READ EIGHTEENTH defines,
which is hashes, columns, tables, env vars, file paths, issue ids and project
names. Sweep them in anyway. The enumeration's stated standard is that it is a
claim to CHECK, and a scope argument that has to be relitigated every sweep
costs more than five extra names. Count them before writing the number: a draft
of this very paragraph said four, then five, then four again in three adjacent
sentences, which is the same class as the "three literals" slip above and
READ SIXTH's "six lines, five shapes", committed inside the paragraph whose
whole subject is enumerating exactly. Per READ EIGHTEENTH's carve out, quoted log CONTENT such as the
uuid literal `"cron"` and the Sentry rollup field names is error text already
published throughout this file from READ FIRST onward. The one log line here
that is NOT already public is the check constraint violation itself, weighed
rather than swept in: it names only the table and constraint that the paragraph
above already clears as this public repo's own committed schema, and carries no
value, no row, no person and no address.

`308ef92` is the PRIVATE sibling's tip and appears nowhere earlier in this file,
so "already published" is NOT its cover and it is recorded as a deliberate first
publication, on the same call READ NINETEENTH made for `9af7a94`: a bare commit
hash of a private repo names no table, route or person, and this file has
published sibling hashes before.

Deliberately withheld: the operational specifics in `b2ccf15`'s message beyond
what the finding needs, including the backlog and channel figures and the cron
job identifier, since the finding is that the gate refused a bad value and none
of that carries it. Also withheld per the practice READ SIXTH set, the state of
the live endorsement vote, any operational read on production sessions, and
anything describing this container's own reporting or credential tooling, which
READ EIGHTEENTH records as a BLOCKER class.

No credential, no DSN, no probe source address, no policy body, no RPC name and
no raw upstream error appears, and nothing here widens access to anything.


## READ TWENTY-FIRST: the 10:20 UTC sweep, four boundaries with no uuid line captured, and why that is not yet a finding

Swept the 24 hours to 2026-08-05 10:20 UTC. No code change. Outside the ignored
watchdog, no Sentry event fired anywhere in the genuinely new observation.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 08:20 UTC, so only 2 hours is new observation.

The watchdog is excluded on purpose, not absent. ENDORSEMENT-SCORER-4 reads 359
on both axes here; READ TWENTIETH read 358 by project against 359 by issue, so
do not quote these as an unchanged pair. A FLAT rolling 24 hour count of a
periodic emitter means events kept landing as old ones aged out, and on its own
numbers roughly 30 watchdog events fired inside this slice.

THE NEW SLICE IS EMPTY, AND THAT CUTS BOTH WAYS
The newest event in the entire organisation outside the watchdog is
SUPABASE-PLATFORM-1 at 08:15:06 UTC, which the 08:20 sweep already read and
which READ TWENTIETH decomposes as one filtered password FATAL. So there is no
new event to classify and no `by_message` left unread.

Do not book that as good news, which is what the first draft of this section
did. A relay that stopped after 08:15 produces an empty slice too. Emptiness is
the one observation that a healthy quiet system and a dead reporting pipeline
share, so it is evidence for neither until something else separates them.

READ TWENTIETH LEFT A TEST. IT WAS RUN, AND THE RESULT IS WEAKER THAN THE
THRESHOLD MAKES IT LOOK
That section observed no hourly `invalid input syntax for type uuid: "cron"`
line captured at 07:00 or 08:00, refused to call it either way, and left a cheap
test: check 09:00 and 10:00. Both are misses. There is no rollup event in the
09:05 or 10:05 slot, and at 10:20 a 10:05 rollup would be fifteen minutes old
and ingested. That is four consecutive hourly boundaries with no uuid line
captured, against a pre-registered threshold of three or four.

The threshold is met and the conclusion still does not follow, for a reason the
threshold did not anticipate. The four misses are NOT four independent
observations. The 09:00 and 10:00 misses have no relay-liveness evidence behind
them at all, because the newest `supabase-platform` event is 08:15:06. Scope
that to the project rather than writing "the newest event of any kind", which is
false three paragraphs after this section says the watchdog fired about 30 times
inside the slice. A relay that died at 08:15 yields the empty slice AND both of
those misses from one cause. Strip
the two that a dead relay would explain anyway and two remain, which is the
count READ TWENTIETH's own threshold says is NOT worth believing.

So the honest statement is the narrow one. The line was not captured at four
consecutive boundaries; relay liveness is demonstrable for the first two only;
and whether the emitter stopped, or the relay stopped, is NOT established.

READ FOURTH ALREADY RECORDED THE PRECEDENT, AND IT POINTS THE OTHER WAY
This is not a new situation. READ FOURTH records hour 16 on 2026-08-03 as a
window hour carrying no uuid line and no `:05` rollup at all, and says in as many
words that one gap proves nothing by itself, and that it is recorded "so the next
run does not read 'once an hour' as a guarantee and then treat a gap as a fix."

That is exactly the trap this section walked into before an auditor pulled it
out. Note also that the emitter's record is "captured once an hour", not "fired
once an hour": hour 16 is a known exception, so any claim of an unbroken ten day
cadence is false against this file.

WHAT THE WINDOW WIDTH DOES AND DOES NOT BUY
The 08:15 rollup carries `window_start` 08:09:01.651 and `window_end`
08:14:02.325, a clean five minute window. Per READ FIRST a skipped or failed run
leaves the NEXT window wider, capped at 60 minutes. Cite that to READ FIRST: it
is not READ TWENTIETH's, and the two silent paths below are READ FIRST's as
well, which READ TWENTIETH misattributed to READ FOURTH.

A clean window is therefore consistent with the watermark having kept pace to
08:09. It does not PROVE that runs executed at the boundary TIMES, and the first
draft said "proves", which is the overclaim.

But read what that concession is actually worth, because a second draft then
over-read it in the opposite direction and claimed a skipped 07:00 hour would
mean "the uuid line was never looked for". That is false against the relay's own
committed source. The window is `[last_end, min(now - 60s, last_end + 60min)]`,
so a relay that stalls and resumes reads FORWARD from the stale watermark rather
than jumping to now: a resume after a dead 07:00 hour queries a capped window
covering the 07:00 boundary, and the next covers 08:00. That is what the
watermark is for, and READ FIRST says so in as many words, that the next run
re-reads the same span under the 60 minute cap. Note also that the first
catch-up step is a capped 60 minute window, not a five minute one.

So skipping does not hide a line. Whether the runs sat on the boundary or caught
up afterwards, the SPANS containing 07:00 and 08:00 were consumed by some run
before the watermark reached 08:09, and any uuid line in them was queried for.

What remains is READ FIRST's pair of silent paths, and BOTH survive. An earlier
draft narrowed it to one and that was wrong on the source.

The first is the `postgres_logs` query failing and being caught non-fatally into
an empty row set. That catch is worth naming precisely, because it sits on the
postgres query SPECIFICALLY, under a `Promise.all` whose two siblings have no
such catch. It is exactly the query that would carry the uuid line.

The second is `sendSentryEvent` returning null when the ingest answers non-ok. It
does not throw, and the watermark update runs after the sends, so the run
completes and advances. Do not exclude it on the grounds that it suppresses a
whole rollup rather than one message key: a suppressed whole rollup in the 07:05
and 08:05 slots is precisely what was observed.

Two narrower mechanisms also survive and are recorded for completeness rather
than because they are likely at these volumes. The postgres query carries a
`limit 200` with no ORDER BY, so a busy window can drop a line from a query that
succeeded, and `by_message` is a capped 15 key tally, so an emitted rollup can
drop a key.

The first draft argued a swallow would have to land on four consecutive
hour-boundary windows and nowhere else. That overstates the constraint: with the
relay silent after 08:15 it needs at most two, which is not a remarkable
coincidence.

THE TEST FOR THE NEXT RUN, AND RUN IT FIRST
One check separates the two readings and costs a single query. Before anything
else, look for ANY `supabase-platform` event with a timestamp after
2026-08-05 08:15:06.

- If one exists, the relay is alive. Do NOT then count every boundary it spans
  as a real miss, which is the sloppy version of this test: the `.catch` above is
  on the postgres_logs query alone, so a storage, auth or traffic rollup can be
  emitted by a run whose postgres query failed silently, and a SUPABASE-PLATFORM-3 event
  proves only that the run threw somewhere, not that the logs query failed: per
  READ FIRST that fingerprint is a catch-all that also collects state-read and
  watermark-update failures. Do not invert that into "so every query succeeded",
  which an earlier draft did and which contradicts the clause before it: the
  postgres rejection is SWALLOWED, so a run whose postgres query failed silently
  still reaches the watermark update and can throw there. A watermark-update
  failure establishes only that the two uncaught siblings did not throw, and says
  nothing about the one query that matters here. It also carries no window at
  all. What counts is a SUPABASE-PLATFORM-1 rollup, the postgres category, whose
  `window_start` to `window_end` span covers the boundary. Count those, and the
  emitter having stopped becomes believable on its own evidence rather than on
  this section's.
- If none exists, the relay has been silent since 08:15:06 and IS the finding.
  State it as that timestamp rather than as a duration: sweep spacing has been as
  short as 56 minutes, so the elapsed figure depends on when the next run happens
  and the argument does not. In that case nothing about the uuid line is established, and the
  scan-noise families going quiet across READ NINETEENTH and READ TWENTIETH
  acquire a candidate common cause and should be re-read as possible early
  symptoms. Credit those two sections correctly while doing it: neither read the
  quiet as declining probe traffic, and both said in terms that the sample was
  too small to mean anything and that they were recording it so a future run
  could notice a trend. They declined to draw a conclusion; they did not draw the
  wrong one.

Either way, do not resolve or re-resolve anything on the strength of this
section.

DO NOT READ ANY OF THIS AS `1cdb96e` HAVING DEPLOYED
Two checks were run rather than assumed and neither settles it, and the first
of them had to be redone after it tripped READ SECOND's shallow clone trap.

`git log -- supabase/functions/sync-google-calendar/` in this container answers
`ece34e3`. That answer is worthless. `ece34e3` is a GRAFT POINT, listed in
`.git/shallow`, so `git show --stat` on it reports 4753 files changed and it is
returned as the last commit for essentially every path in the tree. READ SECOND
says ancestry questions across the graft do not give a trustworthy negative, and
this is that, in the one paragraph of this section that opens by claiming its
checks were run rather than assumed. The real commit behind that hash is the
flutter one READ FOURTEENTH cites, and it never touched this function.

Asking GitHub for the path history instead, which reads the real default branch
rather than a truncated clone, the last commit to touch
`sync-google-calendar/index.ts` is `1cdb96e` itself, on 2026-07-26. Nothing has
touched that function since the fix landed. That is a stronger version of what
the wrong check was reaching for, not a weaker one. Prefer the API for any
"last commit to touch X" question in this container.

The second check is a grep, and state it precisely because a future run will
re-run it: `cron` appears on seven lines of that file. Three carry the quoted
literal `"cron"` and a fourth continues the same comment, all four inside the
block explaining the fix, and the remaining three are the unrelated cron-secret
auth path. No code path passes the string to a uuid column, so the committed
source still carries `1cdb96e`.

The deployed copy remains unobservable from here, which is READ FIRST's whole
subject, and `supabase functions list` is still the check.

An out-of-band hand deploy, the cron job being disabled, the job being
rescheduled off the hour, and a relay that stopped reporting are all consistent
with what was observed. Treat `1cdb96e` as OPEN and leave its day count running.

THE OTHER LONG STANDING FIX IS CONFIRMED STILL UNDEPLOYED, DIRECTLY
Not inferred from silence. The 06:00 UTC cycle carried exactly 32
`legislation_bill_sponsors_unique` lines, unchanged size, inside the 06:05
rollup, so `e79339b` is not deployed. That cycle sits in this window but not in
its new slice, so it is the same occurrence READ NINETEENTH and READ TWENTIETH
read, not a recurrence. No 6 hour boundary falls inside 08:20 to 10:20.

The last captured cron line is in that same 06:05 rollup, whose window is
05:59:06.009 to 06:04:01.762. Say it that way rather than "the 06:00 line": the
window opens 54 seconds before the hour boundary, and READ NINETEENTH's
precedent for this exact rollup key is not to infer where inside a window a line
landed.

DAY COUNTS, RECOMPUTED AND NOT CARRIED FORWARD
With `git show -s --format=%cI` and FLOORED against the 10:20 window close, per
READ TWELFTH: `1cdb96e` at 10 days, `e79339b` at 9, `0d2963e` at 5, `285a05f` at
under 22 hours. None crossed a boundary since the 08:20 sweep.

The deploy blocker was re-checked rather than inherited, per READ TWELFTH:
nothing matching `SUPABASE` or `PROJECT_REF` is in this container's environment.
READ SEVENTEENTH's sharper version of the ask stands.

NOTHING ELSE FIRED, THE WATCHDOG ASIDE
Every other issue's newest event predates the new slice, so all are the same
occurrences the sections above document rather than recurrences, and none was
resolved or re-resolved.

The newest `flutter` event of any kind is 2026-08-04 19:34:33, which is 76
minutes BEFORE `6ff6a45` landed at 20:50:30, so FLUTTER-8, -B and -X have not
fired since that fix. Do not read that as the fix confirmed in production:
Sentry cannot tell a working fix from an unused app, since both emit nothing,
per READ NINETEENTH. That quiet now stands at 14 hours 45 minutes. FLUTTER-Y and
FLUTTER-6 are the `RenderBox was not laid out` pair with zero first party
frames, left alone per READ FOURTEENTH. FLUTTER-5 is browser transport.
SUPABASE-PLATFORM-3's only event is the 12:10:02 429, which `285a05f` postdates.
SUPABASE-PLATFORM-4's only event is the 12:55:16 `form-uploads` probe READ
ELEVENTH documents; the 06:39:35 keyless bucket root GET has aged OUT, as READ
TWENTIETH already recorded. MAUTIC-H's three are the probe POSTs READ SIXTEENTH
records.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 91, flutter 33,
                 mautic 3                                                  = 486
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 89, -4 1, -3 1                        =  91
                 FLUTTER-B 10, -8 10, -X 9, -5 2, -Y 1, -6 1               =  33
                 MAUTIC-H 3                                                =   3
                                                                             486

Both axes agree exactly, unlike the 08:20 sweep where the watchdog differed by
one across two calls. `website`, `moydforms`, `n8n` and `supabase-edge` at zero.
Queried with NO status filter per READ EIGHTH, which is how the ignored watchdog
and the resolved `flutter` issues stayed visible. Read READ TWELFTH's caveat on
what the equality does and does not buy, and note it buys nothing at all about
the relay question above: a census of what arrived cannot detect what was never
sent.

`flutter` reads 33 against the 08:20 sweep's 34 because one FLUTTER-8 event aged
out, taking that issue from 11 to 10. Rolling window, not a behaviour change.

The resolved issues still carrying in window events are FLUTTER-8 and FLUTTER-5,
both set resolved by somebody else. Neither status was touched by this run, per
READ EIGHTH. Word that as declining to touch a status rather than as leaving
them unresolved: they ARE resolved, by someone else.

THE BRANCH REF TRAP, FIFTEENTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `8377639`, and the
sibling's `main` at `77d879f` against a real `308ef92`. That is the same stale
PAIR READ EIGHTEENTH enumerates; per its instruction this is one more
correlation and not a mechanism, so keep running the check. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH, and `git ls-remote`
re-run immediately before committing per READ FOURTEENTH. The ordinal is
recomputed from bites recorded in this file rather than incremented, per READ
NINETEENTH.

WHAT THE AUDITORS CAUGHT, AND THE HEADLINE FAILURE THAT IS NOW TWO IN A ROW
The first draft of this section led with "the hourly uuid line stops" as a
heading and "this emitter has stopped" as a conclusion. An adversarial auditor
returned NOT CLEAN with that as a BLOCKER, on the ground reconstructed above:
two of the four misses are explained by the same silence that makes the slice
empty, so the threshold was double counted. It also caught the false "every
hour", the "proves" overclaim, two citations attributed to the wrong sections,
and the watchdog pair. A second round caught the second draft
over-correcting into a false mechanism claim about skipped runs. A third caught
the third draft over-correcting AGAIN, into "exactly one shape", and caught the
shallow graft answer above, a false SUPABASE-PLATFORM-3 claim, a miscounted grep,
and this heading still carrying a "three" its own body refutes.

That progression is the useful part. Each round's fix was itself the next round's
finding, and every one of those was a checkable fact asserted a little past what
had actually been checked. Three rounds was not excessive here; it was the number
required.

Generalize that carefully rather than sweepingly, because the sweeping version
was itself a finding. READ TWENTIETH does record an auditor catching it putting
"the hourly emitter stopped" in its own heading, and that is the same error as
this one. READ NINETEENTH's four falsified attempts at a column overlap argument
are NOT: that was a body strand it deliberately abandoned, in a sweep whose
heading survived, and it was a suggestive correlation rather than a suggestive
absence. So this is two sweeps in a row with the same headline failure, not
three, and inflating it to three to make a tidier lesson is the same reflex as
inflating the evidence.

The lesson that does hold: a heading is what the next run skims, so the heading
is where this costs something. Write the narrow claim first and let the evidence
argue it up, rather than writing the conclusion and defending it.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. Enumerated rather than waved at,
per READ EIGHTEENTH, and this is a claim to CHECK rather than a habit.

Named above: the commits `1cdb96e`, `e79339b`, `0d2963e`, `285a05f`, `6ff6a45`
and `ece34e3`; the functions `sync-google-calendar` and `sentry-log-relay` and
their `index.ts`; the command `supabase functions list`; the constraint
`legislation_bill_sponsors_unique`; the relay internals `window_start`,
`window_end`, `postgres_logs`, `sendSentryEvent`, `last_end`, `Promise.all`,
`limit 200`, `by_message` and the window expression quoted above; the graft
mechanics `.git/shallow`, `git log`, `git show --stat` and the path
`supabase/functions/sync-google-calendar/`, plus the GitHub path-history API used
to get the real answer; the `form-uploads` bucket;
the issue ids and project names; the stale refs `5d8a5b0` and `77d879f`; the
real tips `8377639` and `308ef92`; and the env var name patterns `SUPABASE` and
`PROJECT_REF`. Carve out the three graft mechanics first: `.git/shallow` and `git show --stat`
appear nowhere earlier in this file, so prior publication is NOT their cover.
They need none. They are generic git plumbing, and their only informational
content, that this clone is shallow, READ SECOND published verbatim. The same
goes for the GitHub path-history API, which is a public API named descriptively.
Say that rather than sweeping them under a universal, which is the inverted
which-repo-published-it check READ SEVENTEENTH names and which an earlier draft
of this very paragraph committed.

Every remaining identifier above already appears in this file or is committed in
this public repo's own tree, `308ef92` included: READ TWENTIETH published it as a
deliberate first publication, so its cover here IS prior publication. Getting
that backwards, as an earlier draft did, is the inverted which-repo-published-it
check READ SEVENTEENTH names as a method.

Per READ EIGHTEENTH's carve out, quoted log CONTENT here is the uuid literal
`"cron"`, the string `RenderBox was not laid out`, and the Sentry rollup field
names, all published in this file since READ FIRST and READ FOURTEENTH. This
slice carried no log content that is not already public, because it carried no
log lines at all.

No credential, no DSN, no probe source address, no policy body, no RPC name and
no raw upstream error appears, and nothing here widens access to anything.
Withheld per the practice READ SIXTH set: the state of the live endorsement
vote, any operational read on production sessions, and anything describing this
container's own reporting or credential tooling, which READ EIGHTEENTH records
as a BLOCKER class.

## READ TWENTY-SECOND: the 12:24 UTC sweep, one hour boundary observed directly, and a branch check that passed for the wrong reason

Swept the 24 hours to 2026-08-05 12:24 UTC. No code change: no defect fired in
the genuinely new observation.

Two findings. The first is a partial answer to the test READ TWENTY-FIRST
registered, and it is narrower than it first looked: one hour boundary is now
directly evidenced rather than inferred from an absent rollup, which is new, and
one boundary is not the emitter stopping, which is not. The second is a defect
in this run's own method, recorded at the bottom, where the prescribed git check
was run against the wrong ref and returned a false pass.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 10:20 UTC, so only about 2 hours is new observation.

Carve out the watchdog the way READ EIGHTEENTH insists rather than writing
"nothing else fired". ENDORSEMENT-SCORER-4 reads 359 on both axes, as it has in
most recent sweeps, and a FLAT rolling 24 hour count of a periodic emitter means
events kept landing as old ones aged out. It is correctly ignored, so it is
excluded on purpose, not absent.

THE TEST WAS RUN FIRST, AND IT RETURNED A USABLE ANSWER
READ TWENTY-FIRST left a pre-registered test, to be run before anything else:
look for any `supabase-platform` event after 2026-08-05 08:15:06, and count only
a SUPABASE-PLATFORM-1 rollup whose window covers an hour boundary, because the
non-fatal catch sits on the postgres query alone.

One exists, and it is exactly the shape the test asked for. A rollup landed at
12:05:07 with `window_start` 11:59:03.845 and `window_end` 12:04:01.268, so its
window covers the 12:00 boundary. Its `by_message` carries ONE key,
`duplicate key value violates unique constraint "?"` at 32, and its `count` is
32. There is no `invalid input syntax for type uuid: "?"` line in it.

Every way that observation could be an artefact was checked and each is
excluded by the event's own fields:

- The postgres query did not fail silently. The catch returns `[]`, and the
  emit is guarded by `if (pgRows.length > 0)`, so a swallowed failure produces
  NO event at all. An event carrying 32 rows proves the query returned them.
- The 15 key `by_message` cap did not truncate it. There is one key.
- The `limit 200` did not drop it. The query returned 32 rows, well under it.
- The line probably did not fall outside the window, and this one is a
  regularity rather than a proof. Every occurrence in this file that carries a
  RECORDED SECOND lands between HH:00:04 and HH:00:10, eleven of them, and the
  window opens about 56 seconds before the hour and closes four minutes after
  it. Scope that honestly: the MAJORITY of captured occurrences in this file are
  written at hour precision only, and one is recorded as "(no ts)" and located
  only to its window, where READ NINETEENTH and READ TWENTY-FIRST both forbid
  inferring a position. So no recorded offset falls outside this window, and
  that is not the same as none ever could.

So at the 12:00 boundary the hourly uuid line was not written to
`postgres_logs` inside 11:59:03.845 to 12:04:01.268. State it with the interval
attached, because the interval is the claim. A line landing after 12:04:01 would
fall into the next window, and no rollup exists there, which is exactly the
ambiguous case this section treats as uninformative everywhere else.

That is a direct observation for one window rather than an inference from an
absent rollup, and it is genuinely new: READ TWENTIETH and READ TWENTY-FIRST
had no boundary observation of this kind at all. Do NOT read it as the general
emitter-stopped claim those sections declined to make. They declined a claim
about the emitter; this establishes a fact about one window. Conflating the two
is how the last two sweeps went wrong.

THE SAME ROLLUP CARRIES THE CONTROL, WHICH IS WHY THIS IS WORTH BELIEVING
The strength here is not the miss on its own. It is that ONE rollup contains
both emitters and only one of them changed.

`e79339b`'s sponsors burst is in that same window at an unchanged 32 lines, on
its usual 6 hour cycle. So the same query, in the same five minute window, still
sees the other undeployed fix's emitter firing at full size. A dead relay or a
failed query is all-or-nothing against the whole window, so neither can take one
emitter and leave the other in the same tally.

Be exact about truncation rather than sweeping it in with those two, which an
earlier draft did and which is wrong on the mechanism: both relay-side
truncations are per-item BY CONSTRUCTION, `limit 200` dropping rows past the two
hundredth and the cap dropping keys past the fifteenth. Truncation is excluded
here by the counts in the bullet list above, 32 rows against 200 and one key
against 15, not by any all-or-nothing property it does not have.

Do NOT extend the control to every capture level problem either. Per-line loss
in the ingestion pipeline ABOVE `postgres_logs` drops one line and delivers the
other 32, so the control is silent about it. What the control excludes is
relay-side and query-side artefacts, which is what it was built for.

That control also bears on the reading that somebody bulk deployed the edge
functions, which READ FIRST warns is a real hazard. Scope the mechanism the way
READ FIRST does rather than assuming it: a deployed `e79339b` clears this line
OR converts it to a `42P10` if the ON CONFLICT target does not match a real
unique index, since that constraint's exact column coverage has never been
confirmed. The window carries 32 unchanged duplicate key lines and no `42P10`,
which is inconsistent with a deployed copy on either branch. Exactly one of the
two emitters changed, so a bulk deploy is not what happened.

ONE BOUNDARY IS NOT A TREND, AND THE TEST FOR THE NEXT RUN
Direct evidence covers exactly ONE boundary. READ FOURTH records hour 16 on
2026-08-03 as a window hour carrying no uuid line and says one gap proves
nothing by itself; READ TWENTIETH's own threshold calls two misses not worth
believing. This section does not overturn either, and a heading claiming the
emitter has stopped would be the third consecutive sweep to make that mistake,
which READ TWENTY-FIRST spent a whole section cataloguing.

So the test is registered rather than concluded. Check the 13:00 and 14:00
boundaries, and count a boundary only when a SUPABASE-PLATFORM-1 rollup's
`window_start` to `window_end` covers it, per READ TWENTY-FIRST. Three or four
consecutive DIRECTLY EVIDENCED boundaries is a step change worth believing. One
is not.

WHAT THIS DOES NOT ESTABLISH, AND THE PART THAT MAY NEED ANDREW
It does NOT establish that `1cdb96e` was deployed. Several causes produce an
identical observation and nothing here separates them. Three are persistent: a
hand deploy of `sync-google-calendar`, that function's hourly cron job being
disabled, or the job being rescheduled off the hour. At least two more are
TRANSIENT, and an earlier draft omitted the whole family, which matters because a
transient cause predicts the line reappearing at 13:00 and a persistent one does
not. A single failed or skipped execution at 12:00 produces this. So does
READ FOURTH's conditionality case, a run that executed but threw upstream of the
statement that writes the uuid: a Google API failure would do it and would leave
this exact trace.

One more sits outside the function entirely: the line may have been written and
lost before it reached `postgres_logs`. Per-line loss in a log ingestion
pipeline delivers 32 rows and drops a thirty-third, which is precisely the shape
observed, and no relay-side reasoning can exclude it because it happens upstream
of the query. So "not written to `postgres_logs`" does not license "the emitter
did not write it".

No commit in either repo records a deploy of that function, which is checked
rather than assumed, though READ FIRST's whole subject is that a hand deploy
leaves no trace in either repo anyway.

Read the ambiguity the right way round, because the cheerful reading is the one
that would be embarrassing to get wrong. If the function was deployed, the error
stopped because the bug is fixed, and that is good. If the cron job was disabled
or is failing to start, the error stopped because the Google Calendar sync is no
longer running, and a silent feature outage looks EXACTLY like a fixed bug from
here. An error going quiet is not by itself good news.

Nothing in this container can tell those apart:
`supabase functions list` and the cron job's own schedule both need dashboard or
CLI access. It is one look for Andrew and it is the only item this run raises.

THE GAP IS THE ORDINARY QUIET CASE
There is no rollup at all between 08:15:06 and 12:05:07, a gap of 3 hours 50
minutes. That is not a symptom. The relay emits a postgres rollup only under
`if (pgRows.length > 0)`, so an absent rollup means the window carried no ERROR
or FATAL row, or the query failed silently.

With the query demonstrably working before the gap and after it, the silent
failure reading requires a failure that began after 08:14:02 and recovered by
11:59:03, covering 45 consecutive five minute slots. Anchor that to the last
good `window_end` rather than to its `window_start`, which is READ TWENTIETH's
catalogued anchoring error: the query succeeded through 08:14:02, so the
interval is 225 minutes and not the 230 that anchoring to 08:09:01 gives. That
reading is possible and is not disprovable from here, but it is no longer the
simpler one. The simpler one is that the database was quiet: the ad hoc
hand SQL family that READ SEVENTEENTH attributes to Andrew's own membership
audit has stopped, and the scan noise families were already recorded as unusually
quiet across READ NINETEENTH and READ TWENTIETH.

Do not upgrade that into a claim that the scan traffic has stopped. Both of
those sections declined to draw a conclusion from a sample this small and said
so in terms; this window adds no reason to overturn that.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on the only event after 10:20 UTC, per READ SEVENTH. Thirty
two log lines, which is the single event's `count`:

    32  duplicate key value violates unique constraint "?"   the 12:00 cycle

No probe shape of any kind: no filtered password FATAL, neither malformed
startup packet family, and no SASL Terminate line. No ad hoc hand SQL family
line. Nothing else at all.

THE UNDEPLOYED FIXES
`e79339b` is confirmed still undeployed from direct evidence, the 12:00 cycle at
an unchanged 32 lines, read this run rather than inherited. `0d2963e` and
`285a05f` are not observable in this slice, since SUPABASE-PLATFORM-3 produced
no event and has now aged out of the window entirely.

Day counts as of the window close, computed with `git show -s --format=%cI` and
FLOORED per READ TWELFTH rather than carried forward: `1cdb96e` at 10 days,
`e79339b` at 9, `0d2963e` at 5, `285a05f` at under 24 hours. None crossed a
boundary since the 10:20 sweep.

`1cdb96e`'s count is kept running deliberately. READ TWENTIETH, not READ
TWENTY-FIRST, is the section saying that if the emitter has genuinely stopped
then that day count stops mattering; READ TWENTY-FIRST's instruction is the
opposite emphasis, to "treat `1cdb96e` as OPEN and leave its day count running",
and that is the one followed here. Its premise is not met anyway: one window is
not the emitter stopping. Its SYMPTOM was absent from one window; whether the
FIX shipped has not been established. Stop tracking it when a deploy is
confirmed, not when the log goes quiet.

The blocker was re-checked rather than inherited, per READ TWELFTH: nothing
matching `SUPABASE` or `PROJECT_REF` is in this container's environment.
READ SEVENTEENTH's sharper version of the ask stands for the remaining three.

NOTHING ELSE FIRED, THE WATCHDOG ASIDE
Every other issue's newest event predates the new slice, so all are the same
occurrences the sections above document rather than recurrences, and none was
resolved or re-resolved.

The newest `flutter` event of any kind is still 2026-08-04 19:34:33, which is 76
minutes BEFORE `6ff6a45` landed at 20:50:30, so FLUTTER-8, -B and -X have not
fired since that fix. Do not read that as the fix confirmed in production:
Sentry cannot tell a working fix from an unused app, since both emit nothing,
per READ NINETEENTH. That quiet now stands at about 16 hours 50 minutes.
FLUTTER-Y and FLUTTER-6 are the `RenderBox was not laid out` pair with zero
first party frames, left alone per READ FOURTEENTH. FLUTTER-5 is browser
transport. SUPABASE-PLATFORM-4's only event is the 12:55:16 `form-uploads` probe
READ ELEVENTH documents, which ages out at 12:55:16 today, about 31 minutes
after this window closed. MAUTIC-H's
three are the probe POSTs READ SIXTEENTH records.

SUPABASE-PLATFORM-3 HAS AGED OUT ENTIRELY
Its only event was the 12:10:02 429 on 2026-08-04, which now falls outside a
window opening at 12:24, so the issue carries no in window event and is absent
from the census below. Apply the aging rule everywhere or it is not a rule,
which READ TWENTIETH records as a caught defect. This is not the 429 having been
fixed: `285a05f` is still undeployed, and the issue will reappear the next time
the relay is throttled.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 81, flutter 33,
                 mautic 3                                                  = 476
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 80, -4 1                              =  81
                 FLUTTER-B 10, -8 10, -X 9, -5 2, -Y 1, -6 1               =  33
                 MAUTIC-H 3                                                =   3
                                                                             476

Both axes agree exactly. `website`, `moydforms`, `n8n` and `supabase-edge` at
zero. Queried with NO status filter per READ EIGHTH, which is how the ignored
watchdog and the resolved `flutter` issues stayed visible. Read READ TWELFTH's
caveat on what the equality does and does not buy.

The resolved issues still carrying in window events are FLUTTER-8 and FLUTTER-5,
both set resolved by somebody else. Neither status was touched by this run, per
READ EIGHTH. They ARE resolved, by someone else; what this run declined to do is
touch a status.

THE BRANCH REF TRAP, SIXTEENTH RUN, AND THIS RUN FAILED THE CHECK BEFORE IT
PASSED IT
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `c3b6d67`, and the
sibling's `main` at `77d879f` against a real `308ef92`. That is the same stale
PAIR READ EIGHTEENTH enumerates. Repaired with
`git -C <path> checkout -B <branch> HEAD` per READ NINTH.

An earlier draft of this section reported the OPPOSITE, that the trap had not
bitten and this was only the second clean run on record. That was false, an
adversarial auditor caught it as a BLOCKER, and the mechanism is worth more than
the correction because READ SECOND predicted the CLASS of it. Not the instance:
the paragraph below is careful that this is a sibling of READ SECOND's failure
rather than a repeat of it.

The check is `git ls-remote --heads origin <branch>` against
`git rev-parse <branch>`. What this run actually ran was `git rev-parse HEAD`,
compared HEAD against the remote, got agreement, and read that agreement as the
check passing. It is not the check. HEAD was detached AT the true tip, so
comparing it to the remote compares the tip with itself and cannot fail, while
the named branch that `git checkout master` would have moved onto sat at
`5d8a5b0` of 2026-08-01, 3 days 16 hours and 35 commits behind the tip, FLOORED
against the tip's own commit time per READ TWELFTH rather than rounded.

READ SECOND's 2026-08-03 addendum documents a sibling failure, a stale
`origin/master`, and says a wrong ref "answers confidently and wrongly". That is
the rule these two share. Do NOT describe the two tells as the same one, which
an earlier draft did and which would have made this paragraph actively
misleading: READ SECOND's commands were `git rev-parse origin/master`,
`git log origin/master` and `git status`, and the branch NAME is right there in
the first two. What was missing there was a fetch. What was missing here was the
right KIND of ref.

So the inheritable guard is not "check the branch name appears in the command",
which passes cleanly on READ SECOND's own failure and would send a future run
back into it. It is a STRENGTHENED form of READ SECOND's rule, restated as a
rule about ref kind: the local side of the comparison must be
`refs/heads/<branch>` itself, not `HEAD`, which is this run's failure, and not
`origin/<branch>`, which is READ SECOND's.

Mark the strengthening rather than passing it off as the original, which is the
miscitation class this file keeps catching. READ SECOND's rule is that
`origin/<branch>` "is not evidence about the remote until you have fetched in
this container", so it ADMITS a freshly fetched remote tracking ref. The version
above admits only `git ls-remote` output. That is stricter than READ SECOND
requires, and deliberately so, because a fetch and a stale cache are
indistinguishable by inspection afterwards while an `ls-remote` result cannot be
stale. A future run that has genuinely fetched in this container is following
READ SECOND correctly and is not making this run's mistake.

One more consequence worth inheriting, scoped rather than stated as a universal.
In THIS container's shape, HEAD detached at the true tip, the wrong command can
only produce a false PASS: it compares the tip with itself. That is a property
of the shape and not of the substitution. The mirror case, HEAD detached at a
stale commit while the branch sits at the tip, makes the same wrong command
produce a false FAIL. So re-derive a clean result on this check rather than
accepting it, because in the container shape these runs keep meeting, clean is
the answer the wrong command always gives.

The ordinal is recomputed from bites recorded in this file rather than
incremented, per READ NINETEENTH, and it counts this run as a bite. Keep running
the check, per READ SECOND. `git ls-remote` was re-run immediately before
committing per READ FOURTEENTH.

DISCLOSURE CHECK, PER READ THIRD
This repo is public. Enumerated rather than waved at, per READ EIGHTEENTH, and
this is a claim to CHECK rather than a habit.

Named above: the commits `1cdb96e`, `e79339b`, `0d2963e`, `285a05f` and
`6ff6a45`; the function `sync-google-calendar` and the command
`supabase functions list`; the constraint `legislation_bill_sponsors_unique`
and the SQLSTATE `42P10` with the clause `ON CONFLICT` it is raised against; the
relay internals `window_start`, `window_end`, `by_message`, `count`, `pgRows`,
`postgres_logs` and the `limit 200` and 15 key caps; the `form-uploads` bucket;
the issue ids and project names; the tips `c3b6d67` and `308ef92`, the stale
refs `5d8a5b0` and `77d879f`, and the remote tracking ref `origin/master`; and
the env var name patterns `SUPABASE` and `PROJECT_REF`.
Every one already appears in this file or is committed in this public repo's own
tree. `308ef92` is the private sibling's tip, and its cover IS prior
publication: READ TWENTIETH published it as a deliberate first publication.
Check WHICH repo published a thing before citing prior publication as cover, per
READ SEVENTEENTH.

Swept in rather than argued about, per READ TWENTIETH, each caught by an auditor
as missing from an earlier draft of this list: the git commands `git ls-remote`,
`git rev-parse`, `git checkout -B`, `git show -s --format=%cI`, `git log`,
`git status` and `git rev-list --count`, plus the ref path
`refs/heads/<branch>`, all generic plumbing already published throughout this
file and the first three of them verbatim in READ SECOND, and the third party
name
Google, which names the calendar API the synced function talks to and is already
in that function's own committed name.

Per READ EIGHTEENTH's carve out, quoted log CONTENT here is the normalized
duplicate key message, the uuid message shape and the string
`RenderBox was not laid out`, all published in this file since READ FIRST and
READ FOURTEENTH. This slice carried no log content that is not already public.

No credential, no DSN, no probe source address, no policy body, no RPC name and
no raw upstream error appears, and nothing here widens access to anything.
Withheld per the practice READ SIXTH set: the state of the live endorsement
vote, any operational read on production sessions, and anything describing this
container's own reporting or credential tooling, which READ EIGHTEENTH records
as a BLOCKER class.

## READ TWENTY-THIRD: the 14:26 UTC sweep, a pre-registered test that came back uninformative, and a dead-relay reading the PREVIOUS sweep had already retired

Swept the 24 hours to 2026-08-05 14:26 UTC. No code change: the only log line in
the genuinely new observation is scan noise. Short by design, per READ TWELFTH.

Per the overlap warning in READ FOURTH: this window shares 22 hours with the
sweep that closed at 12:24 UTC, so only about 2 hours 2 minutes is new
observation. Nothing below independently confirms anything above it.

Carve out the watchdog the way READ EIGHTEENTH insists rather than writing
"nothing else fired". ENDORSEMENT-SCORER-4 reads 359 on both axes, and a FLAT
rolling 24 hour count of a periodic emitter means events kept landing as old
ones aged out. It is correctly ignored, so it is excluded on purpose.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on the only SUPABASE-PLATFORM-1 event after 12:24 UTC, per
READ SEVENTH. One log line, which is that event's `count`:

    13:07:25.971  unsupported frontend protocol 65363.19778   FATAL

That is the malformed startup packet family READ FOURTH enumerates as shape 4,
and specifically the SMB1 fingerprint READ FIRST decodes: 65363 is 0xFF53 and
19778 is 0x4D42, so the four version bytes are `\xFFSMB`, which begins at offset
4 where Postgres expects the protocol version because SMB1 over TCP carries a
4-byte NetBIOS session header. Scan noise, and the same value READ FOURTH
already lists among the observed set.

Do not read its reappearance as a trend in either direction, and do not flatten
the intervening record either way. It is mixed rather than empty, and in TWO ways rather
than one. READ TWELFTH, READ SIXTEENTH and READ EIGHTEENTH each enumerated the
protocol values in their own slices and this value appears in none of them.
Separately, READ THIRTEENTH, FIFTEENTH, SEVENTEENTH, NINETEENTH, TWENTIETH and
TWENTY-SECOND each recorded the malformed startup packet family wholly ABSENT
from a slice they decomposed in full, and family absence entails this value's
absence just as firmly. Both classes are genuine observed absences, so do not
write the second class off as an enumeration gap; only the sweeps that neither
enumerated values nor recorded the family leave real gaps. So the
record supports neither a clean absence nor a continuous presence, and READ
FOURTH's instruction not to treat any list of these values as exhaustive still
stands.

Nothing else was in the slice, and that follows from the event's `count` of 1
rather than from any severity argument. So the ad hoc hand SQL family that READ
SEVENTEENTH attributes to Andrew's own membership audit produced nothing, and
neither did the filtered password family. Do not derive the second of those from
the first: the password family is FATAL, so its absence does not follow from an
absence of ERROR level lines, and only the count settles it.

THE PRE-REGISTERED TEST WAS RUN AND CAME BACK UNINFORMATIVE, WHICH IS NOT THE
SAME AS NEGATIVE
READ TWENTY-SECOND registered a test rather than concluding one: check the 13:00
and 14:00 boundaries for the hourly `invalid input syntax for type uuid: "cron"`
line, and count a boundary ONLY when a SUPABASE-PLATFORM-1 rollup's
`window_start` to `window_end` covers it. Credit that counting rule to READ
TWENTY-FIRST, which states it; READ TWENTY-SECOND registered the test per READ
TWENTY-FIRST rather than inventing the rule.

Neither boundary qualifies. Two rollups bear on the question, and only one of
them is in this window's new ground: the 12:05:07 rollup, which READ
TWENTY-SECOND already read and which predates the 12:24 start of the new slice,
and the 13:10:07 rollup read here, which carries `window_start` 13:04:04.098 and
`window_end` 13:09:02.235. Neither span touches 13:00, and no rollup exists at
all whose window reaches 14:00. So this run adds ZERO directly evidenced
boundaries, and the count stands where READ TWENTY-SECOND left it, at ONE.

Be exact about why the 13:00 boundary is uninformative rather than a miss,
because the tempting reading is available and wrong. The 13:10 rollup's
`window_start` of 13:04:04.098 is CONSISTENT WITH the watermark having kept pace
across the gap: per READ FIRST a skipped or failed run leaves the NEXT window
wider, capped at 60 minutes, and a clean five minute window is not that.

Do not upgrade that to proof, which READ TWENTY-FIRST already caught a draft of
its own doing in this exact place. A relay that stalled after 12:04 and resumed
near 13:00 with a single UNCAPPED catch-up window, then ran two ordinary five
minute ones, reproduces the observed clean window without the watermark having
kept pace at all.

Say uncapped rather than capped, and check the cadence before repeating this
counterexample, because two successive auditors corrected this one paragraph in
opposite directions. READ TWENTY-SECOND puts the 12:05:07 rollup's `window_end`
at 12:04:01.268, so a run that hits the 60 minute cap from there ends at exactly
13:04:01.268, and watermark contiguity forces the IMMEDIATE successor to start
on that value rather than on the observed 13:04:04.098.

That is where the first correction stopped, and it does not reach far enough to
call the capped form impossible. A second run can bridge 13:04:01.268 to
13:04:04.098, after which the observed window follows exactly, so every observed
field IS reproducible with a capped catch-up. What actually rules it out is the
SCHEDULE and not the arithmetic: that bridge is 2.83 seconds wide, and a five
minute cron cannot fire twice inside three seconds. Write it as schedule
unavailable. A resume before roughly 13:05 never reaches the cap at all, which
is what makes the uncapped form the one to reach for.

What the `window_start` DOES establish is the load-bearing part and needs no
assumption at all: every span up to 13:04:04, 13:00 included, was consumed by
some run.

What is not observable is whether the postgres query in that run succeeded,
because READ FIRST's non-fatal catch substitutes an empty row set and the
watermark advances either way. An empty window and a swallowed query are
indistinguishable from here, which is exactly the ambiguous case the counting
rule exists to exclude.

Re-register the test unchanged for the next run: check 15:00 and 16:00, count
only a rollup whose window covers the boundary, and remember that three or four
consecutive DIRECTLY EVIDENCED boundaries is the threshold. One is not a trend,
and this run did not add to it.

THE DEAD-RELAY READING IS RETIRED, AND THE PREVIOUS SWEEP ALREADY RETIRED IT
READ TWENTY-FIRST built a whole branch on the possibility that the relay had
been silent since 2026-08-05 08:15:06, and instructed the next run to look for
any `supabase-platform` event after that timestamp before anything else. Two
exist: the 12:05:07 rollup READ TWENTY-SECOND read, and the 13:10:07 rollup read
here.

Be honest about which run settled it, because the tempting heading is that this
one did. On READ TWENTY-FIRST's own terms, one qualifying event is enough, so
the 12:05:07 rollup already satisfied the test at the previous sweep. This run
adds a second data point and an extra 65 minutes of coverage, not the
settlement.

Present tense is also more than the observation carries, per READ FIRST's
caveat: what is established is that the relay was emitting as of 13:10:07, which
is 76 minutes before this window closed. That gap is better read as the ordinary
quiet case than as evidence of anything, which is a preference between readings
and not a classification of it.

Scope that correctly rather than letting it do more work than it can. The
ordinary quiet case is the SIMPLER reading of the empty stretches in this
window, which is where READ TWENTY-SECOND deliberately left it and is not the
same as establishing it. Two things keep it from being more: the stall
counterexample above is itself a transient reporting outage that reproduces what
was observed, and a swallowed query is a reporting failure that produces an
empty stretch from a perfectly live relay. The 13:10 to 14:26 stretch has no
relay observation covering it at all. It does NOT convert any of those stretches
into evidence about
the cron emitter, for the swallowed-query reason above, and it is not evidence
that `1cdb96e` deployed. Treat that commit as OPEN and leave its day count
running, per READ TWENTY-FIRST.

SUPABASE-PLATFORM-4 HAS AGED OUT ENTIRELY
Its last event was the 12:55:16 `form-uploads` probe on 2026-08-04 that READ
ELEVENTH documents, which now falls outside a window opening at 14:26. The issue
carries no in window event and is absent from the census below. Apply the aging
rule everywhere or it is not a rule, per READ TWENTIETH. This is not that probe
having been fixed; nothing was changed for it and nothing should be.

DAY COUNTS, RECOMPUTED AND NOT CARRIED FORWARD
With `git show -s --format=%cI` and FLOORED against the 14:26 window close, per
READ TWELFTH: `1cdb96e` at 10 days, `e79339b` at 9, `0d2963e` at 5, `285a05f` at
1 day.

`285a05f` reads 1 day where READ TWENTY-SECOND read "under 24 hours". That is
real elapsed time rather than the arithmetic drift READ SEVENTEENTH warns about:
it landed 2026-08-04T12:43:21 UTC and crossed its first day boundary at 12:43
today, nineteen minutes AFTER the previous sweep closed at 12:24. Recompute
rather than assume in either direction.

`e79339b` is not directly observable in this slice because no 6 hour boundary
falls inside 12:24 to 14:26. READ TWENTY-SECOND confirmed it directly at the
12:00 cycle, 32 lines and unchanged.

The blocker was re-checked rather than inherited, per READ TWELFTH: nothing
matching `SUPABASE` or `PROJECT_REF` is in this container's environment. Record
the absence and stop there, per READ THIRTEENTH: an inventory of what this
container does or does not carry beyond that serves nobody but someone probing
it, and READ EIGHTEENTH records that class as a BLOCKER. READ SEVENTEENTH's
sharper version of the ask stands for all four.

NOTHING ELSE FIRED, THE WATCHDOG ASIDE
Every other issue's newest event predates the new slice, so all are the same
occurrences the sections above document rather than recurrences, and none was
resolved or re-resolved.

FLUTTER-8, -B and -X still have not fired since `6ff6a45` landed at 20:50:30 on
2026-08-04, their newest event of any kind being 19:34:33 that day, 76 minutes
before the fix. Do not read that as the fix confirmed in production: Sentry
cannot tell a working fix from an unused app, since both emit nothing, per READ
NINETEENTH. That quiet now stands at about 18 hours 52 minutes. FLUTTER-Y and
FLUTTER-6 are the `RenderBox was not laid out` pair with zero first party
frames, left alone per READ FOURTEENTH; each carries one event and no mechanism
is establishable from this repo plus the event, so nothing was guessed at.
FLUTTER-5 is browser transport. MAUTIC-H's three are the probe POSTs READ
SIXTEENTH records, against a deliberately probe-shaped address, and there is no
droplet access anyway.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 73, flutter 33,
                 mautic 3                                                  = 468
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 73                                    =  73
                 FLUTTER-B 10, -8 10, -X 9, -5 2, -Y 1, -6 1               =  33
                 MAUTIC-H 3                                                =   3
                                                                             468

Both axes agree exactly. `website`, `moydforms`, `n8n` and `supabase-edge` at
zero. Queried with NO status filter per READ EIGHTH, which is how the ignored
watchdog and the resolved `flutter` issues stayed visible. Read READ TWELFTH's
caveat on what the equality does and does not buy, and note it buys nothing
about the cron question above: a census of what arrived cannot detect what was
never sent.

`supabase-platform` is the whole of SUPABASE-PLATFORM-1 for the first time in
this record, since -3 aged out at the 12:24 sweep and -4 aged out at this one.

The resolved issues still carrying in window events are FLUTTER-8 and FLUTTER-5,
both set resolved by somebody else. Neither status was touched by this run, per
READ EIGHTH. They ARE resolved, by someone else; what this run declined to do is
touch a status.

THE BRANCH REF TRAP, SEVENTEENTH RUN
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `db76014`, and the
sibling's `main` at `77d879f` against a real `308ef92`. That is the same stale
PAIR READ EIGHTEENTH enumerates; per its instruction this is one more
correlation and not a mechanism, so keep running the check.

The check was run in the form READ TWENTY-SECOND prescribes after its own false
pass: `git ls-remote --heads origin <branch>` against `git rev-parse <branch>`,
with the local side being the NAMED BRANCH and not `HEAD`. That form is what
surfaced the staleness here, and the wrong form would have compared the detached
tip with itself and returned clean, exactly as it did for READ TWENTY-SECOND.
Repaired with `git -C <path> checkout -B <branch> HEAD` per READ NINTH, and
`git ls-remote` re-run immediately before committing per READ FOURTEENTH. The
ordinal is recomputed from bites recorded in this file rather than incremented,
per READ NINETEENTH.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. Enumerated rather than waved at,
per READ EIGHTEENTH, and this is a claim to CHECK rather than a habit.

Named above: the commits `1cdb96e`, `e79339b`, `0d2963e`, `285a05f` and
`6ff6a45`; the issue ids and project names; the relay internals `window_start`,
`window_end`, `by_message` and `count`; the `form-uploads` bucket; the word
droplet, in the note that there is no droplet access, published here since READ
SEVENTEENTH; the git commands `git ls-remote`, `git rev-parse`, `git checkout -B` and
`git show -s --format=%cI` with the ref path forms they take; the stale refs
`5d8a5b0` and `77d879f`; this repo's real tip `db76014`; the sibling's real tip
`308ef92`; and the env var name patterns `SUPABASE` and `PROJECT_REF`. Every one
already appears in this file or is committed in this public repo's own tree.
`308ef92` is the private sibling's tip and its cover IS prior publication, since
READ TWENTIETH published it as a deliberate first publication; check WHICH repo
published a thing before citing prior publication as cover, per READ SEVENTEENTH.

Per READ EIGHTEENTH's carve out, quoted log CONTENT here is the protocol value
`65363.19778` with its byte decoding, the uuid message shape, the string
`RenderBox was not laid out` and the Sentry rollup field names, all published in
this file since READ FIRST and READ FOURTEENTH. This slice carried no log
content that is not already public. Its one line does name a value, the protocol
number itself, and that value is published in this file from READ FIRST onward;
what it names nothing of is a table, a column, a row, a person or an address.

No credential, no DSN, no probe source address, no policy body, no RPC name and
no raw upstream error appears, and nothing here widens access to anything.
Withheld per the practice READ SIXTH set: the state of the live endorsement
vote, any operational read on production sessions, and anything describing this
container's own reporting or credential tooling, which READ EIGHTEENTH records
as a BLOCKER class.

## READ TWENTY-FOURTH: the 16:20 UTC sweep, an empty slice, and the cron test uninformative a second time

Swept the 24 hours to 2026-08-05 16:20 UTC. No code change: nothing fired in the
genuinely new observation. Short by design, per READ TWELFTH.

Per the overlap warning in READ FOURTH: this window shares about 22 hours with the
sweep that closed at 14:26 UTC, so only about 1 hour 54 minutes is new observation.
Nothing below independently confirms anything above it.

Carve out the watchdog the way READ EIGHTEENTH insists rather than writing "nothing
else fired". ENDORSEMENT-SCORER-4 reads 358 on both axes, and a FLAT rolling 24 hour
count of a periodic emitter means events kept landing as old ones aged out. It is
correctly ignored, so it is excluded on purpose, not absent.

THE NEW SLICE IS EMPTY, AND THAT CUTS BOTH WAYS
The newest event inside this window outside the watchdog is SUPABASE-PLATFORM-1 at
13:10:07, which READ TWENTY-THIRD already read and decomposed as one SMB fingerprint
FATAL. So there is no new event to classify and no `by_message` left unread. One
rollup landed AFTER the close and is recorded below; it is outside every count here.

Do not book that as good news, per READ TWENTY-FIRST. A relay that stopped after
13:10 produces an empty slice too, and emptiness is the one observation a healthy
quiet system and a dead reporting pipeline share.

THE PRE-REGISTERED TEST CAME BACK UNINFORMATIVE, FOR THE SECOND RUN RUNNING
READ TWENTY-THIRD registered: check the 15:00 and 16:00 boundaries for the hourly
`invalid input syntax for type uuid: "cron"` line, counting a boundary ONLY when a
SUPABASE-PLATFORM-1 rollup's `window_start` to `window_end` covers it, which is READ
TWENTY-FIRST's rule rather than READ TWENTY-THIRD's.

Neither qualifies. No rollup exists after 13:10:07 anywhere inside this window, so
neither boundary has a covering window, and neither even has the watermark contiguity
evidence READ TWENTY-THIRD could appeal to for 13:00. The one rollup that landed after
the close, recorded below, covers neither the 15:00 nor the 16:00 boundary either. So
this run adds ZERO directly evidenced boundaries, and the count stands where READ
TWENTY-SECOND left it, at ONE.

THE ONE EVIDENCED BOUNDARY, RE-READ RATHER THAN INHERITED
READ FOURTEENTH says not to inherit a group's diagnosis, so the 12:05:07 rollup was
re-read from its own extras this run rather than carried forward. It holds exactly:
`window_start` 11:59:03.845 and `window_end` 12:04:01.268, so the window covers
12:00; `by_message` carries ONE key, the normalized duplicate key message at 32;
`count` is 32 and `by_severity` is ERROR 32. One key against the 15 key cap and 32
rows against `limit 200`, so neither truncation applies, and a returned row set
excludes the swallowed query. No uuid line in it.

The control in that same tally is what makes it worth believing, and it is READ
TWENTY-SECOND's argument rather than a new one: the sponsors burst is in the same
window at an unchanged 32 lines, sampled at 12:00:35, so the same query in the same
five minute window still sees the other undeployed fix's emitter at full size. A
dead relay or a failed query is all-or-nothing against the whole window and cannot
take one emitter while leaving the other.

TEN HOURLY BOUNDARIES CUMULATIVELY, AND ONLY ONE OF THEM EVIDENCED
The last captured occurrence is still the 06:05 rollup, whose window is 05:59:06.009
to 06:04:01.762, per READ TWENTY-SECOND. That is about 10 hours 16 minutes before
this window closed, spanning the boundaries 07:00 through 16:00. Ten in a row is a
departure from ten days of hourly capture, whose one known exception is hour 16 on
2026-08-03, recorded in READ FOURTH.

Do NOT upgrade that into the emitter having stopped. That would be the fourth sweep
to make the mistake READ TWENTY-FIRST catalogues at length, and nine of the ten
boundaries have no covering rollup, so a relay that is merely quiet reproduces the
identical observation.

THE RELAY GAP, AND A POST CLOSE OBSERVATION THAT RETIRES THE DEAD RELAY BRANCH
3 hours 10 minutes at window close, against the 3 hours 50 minutes gap READ
TWENTY-SECOND records between 08:15:06 and 12:05:07, which resolved on its own. That
is ONE precedent rather than a pattern, and READ TWENTY-THIRD deliberately declined to
call the quiet database reading established rather than merely simpler. Do not upgrade
it here either.

What does move it, and it falls OUTSIDE this window so it changes no count above: a
rollup landed at 16:30:06, ten minutes after the close. Its window is 16:24:04.751 to
16:29:02.810, a clean five minutes rather than the widened catch-up READ FIRST says a
skipped or failed run leaves behind, which is CONSISTENT WITH the watermark having
kept pace and establishes that every span up to 16:24:04 was consumed by some run
before it. Do not upgrade that to proof, which is the correction READ TWENTY-THIRD
already made on itself from this identical evidence shape: a relay that stalled and
resumed walks forward from the stale watermark in capped windows, those catch-up runs
emit nothing on an empty row set, and the next ordinary run then shows exactly this
clean window. It carries 3 FATAL lines and all of them are scan noise: `unsupported
frontend protocol` twice, at 255.255 and 0.0, and `no PostgreSQL user name specified
in startup packet` once, which are the two malformed startup packet families READ
FOURTH enumerates as shapes 4 and 5.

So the relay WAS EMITTING as of 16:30:06, in the past tense READ TWENTY-THIRD insists
on, and on READ TWENTY-FIRST's own test terms one qualifying event is enough to retire
the dead relay branch again. Scope it to that: it establishes emission at 16:30:06 and
span contiguity back to 16:24:04, and nothing else. It does NOT establish that runs
fired at 14:05, 15:05 or 16:05, its window covers neither the 15:00 nor the 16:00
boundary, so it adds no directly evidenced boundary and the count above still stands
at ONE.

WHAT NEEDS ANDREW, AND IT IS ONE LOOK
Read the ambiguity the right way round, per READ TWENTY-SECOND. If
`sync-google-calendar` was hand deployed, the error stopped because `1cdb96e` fixed
it, and that is good. If its hourly cron job is disabled or failing to start, the
error stopped because the Google Calendar sync is no longer running, and a silent
feature outage looks EXACTLY like a fixed bug from here. An error going quiet is not
by itself good news.

Nothing in this container can tell those apart: `supabase functions list` and the
job's own schedule both need dashboard or CLI access. Treat `1cdb96e` as OPEN and
leave its day count running, per READ TWENTY-FIRST.

DAY COUNTS, RECOMPUTED AND NOT CARRIED FORWARD
With `git show -s --format=%cI` and FLOORED against the 16:20 close, per READ
TWELFTH: `1cdb96e` at 10 days, `e79339b` at 9, `0d2963e` at 5, `285a05f` at 1. None
crossed a boundary since the 14:26 sweep. `e79339b` is not observable in this slice
because no 6 hour boundary falls inside 14:26 to 16:20; the 12:00 cycle above is its
most recent direct confirmation.

The blocker was re-checked rather than inherited, per READ TWELFTH: nothing matching
`SUPABASE` or `PROJECT_REF` is in this container's environment. Record the absence
and stop there, per READ THIRTEENTH.

NOTHING ELSE FIRED INSIDE THE WINDOW, THE WATCHDOG ASIDE
Every other issue's newest event INSIDE THIS WINDOW predates the new slice, so all are
the same occurrences the sections above document rather than recurrences, and none was
resolved or re-resolved. Scope that to the window rather than stating it flat: the post
close rollup recorded above is a genuinely new occurrence of the probe family, and it
postdates the slice.

The newest `flutter` event of any kind is 2026-08-04 19:34:33, which is 76 minutes
BEFORE `6ff6a45` landed at 20:50:30, so FLUTTER-8, -B and -X have not fired since
that fix. Do not read that as the fix confirmed in production: Sentry cannot tell a
working fix from an unused app, since both emit nothing, per READ NINETEENTH. That
quiet now stands at 20 hours 45 minutes, floored. FLUTTER-Y and FLUTTER-6 are the
`RenderBox was not laid out` pair with zero first party frames, at 19:32:46 and
19:18:04, left alone per READ FOURTEENTH. FLUTTER-5 is browser transport. MAUTIC-H's
three are the probe POSTs READ SIXTEENTH records, against a deliberately probe
shaped address, and there is no droplet access anyway.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 358, supabase-platform 65, flutter 33,
                 mautic 3                                                  = 459
    by issue     ENDORSEMENT-SCORER-4 358                                  = 358
                 SUPABASE-PLATFORM-1 65                                    =  65
                 FLUTTER-B 10, -8 10, -X 9, -5 2, -Y 1, -6 1               =  33
                 MAUTIC-H 3                                                =   3
                                                                             459

Both axes agree exactly. `website`, `moydforms`, `n8n` and `supabase-edge` at zero.
Queried with NO status filter per READ EIGHTH, which is how the ignored watchdog and
the two resolved `flutter` issues stayed visible. Read READ TWELFTH's caveat on what
the equality does and does not buy, and note it buys nothing about the cron question
above: a census of what arrived cannot detect what was never sent.

`supabase-platform` is wholly SUPABASE-PLATFORM-1 for the second sweep running, -3
having aged out at the 12:24 sweep and -4 at the 14:26 one.

The resolved issues still carrying in window events are FLUTTER-8 and FLUTTER-5,
both set resolved by somebody else. Neither status was touched by this run, per READ
EIGHTH. They ARE resolved, by someone else; what this run declined to do is touch a
status.

THE BRANCH REF TRAP, DELIBERATELY UNNUMBERED
Both repos again presented a stale named branch with `HEAD` detached at the true
remote tip: this repo's `master` at `5d8a5b0` against a real `d2dae70`, and the
sibling's `main` at `77d879f` against a real `308ef92`. That is the same stale PAIR
READ EIGHTEENTH enumerates. The check was run in the form READ TWENTY-SECOND
prescribes after its own false pass, with the local side being the NAMED BRANCH and
not `HEAD`. Repaired with `git -C <path> checkout -B <branch> HEAD` per READ NINTH,
and `git ls-remote` re-run immediately before committing per READ FOURTEENTH.

READ NINETEENTH says to recompute the ordinal from bites recorded in this file rather
than increment the previous section's number. That recount was not run this sweep, so
rather than ship an incremented number the section declares unverified, no ordinal is
quoted at all. This is one more bite. Recount from the recorded bites if the running
count ever needs to be load bearing.

ONE CONTAINER NOTE
`search_issue_events` is not a top level tool in this container. It lives in the
catalog and is reachable as
`execute_sentry_tool(name='search_issue_events', ...)`; calling it directly fails
with "No such tool available". `search_sentry_tools` is how it was found.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. Enumerated rather than waved at, per
READ EIGHTEENTH, and this is a claim to CHECK rather than a habit.

Named above: the commits `1cdb96e`, `e79339b`, `0d2963e`, `285a05f` and `6ff6a45`;
the function `sync-google-calendar` and the command `supabase functions list`; the
constraint `legislation_bill_sponsors_unique`; the relay internals `window_start`,
`window_end`, `by_message`, `by_severity`, `count` and the `limit 200` and 15 key
caps; the issue ids and project names; the git commands `git ls-remote`,
`git rev-parse`, `git checkout -B` and `git show -s --format=%cI`; the stale refs
`5d8a5b0` and `77d879f`; this repo's real tip `d2dae70`; the sibling's real tip
`308ef92`; the env var name patterns `SUPABASE` and `PROJECT_REF`; the Sentry tool
names `search_issue_events`, `search_sentry_tools` and `execute_sentry_tool`; the word
droplet, in the note that there is no droplet access, per READ TWENTY-THIRD which
enumerated it the same way; and the third party name Google Calendar, which READ
TWENTY-SECOND swept in as Google and which is already carried in the committed name of
the function above.
Every one already appears in this file or is committed in this public repo's own
tree, with one exception: `d2dae70` is this PUBLIC repo's own current tip and is
therefore already readable by anyone who can read this sentence. `308ef92` is the
private sibling's tip and its cover IS prior publication, since READ TWENTIETH
published it as a deliberate first publication; check WHICH repo published a thing
before citing prior publication as cover, per READ SEVENTEENTH.

Per READ EIGHTEENTH's carve out, quoted log CONTENT here is the uuid message shape,
the normalized duplicate key message, the string `RenderBox was not laid out`, and
from the post close rollup `unsupported frontend protocol` with the values 255.255 and
0.0 plus `no PostgreSQL user name specified in startup packet`. Every one is published
in this file since READ FIRST and READ FOURTEENTH. The sweep slice itself carried no
log lines at all; the post close lines are scan noise, and they name no table, column,
row, person or address. The probe source address is not reproduced, per READ FIFTH.

No credential, no DSN, no probe source address, no policy body, no RPC name and no
raw upstream error appears, and nothing here widens access to anything. Withheld per
the practice READ SIXTH set: the state of the live endorsement vote, any operational
read on production sessions, and anything describing this container's own reporting
or credential tooling, which READ EIGHTEENTH records as a BLOCKER class.

## READ TWENTY-FIFTH: the 18:21 UTC sweep, a second evidenced boundary miss, and the asymmetry that makes a miss harder to observe than a hit

Swept the 24 hours to 2026-08-05 18:21 UTC. No code change beyond this note: nothing
in the genuinely new observation is a defect. Short by design, per READ TWELFTH.

Per the overlap warning in READ FOURTH: this window shares about 22 hours with the
sweep that closed at 16:20 UTC, so only about 2 hours is new observation. Nothing
below independently confirms anything above it.

Carve out the watchdog the way READ EIGHTEENTH insists rather than writing "nothing
else fired". ENDORSEMENT-SCORER-4 reads 359 on both axes, and a FLAT rolling 24 hour
count of a periodic emitter means events kept landing as old ones aged out. It is
correctly ignored, so it is excluded on purpose, not absent.

FULL DECOMPOSITION OF THE NEW SLICE
`by_message` read on all 3 SUPABASE-PLATFORM-1 events after 16:20 UTC, FATAL tagged
ones included, per READ SEVENTH. Thirty eight log lines, reconciling against the sum
of the three per event `count` fields:

    16:30:06 rollup, window 16:24:04.751 to 16:29:02.810
        2  unsupported frontend protocol N.N     FATAL, values 255.255 and 0.0
        1  no PostgreSQL user name specified in startup packet   FATAL
    16:50:07 rollup, window 16:44:04.781 to 16:49:02.727
        3  password authentication failed for user "?"   FATAL, filtered
    18:05:10 rollup, window 17:59:03.827 to 18:04:03.886
       32  duplicate key value violates unique constraint "?"   the 18:00 cycle

The 16:30:06 rollup is NOT new. READ TWENTY-FOURTH read it in full as a post close
observation, deliberately outside its own counts, and its three lines are identical.
It falls inside this window, so it is counted here for the first and only time. Same
occurrence, counted once, and flagged so a future reader does not have to reconcile
the two sections unaided.

The password total is the usual `by_severity` residual and not a direct read, per the
standing caveat in READ FOURTH. Split the probe shapes rather than lumping them, per
READ TWELFTH. FOUR probe families are on the record, not three: READ FOURTH enumerates
the protocol and no-username families as shapes 4 and 5 alongside the password family
as shape 1, and READ ELEVENTH adds the SASL Terminate line as a fourth, explicitly not
with the password failures. Three of the four appear in this slice and the SASL line
does not. Attribution differs across them and that difference is load bearing, and it does not
split two against two. The PROTOCOL family alone is established scan traffic, by READ
FIRST's byte decoding of the version halves. The no-username line has no bytes to
decode: READ FIRST calls that packet structurally valid and says the unscrubbed source
addresses are what would confirm it, so it is not established to the same standard. The
password family's attribution to that same traffic is INFERRED and not established,
which READ FIRST states and which no sweep since has overturned. Do not upgrade that to
a claim that every sweep preserved it: READ FOURTH labels shape 1 flatly as scan noise,
and READ NINTH, TENTH and SIXTEENTH each call the password family scan noise flatly
with no caveat attached. READ SEVENTH and READ EIGHTH are a separate and weaker case
worth keeping straight rather than padding the list with: they mention the filtered
password FATALs without attributing them to scan traffic at all, so they omit the
caveat without lumping. Never overturned is the accurate form.

The ad hoc hand SQL family that READ SEVENTEENTH attributes to Andrew's own membership
audit produced NOTHING, which settles nothing, for the conditionality reason READ
FOURTH gives.

THE 18:00 BOUNDARY IS THE SECOND EVIDENCED MISS
The counting rule is READ TWENTY-FIRST's: count a boundary only when a
SUPABASE-PLATFORM-1 rollup's `window_start` to `window_end` covers it.

Be exact about the provenance of the test, because pre-registration does real work in
this file and an earlier draft of this section invented some. READ TWENTY-SECOND
registered 13:00 and 14:00; READ TWENTY-THIRD re-registered 15:00 and 16:00; READ
TWENTY-FOURTH RAN that test, reported the count standing at one, and did NOT
re-register anything. So the 17:00 and 18:00 boundaries were not pre-registered by any
prior section. What is inherited is the RULE, not these two boundaries, and this is a
standing rule applied to the next boundaries rather than a registered prediction.

17:00 does not qualify. No rollup exists between 16:50:07 and 18:05:10, so that
boundary has no covering window and is uninformative.

18:00 DOES qualify, and it is a miss. The 18:05:10 rollup's window is 17:59:03.827 to
18:04:03.886, so it covers 18:00. Its `by_message` carries ONE key, the normalized
duplicate key message at 32; `count` is 32 and `by_severity` is ERROR 32. There is no
uuid line in it.

Three relay side and query side artefacts are excluded by the event's own fields, the
way READ TWENTY-SECOND excluded them at 12:00. One key against the 15 key cap, so no
tally truncation. 32 rows against `limit 200`, so no row truncation. A returned row set
at all, so the postgres query did not fail silently into the `[]` that would have
produced no event. The control is in the same tally: the sponsors burst is at an
unchanged 32 lines in that same five minute window, so the same query in the same
window still sees the OTHER undeployed fix's emitter at full size, and a dead relay or
a failed query is all-or-nothing against the whole window and cannot take one emitter
while leaving the other.

TWO artefacts are NOT excluded, and READ TWENTY-SECOND is explicit about both, so do
not inherit the phrase "every artefact" that an earlier draft of this section used.
The line could have fallen outside the window: every occurrence in this file carrying
a recorded second lands between HH:00:04 and HH:00:10, and this window opens 56 seconds
before the hour and closes four minutes after it, so no recorded offset falls outside
it, but READ TWENTY-SECOND calls that a regularity rather than a proof and says in as
many words that it is not the same as none ever could. And per-line loss in the
ingestion pipeline ABOVE `postgres_logs` delivers 32 rows while dropping a
thirty-third; the control is silent about that, because it happens upstream of the
query.

So state it with the interval attached, because the interval is the claim: at the 18:00
boundary the hourly uuid line was not written to `postgres_logs` inside 17:59:03.827
to 18:04:03.886. Per READ TWENTY-SECOND, "not written to `postgres_logs`" does not
license "the emitter did not write it".

THE LAST CAPTURED OCCURRENCE, RE-READ RATHER THAN INHERITED
Per READ FOURTEENTH, the 06:05:03 rollup was re-read from its own extras this run. It
carries four `by_message` keys reconciling to its `count` of 36: the duplicate key
message at 32, `invalid input syntax for type uuid: "?"` at 1, `column "?" does not
exist` at 2 and `aggregate functions are not allowed in GROUP BY` at 1. Its window is
05:59:06.009 to 06:04:01.762, so it covers 06:00 and it is an evidenced HIT.

Scope the sequence to the tracked test rather than to boundaries in general, which is
where an earlier draft of this section overreached. Among the SIX HOUR cycle
boundaries, which are the ones this test has been able to read, it now goes 06:00 hit,
12:00 miss, 18:00 miss: two consecutive evidenced misses with no evidenced hit between
them, and about 12 hours 20 minutes since the last capture. That is NOT a complete list
of evidenced boundaries in this window. The sections above record captured uuid lines
at roughly nine hourly boundaries inside it, from 19:00 and 20:00 on 2026-08-04 in READ
FOURTEENTH through 05:00 in READ NINETEENTH. Those are inherited rather than re-read
this run, and they matter here because they are counterexamples to the mechanism
paragraph below.

The pre-registered threshold is three or four consecutive evidenced boundaries. It is
NOT met at two, and READ TWENTY-FIRST catalogues at length what it costs to write the
conclusion into a heading before the evidence argues it up. Do not conclude the emitter
has stopped. What changed is that the count went from one to two, consecutive, against
a re-verified hit.

A HIT IS SELF EVIDENCING AND A MISS IS NOT, WHICH IS THE ASYMMETRY THAT MATTERS
An earlier draft of this section claimed the test cannot advance faster than every six
hours, and put that in its heading as a mechanism. An adversarial auditor falsified it,
and the correction is more useful than the claim was.

The relay emits a postgres rollup only under `if (pgRows.length > 0)`. What an earlier
draft got wrong is the word ELSE: it wrote that a boundary is observable only when
something ELSE was logged in the window, which quietly assumes the emitter is silent
and then uses that assumption to prove the boundary unobservable. The uuid line is
itself a row. If the emitter fires at 19:00, its own line makes `pgRows` non-empty, the
19:05 rollup covers 19:00, and the boundary is an evidenced HIT with no other traffic
required. That is exactly how the roughly nine hourly captures cited above were
observed, so the "exactly the six hour boundaries" claim is contradicted by this
window's own record.

The true asymmetry is weaker and one sided:

- A HIT is self evidencing at ANY hourly boundary, in the sense that it needs no other
  traffic. It still needs everything else in the reporting path to work: the relay run
  has to happen, the postgres query has to not fail silently into the `[]` that READ
  TWENTY-FIRST records the `.catch` substituting on that query SPECIFICALLY, the row has
  to survive `limit 200` and any per-line ingestion loss, and the ingest has to not
  return null. Every one is a path this file already documents, and they do NOT all cut
  the same way. The three whole-rollup paths cost a hit and a miss alike, but they are
  not equally bad and an earlier draft called all three outright suppression. The run
  not happening is the mildest: per READ FIRST's watermark the next run re-reads the
  same span under the 60 minute cap, so the observation is DELAYED past a sweep rather
  than lost. The 16:30:06 rollup illustrates the delay half only, and only in the
  simpler post close form: it reached this section because it landed after READ
  TWENTY-FOURTH's window closed, not because any run was skipped and caught up. That
  rollup's window is a clean five minutes, which READ TWENTY-FOURTH itself reads as
  consistent with the watermark having KEPT PACE, so do not cite it as evidence of the
  re-read mechanism. The silent `[]` and the null ingest do
  suppress it, because the watermark advances regardless and the span is gone. The two
  row-level paths are worse than symmetric: `limit 200` truncation and per-line
  ingestion loss remove the uuid row while the rest of the window still emits, which
  turns a real HIT into a false MISS and corrupts the consecutive count this section
  tracks. That is the same asymmetry the 18:00 paragraph above describes when it notes
  that per-line loss delivers 32 rows while dropping a thirty-third.
- A MISS needs some OTHER row in the covering window, because a boundary with no uuid
  line and no other traffic produces no rollup at all and is simply uninformative. At
  00, 06, 12 and 18 the 32 line sponsors burst supplies that other row. At the other
  twenty boundaries nothing does reliably, though coincident traffic sometimes supplies
  it: probe traffic lands at arbitrary offsets, READ TWENTY-THIRD's protocol line at
  13:07:25 and this window's 16:28:53 burst, so one can happen to fall in a window
  covering an hour boundary. Say sometimes rather than often, and scope it correctly:
  the window as a whole had roughly twelve of its twenty four hourly boundaries
  covered, per the paragraphs above. The uncovered stretch is 07:00 to 17:00 EXCEPT
  12:00, and that exception is not a quibble, since the 12:05:07 rollup covering 12:00
  is the very evidenced miss this section's sequence rests on. Rollups do exist
  elsewhere in that stretch, at about 08:15, 13:10, 16:30 and 16:50; none of their
  windows covers an hour boundary. Do not cite READ FIRST's 56 to 285 second spread for this, which
  an earlier draft did: those ten offsets are the PASSWORD family's, sampled to rule out
  pg_cron, and that is the family this section has just finished separating out as
  inferred rather than established. Note also that the 16:28:53 burst is two protocol
  lines plus a no-username line rather than a pure protocol data point; the two are
  separate families, per the split above.

So the MISS side of this test is reliably readable only on the six hour cycle, and
that is a non-guarantee elsewhere rather than an impossibility. Do NOT tell a future
run to expect the intervening sweeps to add nothing. They can add a HIT at any hourly
boundary, and a hit resets the consecutive count to zero, which is the single most
decisive thing this test could turn up. Keep checking every sweep.

The next boundary at which a miss would be readable is 00:00, then 06:00. Readable IF
the relay behaves and the burst still fires, which is not a guarantee and must not be
written as one: READ FOURTH's standing rule is not to read an emitter's cadence as a
guarantee and then treat a gap as a fix, this window alone carries long stretches with
no rollup at all, and a hand deploy of `e79339b` before 00:00 could remove the burst,
which is the very interaction the paragraph below describes.

One interaction worth seeing before it surprises somebody: deploying `e79339b` may
remove the sponsors burst, which is what makes the miss side of this test readable.
Whether it does depends on which of the two branches READ TWENTY-SECOND lays out is
real. On the clean branch the ON CONFLICT target matches a real unique index, the burst
stops, the covering row disappears and the miss observation loses its instrument, so
silence would become uninformative and only the self evidencing hit would remain. On
the mismatch branch the statement raises `42P10` instead, on the same six hour
schedule, which still supplies a covering row and leaves this test working. Do not
carry across the VOLUME: `42P10` is raised at plan time on each execution rather than
once per colliding row, so whether it arrives 32 times or once a cycle depends on how
the statement is batched, and READ TWENTY-SECOND makes no volume claim. Only the
covering row matters here, and one is enough. That constraint's exact column coverage has never been confirmed, so which
branch applies is not known from here. Neither is a reason to hold the deploy. Both are
a reason to read the cron schedule directly rather than keep inferring from the log.

WHAT NEEDS ANDREW, AND IT IS STILL ONE LOOK
Unchanged from READ TWENTY-FOURTH, and read the ambiguity the right way round. If
`sync-google-calendar` was hand deployed, the error stopped because `1cdb96e` fixed it,
and that is good. If its hourly cron job is disabled or failing to start, the error
stopped because the Google Calendar sync is no longer running, and a silent feature
outage looks EXACTLY like a fixed bug from here. An error going quiet is not by itself
good news. Nothing in this container can tell those apart. Treat `1cdb96e` as OPEN and
leave its day count running, per READ TWENTY-FIRST.

DAY COUNTS, RECOMPUTED AND NOT CARRIED FORWARD
With `git show -s --format=%cI` and FLOORED against the 18:21 close, per READ TWELFTH:
`1cdb96e` at 10 days, `e79339b` at 9, `0d2963e` at 5, `285a05f` at 1. None crossed a
boundary since the 16:20 sweep.

`e79339b` is confirmed still undeployed from direct evidence rather than inferred from
silence: the 18:00 cycle carried exactly 32 lines, unchanged size, and no `42P10`,
which per READ TWENTY-SECOND is inconsistent with a deployed copy on either branch.

The blocker was re-checked rather than inherited, per READ TWELFTH: nothing matching
`SUPABASE` or `PROJECT_REF` is in this container's environment. Record the absence and
stop there, per READ THIRTEENTH. READ SEVENTEENTH's sharper version of the ask stands
for all four.

NOTHING ELSE FIRED, THE WATCHDOG ASIDE
Every other issue's newest event predates the new slice, so all are the same
occurrences the sections above document rather than recurrences, and none was resolved
or re-resolved.

The newest `flutter` event of any kind is still 2026-08-04 19:34:33, which is 76
minutes BEFORE `6ff6a45` landed at 20:50:30, so FLUTTER-8, -B and -X have not fired
since that fix. Do not read that as the fix confirmed in production: Sentry cannot tell
a working fix from an unused app, since both emit nothing, per READ NINETEENTH. That
quiet now stands at about 22 hours 46 minutes. FLUTTER-Y and FLUTTER-6 are the
`RenderBox was not laid out` pair with zero first party frames, left alone per READ
FOURTEENTH. FLUTTER-5 is browser transport. MAUTIC-H's three are the probe POSTs READ
SIXTEENTH records, against a deliberately probe shaped address, and there is no droplet
access anyway. SUPABASE-PLATFORM-3 and -4 both carry no in window event, having aged
out at the 12:24 and 14:26 sweeps; neither was fixed and neither should be resolved.

THE CENSUS, CROSS FOOTED ON BOTH AXES PER READ TWELFTH

    by project   endorsement-scorer 359, supabase-platform 61, flutter 33,
                 mautic 3                                                  = 456
    by issue     ENDORSEMENT-SCORER-4 359                                  = 359
                 SUPABASE-PLATFORM-1 61                                    =  61
                 FLUTTER-B 10, -8 10, -X 9, -5 2, -Y 1, -6 1               =  33
                 MAUTIC-H 3                                                =   3
                                                                             456

Both axes agree exactly. `website`, `moydforms`, `n8n` and `supabase-edge` at zero.
Queried with NO status filter per READ EIGHTH, which is how the ignored watchdog and
the two resolved `flutter` issues stayed visible. Read READ TWELFTH's caveat on what
the equality does and does not buy, and note it buys nothing about the cron question
above: a census of what arrived cannot detect what was never sent.

`supabase-platform` is wholly SUPABASE-PLATFORM-1 for the third sweep running.

The resolved issues still carrying in window events are FLUTTER-8 and FLUTTER-5, both
set resolved by somebody else. Neither status was touched by this run, per READ EIGHTH.
They ARE resolved, by someone else; what this run declined to do is touch a status.

THE BRANCH REF TRAP, DELIBERATELY UNNUMBERED
Both repos again presented a stale named branch with `HEAD` detached at the true remote
tip: this repo's `master` at `5d8a5b0` against a real `29c4322`, and the sibling's
`main` at `77d879f` against a real `308ef92`. That is the same stale PAIR READ
EIGHTEENTH enumerates. The check was run in the form READ TWENTY-SECOND prescribes
after its own false pass, with the local side being the NAMED BRANCH and not `HEAD`;
the wrong form would have compared the detached tip with itself and returned clean.
Repaired with `git -C <path> checkout -B <branch> HEAD` per READ NINTH, and
`git ls-remote` re-run immediately before committing per READ FOURTEENTH.

No ordinal is quoted, per READ TWENTY-FOURTH: the recount from bites recorded in this
file was not run this sweep, and shipping an incremented number the section itself
declares unverified is the drift READ NINETEENTH warns about. This is one more bite.

ONE CONTAINER NOTE
The Bash tool's cwd persists between calls, which READ NINTH records after it cost that
run a mis-targeted repair. It bit again here in the harmless direction: a plain
`cd my-bluebubbles-web` failed with "No such file or directory" because an earlier call
had already left the shell inside that directory. Use absolute paths and `git -C`, and
read that error as cwd drift rather than as a missing repo.

WHAT THE AUDITOR CAUGHT, BECAUSE THE PATTERN IS THE POINT
The first draft of this section was returned NOT CLEAN with a BLOCKER, and it was a
failure mode this file already names: a conclusion written into a HEADING slightly past
what was checked. Count that the way READ NINETEENTH says to, from failures actually
recorded here rather than by incrementing, because READ TWENTY-FIRST caught an earlier
draft inflating this same tally and said that inflating it to make a tidier lesson is
the same reflex as inflating the evidence. Caught heading failures are READ TWENTIETH,
READ TWENTY-FIRST and this section: THREE, and not consecutive. READ TWENTY-SECOND's
caught BLOCKER was the branch check, READ TWENTY-THIRD records a heading temptation
resisted rather than a heading failure, though it does record caught failures of other
kinds, and READ TWENTY-FOURTH records no caught failure at all, so there is no streak
to claim. The heading claimed the test "CANNOT
ADVANCE FASTER THAN EVERY SIX HOURS" and the body argued it as a mechanism, when the
evidence supports only a non-guarantee, and this window's own record contains roughly
nine counterexamples. The same pass also caught an invented pre-registration attributed
to READ TWENTY-FOURTH, an "every artefact excluded" claim attributed to a section that
explicitly says two are not, a miscounted probe family denominator, two omissions from
the disclosure enumeration, and a cover citation naming the wrong publishing section.

Every one of those is a checkable fact asserted a little past what had been checked,
and every one is a class this file already names. Writing the narrow claim first and
letting the evidence argue it up remains the whole discipline, and the heading is where
it costs something, because the heading is what the next run skims.

DISCLOSURE CHECK, PER READ THIRD
This repo is public and the sibling is private. Enumerated rather than waved at, per
READ EIGHTEENTH, and this is a claim to CHECK rather than a habit. Re-derive it against
the body rather than listing what you remember putting there; the first draft of this
section omitted two entries and an auditor found both.

Named above: the commits `1cdb96e`, `e79339b`, `0d2963e`, `285a05f` and `6ff6a45`; the
function `sync-google-calendar` and the command `supabase functions list`; the
SQLSTATE `42P10` and the `ON CONFLICT` clause it is raised against, listed together per
READ TWENTY-SECOND's precedent; the relay
internals `window_start`, `window_end`, `by_message`, `by_severity`, `count`, `pgRows`,
`postgres_logs` and the `limit 200` and 15 key caps; `pg_cron`, published here since
READ FIRST; the issue ids and project names;
the git commands `git ls-remote`, `git rev-parse`, `git checkout -B` and
`git show -s --format=%cI`; the stale refs `5d8a5b0` and `77d879f`; this repo's real
tip `29c4322`; the sibling's real tip `308ef92`; the env var name patterns `SUPABASE`
and `PROJECT_REF`; the word droplet, in the note that there is no droplet access; and
the third party name Google Calendar, already carried in the committed name of the
function above; and from the container note, the Bash tool, the `cd` and `git -C`
commands, this repo's own directory name and the shell string "No such file or
directory". Split that last group by cover rather than clearing it in one phrase, which
an earlier draft did wrongly. The Bash tool, `cd`, `git -C` and this repo's directory
name are generic tooling already published by READ SECOND and READ NINTH. The shell
string "No such file or directory" appears NOWHERE earlier in this file, so prior
publication is not its cover and this is a deliberate FIRST publication: it is a
standard POSIX error string that names no path of ours, since the path it was raised
against is this repo's own already published directory name. The group is enumerated at
all because a re-audit found it missing from a paragraph professing to re-derive against
the body, and the false cover was then found by a third. Every one already appears in this file or is committed in this public
repo's own tree, with two carve outs stated rather than swept in. `29c4322` is this
PUBLIC repo's own current tip and is therefore already readable by anyone who can read
this sentence. `308ef92` is the private sibling's tip, and its cover is the deliberate
FIRST PUBLICATION in READ TWENTIETH, which recorded it as such precisely because
"already published" was not then available; READ TWENTY-FIRST, TWENTY-SECOND,
TWENTY-THIRD and TWENTY-FOURTH each name it under that cover rather than supplying it.
Getting that
chain backwards is the inverted cover check READ SEVENTEENTH and READ TWENTY-FIRST both
record as caught defects, and an earlier draft of this paragraph got it backwards.

Per READ EIGHTEENTH's carve out, quoted log CONTENT here is the uuid message shape, the
normalized duplicate key message, `password authentication failed for user "?"`, the
protocol values 255.255 and 0.0, `no PostgreSQL user name specified in startup packet`,
`column "?" does not exist`, `aggregate functions are not allowed in GROUP BY` and the
string `RenderBox was not laid out`. Every one is published in this file from READ
FIRST, READ FOURTEENTH and READ NINETEENTH onward. None of the new slice's lines names
a table, column, row, person or address. The probe source address is not reproduced,
per READ FIFTH, and neither is the recipient phone number that appears in the FLUTTER-8
title, per READ FOURTEENTH. The `flutter` events read this run carry an executive's
name, email address and IP; none is reproduced, per the practice READ SIXTH set.

No credential, no DSN, no probe source address, no policy body, no RPC name and no raw
upstream error appears, and nothing here widens access to anything. Withheld per the
practice READ SIXTH set: the state of the live endorsement vote, any operational read
on production sessions, and anything describing this container's own reporting or
credential tooling, which READ EIGHTEENTH records as a BLOCKER class.
