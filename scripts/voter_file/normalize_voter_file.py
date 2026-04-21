"""Transform the 1.68GB PSR tab-delimited file into a clean CSV for psql COPY.

- Reads tab-delimited source
- Writes comma-separated CSV with proper quoting
- Normalizes birthdate (year-only) to int, registration date to ISO
- Rolls 20 voter-history columns into a JSON array
- Validates voter_id present
"""
import csv
import json
import sys
from datetime import datetime
from pathlib import Path

SRC = Path('/Users/moyd/MOYD/voter-file-enrichment-2026-04/01_extracted/data/PSR_VotersList_04012026_8-12-37 AM.txt')
DST = Path('/Users/moyd/MOYD/voter-file-enrichment-2026-04/02_normalized.csv')

# Source columns (tab-delimited headers as in the file, exactly)
SRC_COLS = [
    'County', 'Voter ID', 'First Name', 'Middle Name', 'Last Name', 'Suffix',
    'House Number', 'House Suffix', 'Pre Direction', 'Street Name', 'Street Type', 'Post Direction',
    'Unit Type', 'Unit Number', 'Non Standard Address',
    'Residential City', 'Residential State', 'Residential ZipCode',
    'Mailing Address', 'Mailing City', 'Mailing State', 'Mailing ZipCode',
    'Birthdate', 'Political Party', 'Registration Date',
    'Precinct', 'Precinct Name', 'Split', 'Township', 'Ward',
    'CONGRESSIONAL DISTRICT 20', 'LEGISLATIVE DISTRICT 20', 'SENATE DISTRICT 20',
    'Voter Status',
] + [f'Voter History {i}' for i in range(1, 21)]

# Target columns in mo_voter_file order — matches the COPY column list.
OUT_COLS = [
    'voter_id', 'county', 'first_name', 'middle_name', 'last_name', 'suffix',
    'house_number', 'house_suffix', 'pre_direction', 'street_name', 'street_type', 'post_direction',
    'unit_type', 'unit_number', 'non_standard_address',
    'residential_city', 'residential_state', 'residential_zip5',
    'mailing_address', 'mailing_city', 'mailing_state', 'mailing_zip',
    'birth_year', 'political_party', 'registration_date',
    'precinct', 'precinct_name', 'split', 'township', 'ward',
    'congressional_district', 'legislative_district', 'senate_district',
    'voter_status', 'voter_history',
]


def parse_year(s: str) -> str:
    s = (s or '').strip()
    if not s:
        return ''
    try:
        y = int(s[:4])
        return str(y) if 1900 <= y <= 2020 else ''
    except ValueError:
        return ''


def parse_iso_date(s: str) -> str:
    s = (s or '').strip()
    if not s:
        return ''
    for fmt in ('%m/%d/%Y', '%Y-%m-%d', '%m-%d-%Y'):
        try:
            return datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            continue
    return ''


def main():
    rows_in = rows_out = skipped_no_id = 0

    with SRC.open('r', encoding='utf-8', errors='replace') as fi, \
         DST.open('w', newline='', encoding='utf-8') as fo:
        reader = csv.DictReader(fi, delimiter='\t')
        writer = csv.DictWriter(
            fo, fieldnames=OUT_COLS,
            quoting=csv.QUOTE_MINIMAL, escapechar='\\',
        )
        writer.writeheader()

        for src in reader:
            rows_in += 1

            voter_id = (src.get('Voter ID') or '').strip()
            if not voter_id:
                skipped_no_id += 1
                continue

            # Collect voter history into a JSON array
            history = [
                (src.get(f'Voter History {i}') or '').strip()
                for i in range(1, 21)
            ]
            history = [h for h in history if h]

            out = {
                'voter_id': voter_id,
                'county': (src.get('County') or '').strip(),
                'first_name': (src.get('First Name') or '').strip(),
                'middle_name': (src.get('Middle Name') or '').strip(),
                'last_name': (src.get('Last Name') or '').strip(),
                'suffix': (src.get('Suffix') or '').strip(),
                'house_number': (src.get('House Number') or '').strip(),
                'house_suffix': (src.get('House Suffix') or '').strip(),
                'pre_direction': (src.get('Pre Direction') or '').strip(),
                'street_name': (src.get('Street Name') or '').strip(),
                'street_type': (src.get('Street Type') or '').strip(),
                'post_direction': (src.get('Post Direction') or '').strip(),
                'unit_type': (src.get('Unit Type') or '').strip(),
                'unit_number': (src.get('Unit Number') or '').strip(),
                'non_standard_address': (src.get('Non Standard Address') or '').strip(),
                'residential_city': (src.get('Residential City') or '').strip(),
                'residential_state': (src.get('Residential State') or '').strip(),
                'residential_zip5': ((src.get('Residential ZipCode') or '').strip()[:5]) or '',
                'mailing_address': (src.get('Mailing Address') or '').strip(),
                'mailing_city': (src.get('Mailing City') or '').strip(),
                'mailing_state': (src.get('Mailing State') or '').strip(),
                'mailing_zip': (src.get('Mailing ZipCode') or '').strip(),
                'birth_year': parse_year(src.get('Birthdate') or ''),
                'political_party': (src.get('Political Party') or '').strip(),
                'registration_date': parse_iso_date(src.get('Registration Date') or ''),
                'precinct': (src.get('Precinct') or '').strip(),
                'precinct_name': (src.get('Precinct Name') or '').strip(),
                'split': (src.get('Split') or '').strip(),
                'township': (src.get('Township') or '').strip(),
                'ward': (src.get('Ward') or '').strip(),
                'congressional_district': (src.get('CONGRESSIONAL DISTRICT 20') or '').strip(),
                'legislative_district': (src.get('LEGISLATIVE DISTRICT 20') or '').strip(),
                'senate_district': (src.get('SENATE DISTRICT 20') or '').strip(),
                'voter_status': (src.get('Voter Status') or '').strip(),
                'voter_history': json.dumps(history) if history else '',
            }
            writer.writerow(out)
            rows_out += 1

            if rows_in % 500_000 == 0:
                print(f"  processed {rows_in:,} rows ({rows_out:,} written)")

    print(f"DONE: in={rows_in:,} out={rows_out:,} skipped_no_voter_id={skipped_no_id:,}")


if __name__ == '__main__':
    main()
