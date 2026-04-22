"""Pass 6 for mec_donors: fuzzy full-name matching within county.

For each remaining no_match mec_donor, scope to candidates in the same county
(derived from zip or city) and run rapidfuzz WRatio over full name. Accept only
a unique match >= 0.85 that is notably better than the second-best (margin >= 0.05).

Run only after SQL passes 3-5 are done. Confidence: 0.85.
"""
from __future__ import annotations

import sys
import time
from collections import defaultdict

import psycopg
try:
    from rapidfuzz import fuzz, process
except ImportError:
    print("Install rapidfuzz:  uv pip install rapidfuzz psycopg", file=sys.stderr)
    sys.exit(1)

DB_DSN = "postgresql://postgres:LNEERaCSbAKOVtdR@db.faajpcarasilbfndzkmd.supabase.co:5432/postgres"

THRESHOLD = 85      # rapidfuzz 0-100
TOP_MARGIN = 5      # best must beat 2nd by 5 points to count as unique
BATCH = 5_000
CONFIDENCE = 0.85


def clean_first(first: str) -> str:
    if not first:
        return ""
    import re
    s = re.sub(r"^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?)\s+", "", first, flags=re.I)
    s = re.sub(r"\s+(and|&).*$", "", s, flags=re.I)
    s = re.sub(r"[^A-Za-z].*$", "", s)
    return s.lower().strip()


def clean_last(last: str) -> str:
    if not last:
        return ""
    import re
    s = re.sub(r"\s*\(.*\)\s*$", "", last)
    s = re.sub(r"\s+(jr\.?|sr\.?|ii|iii|iv|2nd|3rd|4th)\s*$", "", s, flags=re.I)
    return s.lower().strip()


def main():
    print("[pass6] connecting ...")
    with psycopg.connect(DB_DSN, autocommit=False) as conn:
        # Build zip5 -> county and city -> county lookups
        print("[pass6] loading zip/city → county lookups ...")
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout='10min'")
            cur.execute("""
                SELECT zip5, lower(county)
                FROM (
                  SELECT residential_zip5 AS zip5, county,
                         ROW_NUMBER() OVER (PARTITION BY residential_zip5 ORDER BY COUNT(*) DESC) rnk
                  FROM public.mo_voter_file
                  WHERE residential_zip5 IS NOT NULL AND county IS NOT NULL
                  GROUP BY residential_zip5, county
                ) x WHERE rnk=1
            """)
            zip_to_county = dict(cur.fetchall())

            cur.execute("""
                SELECT lower(trim(residential_city)), lower(county)
                FROM (
                  SELECT residential_city, county,
                         ROW_NUMBER() OVER (PARTITION BY lower(trim(residential_city)) ORDER BY COUNT(*) DESC) rnk
                  FROM public.mo_voter_file
                  WHERE residential_city IS NOT NULL AND county IS NOT NULL
                  GROUP BY residential_city, county
                ) x WHERE rnk=1
            """)
            city_to_county = dict(cur.fetchall())

        # Load remaining no_match mec_donors
        print("[pass6] loading no_match mec_donors ...")
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id, first_name, last_name, city, zip
                FROM public.mec_donors
                WHERE match_status = 'no_match'
                  AND first_name IS NOT NULL AND last_name IS NOT NULL
            """)
            donors = cur.fetchall()
        print(f"[pass6] {len(donors):,} no_match donors to process")

        # Bucket by county
        by_county: dict[str, list] = defaultdict(list)
        for rec in donors:
            did, fn, ln, city, zipv = rec
            zip5 = (zipv or "")[:5]
            county = zip_to_county.get(zip5) or (
                city_to_county.get((city or "").lower().strip())
                if city else None
            )
            if not county:
                continue
            f = clean_first(fn)
            l = clean_last(ln)
            if len(f) < 2 or len(l) < 2:
                continue
            by_county[county].append((did, f, l, f"{f} {l}"))

        total_buckets = sum(len(v) for v in by_county.values())
        print(f"[pass6] bucketed {total_buckets:,} donors into {len(by_county):,} counties")

        # For each county, load voter-file candidates and match
        matches = []  # (donor_id, voter_id, birth_year)
        ambiguous = 0
        no_hit = 0
        processed = 0
        t0 = time.time()

        for county, donor_rows in by_county.items():
            # Load voter file rows for this county (name + id + birth_year)
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT voter_id, birth_year, lower(first_name), lower(last_name)
                    FROM public.mo_voter_file
                    WHERE lower(county) = %s AND birth_year IS NOT NULL
                    """,
                    (county,),
                )
                vrows = cur.fetchall()
            if not vrows:
                continue
            # Full name index for rapidfuzz
            choices_full = [f"{r[2]} {r[3]}" for r in vrows]

            for did, f, l, full in donor_rows:
                processed += 1
                # Use extract to get top 2
                top = process.extract(full, choices_full, scorer=fuzz.WRatio, limit=2)
                if not top:
                    no_hit += 1
                    continue
                best_name, best_score, best_idx = top[0]
                if best_score < THRESHOLD:
                    no_hit += 1
                    continue
                if len(top) >= 2 and top[1][1] + TOP_MARGIN > best_score:
                    ambiguous += 1
                    continue
                vr = vrows[best_idx]
                matches.append((did, vr[0], vr[1]))

                if processed % 2000 == 0:
                    rate = processed / (time.time() - t0) if time.time() > t0 else 0
                    print(f"  {processed:,}/{total_buckets:,}  matched={len(matches):,}  ambig={ambiguous:,}  no_hit={no_hit:,}  ({rate:.0f}/s)")

        print(f"[pass6] FINAL: processed={processed:,} matched={len(matches):,} ambiguous={ambiguous:,} no_hit={no_hit:,}")

        if not matches:
            print("[pass6] no matches to apply")
            return

        # Apply via COPY + UPDATE
        print("[pass6] applying matches ...")
        with conn.cursor() as cur:
            cur.execute("SET statement_timeout='10min'")
            cur.execute("""
                CREATE TEMP TABLE _mec_stage (
                  donor_id bigint, voter_id text, birth_year int
                ) ON COMMIT DROP
            """)
            with cur.copy("COPY _mec_stage (donor_id, voter_id, birth_year) FROM STDIN") as cpy:
                for m in matches:
                    cpy.write_row(m)
            cur.execute(
                """
                UPDATE public.mec_donors d
                SET mo_voter_file_id = s.voter_id,
                    date_of_birth    = make_date(s.birth_year, 7, 1),
                    birth_year       = s.birth_year,
                    dob_source       = 'voter_file',
                    match_status     = 'matched',
                    match_confidence = %s,
                    match_pass       = 'pass6_fuzzy_county'
                FROM _mec_stage s
                WHERE d.id = s.donor_id
                  AND d.match_status = 'no_match';
                """,
                (CONFIDENCE,),
            )
            print(f"[pass6] applied {cur.rowcount} updates")
        conn.commit()

        with conn.cursor() as cur:
            cur.execute("SELECT match_status, match_pass, COUNT(*) FROM public.mec_donors GROUP BY 1, 2 ORDER BY 1, 3 DESC")
            for row in cur.fetchall():
                print(f"  {row[0]:<16} {row[1] or '':<28} {row[2]:>10,}")


if __name__ == "__main__":
    main()
