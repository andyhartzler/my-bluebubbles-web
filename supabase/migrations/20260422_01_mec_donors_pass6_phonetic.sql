-- 20260422_01_mec_donors_pass6_phonetic.sql
-- Pass 6+ deep voter-file matching for remaining 99k no_match mec_donors.
--
--   Pass 6  (phonetic)           : soundex(first) AND soundex(last) + zip5, UNIQUE.  conf 0.70
--   Pass 6n (nickname_v2)        : expanded nickname list + county fallback, UNIQUE. conf 0.80
--   Pass 6h (household)          : donor last + zip matches a household member at the
--                                   same (house_number, street_name) whose first_name
--                                   matches our donor's first_name (expanded via
--                                   nicknames). UNIQUE voter. conf 0.65
--   Pass 6i (initial_last_city)  : first-initial + exact last + city + MO, UNIQUE.   conf 0.70
--   Pass 6z (fuzzy_last_zip3)    : Levenshtein<=2 last + exact first + zip3 (risky).  conf 0.60
--
-- Strictly operates on match_status='no_match' only (idempotent when re-run).
-- MO scope only — donors whose state<>'MO' never touched.
--
-- Track progress via match_pass = 'phonetic' | 'nickname_v2' | 'household' |
-- 'initial_last_city' | 'fuzzy_last_zip3'.

-- =============================================================================
-- PASS 6n — NICKNAME V2 (expanded nickname table + county fallback)
-- Run FIRST (cheaper than phonetic, higher confidence).
-- =============================================================================
BEGIN;
SET LOCAL statement_timeout = '30min';

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Expanded nickname table (pass 6n additions on top of pass 3/4 list)
CREATE TEMP TABLE _nicknames (nickname text, legal text) ON COMMIT DROP;
INSERT INTO _nicknames (nickname, legal) VALUES
  -- (Re-include baseline from pass 3/4 so this block is self-contained)
  ('mike','michael'),('mikey','michael'),('mick','michael'),
  ('chris','christopher'),('chris','christian'),('chris','christine'),('chris','christina'),
  ('nick','nicholas'),('nicky','nicholas'),('nik','nicholas'),
  ('jim','james'),('jimmy','james'),('jimmie','james'),
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
  ('stephen','steve'),('steven','steve'),('edward','ed'),('charles','charlie'),

  -- === V2 additions (mined from no_match sample 2026-04-22) ===
  ('jeff','jeffrey'),('jeff','jeffery'),('jeffie','jeffrey'),
  ('debbie','deborah'),('debby','deborah'),('deb','deborah'),('deb','debra'),
    ('debbie','debra'),('debby','debra'),('debi','deborah'),('debi','debra'),
  ('pam','pamela'),('pammy','pamela'),('pammie','pamela'),
  ('judy','judith'),('judi','judith'),('jude','judith'),
  ('kim','kimberly'),('kimmy','kimberly'),('kimmie','kimberly'),
  ('doug','douglas'),('dougie','douglas'),
  ('brad','bradley'),('brad','bradford'),('bradley','brad'),
  ('kathi','katherine'),('kathi','kathleen'),('kath','katherine'),('kath','kathleen'),
  ('cathy','catherine'),('cathi','catherine'),('cath','catherine'),
  ('catherine','cathy'),('catherine','cath'),
  ('susie','susan'),('susy','susan'),
  ('tammy','tamara'),('tam','tamara'),('tammie','tamara'),
  ('terri','teresa'),('terri','theresa'),('terrie','teresa'),
  ('joann','joanne'),('joann','joanna'),('joanne','joanna'),('joanna','joanne'),
  ('patti','patricia'),('patsy','patricia'),
  ('margie','margaret'),('peg','margaret'),('pegge','margaret'),
  ('gene','eugene'),('gene','eugenia'),('eugene','gene'),
  ('stan','stanley'),('stanley','stan'),
  ('pete','peter'),('peter','pete'),
  ('rich','richard'),
  ('barb','barbara'),('barbie','barbara'),('barby','barbara'),('babs','barbara'),
    ('barbara','barb'),
  ('nancy','nan'),
  ('shirley','shirl'),('shirl','shirley'),
  ('tanya','tatiana'),
  ('trudy','gertrude'),('trudy','trudi'),
  ('marsha','marcia'),('marcia','marsha'),
  ('maryann','mary'),('maryanne','mary'),
  ('nic','nicholas'),('nickie','nicole'),('nickie','nicholas'),
  ('sonny','sonny'),
  ('marcy','marcia'),('marcy','marcella'),
  ('johnnie','john'),('johnny','john'),
  ('ned','edward'),('ned','edwin'),
  ('dwight','dwight'),
  ('edith','edith'),
  ('ann','anne'),('anne','ann'),('annie','ann'),('annie','anne'),
  ('jennie','jennifer'),
  ('lisa','elisabeth'),
  ('rob','robin'),
  ('jan','janet'),('jan','janice'),('janet','jan'),('janice','jan'),
  ('jane','janet'),
  ('maureen','maura'),
  ('betty','elizabeth'),('bettie','elizabeth'),
  ('chuck','charlie'),
  ('karen','karin'),
  ('karin','karen'),
  ('randy','randall'),('randy','randolph'),('randall','randy'),
  ('kris','kristen'),('kris','kristin'),('kris','krista'),('kris','kristopher'),
  ('kristy','kristen'),('kristy','kristin'),('kristi','kristen'),
  ('vicki','victoria'),('vickie','victoria'),
  ('laurie','laura'),('lori','lauren'),('lori','laura'),
  ('lizzie','elizabeth'),
  ('cassie','cassandra'),('cass','cassandra'),
  ('alli','allison'),('allie','allison'),('ally','allison'),
  ('allison','alli'),
  ('mandy','amanda'),('amanda','mandy'),
  ('ronnie','ronda'),('ronda','rhonda'),
  ('tonya','antonia'),
  ('angie','angela'),('ange','angela'),
  ('tosha','latosha'),
  ('jeffrey','jeff'),('douglas','doug'),('kimberly','kim'),('deborah','debbie'),
  ('debra','debbie'),('pamela','pam'),('judith','judy'),('bradley','bradley'),
  ('elizabeth','liz'),('elizabeth','betty'),('elizabeth','betsy'),
  ('susan','sue'),('susan','susie'),
  ('pamela','pam'),('tamara','tammy'),('teresa','terri'),('theresa','terri'),
  ('eugene','gene'),('peter','pete'),('stanley','stan')
ON CONFLICT DO NOTHING;

CREATE INDEX ON _nicknames (nickname);

-- zip5 and city → county lookups
CREATE TEMP TABLE _zip_counties ON COMMIT DROP AS
SELECT residential_zip5 AS zip5, lower(county) AS county_lc
FROM (
  SELECT residential_zip5, county,
         ROW_NUMBER() OVER (PARTITION BY residential_zip5 ORDER BY COUNT(*) DESC) AS rnk
  FROM public.mo_voter_file
  WHERE residential_zip5 IS NOT NULL AND residential_zip5 <> ''
    AND county IS NOT NULL
  GROUP BY residential_zip5, county
) x WHERE rnk = 1;
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
  WHERE residential_city IS NOT NULL AND county IS NOT NULL
  GROUP BY 1, 2
) x WHERE rnk = 1;
CREATE INDEX ON _city_counties (city_lc);

-- Staging of no_match MO individuals with cleaned names
CREATE TEMP TABLE _pending ON COMMIT DROP AS
WITH raw AS (
  SELECT d.id AS donor_id,
         d.first_name,
         d.last_name,
         d.city,
         d.zip,
         d.address1,
         substring(d.zip FROM '(\d{5})') AS zip5
  FROM public.mec_donors d
  WHERE d.match_status = 'no_match'
    AND d.state = 'MO'
    AND d.first_name IS NOT NULL
    AND d.last_name  IS NOT NULL
),
clean AS (
  SELECT donor_id, address1,
         lower(
           regexp_replace(
             regexp_replace(
               regexp_replace(first_name, '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?|Col\.?|Colonel|Hon\.?)\s+', '', 'i'),
               '\s+(and|&).*$', '', 'i'
             ),
             '[^A-Za-z].*$', ''
           )
         ) AS fn_first,
         lower(
           NULLIF(
             regexp_replace(
               regexp_replace(first_name, '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?|Col\.?|Colonel|Hon\.?)\s+', '', 'i'),
               '^[A-Za-z]+\s+', ''
             ),
             first_name
           )
         ) AS fn_middle,
         lower(
           trim(
             regexp_replace(
               regexp_replace(last_name, '\s*\(.*\)\s*$', ''),
               '\s+(jr\.?|sr\.?|ii|iii|iv|2nd|3rd|4th|junior|senior)\s*$', '', 'i'
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

-- ---------------------------------------------------------------------------
-- PASS 6n-1 : nickname v2 + zip5 (cheapest, highest confidence)
-- ---------------------------------------------------------------------------
WITH expanded AS (
  SELECT p.donor_id, p.fn_first AS fn_try, p.ln, p.zip5 FROM _pending p WHERE p.zip5 IS NOT NULL
  UNION
  SELECT p.donor_id, n.legal AS fn_try, p.ln, p.zip5
  FROM _pending p JOIN _nicknames n ON n.nickname = p.fn_first
  WHERE p.zip5 IS NOT NULL
  UNION
  SELECT p.donor_id, p.fn_middle AS fn_try, p.ln, p.zip5
  FROM _pending p
  WHERE p.zip5 IS NOT NULL AND p.fn_middle IS NOT NULL AND length(p.fn_middle) >= 2
),
match_candidates AS (
  SELECT e.donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY e.donor_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY e.donor_id) AS n
  FROM expanded e
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = e.fn_try
   AND lower(v.last_name)  = e.ln
   AND v.residential_zip5   = e.zip5
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.80,
    match_pass       = 'nickname_v2'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

DELETE FROM _pending WHERE donor_id IN (
  SELECT id FROM public.mec_donors WHERE match_status = 'matched'
);

-- ---------------------------------------------------------------------------
-- PASS 6n-2 : nickname v2 + county (for donors whose zip changed)
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE _pending_with_county ON COMMIT DROP AS
SELECT p.donor_id, p.fn_first, p.fn_middle, p.ln,
       COALESCE(zc.county_lc, cc.county_lc) AS county_lc
FROM _pending p
LEFT JOIN _zip_counties  zc ON zc.zip5    = p.zip5
LEFT JOIN _city_counties cc ON cc.city_lc = p.city_lc;
CREATE INDEX ON _pending_with_county (fn_first, ln, county_lc);

WITH expanded AS (
  SELECT pwc.donor_id, pwc.fn_first AS fn_try, pwc.ln, pwc.county_lc
  FROM _pending_with_county pwc WHERE pwc.county_lc IS NOT NULL
  UNION
  SELECT pwc.donor_id, n.legal AS fn_try, pwc.ln, pwc.county_lc
  FROM _pending_with_county pwc JOIN _nicknames n ON n.nickname = pwc.fn_first
  WHERE pwc.county_lc IS NOT NULL
  UNION
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
    match_confidence = 0.80,
    match_pass       = 'nickname_v2'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

COMMIT;


-- =============================================================================
-- PASS 6  — PHONETIC (soundex-based)
-- Soundex is loose; require BOTH first+last to agree and scope by zip5. UNIQUE only.
-- =============================================================================
BEGIN;
SET LOCAL statement_timeout = '30min';

-- Rebuild _pending (fresh in this transaction)
CREATE TEMP TABLE _pending ON COMMIT DROP AS
WITH raw AS (
  SELECT d.id AS donor_id, d.first_name, d.last_name, d.city, d.zip, d.address1,
         substring(d.zip FROM '(\d{5})') AS zip5
  FROM public.mec_donors d
  WHERE d.match_status = 'no_match' AND d.state = 'MO'
    AND d.first_name IS NOT NULL AND d.last_name IS NOT NULL
),
clean AS (
  SELECT donor_id, address1,
         lower(regexp_replace(regexp_replace(regexp_replace(first_name,
           '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?|Col\.?|Colonel|Hon\.?)\s+','','i'),
           '\s+(and|&).*$','','i'),
           '[^A-Za-z].*$','')) AS fn_first,
         lower(trim(regexp_replace(regexp_replace(last_name,
           '\s*\(.*\)\s*$',''),
           '\s+(jr\.?|sr\.?|ii|iii|iv|2nd|3rd|4th|junior|senior)\s*$','','i'))) AS ln,
         lower(trim(regexp_replace(city, ',?\s*MO$', '', 'i'))) AS city_lc,
         zip5
  FROM raw
)
SELECT * FROM clean
WHERE fn_first IS NOT NULL AND fn_first <> '' AND length(fn_first) >= 3
  AND ln       IS NOT NULL AND ln       <> '' AND length(ln)       >= 4
  AND zip5     IS NOT NULL;

CREATE INDEX ON _pending (zip5, fn_first);
CREATE INDEX ON _pending (donor_id);

-- Precompute donor-side soundex so we can hash-join
CREATE TEMP TABLE _pending_phon ON COMMIT DROP AS
SELECT donor_id, fn_first, ln, zip5,
       soundex(fn_first) AS sx_first,
       soundex(ln)       AS sx_last
FROM _pending;
CREATE INDEX ON _pending_phon (zip5, sx_first, sx_last);

-- Narrow the voter file to (zip5 present in pending) — keeps JOIN tractable
CREATE TEMP TABLE _vf_phon ON COMMIT DROP AS
SELECT v.voter_id, v.birth_year, v.residential_zip5 AS zip5,
       lower(v.first_name) AS vfirst, lower(v.last_name) AS vlast,
       soundex(lower(v.first_name)) AS sx_first,
       soundex(lower(v.last_name))  AS sx_last
FROM public.mo_voter_file v
WHERE v.birth_year IS NOT NULL
  AND v.first_name IS NOT NULL AND v.last_name IS NOT NULL
  AND length(v.first_name) >= 3 AND length(v.last_name) >= 4
  AND v.residential_zip5 IN (SELECT DISTINCT zip5 FROM _pending_phon);
CREATE INDEX ON _vf_phon (zip5, sx_first, sx_last);

-- Match: soundex(first) + soundex(last) + zip5, UNIQUE voter per donor
WITH match_candidates AS (
  SELECT p.donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY p.donor_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY p.donor_id) AS n
  FROM _pending_phon p
  JOIN _vf_phon v
    ON v.zip5 = p.zip5
   AND v.sx_first = p.sx_first
   AND v.sx_last  = p.sx_last
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.70,
    match_pass       = 'phonetic'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

COMMIT;


-- =============================================================================
-- PASS 6h — HOUSEHOLD (donor last + zip matches a household member at same address
--          whose first_name matches donor's first, via nickname expansion)
-- conf 0.65
-- =============================================================================
BEGIN;
SET LOCAL statement_timeout = '30min';

-- Rebuild nickname list + pending
CREATE TEMP TABLE _nicknames (nickname text, legal text) ON COMMIT DROP;
INSERT INTO _nicknames (nickname, legal)
SELECT nickname, legal FROM (VALUES
  ('mike','michael'),('jim','james'),('bob','robert'),('bill','william'),
  ('rob','robert'),('will','william'),('kate','katherine'),('liz','elizabeth'),
  ('beth','elizabeth'),('tim','timothy'),('ben','benjamin'),('tom','thomas'),
  ('josh','joshua'),('ed','edward'),('ted','theodore'),('jerry','gerald'),
  ('rick','richard'),('andy','andrew'),('drew','andrew'),('max','maxwell'),
  ('alex','alexander'),('sam','samuel'),('dan','daniel'),('dave','david'),
  ('steve','steven'),('steve','stephen'),('tony','anthony'),('ron','ronald'),
  ('don','donald'),('joe','joseph'),('john','jonathan'),('jon','jonathan'),
  ('pat','patrick'),('peggy','margaret'),('maggie','margaret'),
  ('terry','theresa'),('abe','abraham'),('abby','abigail'),('al','albert'),
  ('fred','frederick'),('kenny','kenneth'),('ken','kenneth'),
  ('larry','lawrence'),('hank','henry'),('charlie','charles'),('chuck','charles'),
  ('greg','gregory'),('matt','matthew'),('nate','nathan'),('phil','philip'),
  ('walt','walter'),('wes','wesley'),('zack','zachary'),('zach','zachary'),
  ('kev','kevin'),('mark','marcus'),('gus','augustus'),
  ('cindy','cynthia'),('jackie','jacqueline'),('jack','john'),
  ('suzy','susan'),('sue','susan'),('tori','victoria'),('vicky','victoria'),
  ('jeff','jeffrey'),('debbie','deborah'),('debby','deborah'),('deb','deborah'),
  ('deb','debra'),('pam','pamela'),('judy','judith'),('judi','judith'),
  ('kim','kimberly'),('doug','douglas'),('brad','bradley'),
  ('kathy','katherine'),('kathy','kathleen'),('kath','katherine'),
  ('cathy','catherine'),('cath','catherine'),('susie','susan'),
  ('tammy','tamara'),('terri','teresa'),('terri','theresa'),
  ('joann','joanne'),('joanne','joanna'),
  ('patti','patricia'),('margie','margaret'),('peg','margaret'),
  ('gene','eugene'),('stan','stanley'),('pete','peter'),
  ('rich','richard'),('barb','barbara'),('nancy','nan'),
  ('ann','anne'),('annie','anne'),('jennie','jennifer'),
  ('jan','janet'),('jane','janet'),('maureen','maura'),
  ('betty','elizabeth'),('randy','randall'),('randy','randolph'),
  ('kris','kristen'),('kris','kristopher'),
  ('vicki','victoria'),('vickie','victoria'),
  ('laurie','laura'),('lori','laura'),
  ('mandy','amanda'),('angie','angela'),
  -- reverse
  ('michael','mike'),('robert','bob'),('william','bill'),('james','jim'),
  ('jeffrey','jeff'),('douglas','doug'),('kimberly','kim'),
  ('deborah','debbie'),('debra','debbie'),('pamela','pam'),('judith','judy'),
  ('katherine','kate'),('elizabeth','liz'),('elizabeth','beth'),
  ('thomas','tom'),('joseph','joe'),('daniel','dan'),('christopher','chris'),
  ('nicholas','nick'),('richard','rick'),('andrew','andy'),('samuel','sam'),
  ('anthony','tony'),('kenneth','ken'),('frederick','fred'),('ronald','ron'),
  ('donald','don'),('matthew','matt'),('gregory','greg'),('timothy','tim'),
  ('margaret','peggy'),('patricia','pat'),('patricia','patty'),
  ('jennifer','jen'),('jessica','jess'),('victoria','tori'),
  ('theresa','terri'),('teresa','terri'),('tamara','tammy'),
  ('stephen','steve'),('steven','steve'),('edward','ed'),('charles','charlie'),
  ('eugene','gene'),('peter','pete'),('stanley','stan'),
  ('barbara','barb')
) AS v(nickname, legal);
CREATE INDEX ON _nicknames (nickname);

CREATE TEMP TABLE _pending ON COMMIT DROP AS
WITH raw AS (
  SELECT d.id AS donor_id, d.first_name, d.last_name, d.city, d.zip, d.address1,
         substring(d.zip FROM '(\d{5})') AS zip5
  FROM public.mec_donors d
  WHERE d.match_status = 'no_match' AND d.state = 'MO'
    AND d.first_name IS NOT NULL AND d.last_name IS NOT NULL
    AND d.address1 IS NOT NULL
),
parsed AS (
  SELECT donor_id,
         lower(regexp_replace(regexp_replace(regexp_replace(first_name,
           '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?|Col\.?|Colonel|Hon\.?)\s+','','i'),
           '\s+(and|&).*$','','i'),
           '[^A-Za-z].*$','')) AS fn_first,
         lower(trim(regexp_replace(regexp_replace(last_name,
           '\s*\(.*\)\s*$',''),
           '\s+(jr\.?|sr\.?|ii|iii|iv|2nd|3rd|4th|junior|senior)\s*$','','i'))) AS ln,
         -- Parse house_number and first street token from address1
         (regexp_match(address1, '^(\d+)\s'))[1] AS house_num,
         lower(
           regexp_replace(
             regexp_replace(address1, '^\d+\s+', ''),  -- drop house num
             '\s+(st|street|rd|road|ave|avenue|dr|drive|ln|lane|ct|court|blvd|hwy|highway|ter|terrace|pl|place|cir|cres|pkwy|way|loop).*$', '', 'i'
           )
         ) AS street_token,
         zip5
  FROM raw
)
SELECT * FROM parsed
WHERE fn_first IS NOT NULL AND fn_first <> '' AND length(fn_first) >= 2
  AND ln       IS NOT NULL AND ln       <> '' AND length(ln)       >= 2
  AND house_num IS NOT NULL
  AND street_token IS NOT NULL AND length(street_token) >= 3
  AND zip5 IS NOT NULL;
CREATE INDEX ON _pending (zip5, ln);
CREATE INDEX ON _pending (donor_id);

-- Candidate voter pool: only voters in one of our zip5s whose last_name matches
-- a donor's last_name in that zip.  Then check household.
-- Strategy: for each pending donor, find voters at same (zip5, house_num,
-- street_token_prefix) whose first_name matches donor's first (with nickname
-- expansion).  Must be UNIQUE across all candidate first-name variants.
CREATE TEMP TABLE _vf_addr ON COMMIT DROP AS
SELECT v.voter_id, v.birth_year, v.residential_zip5 AS zip5,
       lower(v.first_name) AS vfirst, lower(v.last_name) AS vlast,
       v.house_number AS house_num,
       lower(
         regexp_replace(
           COALESCE(v.street_name,''),
           '\s+(st|street|rd|road|ave|avenue|dr|drive|ln|lane|ct|court|blvd|hwy|highway|ter|terrace|pl|place|cir|cres|pkwy|way|loop).*$', '', 'i'
         )
       ) AS street_token
FROM public.mo_voter_file v
WHERE v.residential_zip5 IN (SELECT DISTINCT zip5 FROM _pending)
  AND v.birth_year IS NOT NULL
  AND v.house_number IS NOT NULL
  AND v.street_name  IS NOT NULL;
CREATE INDEX ON _vf_addr (zip5, house_num, street_token);

-- UNIQUE voter per donor, across donor's first-name AND expansions
WITH expanded_first AS (
  SELECT donor_id, fn_first AS fn_try, ln, house_num, street_token, zip5
  FROM _pending
  UNION
  SELECT p.donor_id, n.legal AS fn_try, p.ln, p.house_num, p.street_token, p.zip5
  FROM _pending p JOIN _nicknames n ON n.nickname = p.fn_first
),
household_matches AS (
  SELECT e.donor_id, v.voter_id, v.birth_year
  FROM expanded_first e
  JOIN _vf_addr v
    ON v.zip5 = e.zip5
   AND v.house_num = e.house_num
   AND v.street_token = e.street_token
   AND v.vfirst = e.fn_try
  -- Don't require last_name match! The key insight: we want to find the donor
  -- EVEN if the voter's last_name differs (spouse, child) — but we verify the
  -- household exists for the donor's last_name by checking another voter at that
  -- same address with matching last_name.
  WHERE EXISTS (
    SELECT 1 FROM _vf_addr v2
    WHERE v2.zip5 = e.zip5
      AND v2.house_num = e.house_num
      AND v2.street_token = e.street_token
      AND v2.vlast = e.ln
  )
),
unique_matches AS (
  SELECT donor_id, voter_id, birth_year,
         ROW_NUMBER() OVER (PARTITION BY donor_id ORDER BY voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY donor_id) AS n
  FROM (SELECT DISTINCT donor_id, voter_id, birth_year FROM household_matches) d
)
UPDATE public.mec_donors d
SET mo_voter_file_id = um.voter_id,
    date_of_birth    = make_date(um.birth_year, 7, 1),
    birth_year       = um.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.65,
    match_pass       = 'household'
FROM unique_matches um
WHERE d.id = um.donor_id AND um.rn = 1 AND um.n = 1
  AND d.match_status = 'no_match';

COMMIT;


-- =============================================================================
-- PASS 6i — INITIAL + LAST + CITY (handles middle-name preference, old immigration
--           records where only an initial is given)
-- conf 0.70
-- =============================================================================
BEGIN;
SET LOCAL statement_timeout = '30min';

CREATE TEMP TABLE _pending ON COMMIT DROP AS
WITH raw AS (
  SELECT d.id AS donor_id, d.first_name, d.last_name, d.city, d.zip,
         substring(d.zip FROM '(\d{5})') AS zip5
  FROM public.mec_donors d
  WHERE d.match_status = 'no_match' AND d.state = 'MO'
    AND d.first_name IS NOT NULL AND d.last_name IS NOT NULL
    AND d.city IS NOT NULL
),
clean AS (
  SELECT donor_id,
         lower(regexp_replace(regexp_replace(regexp_replace(first_name,
           '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?|Col\.?|Colonel|Hon\.?)\s+','','i'),
           '\s+(and|&).*$','','i'),
           '[^A-Za-z].*$','')) AS fn_first,
         lower(trim(regexp_replace(regexp_replace(last_name,
           '\s*\(.*\)\s*$',''),
           '\s+(jr\.?|sr\.?|ii|iii|iv|2nd|3rd|4th|junior|senior)\s*$','','i'))) AS ln,
         lower(trim(regexp_replace(city, ',?\s*MO$', '', 'i'))) AS city_lc,
         zip5
  FROM raw
)
SELECT donor_id, fn_first, substring(fn_first FROM 1 FOR 1) AS fn_initial,
       ln, city_lc, zip5
FROM clean
WHERE fn_first IS NOT NULL AND fn_first <> ''
  AND ln       IS NOT NULL AND ln       <> ''
  AND city_lc  IS NOT NULL AND city_lc  <> ''
  AND length(ln) >= 3;
CREATE INDEX ON _pending (fn_initial, ln, city_lc);

-- Match: voter first_name starts with donor's first initial, last matches, city matches
WITH match_candidates AS (
  SELECT p.donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY p.donor_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY p.donor_id) AS n
  FROM _pending p
  JOIN public.mo_voter_file v
    ON lower(v.last_name)  = p.ln
   AND lower(trim(v.residential_city)) = p.city_lc
   AND v.residential_state = 'MO'
   AND v.birth_year IS NOT NULL
   AND lower(substring(v.first_name FROM 1 FOR 1)) = p.fn_initial
  WHERE length(p.ln) >= 3
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.70,
    match_pass       = 'initial_last_city'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

COMMIT;


-- =============================================================================
-- PASS 6z — FUZZY LAST + ZIP3 (broader geographic; risky; last resort)
-- Requires exact first, fuzzy last ≤2 within same zip3. UNIQUE only. conf 0.60.
-- Flag for human review by setting confidence low.
-- =============================================================================
BEGIN;
SET LOCAL statement_timeout = '30min';

CREATE TEMP TABLE _pending ON COMMIT DROP AS
WITH raw AS (
  SELECT d.id AS donor_id, d.first_name, d.last_name, d.zip,
         substring(d.zip FROM '(\d{5})') AS zip5,
         substring(d.zip FROM '(\d{3})') AS zip3
  FROM public.mec_donors d
  WHERE d.match_status = 'no_match' AND d.state = 'MO'
    AND d.first_name IS NOT NULL AND d.last_name IS NOT NULL
    AND d.zip IS NOT NULL
),
clean AS (
  SELECT donor_id,
         lower(regexp_replace(regexp_replace(regexp_replace(first_name,
           '^(Dr\.?|Mr\.?|Mrs\.?|Ms\.?|Rev\.?|Col\.?|Colonel|Hon\.?)\s+','','i'),
           '\s+(and|&).*$','','i'),
           '[^A-Za-z].*$','')) AS fn_first,
         lower(trim(regexp_replace(regexp_replace(last_name,
           '\s*\(.*\)\s*$',''),
           '\s+(jr\.?|sr\.?|ii|iii|iv|2nd|3rd|4th|junior|senior)\s*$','','i'))) AS ln,
         zip3
  FROM raw
)
SELECT * FROM clean
WHERE fn_first IS NOT NULL AND fn_first <> '' AND length(fn_first) >= 3
  AND ln       IS NOT NULL AND ln       <> '' AND length(ln)       >= 5
  AND zip3 IS NOT NULL;
CREATE INDEX ON _pending (zip3, fn_first);

-- Narrow voter file by (zip3, first_name) first; then fuzzy on last
CREATE TEMP TABLE _vf_z3 ON COMMIT DROP AS
SELECT v.voter_id, v.birth_year,
       substring(v.residential_zip5 FROM 1 FOR 3) AS zip3,
       lower(v.first_name) AS vfirst,
       lower(v.last_name)  AS vlast
FROM public.mo_voter_file v
WHERE v.birth_year IS NOT NULL
  AND v.first_name IS NOT NULL AND v.last_name IS NOT NULL
  AND length(v.last_name) >= 5
  AND substring(v.residential_zip5 FROM 1 FOR 3) IN (SELECT DISTINCT zip3 FROM _pending);
CREATE INDEX ON _vf_z3 (zip3, vfirst);

WITH match_candidates AS (
  SELECT p.donor_id, v.voter_id, v.birth_year,
         levenshtein(v.vlast, p.ln) AS lev,
         ROW_NUMBER() OVER (
           PARTITION BY p.donor_id
           ORDER BY levenshtein(v.vlast, p.ln) ASC, v.voter_id
         ) AS rn,
         COUNT(*) OVER (PARTITION BY p.donor_id) AS n
  FROM _pending p
  JOIN _vf_z3 v
    ON v.zip3   = p.zip3
   AND v.vfirst = p.fn_first
   AND levenshtein(v.vlast, p.ln) BETWEEN 1 AND 2
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched',
    match_confidence = 0.60,
    match_pass       = 'fuzzy_last_zip3'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1
  AND d.match_status = 'no_match';

COMMIT;

-- Rollup
SELECT match_status, match_pass, COUNT(*)
FROM public.mec_donors
GROUP BY 1,2
ORDER BY 1,3 DESC;
