"""Enrich legislators with nickname-expanded voter file matching."""
from __future__ import annotations
import os
import psycopg
from nickname_expander import candidate_first_names, candidate_last_names

DB_DSN = os.environ.get('MOYD_DB_DSN')
if not DB_DSN:
    raise SystemExit(
        'MOYD_DB_DSN is not set. Export the Postgres connection string before '
        'running this script.'
    )


def try_match(cur, fn: str, ln: str) -> tuple[str, int] | None:
    """Return (voter_id, birth_year) iff exactly one voter matches statewide."""
    cur.execute(
        "SELECT voter_id, birth_year FROM public.mo_voter_file "
        "WHERE lower(first_name) = %s AND lower(last_name) = %s AND birth_year IS NOT NULL LIMIT 2",
        (fn.lower(), ln.lower()),
    )
    rs = cur.fetchall()
    return rs[0] if len(rs) == 1 else None


def main():
    with psycopg.connect(DB_DSN) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id::text, first_name, last_name FROM public.legislation_legislators
                WHERE mo_voter_file_id IS NULL
                  AND first_name IS NOT NULL AND last_name IS NOT NULL
            """)
            rows = cur.fetchall()
        print(f"Re-matching {len(rows)} unmatched legislators")

        matches = []
        from collections import Counter
        stats = Counter()
        with conn.cursor() as cur:
            for leg_id, fn, ln in rows:
                first_variants = candidate_first_names(fn)
                last_variants = candidate_last_names(ln)
                found = None
                for fv in first_variants:
                    for lv in last_variants:
                        r = try_match(cur, fv, lv)
                        if r:
                            found = r
                            break
                    if found:
                        break
                if found:
                    matches.append((leg_id, found[0], found[1]))
                    stats['matched'] += 1
                else:
                    stats['no_match'] += 1
        print(f"{dict(stats)}")

        if matches:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TEMP TABLE _leg_stage (
                        source_id text, voter_id text, birth_year int
                    ) ON COMMIT DROP
                """)
                with cur.copy("COPY _leg_stage FROM STDIN") as cpy:
                    for m in matches:
                        cpy.write_row(m)
                cur.execute("""
                    UPDATE public.legislation_legislators l
                    SET mo_voter_file_id = s.voter_id,
                        date_of_birth    = make_date(s.birth_year, 7, 1),
                        birth_year       = s.birth_year,
                        dob_source       = 'voter_file'
                    FROM _leg_stage s
                    WHERE l.id::text = s.source_id;
                """)
                print(f"Applied {cur.rowcount} updates")
            conn.commit()

        # Summary
        with conn.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*) total, COUNT(date_of_birth) with_dob FROM public.legislation_legislators
            """)
            print(f"Final legislators: {cur.fetchone()}")


if __name__ == '__main__':
    main()
