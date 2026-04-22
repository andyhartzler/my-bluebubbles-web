-- 20260421_16_donor_enrichment_deep.sql
-- Deep donor_enrichment voter-file matching mirror of mec_donors passes 3-5.
--
-- full_name is a single text field (e.g. "JOHN SMITH"). We split on first space.
-- Only processes rows where mo_voter_file_id IS NULL AND current_state='MO'.
-- Skips obvious corporate/PAC entities via name pattern.

BEGIN;

SET LOCAL statement_timeout = '30min';

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE public.donor_enrichment
  ADD COLUMN IF NOT EXISTS match_confidence numeric(4,3),
  ADD COLUMN IF NOT EXISTS match_pass       text;

UPDATE public.donor_enrichment
SET match_confidence = 0.95, match_pass = 'pass1_or_2'
WHERE mo_voter_file_id IS NOT NULL AND match_confidence IS NULL;

-- -----------------------------------------------------------------------------
-- Same nickname table as mec_donors migration
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
  ('jo','joanne'),('jo','josephine'),
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
  ('gabe','gabriel'),('greg','gregory'),
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
-- zip5 → county and city → county lookups (same as mec_donors migration)
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
-- Staging: pending donor_enrichment rows with parsed first/last, cleaned zip
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _pending ON COMMIT DROP AS
WITH raw AS (
  SELECT e.id AS enr_id,
         e.full_name,
         e.current_city,
         e.current_zip,
         substring(e.current_zip FROM '(\d{5})') AS zip5
  FROM public.donor_enrichment e
  WHERE e.mo_voter_file_id IS NULL
    AND e.current_state = 'MO'
    AND e.full_name IS NOT NULL AND e.full_name <> ''
    AND e.full_name NOT ILIKE '%LLC%'    AND e.full_name NOT ILIKE '%PAC%'
    AND e.full_name NOT ILIKE '%INC%'    AND e.full_name NOT ILIKE '%CORP%'
    AND e.full_name NOT ILIKE '%COMPANY%' AND e.full_name NOT ILIKE '%COMMITTEE%'
    AND e.full_name NOT ILIKE '%UNION%'  AND e.full_name NOT ILIKE '%FUND%'
    AND e.full_name NOT ILIKE '%FOUNDATION%' AND e.full_name NOT ILIKE '%ASSOC%'
    AND e.full_name NOT ILIKE '%TRUST%'
),
clean AS (
  SELECT enr_id,
         -- First token of full_name, strip honorifics and "and/&" partners
         lower(
           regexp_replace(
             regexp_replace(
               regexp_replace(full_name, '^(DR\.?|MR\.?|MRS\.?|MS\.?|REV\.?)\s+', '', 'i'),
               '\s+(AND|&).*$', '', 'i'
             ),
             '[^A-Za-z].*$', ''
           )
         ) AS fn_first,
         -- "Last" token after the first alpha word
         lower(
           trim(
             regexp_replace(
               regexp_replace(
                 regexp_replace(full_name, '^(DR\.?|MR\.?|MRS\.?|MS\.?|REV\.?)\s+', '', 'i'),
                 '^[A-Za-z]+\.?\s+', ''
               ),
               '\s+(JR\.?|SR\.?|II|III|IV|2ND|3RD|4TH)\s*$', '', 'i'
             )
           )
         ) AS ln,
         lower(trim(regexp_replace(current_city, ',?\s*MO$', '', 'i'))) AS city_lc,
         zip5
  FROM raw
)
SELECT * FROM clean
WHERE fn_first IS NOT NULL AND fn_first <> ''
  AND ln IS NOT NULL AND ln <> ''
  AND length(fn_first) >= 2
  AND length(ln) >= 2;

CREATE INDEX ON _pending (enr_id);
CREATE INDEX ON _pending (fn_first, ln, zip5);
CREATE INDEX ON _pending (fn_first, ln);

-- -----------------------------------------------------------------------------
-- PRE-PASS: Exact first+last+zip5 (catches rows where zip+4 prevented match)
-- -----------------------------------------------------------------------------
WITH match_candidates AS (
  SELECT p.enr_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY p.enr_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY p.enr_id) AS n
  FROM _pending p
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = p.fn_first
   AND lower(v.last_name)  = p.ln
   AND v.residential_zip5   = p.zip5
  WHERE v.birth_year IS NOT NULL AND p.zip5 IS NOT NULL
)
UPDATE public.donor_enrichment e
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    dob_year         = mc.birth_year,
    dob_source       = 'voter_file',
    match_confidence = 0.95,
    match_pass       = 'pass2b_zip5'
FROM match_candidates mc
WHERE e.id = mc.enr_id AND mc.rn = 1 AND mc.n = 1
  AND e.mo_voter_file_id IS NULL;

DELETE FROM _pending WHERE enr_id IN (
  SELECT id FROM public.donor_enrichment WHERE mo_voter_file_id IS NOT NULL
);

-- -----------------------------------------------------------------------------
-- PASS 3: nickname-expanded + county-scoped
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _pending_with_county ON COMMIT DROP AS
SELECT p.enr_id, p.fn_first, p.ln,
       COALESCE(zc.county_lc, cc.county_lc) AS county_lc
FROM _pending p
LEFT JOIN _zip_counties  zc ON zc.zip5    = p.zip5
LEFT JOIN _city_counties cc ON cc.city_lc = p.city_lc;

CREATE INDEX ON _pending_with_county (fn_first, ln, county_lc);
CREATE INDEX ON _pending_with_county (enr_id);

WITH expanded AS (
  SELECT pwc.enr_id, pwc.fn_first AS fn_try, pwc.ln, pwc.county_lc
  FROM _pending_with_county pwc
  WHERE pwc.county_lc IS NOT NULL
  UNION ALL
  SELECT pwc.enr_id, n.legal AS fn_try, pwc.ln, pwc.county_lc
  FROM _pending_with_county pwc
  JOIN _nicknames n ON n.nickname = pwc.fn_first
  WHERE pwc.county_lc IS NOT NULL
),
match_candidates AS (
  SELECT e.enr_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY e.enr_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY e.enr_id) AS n
  FROM expanded e
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = e.fn_try
   AND lower(v.last_name)  = e.ln
   AND lower(v.county)     = e.county_lc
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.donor_enrichment e
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    dob_year         = mc.birth_year,
    dob_source       = 'voter_file',
    match_confidence = 0.85,
    match_pass       = 'pass3_nickname_county'
FROM match_candidates mc
WHERE e.id = mc.enr_id AND mc.rn = 1 AND mc.n = 1
  AND e.mo_voter_file_id IS NULL;

DELETE FROM _pending WHERE enr_id IN (
  SELECT id FROM public.donor_enrichment WHERE mo_voter_file_id IS NOT NULL
);

-- -----------------------------------------------------------------------------
-- PASS 4: exact first+last statewide — UNIQUE only
-- -----------------------------------------------------------------------------
WITH expanded AS (
  SELECT p.enr_id, p.fn_first AS fn_try, p.ln
  FROM _pending p
  UNION ALL
  SELECT p.enr_id, n.legal AS fn_try, p.ln
  FROM _pending p
  JOIN _nicknames n ON n.nickname = p.fn_first
),
match_candidates AS (
  SELECT e.enr_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY e.enr_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY e.enr_id) AS n
  FROM expanded e
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = e.fn_try
   AND lower(v.last_name)  = e.ln
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.donor_enrichment e
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    dob_year         = mc.birth_year,
    dob_source       = 'voter_file',
    match_confidence = 0.75,
    match_pass       = 'pass4_statewide_unique'
FROM match_candidates mc
WHERE e.id = mc.enr_id AND mc.rn = 1 AND mc.n = 1
  AND e.mo_voter_file_id IS NULL;

DELETE FROM _pending WHERE enr_id IN (
  SELECT id FROM public.donor_enrichment WHERE mo_voter_file_id IS NOT NULL
);

-- -----------------------------------------------------------------------------
-- PASS 5: fuzzy last (Levenshtein 1-2) + exact first + zip5
-- -----------------------------------------------------------------------------
WITH candidate_pool AS (
  SELECT p.enr_id, p.fn_first, p.ln, p.zip5
  FROM _pending p
  WHERE p.zip5 IS NOT NULL
    AND length(p.ln) >= 4
),
match_candidates AS (
  SELECT cp.enr_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (
           PARTITION BY cp.enr_id
           ORDER BY levenshtein(lower(v.last_name), cp.ln) ASC, v.voter_id
         ) AS rn,
         COUNT(*) OVER (PARTITION BY cp.enr_id) AS n
  FROM candidate_pool cp
  JOIN public.mo_voter_file v
    ON v.residential_zip5   = cp.zip5
   AND lower(v.first_name)  = cp.fn_first
   AND v.birth_year        IS NOT NULL
   AND length(v.last_name) >= 4
   AND levenshtein(lower(v.last_name), cp.ln) BETWEEN 1 AND 2
)
UPDATE public.donor_enrichment e
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    dob_year         = mc.birth_year,
    dob_source       = 'voter_file',
    match_confidence = 0.80,
    match_pass       = 'pass5_fuzzy_last_zip'
FROM match_candidates mc
WHERE e.id = mc.enr_id AND mc.rn = 1 AND mc.n = 1
  AND e.mo_voter_file_id IS NULL;

COMMIT;

SELECT match_pass, COUNT(*)
FROM public.donor_enrichment
WHERE mo_voter_file_id IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;
