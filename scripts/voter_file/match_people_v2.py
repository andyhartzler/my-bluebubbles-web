"""Enhanced matcher with nickname expansion, hyphenation handling, and initial-only first-name support.

Match passes (tried in order, first success wins):
  A. exact first+last+zip
  B. nickname-expanded first+last+zip (tries Michael for "Mike", etc.)
  C. exact first+last+county
  D. nickname-expanded first+last+county
  E. hyphenated-last-name variants + zip/county
  F. initial-only first-name: first LIKE "K%" + last+zip/county  (unique result wins)
  G. rapidfuzz fuzzy on full name, scoped to county
  H. exact first+last STATEWIDE if unique
  I. none
"""
from __future__ import annotations
import os
import psycopg
from rapidfuzz import process, fuzz
from collections import Counter
from dataclasses import dataclass
from nickname_expander import candidate_first_names, candidate_last_names

DB_DSN = os.environ.get(
    'MOYD_DB_DSN',
    'postgresql://postgres:LNEERaCSbAKOVtdR@db.faajpcarasilbfndzkmd.supabase.co:5432/postgres',
)
FUZZY_THRESHOLD = 82


@dataclass
class Person:
    source_id: str
    first_name: str
    last_name: str
    zip5: str | None = None
    county: str | None = None


@dataclass
class Match:
    source_id: str
    voter_id: str | None
    confidence: float
    method: str


class EnhancedMatcher:
    def __init__(self, conn: psycopg.Connection):
        self.conn = conn
        self._county_cache: dict[str, list[tuple]] = {}
        self._county_names: dict[str, list[str]] = {}

    def _load_county(self, county: str) -> tuple[list[tuple], list[str]]:
        c = county.lower()
        if c not in self._county_cache:
            with self.conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT voter_id, lower(first_name) AS fn, lower(last_name) AS ln,
                           residential_zip5, birth_year
                    FROM public.mo_voter_file
                    WHERE lower(county) = %s
                    """,
                    (c,),
                )
                rows = cur.fetchall()
            self._county_cache[c] = rows
            self._county_names[c] = [f'{r[1]} {r[2]}' for r in rows]
        return self._county_cache[c], self._county_names[c]

    def _find_unique(self, fn: str, ln: str, *, zip5: str | None = None, county: str | None = None) -> str | None:
        """Return the single voter_id matching first+last, scoped by zip OR county; None if 0 or >1."""
        if zip5:
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT voter_id FROM public.mo_voter_file "
                    "WHERE lower(first_name)=%s AND lower(last_name)=%s AND residential_zip5=%s LIMIT 2",
                    (fn, ln, zip5[:5]),
                )
                rs = cur.fetchall()
        elif county:
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT voter_id FROM public.mo_voter_file "
                    "WHERE lower(first_name)=%s AND lower(last_name)=%s AND lower(county)=%s LIMIT 2",
                    (fn, ln, county.lower()),
                )
                rs = cur.fetchall()
        else:
            with self.conn.cursor() as cur:
                cur.execute(
                    "SELECT voter_id FROM public.mo_voter_file "
                    "WHERE lower(first_name)=%s AND lower(last_name)=%s LIMIT 2",
                    (fn, ln),
                )
                rs = cur.fetchall()
        return rs[0][0] if len(rs) == 1 else None

    def _initial_match(self, first_initial: str, last: str, *, zip5: str | None, county: str | None) -> str | None:
        """first_name starts with `first_initial`, last matches exactly, scoped."""
        if zip5:
            sql = "SELECT voter_id FROM public.mo_voter_file WHERE lower(first_name) LIKE %s AND lower(last_name)=%s AND residential_zip5=%s LIMIT 2"
            params = (f'{first_initial.lower()}%', last, zip5[:5])
        elif county:
            sql = "SELECT voter_id FROM public.mo_voter_file WHERE lower(first_name) LIKE %s AND lower(last_name)=%s AND lower(county)=%s LIMIT 2"
            params = (f'{first_initial.lower()}%', last, county.lower())
        else:
            return None
        with self.conn.cursor() as cur:
            cur.execute(sql, params)
            rs = cur.fetchall()
        return rs[0][0] if len(rs) == 1 else None

    def match(self, p: Person) -> Match:
        if not p.first_name or not p.last_name:
            return Match(p.source_id, None, 0.0, 'none')

        first_variants = candidate_first_names(p.first_name)
        last_variants = candidate_last_names(p.last_name)
        if not first_variants or not last_variants:
            return Match(p.source_id, None, 0.0, 'none_empty_variants')

        # Pass A/B: exact + nickname expanded + ZIP
        if p.zip5:
            for fn in first_variants:
                for ln in last_variants:
                    vid = self._find_unique(fn, ln, zip5=p.zip5)
                    if vid:
                        # First variant is the original; label accordingly
                        method = 'exact_name_zip' if fn == first_variants[0] and ln == last_variants[0] else 'nickname_zip'
                        return Match(p.source_id, vid, 1.0, method)

        # Pass C/D: exact + nickname + COUNTY
        if p.county:
            for fn in first_variants:
                for ln in last_variants:
                    vid = self._find_unique(fn, ln, county=p.county)
                    if vid:
                        method = 'exact_name_county' if fn == first_variants[0] and ln == last_variants[0] else 'nickname_county'
                        return Match(p.source_id, vid, 0.9, method)

        # Pass F: initial-only first ("K. Grant" → first LIKE 'k%' + last='grant' + zip)
        first_orig = p.first_name.strip()
        if len(first_orig.rstrip('.')) == 1:
            initial = first_orig[0]
            for ln in last_variants:
                vid = self._initial_match(initial, ln, zip5=p.zip5, county=p.county)
                if vid:
                    return Match(p.source_id, vid, 0.8, 'initial_first')

        # Pass G: fuzzy in county
        if p.county:
            try:
                voters, names = self._load_county(p.county)
            except psycopg.Error:
                voters, names = [], []
            if names:
                # Try fuzzy with each first/last variant pair
                best: tuple[float, int] = (0.0, -1)
                for fn in first_variants:
                    for ln in last_variants:
                        q = f'{fn} {ln}'
                        r = process.extractOne(q, names, scorer=fuzz.token_sort_ratio, score_cutoff=FUZZY_THRESHOLD)
                        if r and r[1] > best[0]:
                            best = (r[1], r[2])
                if best[1] >= 0:
                    score, idx = best
                    return Match(p.source_id, voters[idx][0], score / 100.0, 'fuzzy_county')

        # Pass H: exact statewide, unique
        for fn in first_variants:
            for ln in last_variants:
                vid = self._find_unique(fn, ln)
                if vid:
                    return Match(p.source_id, vid, 0.75, 'exact_name_statewide')

        # Pass G fallback to statewide fuzzy (only if we really can't find anything else, and only on original name)
        # Skip — risky without any geo disambiguation

        return Match(p.source_id, None, 0.0, 'none')


# --- bulk-run helper for candidates ---------------------------------------------

def rematch_unmatched_candidates() -> None:
    with psycopg.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id::text, first_name, last_name, zip, county, city
                FROM public.candidates
                WHERE mo_voter_file_id IS NULL
                  AND first_name IS NOT NULL AND last_name IS NOT NULL
            """)
            rows = cur.fetchall()
        print(f"Re-matching {len(rows)} previously unmatched candidates")

        m = EnhancedMatcher(conn)
        methods = Counter()
        matches = []
        for cid, fn, ln, zip5, county, city in rows:
            mt = m.match(Person(cid, fn, ln, zip5, county))
            matches.append(mt)
            methods[mt.method] += 1
        print(f"Enhanced match methods: {dict(methods)}")

        successful = [mt for mt in matches if mt.voter_id]
        print(f"Applying {len(successful)} new matches")
        if not successful:
            return

        with conn.cursor() as cur:
            cur.execute("""
                CREATE TEMP TABLE _e_stage (
                    source_id text, voter_id text, match_confidence numeric, match_method text
                ) ON COMMIT DROP
            """)
            with cur.copy("COPY _e_stage FROM STDIN") as cpy:
                for mt in successful:
                    cpy.write_row((mt.source_id, mt.voter_id, mt.confidence, mt.method))
            cur.execute("""
                UPDATE public.candidates c
                SET mo_voter_file_id = s.voter_id,
                    date_of_birth    = make_date(v.birth_year, 7, 1),
                    birth_year       = v.birth_year,
                    estimated_age    = EXTRACT(YEAR FROM age(COALESCE(c.election_date, CURRENT_DATE), make_date(v.birth_year, 7, 1)))::int,
                    dob_source       = 'voter_file',
                    match_confidence = s.match_confidence,
                    match_method     = s.match_method
                FROM _e_stage s
                JOIN public.mo_voter_file v ON v.voter_id = s.voter_id
                WHERE c.id::text = s.source_id AND v.birth_year IS NOT NULL;
            """)
            print(f"Updated {cur.rowcount} rows")

            # Recompute is_young_dem
            cur.execute("""
                UPDATE public.candidates
                SET is_young_dem = (
                    party = 'Democratic'
                    AND date_of_birth IS NOT NULL
                    AND date_of_birth > (COALESCE(election_date, CURRENT_DATE) - INTERVAL '36 years')
                );
            """)
            print(f"Recomputed is_young_dem on {cur.rowcount} rows")

            # Summary
            cur.execute("""
                SELECT COUNT(*) total,
                       COUNT(mo_voter_file_id) matched,
                       COUNT(date_of_birth) with_dob,
                       COUNT(*) FILTER (WHERE is_young_dem) young_dems,
                       COUNT(*) FILTER (WHERE party='Democratic' AND mo_voter_file_id IS NULL) dems_still_unmatched
                FROM public.candidates;
            """)
            print(f"Summary: {cur.fetchone()}")
        conn.commit()


if __name__ == '__main__':
    rematch_unmatched_candidates()
