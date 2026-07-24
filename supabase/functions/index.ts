// Enable Supabase Edge Function runtime types
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Comprehensive Missouri Counties and Cities Lookup
const MISSOURI_COUNTIES = {
  'Adair County': { district: 'CD-6', cities: ['kirksville', 'brashear', 'gibbs', 'novinger'] },
  'Andrew County': { district: 'CD-6', cities: ['savannah', 'amazonia', 'bolckow', 'fillmore', 'helena', 'rosendale'] },
  'Atchison County': { district: 'CD-6', cities: ['rock port', 'fairfax', 'tarkio', 'watson', 'westboro'] },
  'Audrain County': { district: 'CD-3', cities: ['mexico', 'vandalia', 'benton city', 'farber', 'laddonia', 'martinsburg', 'rush hill', 'thompson', 'wellsville'] },
  'Barry County': { district: 'CD-7', cities: ['cassville', 'monett', 'exeter', 'purdy', 'butterfield', 'seligman', 'washburn', 'wheaton'] },
  'Barton County': { district: 'CD-4', cities: ['lamar', 'golden city', 'liberal', 'mindenmines', 'nashville'] },
  'Bates County': { district: 'CD-4', cities: ['butler', 'rich hill', 'adrian', 'amsterdam', 'amoret', 'foster', 'hume', 'merwin', 'rockville'] },
  'Benton County': { district: 'CD-4', cities: ['warsaw', 'lincoln', 'cole camp', 'edwards', 'ionia', 'quincy'] },
  'Bollinger County': { district: 'CD-8', cities: ['marble hill', 'glenallen', 'leopold', 'scopus', 'zalma'] },
  'Boone County': { district: 'CD-4', cities: ['columbia', 'como', 'ashland', 'centralia', 'hallsville', 'harrisburg', 'rocheport', 'sturgeon'] },
  'Buchanan County': { district: 'CD-6', cities: ['st. joseph', 'st joseph', 'agency', 'country club', 'de kalb', 'easton', 'rushville', 'wallace'] },
  'Butler County': { district: 'CD-8', cities: ['poplar bluff', 'fisk', 'neelyville', 'qulin', 'rombauer'] },
  'Caldwell County': { district: 'CD-6', cities: ['kingston', 'braymer', 'breckenridge', 'cowgill', 'hamilton', 'kidder', 'polo'] },
  'Callaway County': { district: 'CD-3', cities: ['fulton', 'auxvasse', 'holts summit', 'kingdom city', 'new bloomfield', 'mokane', 'portland', 'steedman', 'williamsburg'] },
  'Camden County': { district: 'CD-4', cities: ['camdenton', 'lake ozark', 'osage beach', 'climax springs', 'linn creek', 'macks creek', 'roach', 'stoutland', 'sunrise beach'] },
  'Cape Girardeau County': { district: 'CD-8', cities: ['cape girardeau', 'jackson', 'scott city', 'chaffee', 'delta', 'gordonville', 'oak ridge', 'whitewater'] },
  'Carroll County': { district: 'CD-6', cities: ['carrollton', 'bogard', 'bosworth', 'de witt', 'norborne', 'tina'] },
  'Carter County': { district: 'CD-8', cities: ['van buren', 'ellsinore', 'fremont', 'grandin'] },
  'Cass County': { district: 'CD-4', cities: ['belton', 'harrisonville', 'raymore', 'peculiar', 'pleasant hill', 'garden city', 'archie', 'cleveland', 'creighton', 'drexel', 'east lynne', 'freeman', 'lake annette'] },
  'Cedar County': { district: 'CD-4', cities: ['stockton', 'el dorado springs', 'cedar springs', 'dadeville', 'jerico springs', 'umber view heights'] },
  'Chariton County': { district: 'CD-6', cities: ['keytesville', 'brunswick', 'dalton', 'marceline', 'salisbury', 'triplett'] },
  'Christian County': { district: 'CD-7', cities: ['ozark', 'nixa', 'clever', 'billings', 'chadwick', 'highlandville', 'sparta'] },
  'Clark County': { district: 'CD-6', cities: ['kahoka', 'alexandria', 'luray', 'revere', 'st. francisville', 'wayland', 'wyaconda'] },
  'Clay County': { district: 'CD-5', cities: ['liberty', 'gladstone', 'north kansas city', 'excelsior springs', 'kearney', 'smithville', 'oakwood', 'mosby', 'holt', 'avondale', 'claycomo', 'ferrelview', 'glenaire', 'homestead', 'houston lake', 'oakview', 'oakwood park', 'oaks', 'pleasant valley', 'randolph', 'riverside'] },
  'Clinton County': { district: 'CD-6', cities: ['plattsburg', 'cameron', 'lathrop', 'gower', 'trimble', 'turney'] },
  'Cole County': { district: 'CD-3', cities: ['jefferson city', 'jeff city', 'brazito', 'centertown', 'elston', 'lohman', 'russellville', 'st. martins', 'st. thomas', 'taos'] },
  'Cooper County': { district: 'CD-4', cities: ['boonville', 'pilot grove', 'bunceton', 'otterville', 'prairie home', 'speed'] },
  'Crawford County': { district: 'CD-3', cities: ['cuba', 'steelville', 'bourbon', 'leasburg', 'sullivan'] },
  'Dade County': { district: 'CD-7', cities: ['greenfield', 'lockwood', 'dadeville', 'everton'] },
  'Dallas County': { district: 'CD-4', cities: ['buffalo', 'louisburg', 'urbana', 'elkland', 'half way', 'long lane', 'niangua', 'windyville'] },
  'Daviess County': { district: 'CD-6', cities: ['gallatin', 'pattonsburg', 'altamont', 'jameson', 'jamesport', 'lock springs', 'mcfall', 'winston'] },
  'DeKalb County': { district: 'CD-6', cities: ['maysville', 'amity', 'clarksdale', 'cosby', 'osborn', 'stewartsville', 'union star', 'weatherby'] },
  'Dent County': { district: 'CD-8', cities: ['salem', 'jadwin', 'lenox'] },
  'Douglas County': { district: 'CD-8', cities: ['ava', 'cabool', 'dogwood', 'glenwood', 'goodhope', 'graff', 'vanzant'] },
  'Dunklin County': { district: 'CD-8', cities: ['kennett', 'malden', 'campbell', 'cardwell', 'clarkton', 'gobler', 'holcomb', 'hornersville', 'senath'] },
  'Franklin County': { district: 'CD-2', cities: ['washington', 'union', 'pacific', 'st. clair', 'sullivan', 'gerald', 'new haven', 'berger', 'catawissa', 'gray summit', 'labadie', 'leslie', 'lyon', 'parkway', 'rosebud', 'stanton', 'villa ridge'] },
  'Gasconade County': { district: 'CD-3', cities: ['hermann', 'owensville', 'bland', 'mount sterling', 'morrison', 'rosebud'] },
  'Gentry County': { district: 'CD-6', cities: ['albany', 'stanberry', 'king city', 'darlington', 'gentry', 'mcfall'] },
  'Greene County': { district: 'CD-7', cities: ['springfield', 'sgf', 'republic', 'willard', 'strafford', 'ash grove', 'battlefield', 'brookline', 'ebenezer', 'fair grove', 'fremont hills', 'pleasant hope', 'rogersville', 'turners'] },
  'Grundy County': { district: 'CD-6', cities: ['trenton', 'galt', 'laredo', 'spickard', 'tindall'] },
  'Harrison County': { district: 'CD-6', cities: ['bethany', 'cainsville', 'eagleville', 'gilman city', 'martinsville', 'ridgeway'] },
  'Henry County': { district: 'CD-4', cities: ['clinton', 'windsor', 'calhoun', 'deepwater', 'montrose', 'urich', 'blairstown', 'leesville'] },
  'Hickory County': { district: 'CD-4', cities: ['hermitage', 'preston', 'cross timbers', 'flemington', 'weaubleau', 'wheatland'] },
  'Holt County': { district: 'CD-6', cities: ['oregon', 'mound city', 'craig', 'forest city', 'maitland'] },
  'Howard County': { district: 'CD-4', cities: ['fayette', 'glasgow', 'armstrong', 'new franklin'] },
  'Howell County': { district: 'CD-8', cities: ['west plains', 'mountain view', 'willow springs', 'brandsville', 'moody', 'pomona', 'pottersville'] },
  'Iron County': { district: 'CD-8', cities: ['ironton', 'annapolis', 'arcadia', 'pilot knob', 'viburnum'] },
  'Jackson County': { district: 'CD-5', cities: ['kansas city', 'kc', 'kcmo', 'independence', 'blue springs', 'lees summit', "lee's summit", 'raytown', 'grandview', 'grain valley', 'oak grove', 'greenwood', 'lake lotawana', 'lake tapawingo', 'lone jack', 'levasy', 'buckner', 'bates city', 'sibley', 'unity village', 'sugar creek'] },
  'Jasper County': { district: 'CD-7', cities: ['joplin', 'webb city', 'carthage', 'carl junction', 'sarcoxie', 'carterville', 'duenweg', 'oronogo', 'airport drive', 'alba', 'avilla', 'asbury', 'diamond', 'duquesne', 'grand falls plaza', 'la russell', 'purcell', 'reeds', 'waco'] },
  'Jefferson County': { district: 'CD-2', cities: ['arnold', 'festus', 'imperial', 'crystal city', 'herculaneum', 'hillsboro', 'de soto', 'byrnes mill', 'high ridge', 'murphy', 'antonia', 'barnhart', 'cedar hill', 'cedar hill lakes', 'dittmer', 'fletcher', 'fountain n lakes', 'Goldman', 'horine', 'kimmswick', 'mapaville', 'maxville', 'olympian village', 'otto', 'pevely', 'seckman', 'sunnyside', 'valles mines', 'victoria'] },
  'Johnson County': { district: 'CD-4', cities: ['warrensburg', 'holden', 'knob noster', 'centerview', 'chilhowee', 'kingsville', 'leeton'] },
  'Knox County': { district: 'CD-6', cities: ['edina', 'knox city', 'baring', 'hurdland', 'plevna'] },
  'Laclede County': { district: 'CD-4', cities: ['lebanon', 'conway', 'richland', 'phillipsburg', 'stoutland', 'bennett spring', 'eldridge', 'falcon', 'morgan heights', 'competition', 'sleeper'] },
  'Lafayette County': { district: 'CD-4', cities: ['lexington', 'higginsville', 'odessa', 'concordia', 'alma', 'corder', 'mayview', 'wellington', 'aullville', 'bates city', 'dover', 'emma', 'napoleon', 'waterloo', 'waverly'] },
  'Lawrence County': { district: 'CD-7', cities: ['mount vernon', 'aurora', 'marionville', 'miller', 'monett', 'pierce city', 'stotts city', 'verona', 'freistatt', 'halltown', 'la russell'] },
  'Lewis County': { district: 'CD-6', cities: ['canton', 'la grange', 'monticello', 'durham', 'ewing', 'lewistown'] },
  'Lincoln County': { district: 'CD-2', cities: ['troy', 'wentzville', 'moscow mills', 'winfield', 'elsberry', 'bowling green', 'foley', 'hawk point', 'old monroe', 'truesdale', 'davis', 'silex'] },
  'Linn County': { district: 'CD-6', cities: ['brookfield', 'linneus', 'laclede', 'meadville', 'marceline', 'bucklin', 'browning', 'purdin'] },
  'Livingston County': { district: 'CD-6', cities: ['chillicothe', 'utica', 'dawn', 'mooresville', 'ludlow', 'wheeling'] },
  'Macon County': { district: 'CD-6', cities: ['macon', 'bevier', 'la plata', 'atlanta', 'new cambria', 'anabel', 'callao', 'elmer', 'ethel'] },
  'Madison County': { district: 'CD-8', cities: ['fredericktown', 'marquand', 'st. mary', 'mine la motte'] },
  'Maries County': { district: 'CD-3', cities: ['vienna', 'belle', 'vichy', 'dixon', 'westphalia', 'brinktown'] },
  'Marion County': { district: 'CD-6', cities: ['hannibal', 'palmyra', 'philadelphia', 'monroe city', 'la grange'] },
  'McDonald County': { district: 'CD-7', cities: ['pineville', 'anderson', 'goodman', 'noel', 'south west city', 'rocky comfort', 'splitlog', 'tiff city', 'lanagan'] },
  'Mercer County': { district: 'CD-6', cities: ['princeton', 'mercer', 'cainsville', 'ravanna', 'harris'] },
  'Miller County': { district: 'CD-4', cities: ['tuscumbia', 'eldon', 'iberia', 'olean', 'brumley', 'st. anthony', 'st. elizabeth', 'lake ozark', 'rocky mount'] },
  'Mississippi County': { district: 'CD-8', cities: ['charleston', 'east prairie', 'wyatt', 'anniston', 'bertrand', 'big oak tree', 'dorena', 'howardville', 'pinhook', 'wolf island'] },
  'Moniteau County': { district: 'CD-4', cities: ['california', 'tipton', 'jamestown', 'clarksburg', 'high point', 'latham', 'lupus'] },
  'Monroe County': { district: 'CD-6', cities: ['paris', 'madison', 'holliday', 'santa fe', 'stoutsville', 'granville', 'hunnewell'] },
  'Montgomery County': { district: 'CD-3', cities: ['montgomery city', 'wellsville', 'bellflower', 'jonesburg', 'middletown', 'new florence', 'high hill'] },
  'Morgan County': { district: 'CD-4', cities: ['versailles', 'stover', 'gravois mills', 'laurie', 'rocky mount', 'barnett', 'florence'] },
  'New Madrid County': { district: 'CD-8', cities: ['new madrid', 'portageville', 'lilbourn', 'marston', 'canalou', 'catron', 'gideon', 'howardville', 'kewanee', 'matthews', 'parma', 'risco', 'tallapoosa'] },
  'Newton County': { district: 'CD-7', cities: ['neosho', 'granby', 'seneca', 'diamond', 'newtonia', 'stark city', 'racine', 'ritchey', 'saginaw', 'shoal creek drive', 'stella'] },
  'Nodaway County': { district: 'CD-6', cities: ['maryville', 'burlington junction', 'clearmont', 'elmo', 'graham', 'hopkins', 'maitland', 'pickering', 'ravenwood', 'skidmore'] },
  'Oregon County': { district: 'CD-8', cities: ['alton', 'thayer', 'couch', 'koshkonong', 'myrtle', 'bardley'] },
  'Osage County': { district: 'CD-3', cities: ['linn', 'belle', 'freeburg', 'westphalia', 'argyle', 'bland', 'bonnots mill', 'chamois', 'koeltztown', 'loose creek', 'meta', 'rich fountain', 'ryors'] },
  'Ozark County': { district: 'CD-8', cities: ['gainesville', 'theodosia', 'bakersfield', 'brixey', 'dora', 'hardenville', 'isabella', 'noble', 'pontiac', 'riverton', 'rueter', 'zanoni'] },
  'Pemiscot County': { district: 'CD-8', cities: ['caruthersville', 'hayti', 'steele', 'holland', 'braggadocio', 'cooter', 'gosnell', 'hayti heights', 'homestown', 'pascola', 'portageville', 'wardell'] },
  'Perry County': { district: 'CD-8', cities: ['perryville', 'st. mary', 'altenburg', 'biehle', 'brazeau', 'crosstown', 'farrar', 'frohna', 'longtown', 'mcbride', 'uniontown'] },
  'Pettis County': { district: 'CD-4', cities: ['sedalia', 'smithton', 'green ridge', 'hughesville', 'la monte', 'windsor place', 'houstonia', 'dresden'] },
  'Phelps County': { district: 'CD-8', cities: ['rolla', 'st. james', 'newburg', 'cuba', 'doolittle', 'edgar springs', 'lenox', 'st. cloud', 'yancy mills'] },
  'Pike County': { district: 'CD-3', cities: ['bowling green', 'louisiana', 'clarksville', 'curryville', 'eolia', 'farber', 'frankford', 'new hartford', 'paynesville', 'vandalia'] },
  'Platte County': { district: 'CD-6', cities: ['platte city', 'parkville', 'riverside', 'smithville', 'weston', 'ferrelview', 'lake waukomis', 'houston lake', 'weatherby lake', 'platte woods', 'northmoor', 'lake of the woods', 'oakwood', 'oakwood park', 'camden point', 'tracy', 'waldron'] },
  'Polk County': { district: 'CD-4', cities: ['bolivar', 'humansville', 'fair play', 'flemington', 'half way', 'morrisville', 'pleasant hope', 'polk'] },
  'Pulaski County': { district: 'CD-4', cities: ['waynesville', 'fort leonard wood', 'crocker', 'dixon', 'richland', 'st. robert'] },
  'Putnam County': { district: 'CD-6', cities: ['unionville', 'powersville', 'livonia', 'lucerne', 'queen city'] },
  'Ralls County': { district: 'CD-3', cities: ['new london', 'perry', 'center', 'saverton', 'spalding'] },
  'Randolph County': { district: 'CD-6', cities: ['moberly', 'huntsville', 'cairo', 'clark', 'higbee', 'renick'] },
  'Ray County': { district: 'CD-6', cities: ['richmond', 'lawson', 'excelsior springs', 'hardin', 'orrick', 'rayville'] },
  'Reynolds County': { district: 'CD-8', cities: ['centerville', 'ellington', 'bunker', 'redford', 'lesterville', 'reynolds', 'black'] },
  'Ripley County': { district: 'CD-8', cities: ['doniphan', 'current view', 'naylor', 'oxly', 'briar'] },
  'St. Charles County': { district: 'CD-2', cities: ['st. charles', 'st charles', "o'fallon", 'ofallon', 'wentzville', 'st. peters', 'st peters', 'lake st. louis', 'lake st louis', 'dardenne prairie', 'weldon spring', 'cottleville', 'new melle', 'flint hill', 'josephville', 'portage des sioux', 'west alton'] },
  'St. Clair County': { district: 'CD-4', cities: ['osceola', 'appleton city', 'lowry city', 'roscoe', 'vista', 'iconium', 'gerster', 'coal', 'monegaw springs'] },
  'St. Francois County': { district: 'CD-8', cities: ['farmington', 'park hills', 'bonne terre', 'desloge', 'flat river', 'leadwood', 'st. mary', 'bismarck', 'doe run', 'elvins', 'esther', 'irondale', 'leadington', 'rivermines', 'valles mines'] },
  'St. Louis City': { district: 'CD-1', cities: ['st. louis', 'st louis', 'stl'] },
  'St. Louis County': { district: 'CD-1', cities: ['clayton', 'university city', 'webster groves', 'kirkwood', 'florissant', 'chesterfield', 'ballwin', 'maryland heights', 'hazelwood', 'creve coeur', 'des peres', 'town and country', 'affton', 'mehlville', 'oakville', 'lemay', 'spanish lake', 'ferguson', 'jennings', 'bridgeton', 'overland', 'bella villa', 'bellefontaine neighbors', 'berkeley', 'breckenridge hills', 'brentwood', 'bridgetown', 'calverton park', 'castle point', 'charlack', 'clarkson valley', 'cool valley', 'country club hills', 'country life acres', 'crestwood', 'crystal lake park', 'dellwood', 'edmundson', 'ellsville', 'eureka', 'fenton', 'ferguson', 'flordell hills', 'frontenac', 'glen echo park', 'glendale', 'grant city', 'grantwood village', 'green park', 'hanley hills', 'hillsdale', 'huntleigh', 'twin oaks', 'jennings', 'kinloch', 'ladue', 'lakeshire', 'mackenzie', 'manchester', 'maplewood', 'marlborough', 'moline acres', 'murphy', 'normandy', 'northwoods', 'norwood court', 'oakland', 'olivette', 'pagedale', 'pasadena hills', 'pasadena park', 'pine lawn', 'richmond heights', 'riverview', 'rock hill', 'shrewsbury', 'sunset hills', 'sycamore hills', 'uplands park', 'valley park', 'velda city', 'velda village hills', 'vinita park', 'vinita terrace', 'warson woods', 'wellston', 'westwood', 'wilbur park', 'winchester', 'woodson terrace'] },
  'Ste. Genevieve County': { district: 'CD-8', cities: ['ste. genevieve', 'st. mary', 'bloomsdale', 'river aux vases'] },
  'Saline County': { district: 'CD-4', cities: ['marshall', 'slater', 'sweet springs', 'malta bend', 'miami', 'gilliam', 'blackburn', 'arrow rock', 'alma', 'brunswick', 'grand pass', 'nelson'] },
  'Schuyler County': { district: 'CD-6', cities: ['lancaster', 'queen city', 'downing', 'glenwood'] },
  'Scotland County': { district: 'CD-6', cities: ['memphis', 'gorin', 'granger', 'arbela', 'rutledge'] },
  'Scott County': { district: 'CD-8', cities: ['sikeston', 'scott city', 'benton', 'chaffee', 'morley', 'oran', 'kelso', 'blodgett', 'commerce', 'haywood city', 'illmo', 'miner', 'morley', 'tamms', 'vanduser'] },
  'Shannon County': { district: 'CD-8', cities: ['eminence', 'birch tree', 'winona', 'alley spring', 'summersville'] },
  'Shelby County': { district: 'CD-6', cities: ['shelbyville', 'shelbina', 'bethel', 'clarence', 'emden', 'hunnewell', 'leonard'] },
  'Stoddard County': { district: 'CD-8', cities: ['dexter', 'bloomfield', 'bernie', 'advance', 'bell city', 'dudley', 'essex', 'gideon', 'grayridge', 'miner', 'puxico'] },
  'Stone County': { district: 'CD-7', cities: ['branson', 'kimberling city', 'crane', 'galena', 'hurley', 'reeds spring', 'blue eye', 'cape fair', 'indian point', 'table rock'] },
  'Sullivan County': { district: 'CD-6', cities: ['milan', 'green city', 'pollock', 'humphreys', 'newtown', 'reger', 'unionville'] },
  'Taney County': { district: 'CD-7', cities: ['branson', 'hollister', 'forsyth', 'rockaway beach', 'bull creek', 'kirbyville', 'merriam woods', 'point lookout', 'taneyville', 'walnut shade'] },
  'Texas County': { district: 'CD-8', cities: ['houston', 'cabool', 'licking', 'summersville', 'bucyrus', 'eunice', 'hartshorn', 'huggins', 'plato', 'roby', 'solo', 'success', 'tyrone'] },
  'Vernon County': { district: 'CD-4', cities: ['nevada', 'el dorado springs', 'walker', 'cottey', 'deerfield', 'harwood', 'horton', 'metz', 'milo', 'montevallo', 'schell city', 'sheldon', 'stotesbury'] },
  'Warren County': { district: 'CD-2', cities: ['warrenton', 'wright city', 'marthasville', 'truesdale', 'innsbrook', 'pendleton'] },
  'Washington County': { district: 'CD-8', cities: ['potosi', 'caledonia', 'mineral point', 'richwoods', 'belgrade', 'old mines', 'tiff'] },
  'Wayne County': { district: 'CD-8', cities: ['greenville', 'piedmont', 'patterson', 'silva', 'mill spring', 'williamsville', 'wappapello'] },
  'Webster County': { district: 'CD-7', cities: ['marshfield', 'rogersville', 'seymour', 'diggins', 'fordland', 'niangua', 'northview'] },
  'Worth County': { district: 'CD-6', cities: ['grant city', 'worth', 'allendale', 'denver', 'sheridan'] },
  'Wright County': { district: 'CD-8', cities: ['hartville', 'mountain grove', 'mansfield', 'norwood', 'ava', 'cabool', 'graff', 'macomb', 'solo', 'vanzant'] }
};

// Enhanced school database with EXTENSIVE variations, misspellings, and abbreviations
const SCHOOL_DATABASE = {
  colleges: {
    // PUBLIC UNIVERSITIES
    'Harris-Stowe State University': [
      'harris stowe', 'harris-stowe', 'hssu', 'harris stowe state', 'harrisstowe',
      'harris stow', 'harris-stow', 'harrrisstowe', 'harris', 'hariss stowe'
    ],
    'Lincoln University': [
      'lincoln university', 'lincoln u', 'lincoln mo', 'lincoln missouri',
      'lincon', 'lincon university', 'lincoln univ'
    ],
    'Missouri Southern State University': [
      'missouri southern', 'mssu', 'mo southern', 'southern state', 'missourisouthern',
      'mo southern state', 'missouri southern state', 'msouthern', 'misouri southern',
      'missouri souther', 'missour southern', 'mo south', 'southern missouri'
    ],
    'Missouri State University': [
      'missouri state', 'msu', 'mo state', 'missouristate', 'mo st', 'missouri st',
      'misouri state', 'missouri state u', 'msstate', 'missouri state univ',
      'missouri state university springfield', 'mo state u'
    ],
    'Missouri University of Science and Technology': [
      'missouri s&t', 'missouri s&t', 'missouri s and t', 'mst', 's&t', 's and t',
      'umr', 'missouri science', 'rolla', 'missouri tech', 'missouri university of science',
      'missouri science and technology', 'missouri s&tech', 'missouri science tech',
      'mo s&t', 'mo s and t', 'university of missouri rolla', 'um rolla'
    ],
    'Missouri Western State University': [
      'missouri western', 'mwsu', 'mo western', 'missouriwestern', 'missouri western state',
      'misouri western', 'missouri wester', 'mo west', 'mwestern'
    ],
    'Northwest Missouri State University': [
      'northwest missouri', 'nwmsu', 'northwest', 'nw missouri', 'northwestmissouri',
      'northwest mo', 'northwest missouri state', 'nw mo', 'northwest msu',
      'northwes missouri', 'north west missouri'
    ],
    'Southeast Missouri State University': [
      'southeast missouri', 'semo', 'southeast', 'se missouri', 'southeastmissouri',
      'southeast mo', 'se mo', 'southeast missouri state', 'semissouri',
      'south east missouri', 'se missouri state', 'southeast msu'
    ],
    'Truman State University': [
      'truman', 'tsu', 'truman state', 'trumanstate', 'truman state u',
      'truman university', 'truman univ'
    ],
    'University of Central Missouri': [
      'central missouri', 'ucm', 'u central missouri', 'centralmo', 'central mo',
      'university of central mo', 'u of central mo', 'u central mo',
      'central missouri university', 'cmu', 'central missouri state'
    ],
    'University of Missouri': [
      'university of missouri', 'mizzou', 'mu', 'missouri', 'u of m', 'u of missouri',
      'umissouri', 'university of mo', 'u missouri', 'u of mo', 'missouri university',
      'missou', 'mizzou columbia', 'missouri columbia'
    ],
    'University of Missouri-Columbia': [
      'mizzou', 'mu', 'missouri columbia', 'u of missouri columbia', 'umc',
      'missouri-columbia', 'u missouri columbia', 'mizzou columbia', 'um columbia',
      'university of missouri columbia', 'missouri at columbia'
    ],
    'University of Missouri-Kansas City': [
      'umkc', 'missouri kansas city', 'u missouri kc', 'missouri-kansas city',
      'umissouri kc', 'u of missouri kc', 'missouri kc', 'um kc', 'umkc',
      'university of missouri kansas city', 'u missouri kansas city'
    ],
    'University of Missouri-St. Louis': [
      'umsl', 'missouri st louis', 'u missouri stl', 'missouri-st louis',
      'missouri saint louis', 'umissouri stl', 'u of missouri st louis',
      'missouri stl', 'um stl', 'university of missouri st louis',
      'u missouri saint louis', 'missouri-saint louis'
    ],
    
    // COMMUNITY COLLEGES
    'Crowder College': [
      'crowder', 'crowder college', 'crowder cc', 'crowder community'
    ],
    'East Central College': [
      'east central', 'ecc', 'east central college', 'east central cc',
      'east central community', 'e central college'
    ],
    'Jefferson College': [
      'jefferson college', 'jeffco', 'jc', 'jefferson', 'jeff college',
      'jeff co', 'jefferson community'
    ],
    'Metropolitan Community College': [
      'metropolitan community', 'mcc', 'mcckc', 'metro community', 'metropolitan',
      'metro cc', 'metropolitan cc', 'metro community college', 'metro kc',
      'metropolitan community kc', 'metropolitan community kansas city'
    ],
    'Mineral Area College': [
      'mineral area', 'mac', 'mineral area college', 'mineral area cc',
      'mineral area community'
    ],
    'Missouri State University-West Plains': [
      'msu west plains', 'msu-wp', 'west plains', 'missouri state west plains',
      'mo state west plains', 'west plains msu', 'west plains campus'
    ],
    'Moberly Area Community College': [
      'moberly', 'macc', 'moberly area', 'moberly cc', 'moberly community',
      'moberly area college', 'moberly college'
    ],
    'North Central Missouri College': [
      'north central missouri', 'ncmc', 'north central', 'north central mo',
      'n central missouri', 'north central college'
    ],
    'Ozarks Technical Community College': [
      'ozarks technical', 'otc', 'ozarks tech', 'ozark technical', 'ozarks cc',
      'ozark tech', 'ozarks technical cc', 'ozarks technical college'
    ],
    'St. Charles Community College': [
      'st charles community', 'scc', 'saint charles cc', 'st charles cc',
      'st charles college', 'saint charles community', 'st charles community college'
    ],
    'St. Louis Community College': [
      'st louis community', 'stlcc', 'saint louis cc', 'st louis cc',
      'st louis community college', 'saint louis community college'
    ],
    'State Fair Community College': [
      'state fair', 'sfcc', 'state fair cc', 'state fair community', 'state fair college'
    ],
    'State Technical College of Missouri': [
      'state tech', 'state technical', 'missouri state tech', 'state tech missouri',
      'state technical college', 'state tech college'
    ],
    'Three Rivers College': [
      'three rivers', 'trc', 'three rivers college', 'three rivers cc',
      'three rivers community', '3 rivers', '3 rivers college'
    ],
    
    // PRIVATE UNIVERSITIES
    'Saint Louis University': [
      'saint louis university', 'slu', 'st louis university', 'saint louis u',
      'st louis u', 'slu law', 'saint louis univ', 'st louis univ',
      'saint lou university', 'st lou university'
    ],
    'Washington University in St. Louis': [
      'washington university', 'washu', 'wustl', 'wash u', 'washington u',
      'washington university st louis', 'washington university in st louis',
      'washu stl', 'wash university', 'washingto university'
    ],
    'Drury University': [
      'drury', 'du', 'drury university', 'drury u', 'drury springfield',
      'drury college', 'drury univ'
    ],
    'Rockhurst University': [
      'rockhurst', 'ru', 'rockhurst u', 'rockhurst university', 'rock hurst',
      'rockhurs', 'rockhurst univ', 'rockhurst kansas city'
    ],
    'Avila University': [
      'avila', 'au', 'avila university', 'avila u', 'avila kansas city', 'avila univ'
    ],
    'Lindenwood University': [
      'lindenwood', 'lu', 'lindenwood university', 'linden wood', 'lindenwood u',
      'lindenwood st charles', 'lindenwood univ'
    ],
    'Maryville University': [
      'maryville', 'maryville u', 'maryville university', 'mary ville',
      'maryville st louis', 'maryville univ'
    ],
    'Missouri Baptist University': [
      'missouri baptist', 'mbu', 'mo baptist', 'missouri baptist u',
      'missouri baptist university', 'misouri baptist'
    ],
    'Westminster College': [
      'westminster', 'westminster mo', 'westminster college', 'westminster fulton',
      'westminster missouri', 'westminster u'
    ],
    'William Jewell College': [
      'william jewell', 'wjc', 'jewell', 'william jewell college', 'jewell college',
      'will jewell', 'william jewel'
    ],
    'Central Methodist University': [
      'central methodist', 'cmu', 'central methodist u', 'central methodist university',
      'central methodist college'
    ],
    'Columbia College': [
      'columbia college', 'cc', 'columbia college mo', 'columbia college missouri',
      'columbia c', 'colombia college'
    ],
    'Evangel University': [
      'evangel', 'eu', 'evangel university', 'evangel u', 'evangel springfield',
      'evangel univ'
    ],
    'Park University': [
      'park', 'park university', 'park u', 'park university mo', 'park univ'
    ],
    'Stephens College': [
      'stephens', 'stephens college', 'stephen college', 'stephens columbia',
      'stephens c'
    ],
    'Southwest Baptist University': [
      'southwest baptist', 'sbu', 'sw baptist', 'southwest baptist u',
      'south west baptist', 'southwest baptist university'
    ],
    'Webster University': [
      'webster', 'wu', 'webster u', 'webster university', 'webster st louis',
      'webster univ'
    ],
    'College of the Ozarks': [
      'college ozarks', 'c of o', 'cofo', 'ozarks college', 'college of ozarks',
      'the ozarks college'
    ],
    'Cottey College': [
      'cottey', 'cottey college', 'cotty college', 'cottey missouri'
    ],
    'Culver-Stockton College': [
      'culver stockton', 'csc', 'culver-stockton', 'culver', 'culver stockton college'
    ],
    'Hannibal-LaGrange University': [
      'hannibal lagrange', 'hlgu', 'hannibal', 'hannibal-lagrange',
      'hannibal lagrange university'
    ],
    'Missouri Valley College': [
      'missouri valley', 'mvc', 'mo valley', 'missouri valley college',
      'missouri valley u'
    ],
    'William Woods University': [
      'william woods', 'wwu', 'woods', 'william woods university',
      'william woods u', 'will woods'
    ],
    
    // OUT-OF-STATE (COMMON)
    'Liberty University': [
      'liberty', 'liberty university', 'liberty u', 'liberty online',
      'liberty univ', 'liberty univesity', 'libery university'
    ],
    'Western Governors University': [
      'wgu', 'western governors', 'w governors', 'western governors university',
      'western govenors', 'wgu online'
    ],
    'Walden University': [
      'walden', 'walden u', 'walden university', 'walden online', 'walden univ'
    ],
    'Oxford University': [
      'oxford', 'oxford u', 'oxford university', 'oxford uk', 'oxfrd university'
    ],
    'University of Chicago': [
      'chicago', 'u chicago', 'uchicago', 'university of chicago', 'u of chicago',
      'univ of chicago', 'chicago university'
    ],
    'University of Wisconsin-Milwaukee': [
      'wisconsin milwaukee', 'uwm', 'milwaukee', 'u wisconsin milwaukee',
      'wisconsin-milwaukee', 'uw milwaukee'
    ],
    'University of Michigan': [
      'michigan', 'u michigan', 'umich', 'u of michigan', 'u of m',
      'michigan university', 'university of mich'
    ],
    'University of Kentucky': [
      'kentucky', 'uk', 'u kentucky', 'u of kentucky', 'kentucky university',
      'u ky', 'uky'
    ],
    'Indiana University': [
      'indiana', 'iu', 'indiana u', 'indiana university', 'u of indiana',
      'indiana univ', 'indi ana university'
    ],
    'Michigan State University': [
      'michigan state', 'msu', 'mich state', 'michigan st', 'michigan state u',
      'michigan state univ'
    ],
    'University of Arkansas Pine Bluff': [
      'arkansas pine bluff', 'uapb', 'pine bluff', 'arkansas pb',
      'u arkansas pine bluff'
    ],
    'Miami University': [
      'miami university', 'miami u', 'miami ohio', 'miami oxford',
      'miami university oxford', 'miami univ'
    ],
    'Pittsburg State University': [
      'pittsburg state', 'pitt state', 'pittsburg', 'pittsburg state u',
      'pitsburg state', 'pittsburg st'
    ],
    'Penn Valley': [
      'penn valley', 'penn valley cc', 'penn valley community college',
      'pennvalley'
    ],
    'Southwestern New Hampshire University': [
      'southwestern nh', 'southwestern new hampshire', 'southwestern newhampshire',
      'southwest nh'
    ],
    'College of Saint Scolastica': [
      'saint scolastica', 'st scolastica', 'scolastica', 'college scolastica',
      'college of scolastica'
    ],
    'University of Arkansas': [
      'arkansas', 'u arkansas', 'u of arkansas', 'arkansas university',
      'uark', 'u ark'
    ],
    
    // HEALTH SCIENCES & SPECIALIZED
    'A.T. Still University': [
      'at still', 'atsu', 'a t still', 'still university', 'a.t. still',
      'at still university'
    ],
    'Cox College': [
      'cox', 'cox college', 'cox nursing', 'cox college nursing'
    ],
    'Kansas City University': [
      'kansas city university', 'kcu', 'kcumb', 'kansas city u',
      'kc university', 'kc u'
    ],
    'Logan University': [
      'logan', 'logan university', 'logan u', 'logan college'
    ],
    'Ranken Technical College': [
      'ranken', 'ranken tech', 'ranken technical', 'ranken college'
    ],
    'Collegiate School of Medicine and Bioscience': [
      'collegiate medicine', 'collegiate bioscience', 'collegiate school medicine',
      'collegiate medical', 'collegiate school bioscience'
    ]
  },
  
  highSchools: {
    // ST. LOUIS PRIVATE HIGH SCHOOLS
    'Chaminade College Preparatory School': [
      'chaminade', 'ccp', 'chaminade prep', 'chaminade college prep',
      'chaminade preparatory', 'chaminade hs'
    ],
    'Christian Brothers College High School': [
      'cbc', 'christian brothers', 'christian brothers college', 'christian bros',
      'cbc hs', 'christian brothers hs', 'christian brothers high'
    ],
    'Cor Jesu Academy': [
      'cor jesu', 'cja', 'corjesu', 'cor jesu academy'
    ],
    'De Smet Jesuit High School': [
      'de smet', 'dsj', 'dsjhs', 'desmet', 'de smet jesuit', 'de smet hs',
      'desmet jesuit', 'de smet high'
    ],
    'Duchesne High School': [
      'duchesne', 'dhs', 'duchesne hs', 'duchesne high'
    ],
    'Incarnate Word Academy': [
      'incarnate word', 'iwa', 'incarnate word academy'
    ],
    'John Burroughs School': [
      'burroughs', 'jbs', 'john burroughs', 'burroughs school', 'burroughs hs'
    ],
    'Lutheran High School North': [
      'lutheran north', 'lhsn', 'lhs north', 'lutheran hs north',
      'lutheran high north'
    ],
    'Lutheran High School South': [
      'lutheran south', 'lhss', 'lhs south', 'lutheran hs south',
      'lutheran high south'
    ],
    'Lutheran High School St. Charles': [
      'lutheran st charles', 'lhscc', 'lutheran scc', 'lutheran st charles county',
      'lutheran st charles high', 'lutheran hs st charles'
    ],
    'Mary Institute and St. Louis Country Day School': [
      'micds', 'mary institute', 'country day', 'mary institute country day',
      'st louis country day', 'mic ds', 'm i c d s'
    ],
    'Nerinx Hall High School': [
      'nerinx hall', 'nerinx', 'nhhs', 'nerinx hs', 'nerinx high'
    ],
    'Notre Dame High School': [
      'notre dame', 'ndhs', 'notre dame stl', 'notre dame high', 'notre dame hs'
    ],
    'Rosati-Kain High School': [
      'rosati kain', 'rka', 'rosati-kain', 'rosati kain hs', 'rosati-kain high'
    ],
    'Saint Louis Priory School': [
      'priory', 'slp', 'st louis priory', 'saint louis priory', 'the priory',
      'priory school', 'priory hs'
    ],
    'St. Dominic High School': [
      'st dominic', 'sdhs', 'saint dominic', 'st dominic hs', 'st dominic high',
      'saint dominic high'
    ],
    'St. Francis Borgia High School': [
      'borgia', 'sfb', 'sfbhs', 'st francis borgia', 'saint francis borgia',
      'borgia hs', 'borgia high'
    ],
    'St. John Vianney High School': [
      'vianney', 'sjv', 'st john vianney', 'saint john vianney', 'vianney hs',
      'vianney high'
    ],
    "St. Joseph's Academy": [
      'st josephs academy', 'sja', 'saint josephs', 'st josephs', 'st joseph academy',
      'saint joseph academy'
    ],
    'St. Louis University High School': [
      'sluh', 'st louis u high', 'slu high', 'st louis university high',
      'saint louis u high', 'saint louis university high', 's l u h'
    ],
    'Ursuline Academy': [
      'ursuline', 'ua', 'ursuline academy', 'ursuline hs', 'ursuline high'
    ],
    'Villa Duchesne High School': [
      'villa duchesne', 'vdhs', 'vd', 'villa duchesne hs', 'villa duchesne high'
    ],
    'Visitation Academy': [
      'visitation', 'va', 'vis academy', 'visitation hs', 'visitation high',
      'vis', 'viz'
    ],
    'Whitfield School': [
      'whitfield', 'whs', 'whitfield school', 'whitfield hs'
    ],
    'Thomas Jefferson School': [
      'thomas jefferson', 'tjs', 'tj school', 't jefferson', 'thomas jeff'
    ],
    'Christian High School': [
      'christian high', 'chsof', 'christian ofallon', 'christian o fallon',
      'christian hs ofallon', 'christian hs'
    ],
    'Westminster Christian Academy': [
      'westminster christian', 'wca', 'westminster christian academy',
      'westminster christian hs'
    ],
    
    // KANSAS CITY PRIVATE HIGH SCHOOLS
    'Rockhurst High School': [
      'rockhurst', 'rhs', 'rockhurst hs', 'rockhurst high', 'rock hurst',
      'rockhurs hs'
    ],
    "St. Teresa's Academy": [
      'st teresas', 'sta', 'saint teresas', 'st teresa', 'saint teresa',
      'st teresas academy', 'st teresa academy'
    ],
    'Notre Dame de Sion High School': [
      'sion', 'de sion', 'notre dame sion', 'notre dame de sion', 'sion hs',
      'sion high'
    ],
    'St. Pius X High School': [
      'st pius', 'spx', 'spxkc', 'saint pius x', 'st pius x', 'st pius hs',
      'saint pius hs', 'st pius x hs', 'st pius kc'
    ],
    'St. Michael the Archangel High School': [
      'st michael', 'sma', 'saint michael', 'st michael archangel',
      'saint michael archangel', 'st michael hs', 'st michael high'
    ],
    'The Barstow School': [
      'barstow', 'barstow school', 'barstow hs', 'the barstow'
    ],
    'Pembroke Hill School': [
      'pembroke hill', 'phs', 'pembroke', 'pembrook hill', 'pembroke hill hs',
      'pembroke hs', 'pembroke high'
    ],
    
    // CENTRAL MISSOURI PRIVATE HIGH SCHOOLS
    'Helias Catholic High School': [
      'helias', 'hchs', 'helias catholic', 'helias hs', 'helias high',
      'helias catholic hs'
    ],
    'Father Tolton Catholic High School': [
      'tolton', 'ftchs', 'father tolton', 'tolton catholic', 'tolton hs',
      'tolton high', 'father tolton hs'
    ],
    'Calvary Lutheran High School': [
      'calvary lutheran', 'clhs', 'calvary lutheran hs', 'calvary lutheran high'
    ],
    
    // SOUTHWEST MISSOURI PRIVATE HIGH SCHOOLS
    'Springfield Catholic High School': [
      'springfield catholic', 'schs', 'springfield catholic hs',
      'springfield catholic high', 'catholic springfield'
    ],
    'McAuley Catholic High School': [
      'mcauley', 'mchs', 'mcauley catholic', 'mcauley hs', 'mcauley high',
      'mcauley joplin'
    ],
    'Gloria Deo Academy': [
      'gloria deo', 'gda', 'gloria deo academy', 'gloria deo hs'
    ],
    
    // SOUTHEAST MISSOURI PRIVATE HIGH SCHOOLS
    'Notre Dame Regional High School': [
      'notre dame regional', 'ndrhs', 'notre dame cape', 'notre dame cape girardeau',
      'notre dame regional hs'
    ],
    'Saxony Lutheran High School': [
      'saxony lutheran', 'slhs', 'saxony', 'saxony hs', 'saxony high',
      'saxony lutheran hs'
    ],
    
    // OTHER PRIVATE HIGH SCHOOLS
    'Crossroads Preparatory Academy': [
      'crossroads prep', 'crossroads preparatory', 'crossroads academy',
      'crossroads preparatory academy'
    ],
    'Collegiate School of Medicine and Bioscience': [
      'collegiate medicine', 'collegiate bioscience', 'collegiate school',
      'collegiate hs', 'collegiate medical school'
    ]
  }
};

// Helper function to normalize text for comparison
function normalizeText(text: string): string {
  return text
    .toLowerCase()
    .trim()
    .replace(/[^\w\s]/g, '') // Remove punctuation
    .replace(/\s+/g, ' ') // Normalize spaces
    .replace(/high school/g, 'hs')
    .replace(/university/g, 'u')
    .replace(/college/g, 'c');
}

// Helper function to calculate similarity score (0-1)
function calculateSimilarity(str1: string, str2: string): number {
  const norm1 = normalizeText(str1);
  const norm2 = normalizeText(str2);
  
  // Exact match after normalization
  if (norm1 === norm2) return 1.0;
  
  // Contains match
  if (norm1.includes(norm2) || norm2.includes(norm1)) return 0.9;
  
  // Word overlap
  const words1 = new Set(norm1.split(' '));
  const words2 = new Set(norm2.split(' '));
  const intersection = new Set([...words1].filter(x => words2.has(x)));
  const union = new Set([...words1, ...words2]);
  
  if (union.size === 0) return 0;
  return intersection.size / union.size;
}

// Helper function to find best school match
function findSchoolMatch(inputText: string): {
  schoolName: string;
  isHighSchool: boolean;
  confidence: number;
  matchedVariant: string;
} | null {
  const normalizedInput = normalizeText(inputText);
  let bestMatch = null;
  let bestScore = 0;
  let bestVariant = '';
  let isHS = false;
  
  // Check colleges
  for (const [schoolName, variants] of Object.entries(SCHOOL_DATABASE.colleges)) {
    for (const variant of variants) {
      const score = calculateSimilarity(normalizedInput, variant);
      if (score > bestScore && score >= 0.7) { // Require 70% similarity minimum
        bestScore = score;
        bestMatch = schoolName;
        bestVariant = variant;
        isHS = false;
      }
    }
  }
  
  // Check high schools
  for (const [schoolName, variants] of Object.entries(SCHOOL_DATABASE.highSchools)) {
    for (const variant of variants) {
      const score = calculateSimilarity(normalizedInput, variant);
      if (score > bestScore && score >= 0.7) {
        bestScore = score;
        bestMatch = schoolName;
        bestVariant = variant;
        isHS = true;
      }
    }
  }
  
  if (bestMatch) {
    return {
      schoolName: bestMatch,
      isHighSchool: isHS,
      confidence: bestScore,
      matchedVariant: bestVariant
    };
  }
  
  return null;
}

// Helper function to extract all schools and context from input
function parseSchoolInput(inputText: string): {
  primarySchool: string | null;
  isHighSchool: boolean;
  confidence: number;
  additionalContext: string;
  allDetectedSchools: string[];
} {
  if (!inputText || inputText.trim() === '' || 
      ['n/a', 'na', 'none', 'no', 'null'].includes(inputText.toLowerCase().trim())) {
    return {
      primarySchool: null,
      isHighSchool: false,
      confidence: 0,
      additionalContext: '',
      allDetectedSchools: []
    };
  }
  
  const input = inputText.trim();
  const lowerInput = input.toLowerCase();
  
  // Try to find all schools mentioned
  const foundSchools: Array<{name: string; isHS: boolean; position: number; length: number; confidence: number}> = [];
  
  // Search for known schools
  const allSchools = {
    ...SCHOOL_DATABASE.colleges,
    ...SCHOOL_DATABASE.highSchools
  };
  
  for (const [schoolName, variants] of Object.entries(allSchools)) {
    for (const variant of variants) {
      const position = lowerInput.indexOf(variant.toLowerCase());
      if (position !== -1) {
        const isHS = schoolName in SCHOOL_DATABASE.highSchools;
        foundSchools.push({
          name: schoolName,
          isHS: isHS,
          position: position,
          length: variant.length,
          confidence: 1.0
        });
      }
    }
  }
  
  // If no exact match found, try fuzzy matching on the entire input
  if (foundSchools.length === 0) {
    const match = findSchoolMatch(input);
    if (match && match.confidence >= 0.7) {
      foundSchools.push({
        name: match.schoolName,
        isHS: match.isHighSchool,
        position: 0,
        length: input.length,
        confidence: match.confidence
      });
    }
  }
  
  // Sort by position (earliest first)
  foundSchools.sort((a, b) => a.position - b.position);
  
  if (foundSchools.length === 0) {
    // No schools detected - check if it looks like a high school
    const hsIndicators = [
      'high school', 'highschool', ' hs ', ' hs', 'hs ', 'h.s.', 'academy',
      'preparatory', ' prep ', 'senior high', 'junior high', 'jr high', 'sr high'
    ];
    
    const hasHSIndicator = hsIndicators.some(ind => lowerInput.includes(ind));
    
    if (hasHSIndicator) {
      // Try to clean up the high school name
      let cleanedHS = input
        .replace(/\(.*?\)/g, '')
        .replace(/high school/gi, 'High School')
        .replace(/highschool/gi, 'High School')
        .replace(/\bhs\b/gi, 'High School')
        .replace(/senior high/gi, 'High School')
        .replace(/jr\.? high/gi, 'Junior High')
        .trim();
      
      // Title case
      cleanedHS = cleanedHS
        .split(' ')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');
      
      return {
        primarySchool: cleanedHS,
        isHighSchool: true,
        confidence: 0.5, // Low confidence - uncertain
        additionalContext: '',
        allDetectedSchools: [cleanedHS]
      };
    }
    
    // Assume it's a college but with very low confidence
    let cleaned = input.replace(/\(.*?\)/g, '').trim();
    cleaned = cleaned
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(' ');
    
    return {
      primarySchool: cleaned,
      isHighSchool: false,
      confidence: 0.3, // Very low confidence
      additionalContext: '',
      allDetectedSchools: [cleaned]
    };
  }
  
  // Primary school is the first one found
  const primary = foundSchools[0];
  const allSchoolNames = foundSchools.map(s => s.name);
  
  // Extract everything that's NOT the primary school name as context
  let contextParts: string[] = [];
  
  // Get text before the primary school
  if (primary.position > 0) {
    const before = input.substring(0, primary.position).trim();
    if (before) contextParts.push(before);
  }
  
  // Get text after the primary school
  const afterPosition = primary.position + primary.length;
  if (afterPosition < input.length) {
    const after = input.substring(afterPosition).trim();
    if (after) contextParts.push(after);
  }
  
  // Add additional schools to context
  if (foundSchools.length > 1) {
    const additionalSchools = foundSchools.slice(1).map(s => s.name);
    contextParts.push('Also attending: ' + additionalSchools.join(', '));
  }
  
  // Clean up context
  const additionalContext = contextParts
    .join(' ')
    .replace(/^[\s,;:.-]+|[\s,;:.-]+$/g, '') // Remove leading/trailing punctuation
    .replace(/\s+/g, ' ')
    .trim();
  
  return {
    primarySchool: primary.name,
    isHighSchool: primary.isHS,
    confidence: primary.confidence,
    additionalContext: additionalContext,
    allDetectedSchools: allSchoolNames
  };
}

// Helper function to get district from county name
function getDistrictFromCounty(countyName: string): string {
  if (!countyName) return '';
  const countyData = MISSOURI_COUNTIES[countyName];
  return countyData ? countyData.district : '';
}

// Helper function to geocode address and find county/district
function geocodeAddress(address: string): { county: string; district: string } {
  if (!address) return { county: '', district: '' };
  const lowerAddress = address.toLowerCase().trim();
  
  for (const [countyName, data] of Object.entries(MISSOURI_COUNTIES)) {
    const lowerCountyName = countyName.toLowerCase();
    if (lowerAddress.includes(lowerCountyName)) {
      return { county: countyName, district: data.district };
    }
    for (const city of data.cities) {
      if (lowerAddress.includes(city)) {
        return { county: countyName, district: data.district };
      }
    }
  }
  return { county: '', district: '' };
}

// Helper function to calculate zodiac sign
function getZodiacSign(dateOfBirth: string): string {
  if (!dateOfBirth) return '';
  const date = new Date(dateOfBirth);
  const month = date.getMonth() + 1;
  const day = date.getDate();
  
  if ((month === 3 && day >= 21) || (month === 4 && day <= 19)) return 'Aries';
  if ((month === 4 && day >= 20) || (month === 5 && day <= 20)) return 'Taurus';
  if ((month === 5 && day >= 21) || (month === 6 && day <= 20)) return 'Gemini';
  if ((month === 6 && day >= 21) || (month === 7 && day <= 22)) return 'Cancer';
  if ((month === 7 && day >= 23) || (month === 8 && day <= 22)) return 'Leo';
  if ((month === 8 && day >= 23) || (month === 9 && day <= 22)) return 'Virgo';
  if ((month === 9 && day >= 23) || (month === 10 && day <= 22)) return 'Libra';
  if ((month === 10 && day >= 23) || (month === 11 && day <= 21)) return 'Scorpio';
  if ((month === 11 && day >= 22) || (month === 12 && day <= 21)) return 'Sagittarius';
  if ((month === 12 && day >= 22) || (month === 1 && day <= 19)) return 'Capricorn';
  if ((month === 1 && day >= 20) || (month === 2 && day <= 18)) return 'Aquarius';
  if ((month === 2 && day >= 19) || (month === 3 && day <= 20)) return 'Pisces';
  return '';
}

// Helper function to format phone number
function formatPhoneE164(phone: string): string {
  if (!phone) return '';
  const digits = phone.replace(/\D/g, '');
  if (digits.length === 11 && digits.startsWith('1')) return `+${digits}`;
  if (digits.length === 10) return `+1${digits}`;
  return phone;
}

// Helper function to format social media handles
function formatSocialMediaHandle(handle: string, platform: 'instagram' | 'tiktok' | 'x'): string {
  if (!handle) return '';
  const trimmedHandle = handle.trim().toLowerCase();
  const noneVariants = ['none', 'n/a', 'na', 'n.a.', 'no', 'null', 'nil', '-'];
  if (noneVariants.includes(trimmedHandle)) return '';
  if (trimmedHandle.startsWith('http://') || trimmedHandle.startsWith('https://')) {
    return handle.trim();
  }
  
  const separators = [' and ', '/', ',', '&', ' & ', '|'];
  let handles = [handle.trim()];
  for (const separator of separators) {
    if (handle.includes(separator)) {
      handles = handle.split(separator).map(h => h.trim());
      break;
    }
  }
  
  const formattedHandles = handles
    .map(h => {
      const trimmed = h.trim();
      if (!trimmed) return '';
      const lowerTrimmed = trimmed.toLowerCase();
      if (noneVariants.includes(lowerTrimmed)) return '';
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
      
      let cleanHandle = trimmed.replace(/^@+/, '');
      cleanHandle = cleanHandle
        .replace(/^instagram\.com\//i, '')
        .replace(/^tiktok\.com\/@?/i, '')
        .replace(/^x\.com\//i, '')
        .replace(/^twitter\.com\//i, '');
      if (!cleanHandle) return '';
      
      switch (platform) {
        case 'instagram': return `https://instagram.com/${cleanHandle}`;
        case 'tiktok': return `https://tiktok.com/@${cleanHandle}`;
        case 'x': return `https://x.com/${cleanHandle}`;
        default: return '';
      }
    })
    .filter(url => url !== '');
  
  return formattedHandles.join(', ');
}

// Helper function to convert strings to boolean
function toBoolean(value: any): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const lower = value.toLowerCase().trim();
    return lower === 'true' || lower === 'yes' || lower === '1';
  }
  return false;
}

// Helper function to format date
function formatDateJoined(timestamp: string): string {
  if (!timestamp) return new Date().toISOString().split('T')[0];
  try {
    const date = new Date(timestamp);
    return date.toISOString().split('T')[0];
  } catch {
    return new Date().toISOString().split('T')[0];
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'GET') {
    return new Response(
      JSON.stringify({ 
        message: 'Zapier webhook endpoint is working! Use POST to submit data.',
        status: 'ready'
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const formData = await req.json();
    console.log("Received form data:", JSON.stringify(formData, null, 2));

    // Geocode address
    const locationInfo = geocodeAddress(formData.address);
    let county = formData.county || locationInfo.county;
    let congressional_district = formData.congressional_district || locationInfo.district;
    if (county && !congressional_district) {
      congressional_district = getDistrictFromCounty(county);
    }

    // Parse school name with enhanced logic
    const schoolInfo = parseSchoolInput(formData.school_name);
    
    // Determine what goes where based on confidence
    let high_school = null;
    let college = null;
    let schoolNotes = '';
    
    if (schoolInfo.primarySchool) {
      if (schoolInfo.confidence >= 0.7) {
        // High confidence - put in appropriate column
        if (schoolInfo.isHighSchool) {
          high_school = schoolInfo.primarySchool;
        } else {
          college = schoolInfo.primarySchool;
        }
      } else {
        // Low confidence - put in notes instead
        schoolNotes = `Uncertain school identification: ${formData.school_name}`;
      }
      
      // Add additional context to notes
      if (schoolInfo.additionalContext) {
        if (schoolNotes) {
          schoolNotes += '. ' + schoolInfo.additionalContext;
        } else {
          schoolNotes = schoolInfo.additionalContext;
        }
      }
    }

    // Calculate zodiac sign
    const zodiac_sign = getZodiacSign(formData.date_of_birth);

    // Format phone number
    const phone_e164 = formatPhoneE164(formData.phone);

    // Format social media handles
    const instagram = formatSocialMediaHandle(formData.instagram, 'instagram');
    const tiktok = formatSocialMediaHandle(formData.tiktok, 'tiktok');
    const x = formatSocialMediaHandle(formData.x, 'x');

    // Format date
    const date_joined = formatDateJoined(formData.date_joined);

    // Combine notes
    let notesArray = [];
    if (formData.notes) notesArray.push(formData.notes);
    if (schoolNotes) notesArray.push(schoolNotes);
    const combinedNotes = notesArray.join('. ');

    // Prepare member data
    const memberData = {
      name: formData.name,
      email: formData.email,
      phone: formData.phone,
      phone_e164: phone_e164,
      date_of_birth: formData.date_of_birth,
      preferred_pronouns: formData.preferred_pronouns,
      gender_identity: formData.gender_identity,
      address: formData.address,
      county: county,
      congressional_district: congressional_district,
      race: formData.race,
      sexual_orientation: formData.sexual_orientation,
      desire_to_lead: formData.desire_to_lead,
      hours_per_week: formData.hours_per_week,
      education_level: formData.education_level,
      registered_voter: toBoolean(formData.registered_voter),
      in_school: formData.in_school,
      school_name: formData.school_name || '', // Keep original
      high_school: high_school,
      college: college,
      employed: formData.employed,
      industry: formData.industry,
      hispanic_latino: toBoolean(formData.hispanic_latino),
      accommodations: formData.accommodations,
      community_type: formData.community_type,
      languages: formData.languages,
      why_join: formData.why_join,
      committee: formData.committee,
      notes: combinedNotes,
      disability: formData.disability,
      political_experience: formData.political_experience,
      current_involvement: formData.current_involvement,
      religion: formData.religion,
      instagram: instagram,
      tiktok: tiktok,
      x: x,
      zodiac_sign: zodiac_sign,
      leadership_experience: formData.leadership_experience,
      date_joined: date_joined,
      goals_and_ambitions: formData.goals_and_ambitions,
      qualified_experience: formData.qualified_experience,
      referral_source: formData.referral_source,
      passionate_issues: formData.passionate_issues,
      why_issues_matter: formData.why_issues_matter,
      areas_of_interest: formData.areas_of_interest,
      current_chapter_member: formData.current_chapter_member,
      chapter_name: formData.chapter_name,
      graduation_year: formData.graduation_year,
      created_at: new Date().toISOString(),
    };

    console.log("Prepared member data:", JSON.stringify(memberData, null, 2));

    // Check if member exists
    const { data: existingMember } = await supabase
      .from("members")
      .select("*")
      .eq("email", formData.email)
      .single();

    let data, error;

    if (existingMember) {
      console.log("Existing member found, performing smart merge...");
      const updateData: any = {};
      Object.keys(memberData).forEach(key => {
        const value = memberData[key];
        if (value !== null && value !== undefined && value !== '') {
          updateData[key] = value;
        }
      });
      updateData.created_at = new Date().toISOString();
      
      // Smart merge notes
      if (schoolNotes && existingMember.notes) {
        const existingNotes = existingMember.notes || '';
        updateData.notes = existingNotes ? `${existingNotes}. ${schoolNotes}` : schoolNotes;
      }
      
      console.log("Fields to update:", Object.keys(updateData));
      const result = await supabase
        .from("members")
        .update(updateData)
        .eq("email", formData.email)
        .select();
      data = result.data;
      error = result.error;
    } else {
      console.log("New member, inserting all data...");
      const result = await supabase
        .from("members")
        .insert(memberData)
        .select();
      data = result.data;
      error = result.error;
    }

    if (error) {
      console.error("Supabase error:", error);
      throw error;
    }

    console.log("Successfully processed member:", data);

    return new Response(
      JSON.stringify({
        success: true,
        data: data,
        geocoded: {
          county: locationInfo.county,
          district: locationInfo.district
        },
        calculated: {
          zodiac_sign: zodiac_sign,
          instagram_url: instagram,
          tiktok_url: tiktok,
          x_url: x,
          date_joined_formatted: date_joined,
          phone_e164: phone_e164
        },
        school_processing: {
          original: formData.school_name,
          primary_school: schoolInfo.primarySchool,
          is_high_school: schoolInfo.isHighSchool,
          confidence: schoolInfo.confidence,
          additional_context: schoolInfo.additionalContext,
          all_detected_schools: schoolInfo.allDetectedSchools,
          placed_in_column: schoolInfo.confidence >= 0.7 ? 
            (schoolInfo.isHighSchool ? 'high_school' : 'college') : 'notes (uncertain)',
          note_added: schoolNotes
        }
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        details: error.toString()
      }), 
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});