-- 20260421_12_mec_donors_nickname_pass.sql
-- Pass 2 for mec_donors: SQL-based nickname expansion.
-- Creates a lookup table of common nicknames → legal names, then joins against
-- mo_voter_file using expanded first names.

BEGIN;

SET LOCAL statement_timeout = '30min';

-- Ephemeral nickname lookup (dropped at end). Populated inline via VALUES for readability.
CREATE TEMP TABLE _nicknames (nickname text, legal text) ON COMMIT DROP;
INSERT INTO _nicknames (nickname, legal) VALUES
  ('mike','michael'),('mikey','michael'),('chris','christopher'),('chris','christian'),('chris','christine'),
  ('nick','nicholas'),('nicky','nicholas'),('jim','james'),('jimmy','james'),
  ('bob','robert'),('bobby','robert'),('rob','robert'),('robbie','robert'),
  ('bill','william'),('billy','william'),('will','william'),('willy','william'),
  ('kate','katherine'),('katy','katherine'),('kathy','katherine'),('katie','katherine'),
  ('becky','rebecca'),('becca','rebecca'),('beth','elizabeth'),('betsy','elizabeth'),
  ('liz','elizabeth'),('lizzy','elizabeth'),('eliza','elizabeth'),
  ('tim','timothy'),('timmy','timothy'),('ben','benjamin'),('benny','benjamin'),
  ('tommy','thomas'),('tom','thomas'),('josh','joshua'),('ray','raymond'),
  ('ed','edward'),('eddy','edward'),('eddie','edward'),('ted','theodore'),('ted','edward'),
  ('teddy','theodore'),('jerry','gerald'),('jerry','jerome'),('gerry','gerald'),
  ('rusty','russell'),('russ','russell'),('jeremy','jeremiah'),
  ('eli','elijah'),('eli','elias'),('dusty','dustin'),('dustin','dusty'),
  ('rick','richard'),('ricky','richard'),('dick','richard'),
  ('andy','andrew'),('drew','andrew'),('ike','isaac'),('ike','dwight'),
  ('max','maxwell'),('alex','alexander'),('alex','alexandra'),
  ('sam','samuel'),('sammy','samuel'),('dan','daniel'),('danny','daniel'),
  ('dave','david'),('davy','david'),('steve','steven'),('steve','stephen'),
  ('tony','anthony'),('ron','ronald'),('ronnie','ronald'),
  ('don','donald'),('donny','donald'),('joe','joseph'),('joey','joseph'),
  ('john','jonathan'),('johnny','jonathan'),('jon','jonathan'),('jon','john'),
  ('pat','patrick'),('pat','patricia'),('patty','patricia'),('pattie','patricia'),
  ('peggy','margaret'),('maggie','margaret'),('meg','margaret'),('meg','megan'),
  ('trish','patricia'),('terry','theresa'),('terry','teresa'),
  ('teri','teresa'),('teri','theresa'),('tina','christina'),('tina','christine'),
  ('abe','abraham'),('abby','abigail'),
  ('al','albert'),('al','alfred'),('al','alan'),
  ('fred','frederick'),('freddy','frederick'),
  ('kenny','kenneth'),('ken','kenneth'),('larry','lawrence'),
  ('harry','harold'),('harry','henry'),('hank','henry'),('hal','harold'),
  ('charlie','charles'),('chuck','charles'),('chaz','charles'),
  ('gabe','gabriel'),('greg','gregory'),('matt','matthew'),('matty','matthew'),
  ('nate','nathan'),('nate','nathaniel'),('nat','nathaniel'),
  ('phil','philip'),('phil','phillip'),('mitch','mitchell'),
  ('stu','stuart'),('vince','vincent'),('vinny','vincent'),
  ('walt','walter'),('wes','wesley'),('zack','zachary'),('zach','zachary'),
  ('kev','kevin'),('mark','marcus'),('gus','augustus'),
  ('cat','catherine'),('cindy','cynthia'),('jackie','jacqueline'),('jack','john'),
  ('missi','melissa'),('missy','melissa'),('suzy','susan'),('suzie','susan'),
  ('suzanne','susan'),('sue','susan'),('rene','renee'),('rene','irene'),
  ('leslie','lesley'),('tori','victoria'),('vicky','victoria'),
  -- Reverse direction too (legal → common nickname form) for donors who registered under nickname
  ('michael','mike'),('robert','bob'),('william','bill'),('james','jim'),
  ('rebecca','becky'),('katherine','kate'),('elizabeth','beth'),('thomas','tom');

CREATE INDEX ON _nicknames (nickname);

-- Pass 2 match: for each pending donor, try expanded first names + exact last + zip
WITH expanded AS (
  SELECT d.id AS donor_id, n.legal AS fn_expanded, lower(d.last_name) AS ln, d.zip
  FROM public.mec_donors d
  JOIN _nicknames n ON n.nickname = lower(d.first_name)
  WHERE d.match_status = 'pending'
    AND d.zip IS NOT NULL
    AND d.last_name IS NOT NULL
),
match_candidates AS (
  SELECT e.donor_id, v.voter_id, v.birth_year,
         ROW_NUMBER() OVER (PARTITION BY e.donor_id ORDER BY v.voter_id) AS rn,
         COUNT(*)    OVER (PARTITION BY e.donor_id) AS n
  FROM expanded e
  JOIN public.mo_voter_file v
    ON lower(v.first_name) = e.fn_expanded
   AND lower(v.last_name)  = e.ln
   AND v.residential_zip5   = e.zip
  WHERE v.birth_year IS NOT NULL
)
UPDATE public.mec_donors d
SET mo_voter_file_id = mc.voter_id,
    date_of_birth    = make_date(mc.birth_year, 7, 1),
    birth_year       = mc.birth_year,
    dob_source       = 'voter_file',
    match_status     = 'matched'
FROM match_candidates mc
WHERE d.id = mc.donor_id AND mc.rn = 1 AND mc.n = 1;

-- Mark any remaining pending rows as no_match
UPDATE public.mec_donors SET match_status = 'no_match' WHERE match_status = 'pending';

COMMIT;

SELECT match_status, COUNT(*) FROM public.mec_donors GROUP BY 1 ORDER BY 2 DESC;
