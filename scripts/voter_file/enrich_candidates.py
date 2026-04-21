"""Match all 520 candidates to the voter file and write results back."""
from __future__ import annotations
import psycopg
from match_people import VoterFileMatcher, Person, DB_DSN


def main():
    with psycopg.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id::text, first_name, last_name, zip, county, city
                FROM public.candidates
                WHERE first_name IS NOT NULL AND last_name IS NOT NULL
            """)
            rows = cur.fetchall()
        print(f"Loaded {len(rows)} candidates")

        matcher = VoterFileMatcher(conn)
        # Clear prior AI DOBs so we're starting clean
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE public.candidates
                SET date_of_birth = NULL, estimated_age = NULL
                WHERE dob_source = 'ai_estimate';
            """)
            print(f"Cleared {cur.rowcount} AI-estimated DOBs")
            conn.commit()

        # Run matcher
        from collections import Counter
        by_method = Counter()
        matches = []
        for i, (cid, fn, ln, zip5, county, city) in enumerate(rows, 1):
            m = matcher.match(Person(cid, fn, ln, zip5, county))
            matches.append(m)
            by_method[m.method] += 1
            if i % 100 == 0:
                print(f"  {i}/{len(rows)} matched  — {dict(by_method)}")
        print(f"FINAL method counts: {dict(by_method)}")

        # Write matches: set mo_voter_file_id + date_of_birth + dob_source + match_confidence + match_method
        successful = [m for m in matches if m.voter_id]
        print(f"Applying {len(successful)} matches")

        with conn.cursor() as cur:
            cur.execute("""
                CREATE TEMP TABLE _match_stage (
                    source_id        text,
                    voter_id         text,
                    match_confidence numeric,
                    match_method     text
                ) ON COMMIT DROP
            """)
            with cur.copy("COPY _match_stage (source_id, voter_id, match_confidence, match_method) FROM STDIN") as cpy:
                for m in successful:
                    cpy.write_row((m.source_id, m.voter_id, m.confidence, m.method))

            cur.execute("""
                UPDATE public.candidates c
                SET mo_voter_file_id = s.voter_id,
                    date_of_birth    = make_date(v.birth_year, 7, 1),
                    birth_year       = v.birth_year,
                    estimated_age    = EXTRACT(YEAR FROM age(COALESCE(c.election_date, CURRENT_DATE), make_date(v.birth_year, 7, 1)))::int,
                    dob_source       = 'voter_file',
                    match_confidence = s.match_confidence,
                    match_method     = s.match_method
                FROM _match_stage s
                JOIN public.mo_voter_file v ON v.voter_id = s.voter_id
                WHERE c.id::text = s.source_id AND v.birth_year IS NOT NULL;
            """)
            print(f"Updated {cur.rowcount} candidates with voter-file data")

            # Recompute is_young_dem from real DOBs
            cur.execute("""
                UPDATE public.candidates
                SET is_young_dem = (
                    party = 'Democratic'
                    AND date_of_birth IS NOT NULL
                    AND date_of_birth > (COALESCE(election_date, CURRENT_DATE) - INTERVAL '36 years')
                );
            """)
            print(f"Recomputed is_young_dem on {cur.rowcount} candidates")

            # Summary
            cur.execute("""
                SELECT
                  COUNT(*) AS total,
                  COUNT(mo_voter_file_id) AS matched,
                  COUNT(date_of_birth) AS with_dob,
                  COUNT(*) FILTER (WHERE is_young_dem) AS young_dems,
                  COUNT(*) FILTER (WHERE is_young_dem AND party='Democratic') AS confirmed_young_dems,
                  COUNT(*) FILTER (WHERE party='Democratic' AND date_of_birth IS NULL) AS dems_unmatched
                FROM public.candidates;
            """)
            print(f"Summary: {cur.fetchone()}")
        conn.commit()


if __name__ == '__main__':
    main()
