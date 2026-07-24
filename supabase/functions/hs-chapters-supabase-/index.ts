// Supabase Edge Function: batch-upsert-hs-members (HIGH SCHOOL VERSION)
// Handles BOTH regular members AND officers in a single function
//
// Enhanced Features:
// - Phone number formatting to E.164
// - Zodiac sign calculation
// - County & Congressional District geocoding
// - Date joined from submission date
// - Auto-adds "High School Democrats" to committee
// - Stores high school name in high_school field
// - Officer-specific fields (position, date_elected, term_expiration)
//
// Matching Priority:
// 1. Email exact match → UPDATE existing record
// 2. Name match + Phone match (only if BOTH sides have phone) → UPDATE
// 3. Name match + DOB match (only if BOTH sides have DOB) → UPDATE
// 4. No match → CREATE new record
//
// Special handling:
// - If existing email ends in .edu and new email is different, moves old email to school_email
// - Smart per-member officer detection based on position field
// - Election dates and term expiration are optional for officers

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

// ============================================
// MISSOURI COUNTIES AND CITIES LOOKUP
// ============================================
const MISSOURI_COUNTIES = {
  'Adair County': {
    district: 'CD-6',
    cities: [
      'kirksville',
      'brashear',
      'gibbs',
      'novinger'
    ]
  },
  'Andrew County': {
    district: 'CD-6',
    cities: [
      'savannah',
      'amazonia',
      'bolckow',
      'fillmore',
      'helena',
      'rosendale'
    ]
  },
  'Atchison County': {
    district: 'CD-6',
    cities: [
      'rock port',
      'fairfax',
      'tarkio',
      'watson',
      'westboro'
    ]
  },
  'Audrain County': {
    district: 'CD-3',
    cities: [
      'mexico',
      'vandalia',
      'benton city',
      'farber',
      'laddonia'
    ]
  },
  'Barry County': {
    district: 'CD-7',
    cities: [
      'cassville',
      'monett',
      'exeter',
      'purdy',
      'butterfield'
    ]
  },
  'Barton County': {
    district: 'CD-4',
    cities: [
      'lamar',
      'golden city',
      'liberal',
      'mindenmines',
      'nashville'
    ]
  },
  'Bates County': {
    district: 'CD-4',
    cities: [
      'butler',
      'rich hill',
      'adrian',
      'amsterdam',
      'amoret'
    ]
  },
  'Benton County': {
    district: 'CD-4',
    cities: [
      'warsaw',
      'lincoln',
      'cole camp',
      'edwards',
      'ionia'
    ]
  },
  'Bollinger County': {
    district: 'CD-8',
    cities: [
      'marble hill',
      'glenallen',
      'leopold',
      'scopus',
      'zalma'
    ]
  },
  'Boone County': {
    district: 'CD-4',
    cities: [
      'columbia',
      'como',
      'ashland',
      'centralia',
      'hallsville'
    ]
  },
  'Buchanan County': {
    district: 'CD-6',
    cities: [
      'st. joseph',
      'st joseph',
      'agency',
      'country club',
      'de kalb'
    ]
  },
  'Butler County': {
    district: 'CD-8',
    cities: [
      'poplar bluff',
      'fisk',
      'neelyville',
      'qulin',
      'rombauer'
    ]
  },
  'Caldwell County': {
    district: 'CD-6',
    cities: [
      'kingston',
      'braymer',
      'breckenridge',
      'cowgill',
      'hamilton'
    ]
  },
  'Callaway County': {
    district: 'CD-3',
    cities: [
      'fulton',
      'auxvasse',
      'holts summit',
      'kingdom city',
      'new bloomfield'
    ]
  },
  'Camden County': {
    district: 'CD-4',
    cities: [
      'camdenton',
      'lake ozark',
      'osage beach',
      'climax springs',
      'linn creek'
    ]
  },
  'Cape Girardeau County': {
    district: 'CD-8',
    cities: [
      'cape girardeau',
      'jackson',
      'scott city',
      'chaffee',
      'delta'
    ]
  },
  'Carroll County': {
    district: 'CD-6',
    cities: [
      'carrollton',
      'bogard',
      'bosworth',
      'de witt',
      'norborne'
    ]
  },
  'Carter County': {
    district: 'CD-8',
    cities: [
      'van buren',
      'ellsinore',
      'fremont',
      'grandin'
    ]
  },
  'Cass County': {
    district: 'CD-4',
    cities: [
      'belton',
      'harrisonville',
      'raymore',
      'peculiar',
      'pleasant hill'
    ]
  },
  'Cedar County': {
    district: 'CD-4',
    cities: [
      'stockton',
      'el dorado springs',
      'cedar springs',
      'dadeville'
    ]
  },
  'Chariton County': {
    district: 'CD-6',
    cities: [
      'keytesville',
      'brunswick',
      'dalton',
      'marceline',
      'salisbury'
    ]
  },
  'Christian County': {
    district: 'CD-7',
    cities: [
      'ozark',
      'nixa',
      'clever',
      'billings',
      'chadwick'
    ]
  },
  'Clark County': {
    district: 'CD-6',
    cities: [
      'kahoka',
      'alexandria',
      'luray',
      'revere',
      'st. francisville'
    ]
  },
  'Clay County': {
    district: 'CD-5',
    cities: [
      'liberty',
      'gladstone',
      'north kansas city',
      'excelsior springs',
      'kearney',
      'smithville'
    ]
  },
  'Clinton County': {
    district: 'CD-6',
    cities: [
      'plattsburg',
      'cameron',
      'lathrop',
      'gower',
      'trimble'
    ]
  },
  'Cole County': {
    district: 'CD-3',
    cities: [
      'jefferson city',
      'jeff city',
      'brazito',
      'centertown',
      'elston'
    ]
  },
  'Cooper County': {
    district: 'CD-4',
    cities: [
      'boonville',
      'pilot grove',
      'bunceton',
      'otterville',
      'prairie home'
    ]
  },
  'Crawford County': {
    district: 'CD-3',
    cities: [
      'cuba',
      'steelville',
      'bourbon',
      'leasburg',
      'sullivan'
    ]
  },
  'Dade County': {
    district: 'CD-7',
    cities: [
      'greenfield',
      'lockwood',
      'dadeville',
      'everton'
    ]
  },
  'Dallas County': {
    district: 'CD-4',
    cities: [
      'buffalo',
      'louisburg',
      'urbana',
      'elkland',
      'half way'
    ]
  },
  'Daviess County': {
    district: 'CD-6',
    cities: [
      'gallatin',
      'pattonsburg',
      'altamont',
      'jameson',
      'jamesport'
    ]
  },
  'DeKalb County': {
    district: 'CD-6',
    cities: [
      'maysville',
      'amity',
      'clarksdale',
      'cosby',
      'osborn'
    ]
  },
  'Dent County': {
    district: 'CD-8',
    cities: [
      'salem',
      'jadwin',
      'lenox'
    ]
  },
  'Douglas County': {
    district: 'CD-8',
    cities: [
      'ava',
      'cabool',
      'dogwood',
      'glenwood',
      'goodhope'
    ]
  },
  'Dunklin County': {
    district: 'CD-8',
    cities: [
      'kennett',
      'malden',
      'campbell',
      'cardwell',
      'clarkton'
    ]
  },
  'Franklin County': {
    district: 'CD-2',
    cities: [
      'washington',
      'union',
      'pacific',
      'st. clair',
      'sullivan'
    ]
  },
  'Gasconade County': {
    district: 'CD-3',
    cities: [
      'hermann',
      'owensville',
      'bland',
      'mount sterling',
      'morrison'
    ]
  },
  'Gentry County': {
    district: 'CD-6',
    cities: [
      'albany',
      'stanberry',
      'king city',
      'darlington',
      'gentry'
    ]
  },
  'Greene County': {
    district: 'CD-7',
    cities: [
      'springfield',
      'sgf',
      'republic',
      'willard',
      'strafford'
    ]
  },
  'Grundy County': {
    district: 'CD-6',
    cities: [
      'trenton',
      'galt',
      'laredo',
      'spickard',
      'tindall'
    ]
  },
  'Harrison County': {
    district: 'CD-6',
    cities: [
      'bethany',
      'cainsville',
      'eagleville',
      'gilman city'
    ]
  },
  'Henry County': {
    district: 'CD-4',
    cities: [
      'clinton',
      'windsor',
      'calhoun',
      'deepwater',
      'montrose'
    ]
  },
  'Hickory County': {
    district: 'CD-4',
    cities: [
      'hermitage',
      'preston',
      'cross timbers',
      'flemington'
    ]
  },
  'Holt County': {
    district: 'CD-6',
    cities: [
      'oregon',
      'mound city',
      'craig',
      'forest city',
      'maitland'
    ]
  },
  'Howard County': {
    district: 'CD-4',
    cities: [
      'fayette',
      'glasgow',
      'armstrong',
      'new franklin'
    ]
  },
  'Howell County': {
    district: 'CD-8',
    cities: [
      'west plains',
      'mountain view',
      'willow springs'
    ]
  },
  'Iron County': {
    district: 'CD-8',
    cities: [
      'ironton',
      'annapolis',
      'arcadia',
      'pilot knob',
      'viburnum'
    ]
  },
  'Jackson County': {
    district: 'CD-5',
    cities: [
      'kansas city',
      'kc',
      'kcmo',
      'independence',
      'blue springs',
      'lees summit',
      "lee's summit",
      'raytown',
      'grandview',
      'grain valley'
    ]
  },
  'Jasper County': {
    district: 'CD-7',
    cities: [
      'joplin',
      'webb city',
      'carthage',
      'carl junction',
      'sarcoxie'
    ]
  },
  'Jefferson County': {
    district: 'CD-2',
    cities: [
      'arnold',
      'festus',
      'imperial',
      'crystal city',
      'herculaneum',
      'hillsboro',
      'de soto'
    ]
  },
  'Johnson County': {
    district: 'CD-4',
    cities: [
      'warrensburg',
      'holden',
      'knob noster',
      'centerview'
    ]
  },
  'Knox County': {
    district: 'CD-6',
    cities: [
      'edina',
      'knox city',
      'baring',
      'hurdland',
      'plevna'
    ]
  },
  'Laclede County': {
    district: 'CD-4',
    cities: [
      'lebanon',
      'conway',
      'richland',
      'phillipsburg',
      'stoutland'
    ]
  },
  'Lafayette County': {
    district: 'CD-4',
    cities: [
      'lexington',
      'higginsville',
      'odessa',
      'concordia',
      'alma'
    ]
  },
  'Lawrence County': {
    district: 'CD-7',
    cities: [
      'mount vernon',
      'aurora',
      'marionville',
      'miller',
      'monett'
    ]
  },
  'Lewis County': {
    district: 'CD-6',
    cities: [
      'canton',
      'la grange',
      'monticello',
      'durham',
      'ewing'
    ]
  },
  'Lincoln County': {
    district: 'CD-2',
    cities: [
      'troy',
      'wentzville',
      'moscow mills',
      'winfield',
      'elsberry'
    ]
  },
  'Linn County': {
    district: 'CD-6',
    cities: [
      'brookfield',
      'linneus',
      'laclede',
      'meadville',
      'marceline'
    ]
  },
  'Livingston County': {
    district: 'CD-6',
    cities: [
      'chillicothe',
      'utica',
      'dawn',
      'mooresville',
      'ludlow'
    ]
  },
  'Macon County': {
    district: 'CD-6',
    cities: [
      'macon',
      'bevier',
      'la plata',
      'atlanta',
      'new cambria'
    ]
  },
  'Madison County': {
    district: 'CD-8',
    cities: [
      'fredericktown',
      'marquand',
      'st. mary',
      'mine la motte'
    ]
  },
  'Maries County': {
    district: 'CD-3',
    cities: [
      'vienna',
      'belle',
      'vichy',
      'dixon',
      'westphalia'
    ]
  },
  'Marion County': {
    district: 'CD-6',
    cities: [
      'hannibal',
      'palmyra',
      'philadelphia',
      'monroe city',
      'la grange'
    ]
  },
  'McDonald County': {
    district: 'CD-7',
    cities: [
      'pineville',
      'anderson',
      'goodman',
      'noel',
      'south west city'
    ]
  },
  'Mercer County': {
    district: 'CD-6',
    cities: [
      'princeton',
      'mercer',
      'cainsville',
      'ravanna',
      'harris'
    ]
  },
  'Miller County': {
    district: 'CD-4',
    cities: [
      'tuscumbia',
      'eldon',
      'iberia',
      'olean',
      'brumley'
    ]
  },
  'Mississippi County': {
    district: 'CD-8',
    cities: [
      'charleston',
      'east prairie',
      'wyatt',
      'anniston',
      'bertrand'
    ]
  },
  'Moniteau County': {
    district: 'CD-4',
    cities: [
      'california',
      'tipton',
      'jamestown',
      'clarksburg',
      'high point'
    ]
  },
  'Monroe County': {
    district: 'CD-6',
    cities: [
      'paris',
      'madison',
      'holliday',
      'santa fe',
      'stoutsville'
    ]
  },
  'Montgomery County': {
    district: 'CD-3',
    cities: [
      'montgomery city',
      'wellsville',
      'bellflower',
      'jonesburg'
    ]
  },
  'Morgan County': {
    district: 'CD-4',
    cities: [
      'versailles',
      'stover',
      'gravois mills',
      'laurie',
      'rocky mount'
    ]
  },
  'New Madrid County': {
    district: 'CD-8',
    cities: [
      'new madrid',
      'portageville',
      'lilbourn',
      'marston',
      'canalou'
    ]
  },
  'Newton County': {
    district: 'CD-7',
    cities: [
      'neosho',
      'granby',
      'seneca',
      'diamond',
      'newtonia'
    ]
  },
  'Nodaway County': {
    district: 'CD-6',
    cities: [
      'maryville',
      'burlington junction',
      'clearmont',
      'elmo',
      'graham'
    ]
  },
  'Oregon County': {
    district: 'CD-8',
    cities: [
      'alton',
      'thayer',
      'couch',
      'koshkonong',
      'myrtle'
    ]
  },
  'Osage County': {
    district: 'CD-3',
    cities: [
      'linn',
      'belle',
      'freeburg',
      'westphalia',
      'argyle'
    ]
  },
  'Ozark County': {
    district: 'CD-8',
    cities: [
      'gainesville',
      'theodosia',
      'bakersfield',
      'brixey',
      'dora'
    ]
  },
  'Pemiscot County': {
    district: 'CD-8',
    cities: [
      'caruthersville',
      'hayti',
      'steele',
      'holland',
      'braggadocio'
    ]
  },
  'Perry County': {
    district: 'CD-8',
    cities: [
      'perryville',
      'st. mary',
      'altenburg',
      'biehle',
      'brazeau'
    ]
  },
  'Pettis County': {
    district: 'CD-4',
    cities: [
      'sedalia',
      'smithton',
      'green ridge',
      'hughesville',
      'la monte'
    ]
  },
  'Phelps County': {
    district: 'CD-8',
    cities: [
      'rolla',
      'st. james',
      'newburg',
      'cuba',
      'doolittle'
    ]
  },
  'Pike County': {
    district: 'CD-3',
    cities: [
      'bowling green',
      'louisiana',
      'clarksville',
      'curryville',
      'eolia'
    ]
  },
  'Platte County': {
    district: 'CD-6',
    cities: [
      'platte city',
      'parkville',
      'riverside',
      'smithville',
      'weston'
    ]
  },
  'Polk County': {
    district: 'CD-4',
    cities: [
      'bolivar',
      'humansville',
      'fair play',
      'flemington',
      'half way'
    ]
  },
  'Pulaski County': {
    district: 'CD-4',
    cities: [
      'waynesville',
      'fort leonard wood',
      'crocker',
      'dixon',
      'richland'
    ]
  },
  'Putnam County': {
    district: 'CD-6',
    cities: [
      'unionville',
      'powersville',
      'livonia',
      'lucerne',
      'queen city'
    ]
  },
  'Ralls County': {
    district: 'CD-3',
    cities: [
      'new london',
      'perry',
      'center',
      'saverton',
      'spalding'
    ]
  },
  'Randolph County': {
    district: 'CD-6',
    cities: [
      'moberly',
      'huntsville',
      'cairo',
      'clark',
      'higbee'
    ]
  },
  'Ray County': {
    district: 'CD-6',
    cities: [
      'richmond',
      'lawson',
      'excelsior springs',
      'hardin',
      'orrick'
    ]
  },
  'Reynolds County': {
    district: 'CD-8',
    cities: [
      'centerville',
      'ellington',
      'bunker',
      'redford',
      'lesterville'
    ]
  },
  'Ripley County': {
    district: 'CD-8',
    cities: [
      'doniphan',
      'current view',
      'naylor',
      'oxly',
      'briar'
    ]
  },
  'St. Charles County': {
    district: 'CD-2',
    cities: [
      'st. charles',
      'st charles',
      "o'fallon",
      'ofallon',
      'wentzville',
      'st. peters',
      'st peters',
      'lake st. louis',
      'lake st louis',
      'dardenne prairie'
    ]
  },
  'St. Clair County': {
    district: 'CD-4',
    cities: [
      'osceola',
      'appleton city',
      'lowry city',
      'roscoe',
      'vista'
    ]
  },
  'St. Francois County': {
    district: 'CD-8',
    cities: [
      'farmington',
      'park hills',
      'bonne terre',
      'desloge',
      'flat river'
    ]
  },
  'St. Louis City': {
    district: 'CD-1',
    cities: [
      'st. louis',
      'st louis',
      'stl'
    ]
  },
  'St. Louis County': {
    district: 'CD-1',
    cities: [
      'clayton',
      'university city',
      'webster groves',
      'kirkwood',
      'florissant',
      'chesterfield',
      'ballwin',
      'maryland heights',
      'hazelwood'
    ]
  },
  'Ste. Genevieve County': {
    district: 'CD-8',
    cities: [
      'ste. genevieve',
      'st. mary',
      'bloomsdale',
      'river aux vases'
    ]
  },
  'Saline County': {
    district: 'CD-4',
    cities: [
      'marshall',
      'slater',
      'sweet springs',
      'malta bend',
      'miami'
    ]
  },
  'Schuyler County': {
    district: 'CD-6',
    cities: [
      'lancaster',
      'queen city',
      'downing',
      'glenwood'
    ]
  },
  'Scotland County': {
    district: 'CD-6',
    cities: [
      'memphis',
      'gorin',
      'granger',
      'arbela',
      'rutledge'
    ]
  },
  'Scott County': {
    district: 'CD-8',
    cities: [
      'sikeston',
      'scott city',
      'benton',
      'chaffee',
      'morley'
    ]
  },
  'Shannon County': {
    district: 'CD-8',
    cities: [
      'eminence',
      'birch tree',
      'winona',
      'alley spring',
      'summersville'
    ]
  },
  'Shelby County': {
    district: 'CD-6',
    cities: [
      'shelbyville',
      'shelbina',
      'bethel',
      'clarence',
      'emden'
    ]
  },
  'Stoddard County': {
    district: 'CD-8',
    cities: [
      'dexter',
      'bloomfield',
      'bernie',
      'advance',
      'bell city'
    ]
  },
  'Stone County': {
    district: 'CD-7',
    cities: [
      'branson',
      'kimberling city',
      'crane',
      'galena',
      'hurley'
    ]
  },
  'Sullivan County': {
    district: 'CD-6',
    cities: [
      'milan',
      'green city',
      'pollock',
      'humphreys',
      'newtown'
    ]
  },
  'Taney County': {
    district: 'CD-7',
    cities: [
      'branson',
      'hollister',
      'forsyth',
      'rockaway beach',
      'bull creek'
    ]
  },
  'Texas County': {
    district: 'CD-8',
    cities: [
      'houston',
      'cabool',
      'licking',
      'summersville',
      'bucyrus'
    ]
  },
  'Vernon County': {
    district: 'CD-4',
    cities: [
      'nevada',
      'el dorado springs',
      'walker',
      'cottey',
      'deerfield'
    ]
  },
  'Warren County': {
    district: 'CD-2',
    cities: [
      'warrenton',
      'wright city',
      'marthasville',
      'truesdale',
      'innsbrook'
    ]
  },
  'Washington County': {
    district: 'CD-8',
    cities: [
      'potosi',
      'caledonia',
      'mineral point',
      'richwoods',
      'belgrade'
    ]
  },
  'Wayne County': {
    district: 'CD-8',
    cities: [
      'greenville',
      'piedmont',
      'patterson',
      'silva',
      'mill spring'
    ]
  },
  'Webster County': {
    district: 'CD-7',
    cities: [
      'marshfield',
      'rogersville',
      'seymour',
      'diggins',
      'fordland'
    ]
  },
  'Worth County': {
    district: 'CD-6',
    cities: [
      'grant city',
      'worth',
      'allendale',
      'denver',
      'sheridan'
    ]
  },
  'Wright County': {
    district: 'CD-8',
    cities: [
      'hartville',
      'mountain grove',
      'mansfield',
      'norwood',
      'ava'
    ]
  }
};

// ZIP code to County mapping (most common MO zip codes)
const ZIP_TO_COUNTY = {
  '63101': 'St. Louis City',
  '63102': 'St. Louis City',
  '63103': 'St. Louis City',
  '63104': 'St. Louis City',
  '63105': 'St. Louis County',
  '63106': 'St. Louis City',
  '63107': 'St. Louis City',
  '63108': 'St. Louis City',
  '63109': 'St. Louis City',
  '63110': 'St. Louis City',
  '63111': 'St. Louis City',
  '63112': 'St. Louis City',
  '63113': 'St. Louis City',
  '63114': 'St. Louis County',
  '63115': 'St. Louis City',
  '63116': 'St. Louis City',
  '63117': 'St. Louis County',
  '63118': 'St. Louis City',
  '63119': 'St. Louis County',
  '63120': 'St. Louis City',
  '63121': 'St. Louis County',
  '63122': 'St. Louis County',
  '63123': 'St. Louis County',
  '63124': 'St. Louis County',
  '63125': 'St. Louis County',
  '63126': 'St. Louis County',
  '63127': 'St. Louis County',
  '63128': 'St. Louis County',
  '63129': 'St. Louis County',
  '63130': 'St. Louis County',
  '63131': 'St. Louis County',
  '63132': 'St. Louis County',
  '63133': 'St. Louis County',
  '63134': 'St. Louis County',
  '63135': 'St. Louis County',
  '63136': 'St. Louis County',
  '63137': 'St. Louis County',
  '63138': 'St. Louis County',
  '63139': 'St. Louis City',
  '63140': 'St. Louis County',
  '63141': 'St. Louis County',
  '63143': 'St. Louis County',
  '63144': 'St. Louis County',
  '63145': 'St. Louis County',
  '63146': 'St. Louis County',
  '63147': 'St. Louis County',
  '64101': 'Jackson County',
  '64102': 'Jackson County',
  '64105': 'Jackson County',
  '64106': 'Jackson County',
  '64108': 'Jackson County',
  '64109': 'Jackson County',
  '64110': 'Jackson County',
  '64111': 'Jackson County',
  '64112': 'Jackson County',
  '64113': 'Jackson County',
  '64114': 'Jackson County',
  '64116': 'Clay County',
  '64117': 'Clay County',
  '64118': 'Clay County',
  '64119': 'Clay County',
  '64120': 'Jackson County',
  '64123': 'Jackson County',
  '64124': 'Jackson County',
  '64125': 'Jackson County',
  '64126': 'Jackson County',
  '64127': 'Jackson County',
  '64128': 'Jackson County',
  '64129': 'Jackson County',
  '64130': 'Jackson County',
  '64131': 'Jackson County',
  '64132': 'Jackson County',
  '64133': 'Jackson County',
  '64134': 'Jackson County',
  '64136': 'Jackson County',
  '64137': 'Jackson County',
  '64138': 'Jackson County',
  '64139': 'Jackson County',
  '64145': 'Jackson County',
  '64146': 'Jackson County',
  '64147': 'Jackson County',
  '64149': 'Jackson County',
  '64150': 'Jackson County',
  '64151': 'Clay County',
  '64152': 'Platte County',
  '64153': 'Clay County',
  '64154': 'Platte County',
  '64155': 'Clay County',
  '64156': 'Clay County',
  '64157': 'Clay County',
  '64158': 'Platte County',
  '64161': 'Jackson County',
  '64163': 'Platte County',
  '64164': 'Platte County',
  '64165': 'Platte County',
  '64166': 'Platte County',
  '64167': 'Platte County',
  '65201': 'Boone County',
  '65202': 'Boone County',
  '65203': 'Boone County',
  '65401': 'Phelps County',
  '65801': 'Greene County',
  '65802': 'Greene County',
  '65803': 'Greene County',
  '65804': 'Greene County',
  '65806': 'Greene County',
  '65807': 'Greene County',
  '65809': 'Greene County',
  '65810': 'Greene County'
};

// ============================================
// HELPER FUNCTIONS
// ============================================

// Calculate zodiac sign from date of birth
function getZodiacSign(dateOfBirth) {
  if (!dateOfBirth) return '';
  const date = new Date(dateOfBirth);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  
  if (month === 3 && day >= 21 || month === 4 && day <= 19) return 'Aries';
  if (month === 4 && day >= 20 || month === 5 && day <= 20) return 'Taurus';
  if (month === 5 && day >= 21 || month === 6 && day <= 20) return 'Gemini';
  if (month === 6 && day >= 21 || month === 7 && day <= 22) return 'Cancer';
  if (month === 7 && day >= 23 || month === 8 && day <= 22) return 'Leo';
  if (month === 8 && day >= 23 || month === 9 && day <= 22) return 'Virgo';
  if (month === 9 && day >= 23 || month === 10 && day <= 22) return 'Libra';
  if (month === 10 && day >= 23 || month === 11 && day <= 21) return 'Scorpio';
  if (month === 11 && day >= 22 || month === 12 && day <= 21) return 'Sagittarius';
  if (month === 12 && day >= 22 || month === 1 && day <= 19) return 'Capricorn';
  if (month === 1 && day >= 20 || month === 2 && day <= 18) return 'Aquarius';
  if (month === 2 && day >= 19 || month === 3 && day <= 20) return 'Pisces';
  
  return '';
}

// Format phone number to E.164 format
function formatPhoneE164(phone) {
  if (!phone) return '';
  const digits = phone.replace(/\D/g, '');
  
  if (digits.length === 11 && digits.startsWith('1')) {
    return `+${digits}`;
  }
  if (digits.length === 10) {
    return `+1${digits}`;
  }
  
  return phone;
}

// Geocode address to find county and congressional district
function geocodeAddress(fullAddress, city, state, zipCode) {
  let county = '';
  let district = '';
  
  // Try ZIP code first (most reliable)
  if (zipCode) {
    const cleanZip = zipCode.toString().trim().slice(0, 5);
    if (ZIP_TO_COUNTY[cleanZip]) {
      county = ZIP_TO_COUNTY[cleanZip];
      const countyData = MISSOURI_COUNTIES[county];
      if (countyData) {
        district = countyData.district;
      }
    }
  }
  
  // If no ZIP match, try city name
  if (!county && city) {
    const lowerCity = city.toLowerCase().trim();
    for (const [countyName, data] of Object.entries(MISSOURI_COUNTIES)) {
      if (data.cities.some((c) => lowerCity.includes(c) || c.includes(lowerCity))) {
        county = countyName;
        district = data.district;
        break;
      }
    }
  }
  
  // If still no match, try full address string
  if (!county && fullAddress) {
    const lowerAddress = fullAddress.toLowerCase().trim();
    for (const [countyName, data] of Object.entries(MISSOURI_COUNTIES)) {
      // Check if county name is in address
      if (lowerAddress.includes(countyName.toLowerCase())) {
        county = countyName;
        district = data.district;
        break;
      }
      // Check if any city is in address
      if (data.cities.some((c) => lowerAddress.includes(c))) {
        county = countyName;
        district = data.district;
        break;
      }
    }
  }
  
  return { county, district };
}

// Format date to YYYY-MM-DD
function formatDate(dateString) {
  if (!dateString) return null;
  try {
    const date = new Date(dateString);
    return date.toISOString().split('T')[0];
  } catch {
    return null;
  }
}

// ============================================
// MAIN MEMBER PROCESSING FUNCTION
// ============================================

async function processSingleMember(
  supabaseClient,
  memberData,
  chapterName,
  schoolName,
  highSchool,  // ← ADDED: High school parameter
  submissionDate,
  isOfficersForm = false
) {
  try {
    // Construct full name and normalize email
    const fullName = `${memberData.firstName.trim()} ${memberData.lastName.trim()}`;
    const normalizedEmail = memberData.email.trim().toLowerCase();
    
    // Handle address - officers form has full address, members form needs construction
    let address = memberData.address || null;
    if (!address && (memberData.city || memberData.state || memberData.zipCode)) {
      const parts = [];
      if (memberData.city) parts.push(memberData.city);
      if (memberData.state) parts.push(memberData.state);
      if (memberData.zipCode) parts.push(memberData.zipCode);
      address = parts.join(', ');
    }
    
    console.log(`Processing: ${fullName} (${normalizedEmail}) ${isOfficersForm ? '[OFFICER FORM]' : '[MEMBER FORM]'}`);
    
    // ============================================
    // CALCULATE ENHANCED FIELDS
    // ============================================
    
    // Format phone to E.164
    const phone_e164 = formatPhoneE164(memberData.phone);
    
    // Calculate zodiac sign
    const zodiac_sign = getZodiacSign(memberData.dateOfBirth);
    
    // Geocode location
    const locationInfo = geocodeAddress(
      address,
      memberData.city,
      memberData.state,
      memberData.zipCode
    );
    
    // Format dates
    const date_of_birth = formatDate(memberData.dateOfBirth);
    const date_joined = formatDate(submissionDate) || new Date().toISOString().split('T')[0];
    
    // ============================================
    // STEP 1: Check for name matches
    // ============================================
    
    const { data: nameMatches, error: nameError } = await supabaseClient
      .from('members')
      .select('*')
      .ilike('name', fullName)
      .limit(10);
    
    if (nameError) throw nameError;
    
    console.log(`Found ${nameMatches?.length || 0} name matches for "${fullName}"`);
    
    // ============================================
    // STEP 2: Check for email match
    // ============================================
    
    const { data: emailMatches, error: emailError } = await supabaseClient
      .from('members')
      .select('*')
      .eq('email', normalizedEmail)
      .single();
    
    if (emailError && emailError.code !== 'PGRST116') throw emailError;
    
    let matchedMember = null;
    let matchReason = '';
    
    // ============================================
    // MATCHING LOGIC
    // ============================================
    
    // Priority 1: Email exact match (strongest signal)
    if (emailMatches) {
      matchedMember = emailMatches;
      matchReason = 'email_exact_match';
      console.log(`✓ Email match for ${normalizedEmail}`);
    } 
    else if (nameMatches && nameMatches.length > 0) {
      console.log(`Checking phone/DOB for name matches...`);
      
      for (const candidate of nameMatches) {
        // ============================================
        // PHONE MATCHING
        // Only compare if BOTH sides have phone data
        // ============================================
        if (memberData.phone && candidate.phone) {
          const incomingPhone = memberData.phone.replace(/\D/g, '');
          const existingPhone = candidate.phone.replace(/\D/g, '');
          
          if (incomingPhone.length > 0 && existingPhone.length > 0 && incomingPhone === existingPhone) {
            matchedMember = candidate;
            matchReason = 'name_and_phone_match';
            console.log(`✓ Name + phone match (${incomingPhone})`);
            break;
          }
        }
        
        // ============================================
        // DATE OF BIRTH MATCHING
        // Only if phone didn't match and BOTH sides have DOB
        // ============================================
        if (!matchedMember && memberData.dateOfBirth && candidate.date_of_birth) {
          const incomingDOB = memberData.dateOfBirth.split('T')[0];
          const existingDOB = candidate.date_of_birth.split('T')[0];
          
          if (incomingDOB && existingDOB && incomingDOB === existingDOB) {
            matchedMember = candidate;
            matchReason = 'name_and_dob_match';
            console.log(`✓ Name + DOB match (${incomingDOB})`);
            break;
          }
        }
      }
      
      if (!matchedMember) {
        console.log(`✗ No phone or DOB match found for "${fullName}"`);
      }
    }
    
    // ============================================
    // PREPARE DATA FOR INSERT/UPDATE
    // ============================================
    
    const dbMemberData = {
      name: fullName,
      email: normalizedEmail,
      phone: memberData.phone || null,
      phone_e164: phone_e164 || null,
      date_of_birth: date_of_birth,
      zodiac_sign: zodiac_sign || null,
      address: address,
      county: locationInfo.county || null,
      congressional_district: locationInfo.district || null,
      current_chapter_member: 'Yes',
      chapter_name: chapterName,
      in_school: 'Yes',
      school_name: schoolName,
      high_school: highSchool,  // ← ADDED: High school field
      committee: ['High School Democrats'],
      date_joined: date_joined
    };
    
    // ============================================
    // ADD OFFICER-SPECIFIC FIELDS (if applicable)
    // ============================================
    
    // Check if THIS SPECIFIC MEMBER is an officer
    // Either by explicit flag OR by having a position
    const isMemberOfficer = memberData.isOfficer || (memberData.position && memberData.position.trim().length > 0);
    
    if (isMemberOfficer) {
      // If this person is an officer, set officer fields from incoming data
      if (memberData.position) {
        dbMemberData.chapter_position = memberData.position;
      }
      if (memberData.dateOfElection) {
        dbMemberData.date_elected = formatDate(memberData.dateOfElection);
      }
      if (memberData.dateOfTermExpiration) {
        dbMemberData.term_expiration = formatDate(memberData.dateOfTermExpiration);
      }
      
      console.log(`Officer data: Position="${memberData.position}", Elected=${memberData.dateOfElection || 'N/A'}, Term Expires=${memberData.dateOfTermExpiration || 'N/A'}`);
    } else {
      console.log(`Regular member (no officer position)`);
    }
    
    // If this is a regular members form, DO NOT touch officer fields
    // This preserves any existing officer data in the database
    
    // ============================================
    // UPDATE OR CREATE
    // ============================================
    
    if (matchedMember) {
      console.log(`Updating member ID: ${matchedMember.id} (${matchReason})`);
      
      // Special case: .edu email handling
      if (matchedMember.email && matchedMember.email.endsWith('.edu') && 
          matchedMember.email !== normalizedEmail) {
        dbMemberData.school_email = matchedMember.email;
        console.log(`Moving .edu email to school_email: ${matchedMember.email}`);
      }
      
      // Only update date_joined if it doesn't exist
      if (matchedMember.date_joined) {
        delete dbMemberData.date_joined;
      }
      
      const { error: updateError } = await supabaseClient
        .from('members')
        .update(dbMemberData)
        .eq('id', matchedMember.id);
      
      if (updateError) throw updateError;
      
      console.log(`✓ Successfully updated member ${matchedMember.id}`);
      
      return {
        name: fullName,
        email: normalizedEmail,
        status: 'updated',
        matchReason: matchReason,
        county: locationInfo.county,
        district: locationInfo.district,
        zodiacSign: zodiac_sign,
        isOfficer: isMemberOfficer,
        position: memberData.position || matchedMember.chapter_position || null
      };
    } else {
      console.log(`Creating new member: ${fullName}`);
      
      const { error: createError } = await supabaseClient
        .from('members')
        .insert([dbMemberData]);
      
      if (createError) throw createError;
      
      console.log(`✓ Successfully created member ${fullName}`);
      
      return {
        name: fullName,
        email: normalizedEmail,
        status: 'created',
        county: locationInfo.county,
        district: locationInfo.district,
        zodiacSign: zodiac_sign,
        isOfficer: isMemberOfficer,
        position: memberData.position || null
      };
    }
  } catch (error) {
    console.error(`Error processing member:`, error);
    return {
      name: `${memberData.firstName} ${memberData.lastName}`,
      email: memberData.email,
      status: 'error',
      error: error.message
    };
  }
}

// ============================================
// MAIN HANDLER
// ============================================

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  
  try {
    // Initialize Supabase client with service role key
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    
    // Parse incoming batch request
    const batchData = await req.json();
    
    // ============================================
    // VALIDATE REQUEST
    // ============================================
    
    if (!batchData.members || !Array.isArray(batchData.members)) {
      return new Response(
        JSON.stringify({ error: 'Missing or invalid members array' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }
    
    if (!batchData.chapterName) {
      return new Response(
        JSON.stringify({ error: 'Missing chapterName' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }
    
    const isOfficersForm = batchData.isOfficersForm || false;
    
    console.log(`Processing batch of ${batchData.members.length} ${isOfficersForm ? 'OFFICERS' : 'MEMBERS'} for ${batchData.chapterName}`);
    console.log(`Submission date: ${batchData.submissionDate || 'not provided'}`);
    
    // ============================================
    // PROCESS ALL MEMBERS
    // ============================================
    
    const results = await Promise.all(
      batchData.members.map((member) =>
        processSingleMember(
          supabaseClient,
          member,
          batchData.chapterName,
          batchData.schoolName || batchData.chapterName,
          batchData.highSchool || batchData.schoolName || batchData.chapterName,  // ← ADDED: highSchool parameter
          batchData.submissionDate,
          isOfficersForm
        )
      )
    );
    
    // ============================================
    // CALCULATE SUMMARY
    // ============================================
    
    const summary = {
      success: results.filter((r) => r.status !== 'error').length,
      failed: results.filter((r) => r.status === 'error').length,
      created: results.filter((r) => r.status === 'created').length,
      updated: results.filter((r) => r.status === 'updated').length,
      officers: results.filter((r) => r.isOfficer).length,
      regularMembers: results.filter((r) => !r.isOfficer && r.status !== 'error').length,
      isOfficersForm: isOfficersForm,
      results: results
    };
    
    console.log(`✓ Batch complete: ${summary.created} created, ${summary.updated} updated, ${summary.failed} failed`);
    console.log(`  ├─ ${summary.officers} officers, ${summary.regularMembers} regular members`);
    
    // Return success response with summary
    return new Response(JSON.stringify(summary), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  } catch (error) {
    console.error('Error in batch-upsert-hs-members:', error);
    
    return new Response(
      JSON.stringify({ error: error.message, stack: error.stack }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});