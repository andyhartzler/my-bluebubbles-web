"""Enrich historical_candidates with voter-file DOBs.

historical_candidates has just a single `name` text field, no address/zip/county.
Matching strategy: split name, then only keep matches that are UNIQUE statewide
(or very-high-confidence fuzzy). This is more conservative than candidates since
we lack geo disambiguation.
"""
from __future__ import annotations
import re
import psycopg
from match_people import DB_DSN


JUNK_NAMES = {
    'other', 'write-in', 'other/write-in votes', 'write-in votes',
    'libertarian', 'democratic', 'republican', 'green', 'constitution',
    'no opposition', 'unknown',
}


def split_name(full: str) -> tuple[str, str]:
    """Split `'First Middle Last Suffix'` into (first, last). Crude but works for 99%."""
    full = full.strip()
    parts = full.split()
    if len(parts) < 2:
        return ('', '')
    first = parts[0]
    # Drop a trailing suffix like "Jr.", "Sr.", "III"
    if parts[-1].rstrip('.').lower() in ('jr', 'sr', 'ii', 'iii', 'iv'):
        parts = parts[:-1]
    last = parts[-1]
    return (first, last)


def main():
    with psycopg.connect(DB_DSN) as conn:
        # Populate first_name/last_name on historical_candidates
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id::text, name
                FROM public.historical_candidates
                WHERE first_name IS NULL AND name IS NOT NULL AND name <> ''
            """)
            rows = cur.fetchall()
            print(f"Splitting names for {len(rows)} historical_candidates")
            to_update = []
            for hid, name in rows:
                if name.lower() in JUNK_NAMES:
                    continue
                fn, ln = split_name(name)
                if fn and ln:
                    to_update.append((fn, ln, hid))
            cur.executemany(
                "UPDATE public.historical_candidates SET first_name=%s, last_name=%s WHERE id::text=%s",
                to_update,
            )
            conn.commit()
            print(f"Wrote first/last to {len(to_update)} rows")

        # Now match each row where we have first+last
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id::text, first_name, last_name
                FROM public.historical_candidates
                WHERE first_name IS NOT NULL AND last_name IS NOT NULL
                  AND mo_voter_file_id IS NULL
            """)
            rows = cur.fetchall()
        print(f"Matching {len(rows)} historical candidates")

        matches = []
        from collections import Counter
        methods = Counter()
        with conn.cursor() as cur:
            for i, (hid, fn, ln) in enumerate(rows, 1):
                # Pass 1: exact first+last, must be UNIQUE statewide
                cur.execute("""
                    SELECT voter_id, birth_year FROM public.mo_voter_file
                    WHERE lower(first_name) = lower(%s)
                      AND lower(last_name)  = lower(%s)
                    LIMIT 3
                """, (fn, ln))
                rs = cur.fetchall()
                if len(rs) == 1 and rs[0][1]:
                    matches.append((hid, rs[0][0], rs[0][1], 0.9, 'exact_unique_statewide'))
                    methods['exact_unique_statewide'] += 1
                else:
                    # skip — too risky without geo info
                    methods['ambiguous_or_missing'] += 1
                if i % 200 == 0:
                    print(f"  {i}/{len(rows)}  {dict(methods)}")
        print(f"Final: {dict(methods)}")

        # Apply matches
        if matches:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TEMP TABLE _h_stage (
                        source_id text, voter_id text, birth_year int,
                        match_confidence numeric, match_method text
                    ) ON COMMIT DROP
                """)
                with cur.copy("COPY _h_stage FROM STDIN") as cpy:
                    for m in matches:
                        cpy.write_row(m)
                cur.execute("""
                    UPDATE public.historical_candidates h
                    SET mo_voter_file_id = s.voter_id,
                        date_of_birth    = make_date(s.birth_year, 7, 1),
                        birth_year       = s.birth_year,
                        dob_source       = 'voter_file'
                    FROM _h_stage s
                    WHERE h.id::text = s.source_id;
                """)
                print(f"Applied to {cur.rowcount} rows")

                # Compute is_young_dem: Dems who were ≤36 at their most recent run
                cur.execute("""
                    UPDATE public.historical_candidates
                    SET is_young_dem = (
                      lower(party) LIKE 'democrat%'
                      AND date_of_birth IS NOT NULL
                      AND years_ran IS NOT NULL
                      AND array_length(years_ran, 1) > 0
                      AND (
                        make_date(years_ran[array_upper(years_ran,1)], 11, 1)
                        - INTERVAL '36 years' < date_of_birth
                      )
                    );
                """)
                print(f"is_young_dem recomputed on {cur.rowcount} rows")
                conn.commit()

        # Summary
        with conn.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*) total,
                       COUNT(mo_voter_file_id) matched,
                       COUNT(date_of_birth) with_dob,
                       COUNT(*) FILTER (WHERE is_young_dem) young_dems,
                       COUNT(*) FILTER (WHERE is_young_dem AND lower(party) LIKE 'democrat%') confirmed_young_dems
                FROM public.historical_candidates;
            """)
            print(f"Summary: {cur.fetchone()}")


if __name__ == '__main__':
    main()
