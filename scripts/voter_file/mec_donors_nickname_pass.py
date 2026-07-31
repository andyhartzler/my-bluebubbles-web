"""Pass 2 for mec_donors: nickname-expansion + zip match.

For each pending mec_donor, try the candidate first_name variants returned
by nickname_expander + exact last_name + zip. If exactly one voter-file row
matches, accept it. Batched by 10k for progress visibility.
"""
from __future__ import annotations
import os
import psycopg
import time
from collections import Counter
from nickname_expander import candidate_first_names, candidate_last_names

DB_DSN = os.environ.get('MOYD_DB_DSN')
if not DB_DSN:
    raise SystemExit(
        'MOYD_DB_DSN is not set. Export the Postgres connection string before '
        'running this script.'
    )
BATCH = 10_000


def main():
    with psycopg.connect(DB_DSN) as conn:
        stats = Counter()
        matches: list[tuple[int, str, int]] = []  # (donor_id, voter_id, birth_year)
        processed = 0
        t0 = time.time()

        with conn.cursor(name='pending_cursor') as read_cur:  # server-side cursor
            read_cur.itersize = BATCH
            read_cur.execute("""
                SELECT id, first_name, last_name, zip
                FROM public.mec_donors
                WHERE match_status = 'pending'
            """)
            with conn.cursor() as q:
                for rec_id, fn, ln, zip5 in read_cur:
                    processed += 1
                    if not fn or not ln or not zip5:
                        stats['skip_empty'] += 1
                        continue
                    first_variants = candidate_first_names(fn)
                    last_variants = candidate_last_names(ln)
                    if not first_variants or not last_variants:
                        stats['skip_empty_variants'] += 1
                        continue

                    # Try only NICKNAME variants (skip the original — it already failed in pass 1)
                    nickname_variants = first_variants[1:] if len(first_variants) > 1 else []
                    if not nickname_variants:
                        stats['no_nickname'] += 1
                        continue

                    found = None
                    for nfn in nickname_variants:
                        for nln in last_variants:
                            q.execute(
                                "SELECT voter_id, birth_year FROM public.mo_voter_file "
                                "WHERE lower(first_name)=%s AND lower(last_name)=%s AND residential_zip5=%s "
                                "  AND birth_year IS NOT NULL LIMIT 2",
                                (nfn, nln, zip5[:5]),
                            )
                            rs = q.fetchall()
                            if len(rs) == 1:
                                found = rs[0]
                                break
                        if found:
                            break
                    if found:
                        matches.append((rec_id, found[0], found[1]))
                        stats['matched'] += 1
                    else:
                        stats['no_match'] += 1

                    if processed % 5000 == 0:
                        elapsed = time.time() - t0
                        rate = processed / elapsed
                        print(f"  {processed:,} processed ({rate:.0f}/s)  stats={dict(stats)}")

        print(f"FINAL: processed={processed} matches={len(matches)} stats={dict(stats)}")

        # Apply matches via COPY + UPDATE
        if matches:
            print("Applying matches...")
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TEMP TABLE _mec_stage (
                        donor_id bigint, voter_id text, birth_year int
                    ) ON COMMIT DROP
                """)
                with cur.copy("COPY _mec_stage (donor_id, voter_id, birth_year) FROM STDIN") as cpy:
                    for m in matches:
                        cpy.write_row(m)
                cur.execute("""
                    UPDATE public.mec_donors d
                    SET mo_voter_file_id = s.voter_id,
                        date_of_birth    = make_date(s.birth_year, 7, 1),
                        birth_year       = s.birth_year,
                        dob_source       = 'voter_file',
                        match_status     = 'matched'
                    FROM _mec_stage s
                    WHERE d.id = s.donor_id;
                """)
                print(f"Applied {cur.rowcount} updates")

                # Mark the rest as no_match
                cur.execute("""
                    UPDATE public.mec_donors SET match_status='no_match'
                    WHERE match_status='pending';
                """)
                print(f"Marked {cur.rowcount} as no_match")
            conn.commit()

        # Final status
        with conn.cursor() as cur:
            cur.execute("SELECT match_status, COUNT(*) FROM public.mec_donors GROUP BY 1 ORDER BY 2 DESC;")
            for row in cur.fetchall():
                print(f"  {row[0]:<16} {row[1]:>10,}")


if __name__ == '__main__':
    main()
