# PSR Voter File — Schema Notes (2026-04-01 edition)

**Source:** `PSR_VotersList_04012026_8-12-37 AM.txt` — Missouri Secretary of State statewide voter file
**Format:** Tab-delimited, UTF-8(ish), 54 columns, 4,340,250 rows (1.68 GB)

## KEY SURPRISE: Birthdate is YEAR-ONLY

Column 23 (`Birthdate`) contains only the year (e.g. `1996`). Missouri SOS only releases the year for privacy. That's still enough for young-dem classification (≤36 years old).

Our `mo_voter_file` table will store `birth_year int`, and every person-table we enrich will get a `birth_year` column alongside `date_of_birth`. For candidates/members already flagged with full DOBs, we'll preserve precision using `dob_source`.

## Political Party column is blank

MO does not register voters by party (closed-primary exception handled via participation history). Column 24 is always space/empty. Don't rely on it — use Voter History 1-20 primary-type inferencing instead.

## Columns (54 total)

| # | Name | Type | Notes |
|---|------|------|-------|
| 1  | County | text | MO county, Title Case |
| 2  | Voter ID | text (9-digit) | PK candidate |
| 3  | First Name | text | UPPER |
| 4  | Middle Name | text | UPPER |
| 5  | Last Name | text | UPPER |
| 6  | Suffix | text | |
| 7  | House Number | text | |
| 8  | House Suffix | text | |
| 9  | Pre Direction | text | N/S/E/W |
| 10 | Street Name | text | |
| 11 | Street Type | text | ST/AVE/etc |
| 12 | Post Direction | text | |
| 13 | Unit Type | text | APT/STE |
| 14 | Unit Number | text | |
| 15 | Non Standard Address | text | free-form when not parseable |
| 16 | Residential City | text | |
| 17 | Residential State | text | |
| 18 | Residential ZipCode | text | 5-digit |
| 19 | Mailing Address | text | |
| 20 | Mailing City | text | |
| 21 | Mailing State | text | |
| 22 | Mailing ZipCode | text | |
| 23 | Birthdate | int year | **YEAR ONLY** |
| 24 | Political Party | text | blank/space always |
| 25 | Registration Date | text MM/DD/YYYY | |
| 26 | Precinct | text | |
| 27 | Precinct Name | text | |
| 28 | Split | text | |
| 29 | Township | text | |
| 30 | Ward | text | |
| 31 | CONGRESSIONAL DISTRICT 20 | text | e.g. `20 CN 6` |
| 32 | LEGISLATIVE DISTRICT 20 | text | `20 LE 003` |
| 33 | SENATE DISTRICT 20 | text | `20 SE 18` |
| 34 | Voter Status | text | Active/Inactive/Cancelled |
| 35-54 | Voter History 1-20 | text | e.g. `11/05/2024 General` |

## Load approach

1. Store voting history as `jsonb` array (20 entries, trim empties).
2. Keep residence + mailing address components in typed columns (searchable).
3. District fields as-is (strings).
4. Normalize MM/DD/YYYY dates to ISO.

## Matching implications

- Match by `(last_name, first_name, residence_zip5)` exact first.
- Fallback `(last_name, first_name, county)`.
- Trigram fuzzy `(last_name, first_name)` scoped to county.
- `birth_year` is sole DOB precision — compute age as `current_year - birth_year`.

## Data volume

- 4.34M rows × ~400 bytes raw → ~1.7 GB disk
- Post-load with JSONB history: ~1.3 GB (compression)
- Indexes: ~600 MB
- Total storage added: ~2 GB on Supabase
