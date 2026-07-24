// supabase/functions/populate-subscriber-geography/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
// Comprehensive Missouri ZIP code to County and Congressional District mapping
const MISSOURI_GEO_DATA = {
  // CD-1: St. Louis City & North St. Louis County
  '63101': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63102': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63103': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63104': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63105': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63106': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63107': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63108': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63109': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63110': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63111': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63112': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63113': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63114': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63115': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63116': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63117': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63118': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63119': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63120': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63121': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63122': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63123': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63124': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63125': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63126': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63127': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63128': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63129': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63130': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63131': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63132': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63133': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63134': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63135': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63136': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63137': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63138': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63139': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  '63140': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63141': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63143': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63144': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63145': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63146': {
    county: 'St. Louis County',
    cd: 'CD-1'
  },
  '63147': {
    county: 'St. Louis City',
    cd: 'CD-1'
  },
  // CD-2: St. Charles, Lincoln, Warren, Jefferson Counties & West St. Louis County
  '63005': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63006': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63011': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63017': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63021': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63025': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63026': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63031': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63033': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63034': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63038': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63039': {
    county: 'Franklin County',
    cd: 'CD-2'
  },
  '63040': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63041': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63042': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63043': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63044': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63045': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63049': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63050': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63051': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63052': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63053': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63055': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63056': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63060': {
    county: 'Warren County',
    cd: 'CD-2'
  },
  '63061': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63068': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63069': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63070': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63071': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63072': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63073': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63074': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63077': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63079': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63080': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63084': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63087': {
    county: 'Warren County',
    cd: 'CD-2'
  },
  '63088': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63089': {
    county: 'St. Louis County',
    cd: 'CD-2'
  },
  '63090': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63091': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63301': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63302': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63303': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63304': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63330': {
    county: 'Warren County',
    cd: 'CD-2'
  },
  '63332': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63333': {
    county: 'Pike County',
    cd: 'CD-2'
  },
  '63334': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63336': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63339': {
    county: 'Pike County',
    cd: 'CD-2'
  },
  '63341': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63343': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63347': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63348': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63349': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63350': {
    county: 'Pike County',
    cd: 'CD-2'
  },
  '63351': {
    county: 'Pike County',
    cd: 'CD-2'
  },
  '63352': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63353': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63357': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63359': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63361': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63362': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63363': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63365': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63366': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63367': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63368': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63369': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63373': {
    county: 'Warren County',
    cd: 'CD-2'
  },
  '63376': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63377': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63379': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63380': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63381': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63382': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63383': {
    county: 'Warren County',
    cd: 'CD-2'
  },
  '63384': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63385': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63386': {
    county: 'Warren County',
    cd: 'CD-2'
  },
  '63387': {
    county: 'Warren County',
    cd: 'CD-2'
  },
  '63389': {
    county: 'St. Charles County',
    cd: 'CD-2'
  },
  '63390': {
    county: 'Lincoln County',
    cd: 'CD-2'
  },
  '63636': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63640': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63645': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63650': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  '63670': {
    county: 'Jefferson County',
    cd: 'CD-2'
  },
  // CD-3: Eastern Missouri - Ste. Genevieve, Perry, Cape Girardeau, Scott, Mississippi, New Madrid, Pemiscot, Dunklin, Stoddard, Butler, Carter, Wayne, Reynolds, Iron, Madison, St. Francois, Washington, Crawford, Dent, Shannon, Oregon, Ripley, Bollinger, Howell, Texas
  '63620': {
    county: 'Iron County',
    cd: 'CD-3'
  },
  '63621': {
    county: 'Iron County',
    cd: 'CD-3'
  },
  '63622': {
    county: 'Reynolds County',
    cd: 'CD-3'
  },
  '63623': {
    county: 'Madison County',
    cd: 'CD-3'
  },
  '63624': {
    county: 'Washington County',
    cd: 'CD-3'
  },
  '63625': {
    county: 'Iron County',
    cd: 'CD-3'
  },
  '63626': {
    county: 'Iron County',
    cd: 'CD-3'
  },
  '63627': {
    county: 'Ste. Genevieve County',
    cd: 'CD-3'
  },
  '63628': {
    county: 'Ste. Genevieve County',
    cd: 'CD-3'
  },
  '63629': {
    county: 'Bollinger County',
    cd: 'CD-3'
  },
  '63630': {
    county: 'Washington County',
    cd: 'CD-3'
  },
  '63631': {
    county: 'Iron County',
    cd: 'CD-3'
  },
  '63633': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63634': {
    county: 'Washington County',
    cd: 'CD-3'
  },
  '63635': {
    county: 'Washington County',
    cd: 'CD-3'
  },
  '63637': {
    county: 'Madison County',
    cd: 'CD-3'
  },
  '63638': {
    county: 'Dent County',
    cd: 'CD-3'
  },
  '63640': {
    county: 'Jefferson County',
    cd: 'CD-3'
  },
  '63650': {
    county: 'Jefferson County',
    cd: 'CD-3'
  },
  '63653': {
    county: 'Washington County',
    cd: 'CD-3'
  },
  '63654': {
    county: 'Reynolds County',
    cd: 'CD-3'
  },
  '63655': {
    county: 'Dent County',
    cd: 'CD-3'
  },
  '63656': {
    county: 'Reynolds County',
    cd: 'CD-3'
  },
  '63660': {
    county: 'Washington County',
    cd: 'CD-3'
  },
  '63662': {
    county: 'Iron County',
    cd: 'CD-3'
  },
  '63663': {
    county: 'Crawford County',
    cd: 'CD-3'
  },
  '63664': {
    county: 'Bollinger County',
    cd: 'CD-3'
  },
  '63666': {
    county: 'Madison County',
    cd: 'CD-3'
  },
  '63670': {
    county: 'Jefferson County',
    cd: 'CD-3'
  },
  '63673': {
    county: 'Wayne County',
    cd: 'CD-3'
  },
  '63674': {
    county: 'Washington County',
    cd: 'CD-3'
  },
  '63675': {
    county: 'Iron County',
    cd: 'CD-3'
  },
  '63701': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63702': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63703': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63730': {
    county: 'Wayne County',
    cd: 'CD-3'
  },
  '63732': {
    county: 'Scott County',
    cd: 'CD-3'
  },
  '63735': {
    county: 'Scott County',
    cd: 'CD-3'
  },
  '63736': {
    county: 'Bollinger County',
    cd: 'CD-3'
  },
  '63738': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63739': {
    county: 'Scott County',
    cd: 'CD-3'
  },
  '63740': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63742': {
    county: 'Mississippi County',
    cd: 'CD-3'
  },
  '63743': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63744': {
    county: 'Mississippi County',
    cd: 'CD-3'
  },
  '63745': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63746': {
    county: 'Bollinger County',
    cd: 'CD-3'
  },
  '63747': {
    county: 'Scott County',
    cd: 'CD-3'
  },
  '63748': {
    county: 'Perry County',
    cd: 'CD-3'
  },
  '63750': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63751': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63752': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63755': {
    county: 'Mississippi County',
    cd: 'CD-3'
  },
  '63758': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63760': {
    county: 'Perry County',
    cd: 'CD-3'
  },
  '63763': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63764': {
    county: 'Perry County',
    cd: 'CD-3'
  },
  '63766': {
    county: 'Scott County',
    cd: 'CD-3'
  },
  '63767': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63769': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63770': {
    county: 'Perry County',
    cd: 'CD-3'
  },
  '63771': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63774': {
    county: 'Wayne County',
    cd: 'CD-3'
  },
  '63775': {
    county: 'Ste. Genevieve County',
    cd: 'CD-3'
  },
  '63780': {
    county: 'Ste. Genevieve County',
    cd: 'CD-3'
  },
  '63781': {
    county: 'Scott County',
    cd: 'CD-3'
  },
  '63782': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63783': {
    county: 'Perry County',
    cd: 'CD-3'
  },
  '63784': {
    county: 'Mississippi County',
    cd: 'CD-3'
  },
  '63785': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63787': {
    county: 'Cape Girardeau County',
    cd: 'CD-3'
  },
  '63801': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63820': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63821': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63822': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63823': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63824': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63825': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63826': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63827': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63828': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63829': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63830': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63833': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63834': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63837': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63839': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63840': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63841': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63845': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63846': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63847': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63848': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63849': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63850': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63851': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63852': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63855': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63857': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63860': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63862': {
    county: 'New Madrid County',
    cd: 'CD-3'
  },
  '63863': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63866': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63867': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63868': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63869': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63870': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63873': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63874': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63875': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63876': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63877': {
    county: 'Dunklin County',
    cd: 'CD-3'
  },
  '63878': {
    county: 'Stoddard County',
    cd: 'CD-3'
  },
  '63879': {
    county: 'Pemiscot County',
    cd: 'CD-3'
  },
  '63901': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63902': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63930': {
    county: 'Oregon County',
    cd: 'CD-3'
  },
  '63932': {
    county: 'Carter County',
    cd: 'CD-3'
  },
  '63933': {
    county: 'Ripley County',
    cd: 'CD-3'
  },
  '63934': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63935': {
    county: 'Carter County',
    cd: 'CD-3'
  },
  '63936': {
    county: 'Shannon County',
    cd: 'CD-3'
  },
  '63937': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63938': {
    county: 'Carter County',
    cd: 'CD-3'
  },
  '63939': {
    county: 'Ripley County',
    cd: 'CD-3'
  },
  '63940': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63941': {
    county: 'Ripley County',
    cd: 'CD-3'
  },
  '63942': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63943': {
    county: 'Wayne County',
    cd: 'CD-3'
  },
  '63944': {
    county: 'Shannon County',
    cd: 'CD-3'
  },
  '63945': {
    county: 'Wayne County',
    cd: 'CD-3'
  },
  '63950': {
    county: 'Oregon County',
    cd: 'CD-3'
  },
  '63951': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63952': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63953': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63954': {
    county: 'Howell County',
    cd: 'CD-3'
  },
  '63955': {
    county: 'Ripley County',
    cd: 'CD-3'
  },
  '63956': {
    county: 'Ripley County',
    cd: 'CD-3'
  },
  '63957': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63960': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63961': {
    county: 'Butler County',
    cd: 'CD-3'
  },
  '63964': {
    county: 'Shannon County',
    cd: 'CD-3'
  },
  '63965': {
    county: 'Oregon County',
    cd: 'CD-3'
  },
  '63966': {
    county: 'Carter County',
    cd: 'CD-3'
  },
  '63967': {
    county: 'Shannon County',
    cd: 'CD-3'
  },
  '65013': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65014': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65017': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65018': {
    county: 'Moniteau County',
    cd: 'CD-3'
  },
  '65020': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65025': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65026': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65032': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65037': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65039': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65040': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65041': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65042': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65043': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65046': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65047': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65048': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65049': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65050': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65051': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65052': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65053': {
    county: 'Gasconade County',
    cd: 'CD-3'
  },
  '65054': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65055': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65058': {
    county: 'Moniteau County',
    cd: 'CD-3'
  },
  '65062': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65063': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65064': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65065': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65066': {
    county: 'Gasconade County',
    cd: 'CD-3'
  },
  '65067': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65068': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65069': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65072': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65074': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65076': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65077': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65078': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65079': {
    county: 'Gasconade County',
    cd: 'CD-3'
  },
  '65080': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65081': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65082': {
    county: 'Maries County',
    cd: 'CD-3'
  },
  '65083': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65084': {
    county: 'Osage County',
    cd: 'CD-3'
  },
  '65101': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65102': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65103': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65104': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65105': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65106': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65107': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65109': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65110': {
    county: 'Cole County',
    cd: 'CD-3'
  },
  '65201': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65202': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65203': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65211': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65212': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65215': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65216': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65217': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65230': {
    county: 'Randolph County',
    cd: 'CD-3'
  },
  '65231': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65232': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65233': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65236': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65237': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65239': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65240': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65243': {
    county: 'Howard County',
    cd: 'CD-3'
  },
  '65244': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65246': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65247': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65248': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65250': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65251': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65254': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65255': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65256': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65257': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65258': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65259': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  '65261': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65262': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65263': {
    county: 'Howard County',
    cd: 'CD-3'
  },
  '65264': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65265': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65270': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65274': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65275': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65276': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65278': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65279': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65280': {
    county: 'Randolph County',
    cd: 'CD-3'
  },
  '65281': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65282': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65283': {
    county: 'Audrain County',
    cd: 'CD-3'
  },
  '65284': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65285': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65286': {
    county: 'Howard County',
    cd: 'CD-3'
  },
  '65287': {
    county: 'Callaway County',
    cd: 'CD-3'
  },
  '65299': {
    county: 'Boone County',
    cd: 'CD-3'
  },
  // CD-4: Central/Western Missouri - Boone, Callaway, Cole, Cooper, Howard, Moniteau, Morgan, Miller, Camden, Laclede, Pulaski, Maries, Phelps, Crawford, Franklin, Gasconade, Warren, Montgomery, Audrain, Lincoln (partial), Benton, Henry, Johnson, Lafayette, Pettis, Saline, plus many rural counties
  '63301': {
    county: 'St. Charles County',
    cd: 'CD-4'
  },
  '63435': {
    county: 'Monroe County',
    cd: 'CD-4'
  },
  '63436': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63437': {
    county: 'Ralls County',
    cd: 'CD-4'
  },
  '63438': {
    county: 'Monroe County',
    cd: 'CD-4'
  },
  '63439': {
    county: 'Ralls County',
    cd: 'CD-4'
  },
  '63440': {
    county: 'Marion County',
    cd: 'CD-4'
  },
  '63441': {
    county: 'Marion County',
    cd: 'CD-4'
  },
  '63443': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63445': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63446': {
    county: 'Shelby County',
    cd: 'CD-4'
  },
  '63447': {
    county: 'Shelby County',
    cd: 'CD-4'
  },
  '63448': {
    county: 'Knox County',
    cd: 'CD-4'
  },
  '63450': {
    county: 'Marion County',
    cd: 'CD-4'
  },
  '63451': {
    county: 'Shelby County',
    cd: 'CD-4'
  },
  '63452': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63453': {
    county: 'Schuyler County',
    cd: 'CD-4'
  },
  '63454': {
    county: 'Marion County',
    cd: 'CD-4'
  },
  '63456': {
    county: 'Monroe County',
    cd: 'CD-4'
  },
  '63457': {
    county: 'Clark County',
    cd: 'CD-4'
  },
  '63458': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63459': {
    county: 'Marion County',
    cd: 'CD-4'
  },
  '63460': {
    county: 'Scotland County',
    cd: 'CD-4'
  },
  '63461': {
    county: 'Knox County',
    cd: 'CD-4'
  },
  '63462': {
    county: 'Knox County',
    cd: 'CD-4'
  },
  '63463': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63464': {
    county: 'Scotland County',
    cd: 'CD-4'
  },
  '63465': {
    county: 'Marion County',
    cd: 'CD-4'
  },
  '63466': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63467': {
    county: 'Shelby County',
    cd: 'CD-4'
  },
  '63468': {
    county: 'Scotland County',
    cd: 'CD-4'
  },
  '63469': {
    county: 'Knox County',
    cd: 'CD-4'
  },
  '63471': {
    county: 'Ralls County',
    cd: 'CD-4'
  },
  '63472': {
    county: 'Knox County',
    cd: 'CD-4'
  },
  '63473': {
    county: 'Clark County',
    cd: 'CD-4'
  },
  '63474': {
    county: 'Lewis County',
    cd: 'CD-4'
  },
  '63532': {
    county: 'Adair County',
    cd: 'CD-4'
  },
  '63533': {
    county: 'Putnam County',
    cd: 'CD-4'
  },
  '63534': {
    county: 'Adair County',
    cd: 'CD-4'
  },
  '63535': {
    county: 'Putnam County',
    cd: 'CD-4'
  },
  '63536': {
    county: 'Macon County',
    cd: 'CD-4'
  },
  '63537': {
    county: 'Sullivan County',
    cd: 'CD-4'
  },
  '63538': {
    county: 'Putnam County',
    cd: 'CD-4'
  },
  '63539': {
    county: 'Schuyler County',
    cd: 'CD-4'
  },
  '63540': {
    county: 'Linn County',
    cd: 'CD-4'
  },
  '63541': {
    county: 'Macon County',
    cd: 'CD-4'
  },
  '63543': {
    county: 'Sullivan County',
    cd: 'CD-4'
  },
  '63544': {
    county: 'Macon County',
    cd: 'CD-4'
  },
  '63545': {
    county: 'Linn County',
    cd: 'CD-4'
  },
  '63546': {
    county: 'Linn County',
    cd: 'CD-4'
  },
  '63547': {
    county: 'Linn County',
    cd: 'CD-4'
  },
  '63548': {
    county: 'Grundy County',
    cd: 'CD-4'
  },
  '63549': {
    county: 'Adair County',
    cd: 'CD-4'
  },
  '63551': {
    county: 'Sullivan County',
    cd: 'CD-4'
  },
  '63552': {
    county: 'Adair County',
    cd: 'CD-4'
  },
  '63555': {
    county: 'Macon County',
    cd: 'CD-4'
  },
  '63556': {
    county: 'Putnam County',
    cd: 'CD-4'
  },
  '63557': {
    county: 'Linn County',
    cd: 'CD-4'
  },
  '63558': {
    county: 'Linn County',
    cd: 'CD-4'
  },
  '63559': {
    county: 'Macon County',
    cd: 'CD-4'
  },
  '63560': {
    county: 'Putnam County',
    cd: 'CD-4'
  },
  '63561': {
    county: 'Macon County',
    cd: 'CD-4'
  },
  '63563': {
    county: 'Adair County',
    cd: 'CD-4'
  },
  '63565': {
    county: 'Sullivan County',
    cd: 'CD-4'
  },
  '63566': {
    county: 'Adair County',
    cd: 'CD-4'
  },
  '63567': {
    county: 'Schuyler County',
    cd: 'CD-4'
  },
  '64001': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64011': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64012': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64014': {
    county: 'Bates County',
    cd: 'CD-4'
  },
  '64015': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64016': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64017': {
    county: 'Henry County',
    cd: 'CD-4'
  },
  '64018': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64019': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64020': {
    county: 'Bates County',
    cd: 'CD-4'
  },
  '64021': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64022': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64024': {
    county: 'Henry County',
    cd: 'CD-4'
  },
  '64028': {
    county: 'Carroll County',
    cd: 'CD-4'
  },
  '64029': {
    county: 'Carroll County',
    cd: 'CD-4'
  },
  '64030': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64034': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64035': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64036': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64037': {
    county: 'Livingston County',
    cd: 'CD-4'
  },
  '64040': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64050': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64051': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64052': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '64053': {
    county: 'Johnson County',
    cd: 'CD-4'
  },
  '64054': {
    county: 'Johnson County',
    cd: 'CD-4'
  },
  '64055': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64056': {
    county: 'Johnson County',
    cd: 'CD-4'
  },
  '64057': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64058': {
    county: 'Johnson County',
    cd: 'CD-4'
  },
  '64060': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64061': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64062': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64063': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64064': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64065': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64066': {
    county: 'Henry County',
    cd: 'CD-4'
  },
  '64067': {
    county: 'Henry County',
    cd: 'CD-4'
  },
  '64068': {
    county: 'Livingston County',
    cd: 'CD-4'
  },
  '64070': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64071': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64072': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64073': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64074': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64075': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '64076': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64077': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64078': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64079': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64080': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64081': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64082': {
    county: 'Johnson County',
    cd: 'CD-4'
  },
  '64083': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64084': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64085': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64086': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64088': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64089': {
    county: 'Lafayette County',
    cd: 'CD-4'
  },
  '64090': {
    county: 'Henry County',
    cd: 'CD-4'
  },
  '64092': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '64093': {
    county: 'Henry County',
    cd: 'CD-4'
  },
  '64096': {
    county: 'Ray County',
    cd: 'CD-4'
  },
  '64097': {
    county: 'Carroll County',
    cd: 'CD-4'
  },
  '64098': {
    county: 'Henry County',
    cd: 'CD-4'
  },
  '65001': {
    county: 'Crawford County',
    cd: 'CD-4'
  },
  '65010': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65011': {
    county: 'Crawford County',
    cd: 'CD-4'
  },
  '65013': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65016': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65017': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65020': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65023': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65024': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65025': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65026': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65035': {
    county: 'Pulaski County',
    cd: 'CD-4'
  },
  '65036': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65037': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65039': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65040': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65041': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65043': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65046': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65047': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65048': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65049': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65051': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65052': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65053': {
    county: 'Gasconade County',
    cd: 'CD-4'
  },
  '65054': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65055': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65058': {
    county: 'Moniteau County',
    cd: 'CD-4'
  },
  '65061': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65062': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65063': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65064': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65065': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65066': {
    county: 'Gasconade County',
    cd: 'CD-4'
  },
  '65067': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65068': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65069': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65072': {
    county: 'Cole County',
    cd: 'CD-4'
  },
  '65074': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65076': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65077': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65078': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65079': {
    county: 'Gasconade County',
    cd: 'CD-4'
  },
  '65080': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65081': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65082': {
    county: 'Maries County',
    cd: 'CD-4'
  },
  '65083': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65084': {
    county: 'Osage County',
    cd: 'CD-4'
  },
  '65085': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65201': {
    county: 'Boone County',
    cd: 'CD-4'
  },
  '65301': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65302': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65305': {
    county: 'Cooper County',
    cd: 'CD-4'
  },
  '65320': {
    county: 'Benton County',
    cd: 'CD-4'
  },
  '65322': {
    county: 'Cooper County',
    cd: 'CD-4'
  },
  '65323': {
    county: 'Benton County',
    cd: 'CD-4'
  },
  '65324': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65325': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65326': {
    county: 'Cooper County',
    cd: 'CD-4'
  },
  '65327': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65329': {
    county: 'Cooper County',
    cd: 'CD-4'
  },
  '65332': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65333': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65334': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65335': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65336': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65337': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65338': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65339': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65340': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65344': {
    county: 'Cooper County',
    cd: 'CD-4'
  },
  '65345': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65347': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65348': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65349': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65350': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65351': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65354': {
    county: 'Pettis County',
    cd: 'CD-4'
  },
  '65355': {
    county: 'Cooper County',
    cd: 'CD-4'
  },
  '65360': {
    county: 'Saline County',
    cd: 'CD-4'
  },
  '65401': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65402': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65409': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65433': {
    county: 'Pulaski County',
    cd: 'CD-4'
  },
  '65436': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65438': {
    county: 'Crawford County',
    cd: 'CD-4'
  },
  '65439': {
    county: 'Crawford County',
    cd: 'CD-4'
  },
  '65440': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65441': {
    county: 'Crawford County',
    cd: 'CD-4'
  },
  '65443': {
    county: 'Gasconade County',
    cd: 'CD-4'
  },
  '65444': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65449': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65452': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65453': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65456': {
    county: 'Dent County',
    cd: 'CD-4'
  },
  '65457': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65459': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65461': {
    county: 'Pulaski County',
    cd: 'CD-4'
  },
  '65462': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65463': {
    county: 'Dent County',
    cd: 'CD-4'
  },
  '65464': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65466': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65468': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65470': {
    county: 'Pulaski County',
    cd: 'CD-4'
  },
  '65473': {
    county: 'Dent County',
    cd: 'CD-4'
  },
  '65479': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65483': {
    county: 'Crawford County',
    cd: 'CD-4'
  },
  '65484': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65486': {
    county: 'Phelps County',
    cd: 'CD-4'
  },
  '65501': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65529': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65532': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65534': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65535': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65536': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65541': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65542': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65543': {
    county: 'Howell County',
    cd: 'CD-4'
  },
  '65548': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65550': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65552': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65555': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65556': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65557': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65559': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65560': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65564': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65565': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65566': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65567': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65570': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65571': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65580': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65582': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65583': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65584': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65586': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65588': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65589': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '65590': {
    county: 'Laclede County',
    cd: 'CD-4'
  },
  '65591': {
    county: 'Texas County',
    cd: 'CD-4'
  },
  '6': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65603': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65604': {
    county: 'Camden County',
    cd: 'CD-4'
  },
  '65605': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65606': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65607': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65608': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65609': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65610': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65611': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65613': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65614': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65616': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65617': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65618': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65619': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65620': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65622': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65626': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65627': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65629': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65630': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65631': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65632': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65633': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65634': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65635': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65636': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65637': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65638': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65640': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65641': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65644': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65645': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65646': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65647': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65648': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65649': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65650': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65652': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65653': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65654': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65655': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65656': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65657': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65658': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65660': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65661': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65662': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65663': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65664': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65667': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65668': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65669': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65672': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65674': {
    county: 'Miller County',
    cd: 'CD-4'
  },
  '65676': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65679': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65680': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65681': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65682': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65686': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65689': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65692': {
    county: 'Morgan County',
    cd: 'CD-4'
  },
  '65702': {
    county: 'Benton County',
    cd: 'CD-4'
  },
  // CD-5: Kansas City and parts of Jackson County
  '64101': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64102': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64105': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64106': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64108': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64109': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64110': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64111': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64112': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64113': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64114': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64116': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64117': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64118': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64119': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64120': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64121': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64123': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64124': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64125': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64126': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64127': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64128': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64129': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64130': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64131': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64132': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64133': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64134': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64136': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64137': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64138': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64139': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64141': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64144': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64145': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64146': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64147': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64148': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64149': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64150': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64151': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64152': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64153': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64154': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64155': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64156': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64157': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64158': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64161': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64163': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64164': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64165': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64166': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64167': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64168': {
    county: 'Clay County',
    cd: 'CD-5'
  },
  '64170': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64171': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64172': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64179': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64180': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64183': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64184': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64185': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64187': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64188': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64191': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64192': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64193': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64194': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64195': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64196': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64197': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64198': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  '64199': {
    county: 'Jackson County',
    cd: 'CD-5'
  },
  // CD-6: Northern Missouri - Platte, Clay, Ray, Carroll, Chariton, Grundy, Harrison, Mercer, Putnam, Schuyler, Sullivan, Livingston, Linn, Macon, Adair, Knox, Scotland, Clark, Lewis, Marion, Shelby, Monroe, Randolph, Howard, plus parts of Jackson
  '64401': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64402': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64420': {
    county: 'Andrew County',
    cd: 'CD-6'
  },
  '64421': {
    county: 'Andrew County',
    cd: 'CD-6'
  },
  '64422': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64423': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64424': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64426': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64427': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64428': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64429': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64430': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64431': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64432': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64433': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64434': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64436': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64437': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64438': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64439': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64440': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64441': {
    county: 'Worth County',
    cd: 'CD-6'
  },
  '64442': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64443': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64444': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64445': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64446': {
    county: 'Worth County',
    cd: 'CD-6'
  },
  '64448': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64449': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64451': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64453': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64454': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64455': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64456': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64457': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64458': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64459': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64461': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64463': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64465': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64466': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64467': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64468': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64469': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64470': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64471': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64473': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64474': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64475': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64476': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64477': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64479': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64480': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64481': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64482': {
    county: 'Andrew County',
    cd: 'CD-6'
  },
  '64483': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64484': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64485': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64486': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64487': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64489': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64490': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64491': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64492': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64493': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64494': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64496': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64497': {
    county: 'Andrew County',
    cd: 'CD-6'
  },
  '64498': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64499': {
    county: 'Andrew County',
    cd: 'CD-6'
  },
  '64501': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64502': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64503': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64504': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64505': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64506': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64507': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64508': {
    county: 'Buchanan County',
    cd: 'CD-6'
  },
  '64601': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64620': {
    county: 'Worth County',
    cd: 'CD-6'
  },
  '64621': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64622': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64623': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64624': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64625': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64628': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64630': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64631': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64632': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64633': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64635': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64636': {
    county: 'Worth County',
    cd: 'CD-6'
  },
  '64637': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64638': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64639': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64640': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64641': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64642': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64643': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64644': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64645': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64646': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64647': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64648': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64649': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64650': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64651': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64652': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64653': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64654': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64655': {
    county: 'Worth County',
    cd: 'CD-6'
  },
  '64656': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64657': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64658': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64659': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64660': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64661': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64664': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64667': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64668': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64670': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64671': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64672': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64673': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64674': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64676': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64679': {
    county: 'Atchison County',
    cd: 'CD-6'
  },
  '64681': {
    county: 'Holt County',
    cd: 'CD-6'
  },
  '64682': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64683': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64686': {
    county: 'Mercer County',
    cd: 'CD-6'
  },
  '64688': {
    county: 'Nodaway County',
    cd: 'CD-6'
  },
  '64689': {
    county: 'Grundy County',
    cd: 'CD-6'
  },
  '64720': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64722': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64723': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64724': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64725': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64726': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64728': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64730': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64733': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64734': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64735': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64738': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64739': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64740': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64741': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64742': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64743': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64744': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64745': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64746': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64747': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64748': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64750': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64755': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64756': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64759': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64761': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64762': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64763': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64767': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64769': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64770': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64771': {
    county: 'Harrison County',
    cd: 'CD-6'
  },
  '64772': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64776': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64778': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64779': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64780': {
    county: 'Gentry County',
    cd: 'CD-6'
  },
  '64781': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  '64783': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64784': {
    county: 'Caldwell County',
    cd: 'CD-6'
  },
  '64788': {
    county: 'DeKalb County',
    cd: 'CD-6'
  },
  '64790': {
    county: 'Daviess County',
    cd: 'CD-6'
  },
  // CD-7: Southwest Missouri - Greene, Christian, Taney, Stone, Lawrence, Barry, McDonald, Newton, Jasper, Barton, Dade, Cedar, Polk, Dallas, Webster, Wright, Douglas, Ozark, Howell (partial)
  '64801': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64802': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64803': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64804': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64830': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64831': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64832': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64833': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64834': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64835': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64836': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64840': {
    county: 'Cedar County',
    cd: 'CD-7'
  },
  '64841': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64842': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64843': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64844': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64847': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64848': {
    county: 'Vernon County',
    cd: 'CD-7'
  },
  '64849': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64850': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64853': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64854': {
    county: 'Dade County',
    cd: 'CD-7'
  },
  '64855': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64856': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64857': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64858': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64859': {
    county: 'Dade County',
    cd: 'CD-7'
  },
  '64861': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64862': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64863': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64865': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64866': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64867': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64868': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '64870': {
    county: 'Newton County',
    cd: 'CD-7'
  },
  '64873': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '64874': {
    county: 'Jasper County',
    cd: 'CD-7'
  },
  '65001': {
    county: 'Barton County',
    cd: 'CD-7'
  },
  '65610': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65611': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65612': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65613': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65614': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65615': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65616': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65617': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65618': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65619': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65620': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65622': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65623': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65624': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65625': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65626': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65627': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65629': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65630': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65631': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65632': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65633': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65634': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65635': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65636': {
    county: 'Douglas County',
    cd: 'CD-7'
  },
  '65637': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65638': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65640': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65641': {
    county: 'Dallas County',
    cd: 'CD-7'
  },
  '65644': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65645': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65646': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65647': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65648': {
    county: 'Douglas County',
    cd: 'CD-7'
  },
  '65649': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65650': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65652': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65653': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65654': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65655': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65656': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65657': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65658': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65660': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65661': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65662': {
    county: 'Dallas County',
    cd: 'CD-7'
  },
  '65663': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65664': {
    county: 'Webster County',
    cd: 'CD-7'
  },
  '65666': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65667': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65668': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65669': {
    county: 'Dallas County',
    cd: 'CD-7'
  },
  '65672': {
    county: 'Douglas County',
    cd: 'CD-7'
  },
  '65674': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65676': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65679': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65680': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65681': {
    county: 'Webster County',
    cd: 'CD-7'
  },
  '65682': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65685': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65686': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65689': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65692': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65701': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65702': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65704': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65705': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65706': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65707': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65708': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65710': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65711': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65712': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65713': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65714': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65715': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65717': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65720': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65721': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65722': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65723': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65724': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65725': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65726': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65727': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65728': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65729': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65730': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65731': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65732': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65733': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65734': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65735': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65737': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65738': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65739': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65740': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65741': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65742': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65744': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65745': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65746': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65747': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65752': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65753': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65754': {
    county: 'Webster County',
    cd: 'CD-7'
  },
  '65755': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65756': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65757': {
    county: 'Newton County',
    cd: 'CD-7'
  },
  '65759': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65760': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65761': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65762': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65764': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65766': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65767': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65768': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65769': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65770': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65771': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65772': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65773': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65774': {
    county: 'Taney County',
    cd: 'CD-7'
  },
  '65775': {
    county: 'Lawrence County',
    cd: 'CD-7'
  },
  '65777': {
    county: 'McDonald County',
    cd: 'CD-7'
  },
  '65778': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65779': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65781': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65783': {
    county: 'Webster County',
    cd: 'CD-7'
  },
  '65784': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65785': {
    county: 'Stone County',
    cd: 'CD-7'
  },
  '65786': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65787': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65788': {
    county: 'Dallas County',
    cd: 'CD-7'
  },
  '65789': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65790': {
    county: 'Barry County',
    cd: 'CD-7'
  },
  '65791': {
    county: 'Webster County',
    cd: 'CD-7'
  },
  '65793': {
    county: 'Christian County',
    cd: 'CD-7'
  },
  '65801': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65802': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65803': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65804': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65805': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65806': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65807': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65808': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65809': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65810': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65814': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65817': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65890': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65897': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65898': {
    county: 'Greene County',
    cd: 'CD-7'
  },
  '65899': {
    county: 'Greene County',
    cd: 'CD-7'
  }
};
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { subscriberId, runAll } = body || {};

    console.log("[populate-subscriber-geography] Incoming:", body);

    // ---------------------------------------------------------
    // SAFEST RUN ALL MODE — NO RECURSION, NO INVOKES, NO CRASH
    // ---------------------------------------------------------
    if (runAll === true) {
      console.log("[populate-subscriber-geography] Starting SAFE FULL-TABLE BACKFILL");

      const supabaseUrl = Deno.env.get("SUPABASE_URL");
      const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
      const supabase = createClient(supabaseUrl, supabaseServiceKey);

      const batchSize = 50;
      let offset = 0;
      let totalProcessed = 0;

      while (true) {
        // Fetch 50 subscribers at a time - only need zip_code now
        const { data: subs, error: batchErr } = await supabase
          .from("subscribers")
          .select("id, zip_code")
          .order("id")
          .range(offset, offset + batchSize - 1);

        if (batchErr) throw batchErr;
        if (!subs || subs.length === 0) break;

        console.log(`[populate-subscriber-geography] Processing batch of ${subs.length}`);

        for (const s of subs) {
          if (!s.zip_code) {
            continue;
          }

          const zipCode = s.zip_code.substring(0, 5);
          const geoData = MISSOURI_GEO_DATA[zipCode];

          // Skip if zip code not in our Missouri data
          if (!geoData) continue;

          // Auto-populate state as MO since this is Missouri geo data
          const { error: updateErr } = await supabase
            .from("subscribers")
            .update({
              state: "MO",
              county: geoData.county,
              congressional_district: geoData.cd,
              house_district: geoData.house || null,
              senate_district: geoData.senate || null,
            })
            .eq("id", s.id);

          if (updateErr) console.error("Update error:", updateErr);

          totalProcessed++;
        }

        offset += batchSize;
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: `Completed safe backfill. Updated ${totalProcessed} rows.`,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ---------------------------------------------------------
    // SINGLE SUBSCRIBER MODE
    // ---------------------------------------------------------
    if (!subscriberId) {
      throw new Error("subscriberId is required unless runAll=true");
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: subscriber, error: fetchError } = await supabase
      .from("subscribers")
      .select("id, zip_code")
      .eq("id", subscriberId)
      .single();

    if (fetchError) throw fetchError;
    if (!subscriber) throw new Error("Subscriber not found");

    if (!subscriber.zip_code) {
      return new Response(
        JSON.stringify({
          success: false,
          message: "ZIP code is required",
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400,
        }
      );
    }

    const zipCode = subscriber.zip_code.substring(0, 5);
    const geoData = MISSOURI_GEO_DATA[zipCode];

    if (!geoData) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Geographic data not available for this ZIP code (not a Missouri ZIP)",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Auto-populate state as MO since this is Missouri geo data
    const { error: updateError } = await supabase
      .from("subscribers")
      .update({
        state: "MO",
        county: geoData.county,
        congressional_district: geoData.cd,
        house_district: geoData.house || null,
        senate_district: geoData.senate || null,
      })
      .eq("id", subscriberId);

    if (updateError) throw updateError;

    return new Response(
      JSON.stringify({
        success: true,
        state: "MO",
        county: geoData.county,
        congressional_district: geoData.cd,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("[populate-subscriber-geography] Error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});