"""Match all ~409 MOYD members to the Missouri voter file.

Hard constraint: NEVER overwrites public.members.date_of_birth (self-reported from
signup form is canonical — 343 of 409 rows have one). We only populate
mo_voter_file_id (FK to mo_voter_file.voter_id) plus, for members who never
self-reported a DOB, the reference voter-file birth_year.

dob_source semantics:
  - 'self_reported'               — member has a self-reported DOB; we preserve it as-is
  - 'voter_file_birth_year_only'  — member had NO self-reported DOB, and we filled
                                    birth_year from the voter file (DOB stays NULL,
                                    year is reference only for UI display)

We also report divergence (self-reported DOB year != voter-file birth_year) as
telemetry so Andrew can review who to reach out to — we do NOT touch those rows'
DOB data.

Webhook triggers on members are expected to be DISABLED before this runs and
re-enabled after — see the driver block at the bottom and the prompt.
"""
from __future__ import annotations

import os
import re
import sys
from collections import Counter
from dataclasses import dataclass
from typing import Optional

import psycopg

# Local helpers
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from match_people_v2 import EnhancedMatcher, Person  # noqa: E402

DB_DSN = os.environ.get("MOYD_DB_DSN")
if not DB_DSN:
    raise SystemExit(
        "MOYD_DB_DSN is not set. Export the Postgres connection string before "
        "running this script."
    )


_ZIP_RE = re.compile(r"\b(\d{5})(?:-\d{4})?\b")


def parse_zip(address: Optional[str]) -> Optional[str]:
    if not address:
        return None
    m = _ZIP_RE.search(address)
    return m.group(1) if m else None


def split_name(full: Optional[str]) -> tuple[Optional[str], Optional[str]]:
    """Very simple first/last split.

    Drops common honorifics, collapses internal whitespace, treats the last
    whitespace-separated token as the last name and the first token as first.
    For middle names/initials we skip them (matcher only takes first+last).
    Preserves hyphenated last names as a unit.
    """
    if not full:
        return None, None
    # normalize whitespace
    cleaned = re.sub(r"\s+", " ", full).strip()
    if not cleaned:
        return None, None
    # drop common honorifics
    parts = cleaned.split(" ")
    if len(parts) > 1 and parts[0].lower().rstrip(".") in {"mr", "mrs", "ms", "dr", "rev"}:
        parts = parts[1:]
    # drop common generational suffixes from the end
    if len(parts) > 2 and parts[-1].lower().rstrip(".") in {"jr", "sr", "ii", "iii", "iv"}:
        parts = parts[:-1]
    if len(parts) == 1:
        return parts[0], ""
    return parts[0], parts[-1]


@dataclass
class MemberMatchResult:
    member_id: str
    name: str
    voter_id: Optional[str]
    method: str
    confidence: float
    self_reported_dob_year: Optional[int]
    voter_file_birth_year: Optional[int]
    had_self_reported_dob: bool


def fetch_members(conn: psycopg.Connection):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id::text,
                   name,
                   address,
                   county,
                   date_of_birth,
                   EXTRACT(YEAR FROM date_of_birth)::int AS dob_year
            FROM public.members
            WHERE name IS NOT NULL AND name <> ''
            ORDER BY created_at NULLS LAST, name
            """
        )
        return cur.fetchall()


def voter_birth_year(conn: psycopg.Connection, voter_id: str) -> Optional[int]:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT birth_year FROM public.mo_voter_file WHERE voter_id = %s",
            (voter_id,),
        )
        row = cur.fetchone()
        return row[0] if row else None


def run():
    with psycopg.connect(DB_DSN) as conn:
        rows = fetch_members(conn)
        print(f"Loaded {len(rows)} members")

        matcher = EnhancedMatcher(conn)

        results: list[MemberMatchResult] = []
        by_method: Counter[str] = Counter()

        for i, (mid, name, address, county, dob, dob_year) in enumerate(rows, 1):
            first, last = split_name(name)
            zip5 = parse_zip(address)
            had_dob = dob is not None

            if not first or not last:
                results.append(
                    MemberMatchResult(
                        member_id=mid,
                        name=name,
                        voter_id=None,
                        method="none_name_unparsable",
                        confidence=0.0,
                        self_reported_dob_year=dob_year,
                        voter_file_birth_year=None,
                        had_self_reported_dob=had_dob,
                    )
                )
                by_method["none_name_unparsable"] += 1
                continue

            m = matcher.match(Person(mid, first, last, zip5, county))
            vf_year = voter_birth_year(conn, m.voter_id) if m.voter_id else None
            results.append(
                MemberMatchResult(
                    member_id=mid,
                    name=name,
                    voter_id=m.voter_id,
                    method=m.method,
                    confidence=m.confidence,
                    self_reported_dob_year=dob_year,
                    voter_file_birth_year=vf_year,
                    had_self_reported_dob=had_dob,
                )
            )
            by_method[m.method] += 1
            if i % 50 == 0:
                print(f"  {i}/{len(rows)}  methods={dict(by_method)}")

        print(f"FINAL methods: {dict(by_method)}")

        successful = [r for r in results if r.voter_id]
        print(f"{len(successful)} of {len(results)} members matched a voter-file record")

        # Divergence report: member had self-reported DOB AND matched voter file AND years differ
        divergences = [
            r for r in successful
            if r.had_self_reported_dob
            and r.voter_file_birth_year is not None
            and r.self_reported_dob_year is not None
            and r.self_reported_dob_year != r.voter_file_birth_year
        ]
        print(f"\n=== DIVERGENCE REPORT ({len(divergences)} members) ===")
        if divergences:
            print(f"{'NAME':40s}  {'SELF':>5s}  {'VOTER':>5s}  DELTA")
            for r in sorted(divergences, key=lambda r: abs((r.voter_file_birth_year or 0) - (r.self_reported_dob_year or 0)), reverse=True):
                delta = (r.voter_file_birth_year or 0) - (r.self_reported_dob_year or 0)
                print(f"{r.name[:40]:40s}  {r.self_reported_dob_year:>5d}  {r.voter_file_birth_year:>5d}  {delta:+d}")
        else:
            print("(no divergences)")

        # --- WRITE PHASE ---
        # We only ever write: mo_voter_file_id, dob_source, and (when no self-reported DOB) birth_year.
        # We do NOT touch date_of_birth. Ever.
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TEMP TABLE _mem_stage (
                    member_id   uuid,
                    voter_id    text,
                    birth_year  int,
                    dob_source  text
                ) ON COMMIT DROP
                """
            )
            with cur.copy("COPY _mem_stage (member_id, voter_id, birth_year, dob_source) FROM STDIN") as cpy:
                for r in results:
                    # Decide dob_source:
                    if r.had_self_reported_dob:
                        # PRESERVE existing DOB. Mark it as self_reported. Never overwrite with voter data.
                        dob_src = "self_reported"
                        bye = None  # do NOT populate birth_year — keep truth from DOB if they want it
                    elif r.voter_file_birth_year is not None:
                        dob_src = "voter_file_birth_year_only"
                        bye = r.voter_file_birth_year
                    else:
                        dob_src = None
                        bye = None
                    # Only stage rows that have anything to write
                    if r.voter_id or dob_src is not None or bye is not None:
                        cpy.write_row((r.member_id, r.voter_id, bye, dob_src))

            # Defensive: never touch date_of_birth in the UPDATE statement.
            cur.execute(
                """
                UPDATE public.members m
                SET
                    mo_voter_file_id = COALESCE(s.voter_id, m.mo_voter_file_id),
                    birth_year       = CASE
                                          WHEN m.date_of_birth IS NOT NULL THEN m.birth_year
                                          ELSE COALESCE(s.birth_year, m.birth_year)
                                       END,
                    dob_source       = COALESCE(s.dob_source, m.dob_source)
                FROM _mem_stage s
                WHERE m.id = s.member_id;
                """
            )
            print(f"\nUPDATE affected {cur.rowcount} members")

        conn.commit()

        # Post-write summary
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    COUNT(*) AS total,
                    COUNT(mo_voter_file_id) AS matched,
                    COUNT(date_of_birth) AS with_self_dob,
                    COUNT(*) FILTER (WHERE dob_source = 'self_reported') AS src_self,
                    COUNT(*) FILTER (WHERE dob_source = 'voter_file_birth_year_only') AS src_vf_year,
                    COUNT(*) FILTER (WHERE dob_source IS NULL) AS src_null
                FROM public.members
                """
            )
            print(f"POST SUMMARY: {cur.fetchone()}")

        return results, divergences


if __name__ == "__main__":
    run()
