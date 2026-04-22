-- 20260421_15_mec_donors_pass3_4_5.sql
-- Deep mec_donors voter-file matching:
--   Pass 3: Nickname-expanded, county-scoped (handles moved donors where city
--           is stable but zip changed). Confidence 0.85.
--   Pass 4: Exact first+last statewide, UNIQUE only (handles movers). Confidence 0.75.
--   Pass 5: Fuzzy last name (Levenshtein<=2) + exact first + zip5. Confidence 0.80.
--
-- Only operates on match_status='no_match' rows. Never overrides existing matches.
-- Also adds:
--   * match_confidence numeric column
--   * match_pass text column (which pass set the match)
--   * normalized zip5 handling (strip +4)
--   * fuzzystrmatch extension for Levenshtein

BEGIN;

SET LOCAL statement_timeout = '30min';

-- Prereqs
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE public.mec_donors
  ADD COLUMN IF NOT EXISTS match_confidence numeric(4,3),
  ADD COLUMN IF NOT EXISTS match_pass       text;

-- Backfill confidence/pass for prior matches so the column is honest.
UPDATE public.mec_donors
SET match_confidence = 0.95, match_pass = 'pass1_or_2'
WHERE match_status = 'matched' AND match_confidence IS NULL;

-- -----------------------------------------------------------------------------
-- Expanded nickname table (union of prior pass-2 list + second-wave additions)
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _nicknames (nickname text, legal text) ON COMMIT DROP;
INSERT INTO _nicknames (nickname, legal) VALUES
  ('mike','michael'),('mikey','michael'),('mick','michael'),
  ('chris','christopher'),('chris','christian'),('chris','christine'),('chris','christina'),
  ('nick','nicholas'),('nicky','nicholas'),('nik','nicholas'),
  ('jim','james'),('jimmy','james'),
  ('bob','robert'),('bobby','robert'),('rob','robert'),('robbie','robert'),
  ('bill','william'),('billy','william'),('will','william'),('willy','william'),('liam','william'),
  ('kate','katherine'),('katy','katherine'),('kathy','katherine'),('katie','katherine'),('kathy','kathleen'),
  ('becky','rebecca'),('becca','rebecca'),('bekki','rebecca'),('reba','rebecca'),
  ('beth','elizabeth'),('beth','bethany'),('betsy','elizabeth'),
  ('liz','elizabeth'),('lizzy','elizabeth'),('eliza','elizabeth'),
  ('tim','timothy'),('timmy','timothy'),('ben','benjamin'),('benny','benjamin'),
  ('tommy','thomas'),('tom','thomas'),('josh','joshua'),('ray','raymond'),
  ('ed','edward'),('ed','edwin'),('ed','edmund'),('eddy','edward'),('eddie','edward'),
  ('ted','theodore'),('ted','edward'),('teddy','theodore'),
  ('jerry','gerald'),('jerry','jerome'),('jerry','gerard'),('gerry','gerald'),
  ('rusty','russell'),('russ','russell'),('jeremy','jeremiah'),('jere','jeremy'),('jere','jeremiah'),
  ('eli','elijah'),('eli','elias'),('eli','eliezer'),('dusty','dustin'),('dustin','dusty'),
  ('rick','richard'),('ricky','richard'),('dick','richard'),
  ('andy','andrew'),('drew','andrew'),('ike','isaac'),('ike','dwight'),
  ('max','maxwell'),('max','maximilian'),
  ('alex','alexander'),('alex','alexandra'),('alex','alexis'),
  ('sandy','sandra'),('sandy','alexander'),
  ('sam','samuel'),('sam','samantha'),('sammy','samuel'),
  ('dan','daniel'),('danny','daniel'),
  ('dave','david'),('davy','david'),('steve','steven'),('steve','stephen'),('stevie','steven'),
  ('tony','anthony'),('ron','ronald'),('ron','aaron'),('ronnie','ronald'),
  ('don','donald'),('donny','donald'),('joe','joseph'),('joey','joseph'),
  ('jo','joanne'),('jo','josephine'),('jojo','joanne'),('jojo','josephine'),
  ('john','jonathan'),('johnny','jonathan'),('johnny','john'),
  ('jon','jonathan'),('jon','john'),('jonny','jonathan'),
  ('pat','patrick'),('pat','patricia'),('patty','patricia'),('pattie','patricia'),
  ('peggy','margaret'),('maggie','margaret'),('meg','margaret'),('meg','megan'),
  ('trish','patricia'),('terry','theresa'),('terry','teresa'),('terry','terrence'),
  ('teri','teresa'),('teri','theresa'),
  ('tina','christina'),('tina','christine'),('tina','martina'),
  ('abe','abraham'),('abby','abigail'),
  ('al','albert'),('al','alfred'),('al','alan'),('al','alexander'),
  ('fred','frederick'),('fred','alfred'),('freddy','frederick'),
  ('kenny','kenneth'),('ken','kenneth'),('larry','lawrence'),('larry','laurence'),
  ('harry','harold'),('harry','henry'),('hank','henry'),('hal','harold'),('hal','henry'),
  ('charlie','charles'),('chuck','charles'),('chaz','charles'),
  ('gabe','gabriel'),('greg','gregory'),('greggy','gregory'),
  ('barry','barrett'),('barry','bartholomew'),('bart','bartholomew'),
  ('matt','matthew'),('matty','matthew'),
  ('nate','nathan'),('nate','nathaniel'),('nat','nathaniel'),('nat','nathan'),
  ('paddy','patrick'),
  ('phil','philip'),('phil','phillip'),('mitch','mitchell'),
  ('stu','stuart'),('stu','stewart'),
  ('vince','vincent'),('vinny','vincent'),
  ('walt','walter'),('wes','wesley'),('zack','zachary'),('zach','zachary'),
  ('kev','kevin'),('mark','marcus'),('marc','marcus'),('marc','mark'),
  ('gus','augustus'),('gus','angus'),
  ('cat','catherine'),('cat','catharine'),
  ('cindy','cynthia'),('mindy','melinda'),
  ('jackie','jacqueline'),('jackie','jacquelyn'),
  ('jack','john'),('jack','jackson'),
  ('missi','melissa'),('missy','melissa'),('missi','michelle'),('missy','michelle'),
  ('suzy','susan'),('suzie','susan'),('suzanne','susan'),('sue','susan'),('sue','susanne'),
  ('rene','renee'),('rene','irene'),
  ('leslie','lesley'),('tori','victoria'),('vicky','victoria'),
  ('rudy','rudolph'),('kemp','kempton'),
  ('brit','brittany'),('brit','britney'),
  ('brittney','brittany'),
  ('kirk','kirkland'),
  -- Second-wave additions
  ('misty','michelle'),('shelly','michelle'),('shelly','rochelle'),('shell','michelle'),
  ('marty','martin'),('marty','martha'),('marge','margaret'),('madge','margaret'),
  ('midge','margaret'),('midge','mildred'),
  ('lou','louis'),('lou','louise'),('louie','louis'),
  ('nan','nancy'),('nan','anne'),('nancy','anne'),
  ('sally','sarah'),('sal','salvatore'),('sal','sally'),
  ('xan','alexander'),('xan','alexandra'),
  ('fran','francis'),('fran','frances'),('fran','francine'),
  ('frank','francis'),('frank','franklin'),('franny','frances'),
  ('jen','jennifer'),('jen','jenna'),('jenny','jennifer'),
  ('jess','jessica'),('jess','jesse'),('jessie','jessica'),('jessie','jesse'),
  ('connie','constance'),('con','constance'),
  ('tessa','theresa'),('tessa','teresa'),('tess','theresa'),('tess','teresa'),
  ('bev','beverly'),('vi','violet'),('vi','viola'),
  ('penny','penelope'),
  ('polly','paula'),('polly','pauline'),('polly','mary'),
  ('winnie','winifred'),('dolly','dorothy'),('dot','dorothy'),('dottie','dorothy'),
  ('lily','lillian'),('lila','lillian'),
  ('rosie','rose'),('rosie','rosemary'),
  ('evie','evelyn'),('evie','eva'),
  ('lucy','lucille'),('hattie','harriet'),('sadie','sarah'),
  ('gwyn','gwendolyn'),('gwen','gwendolyn'),
  ('bernie','bernard'),('bernie','bernadette'),
  ('cliff','clifford'),('cliff','clifton'),('curt','curtis'),
  ('manny','manuel'),('manny','emmanuel'),('monty','montgomery'),
  ('reg','reginald'),('rod','rodney'),('rod','rodrick'),
  ('sol','solomon'),('theo','theodore'),
  ('dom','dominic'),('dominick','dominic'),
  ('wally','walter'),('cal','calvin'),
  ('herb','herbert'),('herm','herman'),('kurt','kurtis'),
  ('lenny','leonard'),('len','leonard'),('len','leonid'),
  ('leo','leonard'),('leo','leopold'),('leo','leonardo'),
  ('ernie','ernest'),('ern','ernest'),('gil','gilbert'),
  -- Reverse direction so donor-registered-under-legal-name also matches voter-registered-under-nickname
  ('michael','mike'),('robert','bob'),('william','bill'),('james','jim'),
  ('rebecca','becky'),('katherine','kate'),('elizabeth','beth'),('thomas','tom'),
  ('jeremiah','jeremy'),('joseph','joe'),('daniel','dan'),('christopher','chris'),
  ('nicholas','nick'),('richard','rick'),('andrew','andy'),('samuel','sam'),
  ('anthony','tony'),('kenneth','ken'),('frederick','fred'),('ronald','ron'),
  ('donald','don'),('matthew','matt'),('gregory','greg'),('timothy','tim'),
  ('margaret','peggy'),('margaret','maggie'),('patricia','pat'),('patricia','patty'),
  ('jennifer','jen'),('jessica','jess'),('victoria','tori'),('theresa','terry'),
  ('stephen','steve'),('steven','steve'),('edward','ed'),('charles','charlie')
ON CONFLICT DO NOTHING;

CREATE INDEX ON _nicknames (nickname);

-- -----------------------------------------------------------------------------
-- Helper: zip5 → county lookup (majority vote from voter file)
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _zip_counties ON COMMIT DROP AS
SELECT residential_zip5 AS zip5, county, lower(county) AS county_lc
FROM (
  SELECT residential_zip5, county,
         ROW_NUMBER() OVER (PARTITION BY residential_zip5 ORDER BY COUNT(*) DESC) AS rnk
  FROM public.mo_voter_file
  WHERE residential_zip5 IS NOT NULL AND residential_zip5 <> ''
    AND county IS NOT NULL
  GROUP BY residential_zip5, county
) x
WHERE rnk = 1;

CREATE INDEX ON _zip_counties (zip5);

-- Helper: city → county lookup (majority vote)
CREATE TEMP TABLE _city_counties ON COMMIT DROP AS
SELECT residential_city_lc AS city_lc, county_lc
FROM (
  SELECT lower(trim(residential_city)) AS residential_city_lc,
         lower(county)                 AS county_lc,
         ROW_NUMBER() OVER (
           PARTITION BY lower(trim(residential_city))
           ORDER BY COUNT(*) DESC
         ) AS rnk
  FROM public.mo_voter_file
  WHERE residential_city IS NOT NULL
    AND county IS NOT NULL
  GROUP BY 1, 2
) x
WHERE rnk = 1;

CREATE INDEX ON _city_counties (city_lc);

-- -----------------------------------------------------------------------------
-- Staging: every still-unmatched no_match mec_donor, with cleaned name/zip/county
-- -----------------------------------------------------------------------------
-- Clean first_name: strip trailing initial punctuation, take first token if
-- there's an "and" or "&" pattern ("Dr. John and Anne" → "John"), keep the
-- raw too.
CREATE TEMP TABLE _pending ON COMMIT DROP AS
WITH raw AS (
  SELECT d.id AS donor_id,
         d.first_name,
         d.last_name,
         d.city,
         d.zip,
         substring(d.zip FROM '(\d{5})') AS zip5
  FROM public.mec_donors d
  WHERE d.match_status = 'no_match'
    AND d.first_name IS NOT NULL
    AND d.last_name  IS NOT NULL
),
clean AS (
  SELECT donor_id,
         -- Drop leading honorifics + take first alpha word from first_name
         -- (handles "Dr. John and Anne" → "John", "Mary Sue" → "Mary")
         lower(
           regexp_replace(
             regexp_replace(
               regexp_replace(first_name, '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?)\s+', '', 'i'),
               '\s+(and|&).*$', '', 'i'
             ),
             '[^A-Za-z].*$', ''
           )
         ) AS fn_first,
         -- Also keep a "compound" first name — middle name position (e.g. "Mary Sue" → "sue")
         lower(
           NULLIF(
             regexp_replace(
               regexp_replace(first_name, '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?)\s+', '', 'i'),
               '^[A-Za-z]+\s+', ''
             ),
             first_name
           )
         ) AS fn_middle,
         -- Clean last: drop suffixes "Jr", "Sr", "III", "(Trust)" etc.
         lower(
           trim(
             regexp_replace(
               regexp_replace(last_name, '\s*\(.*\)\s*$', ''),
               '\s+(jr\.?|sr\.?|ii|iii|iv|2nd|3rd|4th)\s*$', '', 'i'
             )
           )
         ) AS ln,
         lower(trim(regexp_replace(city, ',?\s*MO$', '', 'i'))) AS city_lc,
         zip5
  FROM raw
)
SELECT * FROM clean
WHERE fn_first IS NOT NULL AND fn_first <> ''
  AND ln       IS NOT NULL AND ln       <> ''
  AND length(fn_first) >= 2
  AND length(ln)       >= 2;

CREATE INDEX ON _pending (donor_id);
CREATE INDEX ON _pending (fn_first, ln, zip5);
CREATE INDEX ON _pending (fn_first, ln);

-- -----------------------------------------------------------------------------
-- PRE-PASS: Exact first+last+zip5 (catches rows where zip+4 prevented match)
-- -----------------------------------------------------------------------------
WITH match_candidates AS (
  SELECT p.donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY p.donor_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY p.donor_id) AS n
  FROM _pending p
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = p.fn_first
   AND lower(v.last_name)  = p.ln
   AND v.residential_zip5   = p.zip5
  WHERE v.birth_year IS NOT NULL AND p.zip5 IS NOT NULL
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.95,
    match_pass       = 'pass2b_zip5'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

DELETE FROM _pending WHERE donor_id IN (
  SELECT id FROM public.mec_donors WHERE match_status = 'matched'
);

-- -----------------------------------------------------------------------------
-- PASS 3: nickname-expanded + county-scoped
-- Derive county from zip5 first (via _zip_counties), fall back to city lookup.
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _pending_with_county ON COMMIT DROP AS
SELECT p.donor_id, p.fn_first, p.fn_middle, p.ln,
       COALESCE(zc.county_lc, cc.county_lc) AS county_lc
FROM _pending p
LEFT JOIN _zip_counties  zc ON zc.zip5    = p.zip5
LEFT JOIN _city_counties cc ON cc.city_lc = p.city_lc;

CREATE INDEX ON _pending_with_county (fn_first, ln, county_lc);
CREATE INDEX ON _pending_with_county (donor_id);

WITH expanded AS (
  -- Base: the donor's own first name
  SELECT pwc.donor_id, pwc.fn_first AS fn_try, pwc.ln, pwc.county_lc
  FROM _pending_with_county pwc
  WHERE pwc.county_lc IS NOT NULL
  UNION ALL
  -- Expanded: nickname → legal (and reverse, via the union above)
  SELECT pwc.donor_id, n.legal AS fn_try, pwc.ln, pwc.county_lc
  FROM _pending_with_county pwc
  JOIN _nicknames n ON n.nickname = pwc.fn_first
  WHERE pwc.county_lc IS NOT NULL
  UNION ALL
  -- Middle-name-as-first-name (Mary Sue → try Sue)
  SELECT pwc.donor_id, pwc.fn_middle AS fn_try, pwc.ln, pwc.county_lc
  FROM _pending_with_county pwc
  WHERE pwc.county_lc IS NOT NULL
    AND pwc.fn_middle IS NOT NULL AND length(pwc.fn_middle) >= 2
),
match_candidates AS (
  SELECT e.donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY e.donor_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY e.donor_id) AS n
  FROM expanded e
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = e.fn_try
   AND lower(v.last_name)  = e.ln
   AND lower(v.county)     = e.county_lc
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.85,
    match_pass       = 'pass3_nickname_county'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

DELETE FROM _pending_with_county WHERE donor_id IN (
  SELECT id FROM public.mec_donors WHERE match_status = 'matched'
);
DELETE FROM _pending WHERE donor_id IN (
  SELECT id FROM public.mec_donors WHERE match_status = 'matched'
);

-- -----------------------------------------------------------------------------
-- PASS 4: exact first+last statewide — UNIQUE only (catches movers)
-- Also try nickname-expansion statewide (unique-only).
-- -----------------------------------------------------------------------------
WITH expanded AS (
  SELECT p.donor_id, p.fn_first AS fn_try, p.ln
  FROM _pending p
  UNION ALL
  SELECT p.donor_id, n.legal AS fn_try, p.ln
  FROM _pending p
  JOIN _nicknames n ON n.nickname = p.fn_first
  UNION ALL
  SELECT p.donor_id, p.fn_middle AS fn_try, p.ln
  FROM _pending p
  WHERE p.fn_middle IS NOT NULL AND length(p.fn_middle) >= 2
),
match_candidates AS (
  SELECT e.donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY e.donor_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY e.donor_id) AS n
  FROM expanded e
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = e.fn_try
   AND lower(v.last_name)  = e.ln
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.75,
    match_pass       = 'pass4_statewide_unique'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

DELETE FROM _pending WHERE donor_id IN (
  SELECT id FROM public.mec_donors WHERE match_status = 'matched'
);

-- -----------------------------------------------------------------------------
-- PASS 5: fuzzy last-name (Levenshtein<=2) + exact first + zip5
-- Scope to zip5 to prevent explosion. Only for donors with zip5.
-- Requires last name length >= 4 (so "Li" etc. don't fuzz-match).
-- -----------------------------------------------------------------------------
WITH candidate_pool AS (
  SELECT p.donor_id, p.fn_first, p.ln, p.zip5
  FROM _pending p
  WHERE p.zip5 IS NOT NULL
    AND length(p.ln) >= 4
),
match_candidates AS (
  SELECT cp.donor_id, v.voter_id, v.birth_year,
         levenshtein(lower(v.last_name), cp.ln) AS lev_dist,
         ROW_NUMBER() OVER (
           PARTITION BY cp.donor_id
           ORDER BY levenshtein(lower(v.last_name), cp.ln) ASC, v.voter_id
         ) AS rn,
         COUNT(*) OVER (PARTITION BY cp.donor_id) AS n
  FROM candidate_pool cp
  JOIN public.mo_voter_file v
    ON v.residential_zip5   = cp.zip5
   AND lower(v.first_name)  = cp.fn_first
   AND v.birth_year        IS NOT NULL
   AND length(v.last_name) >= 4
   AND levenshtein(lower(v.last_name), cp.ln) BETWEEN 1 AND 2
   -- Levenshtein is O(n*m) — scope query so index on (first_name, zip5) prunes hard.
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.80,
    match_pass       = 'pass5_fuzzy_last_zip'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

COMMIT;

-- Status rollup
SELECT match_status, match_pass, COUNT(*)
FROM public.mec_donors
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
