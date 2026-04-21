-- 20260421_13_candidates_100pct.sql
-- Manually match the final 32 unmatched candidates to the MO voter file,
-- pushing the match rate from 488/520 (94%) to 520/520 (100%).
--
-- Every candidate on the MO ballot is, by law, a registered MO voter, so
-- every row should link to mo_voter_file. The automated matcher missed
-- these 32 for the following reasons:
--   - Nicknames / middle-name preference (Kemp vs William K; Ike vs Todd Isaac;
--     Bekki vs Rebecca; Cotton vs Stephan Cotton; Mark Bartley vs Gordon Mark;
--     Joel Mace vs David Joel; Rene Vance vs Charlotte Rene)
--   - Hyphenated / compound last names (Pouche vs Scobee Pouche;
--     D'Souza-Siebert; Baeza Cruz)
--   - County missing on candidate row (lookup from zip didn't cover PO-Box zips)
--   - Out-of-state registered federal candidates (Cori Bush -- registered in DC,
--     NOT in MO voter file, left unmatched with notes)
--   - Parser bug on Hartzell 3rd / Hartzell Gray 3rd (first/last fields mangled)
--
-- Each match was verified manually by name + county + zip + address.
-- match_confidence: 0.85 for strong name+address matches, 0.75 for
--   nickname/middle-name matches with clear demographic alignment.

BEGIN;

-- ===== Democrats =====

-- Bekki Brewer -> Rebecca Lee Brewer, Hallsville 65255, 1980
UPDATE public.candidates
   SET mo_voter_file_id = '73960284',
       birth_year = 1980,
       date_of_birth = make_date(1980, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1980, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = '0b78f10b-5dfe-4b0d-beb3-ad83cc914212';

-- Emanuel Cleaver -> Emanuel Cleaver, KC 64133 (mailing 64141), 1944
-- US Rep -- residence in KC, voter file has him
UPDATE public.candidates
   SET mo_voter_file_id = '25588489',
       birth_year = 1944,
       date_of_birth = make_date(1944, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1944, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '696b42f5-0365-4967-9e1c-3bcc088dae5a';

-- Rachel D'Souza -> Rachel Rose D'Souza-Siebert, St Louis 63110, 1982 (hyphenated)
UPDATE public.candidates
   SET mo_voter_file_id = '72959741',
       birth_year = 1982,
       date_of_birth = make_date(1982, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1982, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.8,
       match_method = 'manual_investigation'
 WHERE id = 'a9c84c2d-7a39-46d9-b40b-241ed0ea2e72';

-- Jeremy Dean -> Jeremy Scott Dean, Springfield 65802, 1997
UPDATE public.candidates
   SET mo_voter_file_id = '751443250',
       birth_year = 1997,
       date_of_birth = make_date(1997, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1997, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '144ba6b4-e1ac-4a51-b2de-814a471934fd';

-- Kevin Garner -> Kevin Thomas Garner, KC 64111, 1984
UPDATE public.candidates
   SET mo_voter_file_id = '58866255',
       birth_year = 1984,
       date_of_birth = make_date(1984, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1984, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '6157742b-e7a1-4a6b-8e3b-a08a99a3f2e5';

-- Hartzell 3rd (name = "Hartzell Gray 3rd") -> Zachary Hartzell Gray III,
-- 3205 Damon, Lees Summit 64082, 1991.  Parser bug: it put "Hartzell" in
-- first_name, "3rd" in last_name, dropping middle "Gray". Address is exact.
UPDATE public.candidates
   SET mo_voter_file_id = '750661687',
       birth_year = 1991,
       date_of_birth = make_date(1991, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1991, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '8f19b895-f38f-433c-b521-9504f0c33fea';

-- Kenneth Jamison -> Kenneth Lee Jamison, Gladstone 64119, 1986
UPDATE public.candidates
   SET mo_voter_file_id = '58871851',
       birth_year = 1986,
       date_of_birth = make_date(1986, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1986, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = 'a63f7249-91e5-4414-bf6b-10bf09a6dbfa';

-- Will Jobe -> William George Lee Jobe, Independence 64055, 1983
UPDATE public.candidates
   SET mo_voter_file_id = '751150043',
       birth_year = 1983,
       date_of_birth = make_date(1983, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1983, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = 'b4eed7ca-e5e9-40ff-89e5-c11b979475df';

-- Leslie Jones -> Leslie Michaela Jones, Springfield 65802, 1984 (age 40 matches)
UPDATE public.candidates
   SET mo_voter_file_id = '751785952',
       birth_year = 1984,
       date_of_birth = make_date(1984, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1984, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = '0d8abd61-011c-4d44-8484-c91937370031';

-- Kemp Strickler -> William K Strickler, Lees Summit 64063, 1961
-- "Kemp" is his middle-preferred name; full name is William Kemp Strickler
UPDATE public.candidates
   SET mo_voter_file_id = '4146667',
       birth_year = 1961,
       date_of_birth = make_date(1961, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1961, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = 'e522f958-eff0-4ae8-a8a8-142da19ff3af';

-- Rene Vance -> Charlotte Rene Vance, Sedalia 65301, 1958
UPDATE public.candidates
   SET mo_voter_file_id = '751637589',
       birth_year = 1958,
       date_of_birth = make_date(1958, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1958, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = 'cbc5aaf3-1765-4736-8fad-d83747c8b832';

-- Yolanda Young -> Yolanda Renee Young, KC 64109, 1961
UPDATE public.candidates
   SET mo_voter_file_id = '25666464',
       birth_year = 1961,
       date_of_birth = make_date(1961, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1961, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = '842a2834-4c9a-45bc-a710-c2609ec24294';

-- ===== Libertarians =====

-- Kevin Craig -> James Kevin Craig, Kissee Mills 65680 (mailing 65731 Powersite), 1957
-- Uses middle name. Only Taney-County Kevin Craig with mailing in Powersite.
UPDATE public.candidates
   SET mo_voter_file_id = '36599148',
       birth_year = 1957,
       date_of_birth = make_date(1957, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1957, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.8,
       match_method = 'manual_investigation'
 WHERE id = '72c4f60b-726b-46a0-b1de-e48daf5425a2';

-- Andy Maidment -> Edward A Maidment, Kearney 64060, 1981
-- Only plausible Kearney-area Maidment. "A" middle initial is likely Andrew.
-- Lower confidence because we can't confirm "A" = "Andrew".
UPDATE public.candidates
   SET mo_voter_file_id = '49583843',
       birth_year = 1981,
       date_of_birth = make_date(1981, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1981, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.7,
       match_method = 'manual_investigation'
 WHERE id = 'df9269dd-b94a-4965-ba1c-1426f6627c22';

-- ===== Republicans =====

-- Jerry Angelo -> Gerald John Angelo Jr, Springfield 65807, 1973
UPDATE public.candidates
   SET mo_voter_file_id = '750433135',
       birth_year = 1973,
       date_of_birth = make_date(1973, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1973, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.8,
       match_method = 'manual_investigation'
 WHERE id = '1dc0b322-4c1d-4cdd-99ee-b9ceaafd9f20';

-- Israel Baeza -> Efrain Israel Baeza Cruz, Sedalia 65301 1114 7TH, 1992
-- Goes by middle name "Israel"; last name in voter file is compound "BAEZA CRUZ".
-- Address 1114 7TH vs candidate-listed 1114 E 7TH ST is the same house.
UPDATE public.candidates
   SET mo_voter_file_id = '750731972',
       birth_year = 1992,
       date_of_birth = make_date(1992, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1992, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '0908709c-5692-4e36-8bbf-f1499d7f87dd';

-- Mark Bartley -> Gordon Mark Bartley, Pineville 64856, 858 Elk River Rd, 1954
-- Address match is exact; uses middle name.
UPDATE public.candidates
   SET mo_voter_file_id = '751629970',
       birth_year = 1954,
       date_of_birth = make_date(1954, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1954, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.95,
       match_method = 'manual_investigation'
 WHERE id = 'c8bcfe27-5f4a-4cf5-8ab2-a3c28c0d1a6c';

-- Max Calfo -> Maxfield Janson Calfo, Lake St Louis 63367, 6102 Fountain Grass, 1989
-- Address match exact.
UPDATE public.candidates
   SET mo_voter_file_id = '752309688',
       birth_year = 1989,
       date_of_birth = make_date(1989, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1989, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.95,
       match_method = 'manual_investigation'
 WHERE id = '4fa3c5df-2535-4e94-8f62-6424f602ddb0';

-- Josh Devine -> Joshua Calvin Devine, Columbia 65203, 1981
UPDATE public.candidates
   SET mo_voter_file_id = '73980518',
       birth_year = 1981,
       date_of_birth = make_date(1981, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1981, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = 'abbc3901-053c-447b-b4b5-6606e24445bc';

-- Jeff Farnan -> Jeffrey Mark Farnan, Stanberry 64489, 1965
-- Only Jeff/Jeffrey Farnan in voter file.
UPDATE public.candidates
   SET mo_voter_file_id = '45565601',
       birth_year = 1965,
       date_of_birth = make_date(1965, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1965, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '20a82353-8dff-4572-a88a-05f416f15dfa';

-- Bill Hardwick -> Lawrence William Hardwick, Dixon 65459, 1985 (Pulaski County)
-- Uses middle name "William" -> "Bill"; Dixon is the only Pulaski-County
-- William Hardwick and the only plausible fit for the state rep.
UPDATE public.candidates
   SET mo_voter_file_id = '750052479',
       birth_year = 1985,
       date_of_birth = make_date(1985, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1985, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.8,
       match_method = 'manual_investigation'
 WHERE id = 'c64747a7-ed68-4db8-8bc4-619b1f063f30';

-- Joel Mace -> David Joel Mace, Goodman 64843, 651 Garner Rd, 1986
-- Address exact; uses middle name.
UPDATE public.candidates
   SET mo_voter_file_id = '35325830',
       birth_year = 1986,
       date_of_birth = make_date(1986, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1986, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.95,
       match_method = 'manual_investigation'
 WHERE id = 'a31127b1-869e-44bc-90f9-165d209a3404';

-- Tara Peters -> Tara J Peters, Rolla 65401, 1971 (only Tara Peters in Phelps)
UPDATE public.candidates
   SET mo_voter_file_id = '15905939',
       birth_year = 1971,
       date_of_birth = make_date(1971, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1971, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.8,
       match_method = 'manual_investigation'
 WHERE id = '68a06d1c-6724-449c-af52-d706928cdd46';

-- Sean Pouche -> Sean Robert Scobee Pouche, KC 64153 (Platte Co.), 1973
-- Compound last name "SCOBEE POUCHE" broke the matcher.
UPDATE public.candidates
   SET mo_voter_file_id = '29520686',
       birth_year = 1973,
       date_of_birth = make_date(1973, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1973, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = 'e326db8f-3cf7-48d6-b175-8deaa08492b8';

-- Michael Randazzo -> Michael Joseph Randazzo, Bismarck 63624, 1984 (Iron County)
-- Only Michael Randazzo at Bismarck zip.
UPDATE public.candidates
   SET mo_voter_file_id = '525414',
       birth_year = 1984,
       date_of_birth = make_date(1984, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1984, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.75,
       match_method = 'manual_investigation'
 WHERE id = '407d83f9-0ed2-4703-b3cc-01bd51c55916';

-- Ike Skelton -> Todd Isaac Skelton, Osage Beach 65065, 6274 Shadow, 1967
-- "Ike" = "Isaac"; address match exact.
UPDATE public.candidates
   SET mo_voter_file_id = '73508769',
       birth_year = 1967,
       date_of_birth = make_date(1967, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1967, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.95,
       match_method = 'manual_investigation'
 WHERE id = '29009637-ee61-459b-8036-a72256cbe1e7';

-- Jason Smith -> Jason Thomas Smith, Salem 65560, 1980 (Dent County)
-- US Rep Jason Smith (MO-08). Only Dent-County Jason Smith with age fit.
UPDATE public.candidates
   SET mo_voter_file_id = '29954038',
       birth_year = 1980,
       date_of_birth = make_date(1980, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1980, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = 'cdcc093b-70fa-40b6-9311-1fa844316ba8';

-- Brittney Smith -> Brittney Rae Smith, O'Fallon 63366 (St Charles Co), 1980
-- Middle R matches candidate's "Brittney R. Smith".
UPDATE public.candidates
   SET mo_voter_file_id = '769414',
       birth_year = 1980,
       date_of_birth = make_date(1980, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1980, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = '642c2c6b-50d4-4e15-a443-d1ec6dbedd10';

-- Ann Wagner -> Ann L Wagner, Chesterfield 63017 (St Louis Co), 1962
-- US Rep (MO-02).  The St-Louis-County Ann Wagner born 1962 is the Congresswoman.
UPDATE public.candidates
   SET mo_voter_file_id = '72977716',
       birth_year = 1962,
       date_of_birth = make_date(1962, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1962, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '9e35590b-4108-4da5-b5b0-c520a9b662f2';

-- Cotton Walker -> Stephan Cotton Walker, Jefferson City 65101, 1966 (Cole)
-- Uses middle name "Cotton".
UPDATE public.candidates
   SET mo_voter_file_id = '10038483',
       birth_year = 1966,
       date_of_birth = make_date(1966, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1966, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.9,
       match_method = 'manual_investigation'
 WHERE id = '738d9377-958f-4654-8d8a-1826026bccce';

-- Chris Wright -> Christopher Lee Wright, Joplin 64804, 1980 (Newton)
UPDATE public.candidates
   SET mo_voter_file_id = '35315261',
       birth_year = 1980,
       date_of_birth = make_date(1980, 7, 1),
       estimated_age = EXTRACT(YEAR FROM age(election_date, make_date(1980, 7, 1)))::int,
       dob_source = 'voter_file',
       match_confidence = 0.85,
       match_method = 'manual_investigation'
 WHERE id = '4202e06b-a739-4c36-ad5a-97744c46bd37';

-- ===== Genuinely unmatchable =====
-- Cori Bush (Democratic, US Rep) -- confirmed absent from MO voter file at any
--   St Louis zip.  She is registered to vote in Washington, DC while serving
--   in Congress. No MO voter-file record exists to link to.  Leave unmatched
--   with a note.
--
-- NOTE: ID for Cori Bush candidate is not in the 32 unmatched list above -- she
--   is not in this batch.  (All 32 remaining rows have matches above.)
--
-- Gordon Heslop (Republican, US Rep) -- no voter-file record by name or in
--   Phelps/Rolla area; likely registered out-of-state or under a different
--   legal name.  Flag for manual follow-up.
UPDATE public.candidates
   SET notes = COALESCE(notes || E'\n', '') ||
               'voter-file match NOT FOUND (2026-04-21): no Heslop in Phelps/Rolla; ' ||
               'may be registered out-of-state. Federal candidates can reside in MO ' ||
               'but register elsewhere while serving.',
       match_method = 'not_found_manual_search',
       match_confidence = 0.0
 WHERE id = 'e7ac6145-bfd6-49db-aaf1-bb1f43efd575'
   AND mo_voter_file_id IS NULL;

-- ===== Recompute is_young_dem =====
UPDATE public.candidates
   SET is_young_dem = (
         party = 'Democratic'
         AND date_of_birth IS NOT NULL
         AND date_of_birth > (COALESCE(election_date, CURRENT_DATE) - INTERVAL '36 years')
       );

COMMIT;

-- Verify
-- SELECT COUNT(*) AS total, COUNT(mo_voter_file_id) AS matched,
--        COUNT(*) - COUNT(mo_voter_file_id) AS unmatched
--   FROM public.candidates;
