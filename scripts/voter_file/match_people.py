"""Match people records (candidates, historical_candidates, members, etc.) to the
statewide voter file using a 3-pass strategy.

Pass 1: exact lower(first) + lower(last) + zip5
Pass 2: exact lower(first) + lower(last) + lower(county)
Pass 3: rapidfuzz partial_ratio on normalized full-name, scoped to county (≥ 85)

Runs entirely in Python to sidestep the disk-fat GIN trigram index. For each county,
we pull the voter subset once (cached), then fuzzy-match every unmatched person in
that county against it.

Results are returned as a list of (source_id, voter_id, confidence, method). The
caller writes them to the source table via bulk UPDATE.
"""
from __future__ import annotations
import os
import re
import psycopg
from psycopg.rows import dict_row
from rapidfuzz import process, fuzz
from collections import defaultdict
from dataclasses import dataclass
from typing import Iterable


# --- config ---------------------------------------------------------------------

DB_DSN = os.environ.get('MOYD_DB_DSN')
if not DB_DSN:
    raise SystemExit(
        'MOYD_DB_DSN is not set. Export the Postgres connection string before '
        'running this script.'
    )
FUZZY_THRESHOLD = 85  # rapidfuzz partial_ratio cutoff (0-100)


def _norm(s: str | None) -> str:
    """Normalize a name for comparison: lowercase, strip punctuation/whitespace."""
    if not s:
        return ''
    return re.sub(r'[^a-z]', '', s.lower())


# --- data structures -------------------------------------------------------------

@dataclass
class Person:
    source_id: str             # stringified pk from source table (uuid or int as text)
    first_name: str
    last_name: str
    zip5: str | None = None
    county: str | None = None


@dataclass
class Match:
    source_id: str
    voter_id: str | None
    confidence: float          # 0.0-1.0
    method: str                # exact_name_zip | exact_name_county | fuzzy_county | none


# --- matcher --------------------------------------------------------------------

class VoterFileMatcher:
    def __init__(self, conn: psycopg.Connection):
        self.conn = conn
        # Per-county voter subset cache: {county_lower: [(voter_id, first_lower, last_lower, zip5, birth_year)]}
        self._county_cache: dict[str, list[tuple]] = {}
        # Candidate name tuples for rapidfuzz (cached per-county)
        self._county_names: dict[str, list[str]] = {}

    def _load_county(self, county: str) -> list[tuple]:
        """Lazy-load all voters for a county."""
        c = county.lower()
        if c in self._county_cache:
            return self._county_cache[c]
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT voter_id, lower(first_name) AS fn, lower(last_name) AS ln,
                       residential_zip5 AS zip5, birth_year
                FROM public.mo_voter_file
                WHERE lower(county) = %s
                """,
                (c,),
            )
            rows = cur.fetchall()
        self._county_cache[c] = rows
        self._county_names[c] = [_norm(f'{r[1]} {r[2]}') for r in rows]
        return rows

    def match(self, p: Person) -> Match:
        if not p.first_name or not p.last_name:
            return Match(p.source_id, None, 0.0, 'none')

        fn, ln = p.first_name.strip().lower(), p.last_name.strip().lower()

        # --- Pass 1: exact name + zip5 (unique) ---
        if p.zip5:
            with self.conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT voter_id FROM public.mo_voter_file
                    WHERE lower(first_name) = %s
                      AND lower(last_name)  = %s
                      AND residential_zip5  = %s
                    LIMIT 2
                    """,
                    (fn, ln, p.zip5[:5]),
                )
                rs = cur.fetchall()
            if len(rs) == 1:
                return Match(p.source_id, rs[0][0], 1.0, 'exact_name_zip')

        # --- Pass 2: exact name + county (unique) ---
        if p.county:
            with self.conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT voter_id FROM public.mo_voter_file
                    WHERE lower(first_name) = %s
                      AND lower(last_name)  = %s
                      AND lower(county)     = %s
                    LIMIT 2
                    """,
                    (fn, ln, p.county.lower()),
                )
                rs = cur.fetchall()
            if len(rs) == 1:
                return Match(p.source_id, rs[0][0], 0.9, 'exact_name_county')

        # --- Pass 3: fuzzy, county-scoped (rapidfuzz) ---
        if p.county:
            voters = self._load_county(p.county)
            names = self._county_names[p.county.lower()]
            query = _norm(f'{fn} {ln}')
            result = process.extractOne(query, names, scorer=fuzz.token_sort_ratio, score_cutoff=FUZZY_THRESHOLD)
            if result:
                _, score, idx = result
                return Match(p.source_id, voters[idx][0], score / 100.0, 'fuzzy_county')

        # --- Pass 4: exact name statewide (tie-break by most common zip) ---
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT voter_id, COUNT(*) OVER (PARTITION BY lower(first_name), lower(last_name)) AS name_count
                FROM public.mo_voter_file
                WHERE lower(first_name) = %s AND lower(last_name) = %s
                LIMIT 2
                """,
                (fn, ln),
            )
            rs = cur.fetchall()
        if len(rs) == 1:
            return Match(p.source_id, rs[0][0], 0.75, 'exact_name_statewide')

        return Match(p.source_id, None, 0.0, 'none')


# --- driver helpers for bulk runs -----------------------------------------------

def match_people(people: Iterable[Person]) -> list[Match]:
    with psycopg.connect(DB_DSN) as conn:
        m = VoterFileMatcher(conn)
        results: list[Match] = []
        for i, p in enumerate(people, 1):
            results.append(m.match(p))
            if i % 100 == 0:
                print(f'  matched {i} people')
        return results


def write_matches(
    table: str,
    id_col: str,
    matches: list[Match],
    dob_source: str = 'voter_file',
) -> int:
    """Apply matches to a target table by writing mo_voter_file_id and joining to
    mo_voter_file to populate date_of_birth (July 1 of birth_year).

    Returns the number of rows updated.
    """
    if not matches:
        return 0
    successful = [m for m in matches if m.voter_id]
    with psycopg.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            # Stage the matches in a temp table for a single SET FROM join
            cur.execute(
                """
                CREATE TEMP TABLE IF NOT EXISTS _match_stage (
                    source_id        text,
                    voter_id         text,
                    match_confidence numeric,
                    match_method     text
                ) ON COMMIT DROP
                """
            )
            cur.execute('TRUNCATE _match_stage')
            with cur.copy('COPY _match_stage (source_id, voter_id, match_confidence, match_method) FROM STDIN') as cpy:
                for m in successful:
                    cpy.write_row((m.source_id, m.voter_id, m.confidence, m.method))
            cur.execute(
                f"""
                UPDATE public.{table} t
                SET mo_voter_file_id = s.voter_id,
                    date_of_birth    = make_date(v.birth_year, 7, 1),
                    dob_source       = %s
                FROM _match_stage s
                JOIN public.mo_voter_file v ON v.voter_id = s.voter_id
                WHERE t.{id_col}::text = s.source_id AND v.birth_year IS NOT NULL
                """,
                (dob_source,),
            )
            updated = cur.rowcount
        conn.commit()
    return updated


if __name__ == '__main__':
    # Smoke test — try matching a few known MO Dem candidates
    test_people = [
        Person('t1', 'Crystal', 'Quade', '65807', 'Greene'),
        Person('t2', 'Mike', 'Kehoe', None, 'Cole'),  # Republican, for comparison
    ]
    print('Smoke test:')
    for m in match_people(test_people):
        print(f'  {m}')
