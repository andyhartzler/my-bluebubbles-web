"""Nickname/suffix expansion for voter-file matching.

Input: a name like "Mike" or "Chris".
Output: a list of candidate legal names to try against the voter file, in order of
preference: the original first, then common legal forms.

Scope: the 50 most common US nicknames that showed up in the 105 unmatched MOYD
candidates. We err on the side of INCLUDING ambiguous mappings (Eli → Elijah AND
Elias) and let the voter-file match disambiguate.
"""

# nickname -> list of possible legal names (most common first)
NICKNAMES = {
    'mike': ['michael'],
    'mikey': ['michael'],
    'chris': ['christopher', 'christian', 'christine', 'christina'],
    'nick': ['nicholas', 'nicolas'],
    'nicky': ['nicholas'],
    'jim': ['james'],
    'jimmy': ['james'],
    'bob': ['robert'],
    'bobby': ['robert'],
    'rob': ['robert'],
    'robbie': ['robert'],
    'bill': ['william'],
    'billy': ['william'],
    'will': ['william'],
    'willy': ['william'],
    'liam': ['william'],
    'kate': ['katherine', 'kathryn', 'kathleen'],
    'katy': ['katherine'],
    'kathy': ['katherine', 'kathleen'],
    'katie': ['katherine', 'kathryn'],
    'becky': ['rebecca'],
    'becca': ['rebecca'],
    'bekki': ['rebecca'],
    'reba': ['rebecca'],
    'beth': ['elizabeth', 'bethany'],
    'betsy': ['elizabeth'],
    'liz': ['elizabeth'],
    'lizzy': ['elizabeth'],
    'eliza': ['elizabeth'],
    'tim': ['timothy'],
    'timmy': ['timothy'],
    'ben': ['benjamin'],
    'benny': ['benjamin'],
    'tommy': ['thomas'],
    'tom': ['thomas'],
    'josh': ['joshua'],
    'ray': ['raymond'],
    'ed': ['edward', 'edwin', 'edmund'],
    'eddy': ['edward'],
    'eddie': ['edward'],
    'ted': ['theodore', 'edward'],
    'teddy': ['theodore'],
    'jerry': ['gerald', 'jerome', 'gerard'],
    'gerry': ['gerald'],
    'rusty': ['russell'],
    'russ': ['russell'],
    'jeremy': ['jeremiah'],
    'jere': ['jeremy', 'jeremiah'],
    'eli': ['elijah', 'elias', 'eliezer'],
    'cori': ['corrine', 'cora'],
    'dusty': ['dustin'],
    'dustin': ['dusty'],
    'rick': ['richard'],
    'ricky': ['richard'],
    'dick': ['richard'],
    'andy': ['andrew'],
    'drew': ['andrew'],
    'ike': ['isaac', 'dwight'],  # Ike Skelton was Dwight
    'max': ['maxwell', 'maximilian'],
    'alex': ['alexander', 'alexandra', 'alexis'],
    'sandy': ['sandra', 'alexander'],
    'sam': ['samuel', 'samantha'],
    'sammy': ['samuel'],
    'dan': ['daniel'],
    'danny': ['daniel'],
    'dave': ['david'],
    'davy': ['david'],
    'steve': ['steven', 'stephen'],
    'stevie': ['steven'],
    'tony': ['anthony'],
    'ron': ['ronald', 'aaron'],
    'ronnie': ['ronald'],
    'don': ['donald'],
    'donny': ['donald'],
    'joe': ['joseph'],
    'joey': ['joseph'],
    'jo': ['joanne', 'josephine'],
    'jojo': ['joanne', 'josephine', 'johnathon'],
    'john': ['jonathan', 'johnathan'],
    'johnny': ['john', 'jonathan'],
    'jon': ['jonathan', 'john'],
    'jonny': ['jonathan'],
    'pat': ['patrick', 'patricia'],
    'patty': ['patricia'],
    'pattie': ['patricia'],
    'peggy': ['margaret'],
    'maggie': ['margaret'],
    'meg': ['margaret', 'megan'],
    'trish': ['patricia'],
    'terry': ['theresa', 'teresa', 'terrence'],
    'teri': ['teresa', 'theresa'],
    'tina': ['christina', 'christine', 'martina'],
    'abe': ['abraham'],
    'abby': ['abigail'],
    'al': ['albert', 'alfred', 'alan', 'alexander'],
    'fred': ['frederick', 'alfred'],
    'freddy': ['frederick'],
    'kenny': ['kenneth'],
    'ken': ['kenneth'],
    'larry': ['lawrence', 'laurence'],
    'harry': ['harold', 'henry'],
    'hank': ['henry'],
    'hal': ['harold', 'henry'],
    'charlie': ['charles'],
    'chuck': ['charles'],
    'chaz': ['charles'],
    'gabe': ['gabriel'],
    'greg': ['gregory'],
    'greggy': ['gregory'],
    'barry': ['barrett', 'bartholomew'],
    'bart': ['bartholomew'],
    'matt': ['matthew'],
    'matty': ['matthew'],
    'nate': ['nathan', 'nathaniel'],
    'nat': ['nathaniel', 'nathan'],
    'paddy': ['patrick'],
    'perry': ['peregrine', 'persimmon'],
    'phil': ['philip', 'phillip'],
    'mitch': ['mitchell'],
    'stu': ['stuart', 'stewart'],
    'vince': ['vincent'],
    'vinny': ['vincent'],
    'walt': ['walter'],
    'wes': ['wesley'],
    'zack': ['zachary'],
    'zach': ['zachary'],
    'kev': ['kevin'],
    'greg': ['gregory'],
    'mark': ['marcus'],
    'tru': ['truman', 'trudy'],
    'gus': ['augustus', 'angus'],
    'cat': ['catherine', 'catharine'],
    'mindy': ['melinda'],
    'cindy': ['cynthia'],
    'jackie': ['jacqueline', 'jacquelyn'],
    'jack': ['john', 'jackson'],
    'missi': ['melissa', 'michelle'],
    'missy': ['melissa', 'michelle', 'missouri'],
    'suzy': ['susan', 'susanna'],
    'suzie': ['susan'],
    'suzanne': ['susan', 'susanne'],
    'sue': ['susan', 'susanne'],
    'rene': ['renee', 'irene'],
    'donna': ['madonna'],
    'yolanda': ['yo'],
    'leslie': ['lesley'],
    'tara': ['tarah', 'taralee'],
    'niles': ['nile'],
    'cotton': ['cottonmouth'],  # joke — but MO might have weird names
    'burt': ['burton'],
    'rudy': ['rudolph'],
    'kemp': ['kempton'],
    'brit': ['brittany', 'britney'],
    'brittney': ['brittany', 'britany', 'brittani'],
    'drury': ['drew'],
    'kirk': ['kirkland'],
    'tori': ['victoria'],
    'vicky': ['victoria'],
    'gordon': ['gordy'],
    # Second-wave additions (2026-04-21) after examining mec_donors no_match sample
    'misty': ['michelle'],
    'shelly': ['michelle', 'rochelle'],
    'shell': ['michelle'],
    'mick': ['michael'],
    'mitzi': ['mildred', 'mary'],
    'marty': ['martin', 'martha'],
    'marge': ['margaret'],
    'madge': ['margaret'],
    'midge': ['margaret', 'mildred'],
    'lou': ['louis', 'louise'],
    'louie': ['louis'],
    'nan': ['nancy', 'anne'],
    'nancy': ['anne'],
    'sally': ['sarah'],
    'sal': ['salvatore', 'sally'],
    'hank': ['henry'],
    'xan': ['alexander', 'alexandra'],
    'fran': ['francis', 'frances', 'francine'],
    'frank': ['francis', 'franklin'],
    'franny': ['frances'],
    'jen': ['jennifer', 'jenna'],
    'jenny': ['jennifer'],
    'jess': ['jessica', 'jesse'],
    'jessie': ['jessica', 'jesse'],
    'connie': ['constance'],
    'con': ['constance'],
    'tessa': ['theresa', 'teresa'],
    'tess': ['theresa', 'teresa'],
    'bev': ['beverly'],
    'vi': ['violet', 'viola'],
    'penny': ['penelope'],
    'polly': ['paula', 'pauline', 'mary'],
    'winnie': ['winifred'],
    'dolly': ['dorothy'],
    'dot': ['dorothy'],
    'dottie': ['dorothy'],
    'lily': ['lillian'],
    'lila': ['lillian'],
    'rosie': ['rose', 'rosemary'],
    'evie': ['evelyn', 'eva'],
    'lucy': ['lucille'],
    'hattie': ['harriet'],
    'sadie': ['sarah'],
    'gwyn': ['gwendolyn'],
    'gwen': ['gwendolyn'],
    'bernie': ['bernard', 'bernadette'],
    'cliff': ['clifford', 'clifton'],
    'curt': ['curtis'],
    'manny': ['manuel', 'emmanuel'],
    'monty': ['montgomery'],
    'reg': ['reginald'],
    'rod': ['rodney', 'rodrick'],
    'sol': ['solomon'],
    'theo': ['theodore'],
    'marc': ['marcus', 'mark'],
    'nik': ['nicholas', 'nikolai'],
    'dom': ['dominic'],
    'dominick': ['dominic'],
    'wally': ['walter'],
    'ozzy': ['oswald', 'oscar'],
    'winny': ['winston'],
    'cal': ['calvin'],
    'herb': ['herbert'],
    'herm': ['herman'],
    'kurt': ['kurtis'],
    'lenny': ['leonard'],
    'len': ['leonard', 'leonid'],
    'leo': ['leonard', 'leopold', 'leonardo'],
    'jasper': ['jas'],
    'ray': ['raymond'],
    'shel': ['sheldon', 'shelley'],
    'rolly': ['roland', 'rolland'],
    'ernie': ['ernest'],
    'ern': ['ernest'],
    'gil': ['gilbert'],
    'ike': ['isaac', 'dwight', 'eisenhower'],
}

# Build reverse mapping too (legal → nicknames)
REVERSE: dict[str, list[str]] = {}
for nick, legals in NICKNAMES.items():
    for legal in legals:
        REVERSE.setdefault(legal, []).append(nick)


def candidate_first_names(first: str) -> list[str]:
    """Return first_name variants to try against the voter file."""
    first = first.strip()
    if not first:
        return []

    # Strip trailing initials / periods
    first_norm = first.rstrip('. ').lower()
    # Strip leading/trailing punctuation
    first_norm = first_norm.lstrip('.-_ ')

    variants = [first_norm]

    # Nickname → legal forms
    if first_norm in NICKNAMES:
        variants.extend(NICKNAMES[first_norm])

    # Legal → nickname (less useful but covers rare cases)
    if first_norm in REVERSE:
        variants.extend(REVERSE[first_norm])

    # Dedupe preserving order
    seen = set()
    out = []
    for v in variants:
        if v and v not in seen:
            seen.add(v)
            out.append(v)
    return out


def candidate_last_names(last: str) -> list[str]:
    """Return last_name variants: handle suffix, hyphens, apostrophes."""
    if not last:
        return []
    last = last.strip().lower()

    # Strip leading generational-suffix junk ("3rd" / "ii" / "iv" as last_name)
    if last in ('3rd', '2nd', '4th', 'ii', 'iii', 'iv', 'jr', 'sr'):
        return []

    variants = [last]

    # Hyphenated: try both halves
    if '-' in last:
        parts = last.split('-')
        variants.extend([p.strip() for p in parts if p.strip()])
        # Also try concatenated without hyphen
        variants.append(last.replace('-', ''))

    # Apostrophes — try with and without
    if "'" in last:
        variants.append(last.replace("'", ''))

    # Dedupe
    seen = set()
    out = []
    for v in variants:
        if v and v not in seen:
            seen.add(v)
            out.append(v)
    return out


if __name__ == '__main__':
    # Smoke test
    tests = [
        ('Mike', 'McCaffree'),
        ('Chris', 'Daugherty'),
        ('Jessica', "O'Neal-Slisz"),
        ('Hartzell', '3rd'),
        ('K.', 'Grant'),
        ('J.', 'Salcedo'),
    ]
    for fn, ln in tests:
        print(f'{fn!r} {ln!r}  →  first={candidate_first_names(fn)}  last={candidate_last_names(ln)}')
