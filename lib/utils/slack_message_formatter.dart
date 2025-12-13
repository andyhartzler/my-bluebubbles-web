import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utility class to parse and format Slack messages for display in Flutter
class SlackMessageFormatter {
  SlackMessageFormatter._();

  // Patterns for Slack formatting
  static final RegExp _linkRegex = RegExp(r'<(https?://[^|>]+)\|?([^>]*)>');
  static final RegExp _mailtoRegex = RegExp(r'<mailto:([^|>]+)\|?([^>]*)>');
  static final RegExp _boldRegex = RegExp(r'\*([^*]+)\*');
  static final RegExp _channelMentionRegex = RegExp(r'<!channel>|<!here>|<!everyone>');
  static final RegExp _userMentionRegex = RegExp(r'<@([A-Z0-9]+)>|@([A-Z0-9]{9,})');
  static final RegExp _emojiRegex = RegExp(r':([a-z0-9_+-]+)(?:::skin-tone-(\d))?:');

  /// Parse a Slack message and return a list of InlineSpan elements
  static List<InlineSpan> parse(
    String text, {
    required TextStyle baseStyle,
    required Color linkColor,
    required Color mentionColor,
    Map<String, Map<String, String>>? userMappings,
    void Function(String userId, String? memberId)? onMentionTap,
  }) {
    if (text.isEmpty) return [];

    // First, process all special elements and build a list of segments
    final segments = <_Segment>[];
    int lastEnd = 0;

    // Combine all patterns and find all matches
    final allMatches = <_Match>[];

    // Find links
    for (final match in _linkRegex.allMatches(text)) {
      allMatches.add(_Match(match.start, match.end, _MatchType.link, match));
    }

    // Find mailto links
    for (final match in _mailtoRegex.allMatches(text)) {
      allMatches.add(_Match(match.start, match.end, _MatchType.mailto, match));
    }

    // Find bold text
    for (final match in _boldRegex.allMatches(text)) {
      allMatches.add(_Match(match.start, match.end, _MatchType.bold, match));
    }

    // Find channel mentions
    for (final match in _channelMentionRegex.allMatches(text)) {
      allMatches.add(_Match(match.start, match.end, _MatchType.channelMention, match));
    }

    // Find user mentions
    for (final match in _userMentionRegex.allMatches(text)) {
      allMatches.add(_Match(match.start, match.end, _MatchType.userMention, match));
    }

    // Find emojis
    for (final match in _emojiRegex.allMatches(text)) {
      allMatches.add(_Match(match.start, match.end, _MatchType.emoji, match));
    }

    // Sort by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    // Filter out overlapping matches (keep first one)
    final filteredMatches = <_Match>[];
    int currentEnd = 0;
    for (final match in allMatches) {
      if (match.start >= currentEnd) {
        filteredMatches.add(match);
        currentEnd = match.end;
      }
    }

    // Build segments
    for (final match in filteredMatches) {
      // Add plain text before this match
      if (match.start > lastEnd) {
        segments.add(_Segment(
          text: text.substring(lastEnd, match.start),
          type: _SegmentType.plain,
        ));
      }

      // Add the matched segment
      switch (match.type) {
        case _MatchType.link:
          final regexMatch = match.match;
          final url = regexMatch.group(1) ?? '';
          var displayText = regexMatch.group(2);
          if (displayText == null || displayText.isEmpty) {
            displayText = url;
          }
          segments.add(_Segment(
            text: displayText,
            type: _SegmentType.link,
            url: url,
          ));
          break;

        case _MatchType.mailto:
          final regexMatch = match.match;
          final email = regexMatch.group(1) ?? '';
          var displayText = regexMatch.group(2);
          if (displayText == null || displayText.isEmpty) {
            displayText = email;
          }
          segments.add(_Segment(
            text: displayText,
            type: _SegmentType.link,
            url: 'mailto:$email',
          ));
          break;

        case _MatchType.bold:
          final regexMatch = match.match;
          final boldText = regexMatch.group(1) ?? '';
          segments.add(_Segment(
            text: boldText,
            type: _SegmentType.bold,
          ));
          break;

        case _MatchType.channelMention:
          final mentionText = match.match.group(0) ?? '';
          String displayMention;
          if (mentionText.contains('channel')) {
            displayMention = '@channel';
          } else if (mentionText.contains('here')) {
            displayMention = '@here';
          } else {
            displayMention = '@everyone';
          }
          segments.add(_Segment(
            text: displayMention,
            type: _SegmentType.channelMention,
          ));
          break;

        case _MatchType.userMention:
          final regexMatch = match.match;
          final userId = regexMatch.group(1) ?? regexMatch.group(2) ?? '';
          final userInfo = userMappings?[userId];
          final displayName = userInfo?['real_name']?.isNotEmpty == true
              ? userInfo!['real_name']!
              : (userInfo?['display_name']?.isNotEmpty == true
                  ? userInfo!['display_name']!
                  : userId);
          final memberId = userInfo?['member_id'];
          segments.add(_Segment(
            text: '@$displayName',
            type: _SegmentType.userMention,
            userId: userId,
            memberId: memberId,
          ));
          break;

        case _MatchType.emoji:
          final regexMatch = match.match;
          final emojiName = regexMatch.group(1) ?? '';
          final skinTone = regexMatch.group(2);
          final emoji = _slackEmojiToUnicode(emojiName, skinTone);
          if (emoji != null) {
            segments.add(_Segment(
              text: emoji,
              type: _SegmentType.emoji,
            ));
          } else {
            // Keep original if not found
            segments.add(_Segment(
              text: match.match.group(0) ?? '',
              type: _SegmentType.plain,
            ));
          }
          break;
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      segments.add(_Segment(
        text: text.substring(lastEnd),
        type: _SegmentType.plain,
      ));
    }

    // Convert segments to InlineSpan
    return segments.map((segment) {
      switch (segment.type) {
        case _SegmentType.plain:
          return TextSpan(text: segment.text, style: baseStyle);

        case _SegmentType.bold:
          return TextSpan(
            text: segment.text,
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          );

        case _SegmentType.link:
          return TextSpan(
            text: segment.text,
            style: baseStyle.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final url = segment.url;
                if (url != null && url.isNotEmpty) {
                  _launchUrl(url);
                }
              },
          );

        case _SegmentType.channelMention:
          return TextSpan(
            text: segment.text,
            style: baseStyle.copyWith(
              color: mentionColor,
              fontWeight: FontWeight.w600,
              backgroundColor: mentionColor.withOpacity(0.1),
            ),
          );

        case _SegmentType.userMention:
          final hasValidMemberId = segment.memberId != null && segment.memberId!.isNotEmpty;
          return TextSpan(
            text: segment.text,
            style: baseStyle.copyWith(
              color: mentionColor,
              fontWeight: FontWeight.w600,
              decoration: hasValidMemberId ? TextDecoration.underline : null,
            ),
            recognizer: hasValidMemberId
                ? (TapGestureRecognizer()
                  ..onTap = () {
                    onMentionTap?.call(segment.userId ?? '', segment.memberId);
                  })
                : null,
          );

        case _SegmentType.emoji:
          // Return emoji with slightly larger font for better visibility
          return TextSpan(
            text: segment.text,
            style: baseStyle.copyWith(
              fontFamily: 'Apple Color Emoji, Segoe UI Emoji, Noto Color Emoji, sans-serif',
            ),
          );
      }
    }).toList();
  }

  static Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  /// Convert Slack emoji shortcode to Unicode emoji (public method)
  static String? emojiToUnicode(String name) => _slackEmojiToUnicode(name, null);

  /// Convert Slack emoji shortcode to Unicode emoji
  static String? _slackEmojiToUnicode(String name, String? skinTone) {
    // Skin tone modifiers
    final skinToneModifiers = {
      '2': '\u{1F3FB}', // light
      '3': '\u{1F3FC}', // medium-light
      '4': '\u{1F3FD}', // medium
      '5': '\u{1F3FE}', // medium-dark
      '6': '\u{1F3FF}', // dark
    };

    // Common Slack emoji mappings to Unicode
    final emojiMap = <String, String>{
      // Smileys & Emotion
      'smile': '\u{1F604}',
      'laughing': '\u{1F606}',
      'blush': '\u{1F60A}',
      'smiley': '\u{1F603}',
      'relaxed': '\u{263A}\u{FE0F}',
      'smirk': '\u{1F60F}',
      'heart_eyes': '\u{1F60D}',
      'kissing_heart': '\u{1F618}',
      'kissing_closed_eyes': '\u{1F61A}',
      'flushed': '\u{1F633}',
      'relieved': '\u{1F60C}',
      'satisfied': '\u{1F60C}',
      'grin': '\u{1F601}',
      'wink': '\u{1F609}',
      'stuck_out_tongue_winking_eye': '\u{1F61C}',
      'stuck_out_tongue_closed_eyes': '\u{1F61D}',
      'grinning': '\u{1F600}',
      'kissing': '\u{1F617}',
      'kissing_smiling_eyes': '\u{1F619}',
      'stuck_out_tongue': '\u{1F61B}',
      'sleeping': '\u{1F634}',
      'worried': '\u{1F61F}',
      'frowning': '\u{1F626}',
      'anguished': '\u{1F627}',
      'open_mouth': '\u{1F62E}',
      'grimacing': '\u{1F62C}',
      'confused': '\u{1F615}',
      'hushed': '\u{1F62F}',
      'expressionless': '\u{1F611}',
      'unamused': '\u{1F612}',
      'sweat_smile': '\u{1F605}',
      'sweat': '\u{1F613}',
      'disappointed_relieved': '\u{1F625}',
      'weary': '\u{1F629}',
      'pensive': '\u{1F614}',
      'disappointed': '\u{1F61E}',
      'confounded': '\u{1F616}',
      'fearful': '\u{1F628}',
      'cold_sweat': '\u{1F630}',
      'persevere': '\u{1F623}',
      'cry': '\u{1F622}',
      'sob': '\u{1F62D}',
      'joy': '\u{1F602}',
      'astonished': '\u{1F632}',
      'scream': '\u{1F631}',
      'tired_face': '\u{1F62B}',
      'angry': '\u{1F620}',
      'rage': '\u{1F621}',
      'triumph': '\u{1F624}',
      'sleepy': '\u{1F62A}',
      'yum': '\u{1F60B}',
      'mask': '\u{1F637}',
      'sunglasses': '\u{1F60E}',
      'dizzy_face': '\u{1F635}',
      'imp': '\u{1F47F}',
      'smiling_imp': '\u{1F608}',
      'neutral_face': '\u{1F610}',
      'no_mouth': '\u{1F636}',
      'innocent': '\u{1F607}',
      'alien': '\u{1F47D}',
      'yellow_heart': '\u{1F49B}',
      'blue_heart': '\u{1F499}',
      'purple_heart': '\u{1F49C}',
      'heart': '\u{2764}\u{FE0F}',
      'green_heart': '\u{1F49A}',
      'broken_heart': '\u{1F494}',
      'heartbeat': '\u{1F493}',
      'heartpulse': '\u{1F497}',
      'two_hearts': '\u{1F495}',
      'revolving_hearts': '\u{1F49E}',
      'cupid': '\u{1F498}',
      'sparkling_heart': '\u{1F496}',
      'sparkles': '\u{2728}',
      'star': '\u{2B50}',
      'star2': '\u{1F31F}',
      'dizzy': '\u{1F4AB}',
      'boom': '\u{1F4A5}',
      'collision': '\u{1F4A5}',
      'anger': '\u{1F4A2}',
      'exclamation': '\u{2757}',
      'question': '\u{2753}',
      'grey_exclamation': '\u{2755}',
      'grey_question': '\u{2754}',
      'zzz': '\u{1F4A4}',
      'dash': '\u{1F4A8}',
      'sweat_drops': '\u{1F4A6}',
      'notes': '\u{1F3B6}',
      'musical_note': '\u{1F3B5}',
      'fire': '\u{1F525}',
      'poop': '\u{1F4A9}',

      // Gestures
      '+1': '\u{1F44D}',
      'thumbsup': '\u{1F44D}',
      '-1': '\u{1F44E}',
      'thumbsdown': '\u{1F44E}',
      'ok_hand': '\u{1F44C}',
      'punch': '\u{1F44A}',
      'facepunch': '\u{1F44A}',
      'fist': '\u{270A}',
      'v': '\u{270C}\u{FE0F}',
      'wave': '\u{1F44B}',
      'hand': '\u{270B}',
      'raised_hand': '\u{270B}',
      'open_hands': '\u{1F450}',
      'point_up': '\u{261D}\u{FE0F}',
      'point_down': '\u{1F447}',
      'point_left': '\u{1F448}',
      'point_right': '\u{1F449}',
      'raised_hands': '\u{1F64C}',
      'pray': '\u{1F64F}',
      'point_up_2': '\u{1F446}',
      'clap': '\u{1F44F}',
      'muscle': '\u{1F4AA}',
      'metal': '\u{1F918}',
      'fu': '\u{1F595}',
      'middle_finger': '\u{1F595}',
      'heart_hands': '\u{1FAF6}',
      'raised_fist': '\u{270A}',
      'pinching_hand': '\u{1F90F}',
      'pinched_fingers': '\u{1F90C}',
      'crossed_fingers': '\u{1F91E}',
      'love_you_gesture': '\u{1F91F}',
      'call_me_hand': '\u{1F919}',
      'writing_hand': '\u{270D}\u{FE0F}',
      'selfie': '\u{1F933}',
      'nail_care': '\u{1F485}',

      // People
      'couple': '\u{1F46B}',
      'couple_with_heart': '\u{1F491}',
      'couplekiss': '\u{1F48F}',
      'family': '\u{1F46A}',
      'man': '\u{1F468}',
      'woman': '\u{1F469}',
      'boy': '\u{1F466}',
      'girl': '\u{1F467}',
      'person': '\u{1F9D1}',
      'adult': '\u{1F9D1}',
      'child': '\u{1F9D2}',
      'baby': '\u{1F476}',
      'older_man': '\u{1F474}',
      'older_woman': '\u{1F475}',
      'older_adult': '\u{1F9D3}',
      'bearded_person': '\u{1F9D4}',
      'man_with_beard': '\u{1F9D4}\u{200D}\u{2642}\u{FE0F}',
      'woman_with_headscarf': '\u{1F9D5}',
      'person_bald': '\u{1F9D1}\u{200D}\u{1F9B2}',
      'man_bald': '\u{1F468}\u{200D}\u{1F9B2}',
      'woman_bald': '\u{1F469}\u{200D}\u{1F9B2}',
      'person_red_hair': '\u{1F9D1}\u{200D}\u{1F9B0}',
      'person_curly_hair': '\u{1F9D1}\u{200D}\u{1F9B1}',
      'person_white_hair': '\u{1F9D1}\u{200D}\u{1F9B3}',
      'cop': '\u{1F46E}',
      'construction_worker': '\u{1F477}',
      'princess': '\u{1F478}',
      'angel': '\u{1F47C}',
      'bride_with_veil': '\u{1F470}',
      'bow': '\u{1F647}',
      'information_desk_person': '\u{1F481}',
      'no_good': '\u{1F645}',
      'ok_woman': '\u{1F646}',
      'raising_hand': '\u{1F64B}',
      'person_with_pouting_face': '\u{1F64E}',
      'person_frowning': '\u{1F64D}',
      'haircut': '\u{1F487}',
      'massage': '\u{1F486}',
      'dancer': '\u{1F483}',
      'man_dancing': '\u{1F57A}',
      'dancers': '\u{1F46F}',
      'walking': '\u{1F6B6}',
      'runner': '\u{1F3C3}',
      'running': '\u{1F3C3}',

      // Nature
      'dog': '\u{1F436}',
      'cat': '\u{1F431}',
      'mouse': '\u{1F42D}',
      'hamster': '\u{1F439}',
      'rabbit': '\u{1F430}',
      'wolf': '\u{1F43A}',
      'frog': '\u{1F438}',
      'tiger': '\u{1F42F}',
      'koala': '\u{1F428}',
      'bear': '\u{1F43B}',
      'pig': '\u{1F437}',
      'cow': '\u{1F42E}',
      'boar': '\u{1F417}',
      'monkey_face': '\u{1F435}',
      'monkey': '\u{1F412}',
      'horse': '\u{1F434}',
      'racehorse': '\u{1F40E}',
      'camel': '\u{1F42B}',
      'sheep': '\u{1F411}',
      'elephant': '\u{1F418}',
      'snake': '\u{1F40D}',
      'bird': '\u{1F426}',
      'baby_chick': '\u{1F424}',
      'chicken': '\u{1F414}',
      'penguin': '\u{1F427}',
      'turtle': '\u{1F422}',
      'bug': '\u{1F41B}',
      'honeybee': '\u{1F41D}',
      'ant': '\u{1F41C}',
      'beetle': '\u{1FAB2}',
      'snail': '\u{1F40C}',
      'octopus': '\u{1F419}',
      'fish': '\u{1F41F}',
      'whale': '\u{1F433}',
      'dolphin': '\u{1F42C}',
      'sunflower': '\u{1F33B}',
      'rose': '\u{1F339}',
      'tulip': '\u{1F337}',
      'cherry_blossom': '\u{1F338}',
      'four_leaf_clover': '\u{1F340}',
      'maple_leaf': '\u{1F341}',
      'fallen_leaf': '\u{1F342}',
      'leaves': '\u{1F343}',
      'mushroom': '\u{1F344}',
      'cactus': '\u{1F335}',
      'palm_tree': '\u{1F334}',
      'deciduous_tree': '\u{1F333}',
      'evergreen_tree': '\u{1F332}',
      'christmas_tree': '\u{1F384}',
      'sun_with_face': '\u{1F31E}',
      'full_moon_with_face': '\u{1F31D}',
      'new_moon_with_face': '\u{1F31A}',
      'first_quarter_moon_with_face': '\u{1F31B}',
      'last_quarter_moon_with_face': '\u{1F31C}',
      'full_moon': '\u{1F315}',
      'new_moon': '\u{1F311}',
      'waxing_crescent_moon': '\u{1F312}',
      'first_quarter_moon': '\u{1F313}',
      'moon': '\u{1F314}',
      'waxing_gibbous_moon': '\u{1F314}',
      'waning_gibbous_moon': '\u{1F316}',
      'last_quarter_moon': '\u{1F317}',
      'waning_crescent_moon': '\u{1F318}',
      'crescent_moon': '\u{1F319}',
      'earth_africa': '\u{1F30D}',
      'earth_americas': '\u{1F30E}',
      'earth_asia': '\u{1F30F}',
      'sun_small_cloud': '\u{1F324}\u{FE0F}',
      'partly_sunny': '\u{26C5}',
      'mostly_sunny': '\u{1F324}\u{FE0F}',
      'sun_behind_large_cloud': '\u{1F325}\u{FE0F}',
      'sun_behind_rain_cloud': '\u{1F326}\u{FE0F}',
      'cloud': '\u{2601}\u{FE0F}',
      'rain_cloud': '\u{1F327}\u{FE0F}',
      'thunder_cloud_and_rain': '\u{26C8}\u{FE0F}',
      'lightning': '\u{1F329}\u{FE0F}',
      'lightning_cloud': '\u{1F329}\u{FE0F}',
      'zap': '\u{26A1}',
      'snow_cloud': '\u{1F328}\u{FE0F}',
      'snowflake': '\u{2744}\u{FE0F}',
      'snowman': '\u{26C4}',
      'snowman_without_snow': '\u{26C4}',
      'wind_face': '\u{1F32C}\u{FE0F}',
      'wind_blowing_face': '\u{1F32C}\u{FE0F}',
      'fog': '\u{1F32B}\u{FE0F}',
      'umbrella': '\u{2614}',
      'umbrella2': '\u{2602}\u{FE0F}',
      'rainbow': '\u{1F308}',
      'ocean': '\u{1F30A}',

      // Food & Drink
      'apple': '\u{1F34E}',
      'green_apple': '\u{1F34F}',
      'tangerine': '\u{1F34A}',
      'lemon': '\u{1F34B}',
      'cherries': '\u{1F352}',
      'grapes': '\u{1F347}',
      'watermelon': '\u{1F349}',
      'strawberry': '\u{1F353}',
      'peach': '\u{1F351}',
      'melon': '\u{1F348}',
      'banana': '\u{1F34C}',
      'pear': '\u{1F350}',
      'pineapple': '\u{1F34D}',
      'tomato': '\u{1F345}',
      'eggplant': '\u{1F346}',
      'corn': '\u{1F33D}',
      'bread': '\u{1F35E}',
      'cheese': '\u{1F9C0}',
      'hamburger': '\u{1F354}',
      'pizza': '\u{1F355}',
      'fries': '\u{1F35F}',
      'hotdog': '\u{1F32D}',
      'popcorn': '\u{1F37F}',
      'taco': '\u{1F32E}',
      'burrito': '\u{1F32F}',
      'ramen': '\u{1F35C}',
      'spaghetti': '\u{1F35D}',
      'sushi': '\u{1F363}',
      'rice': '\u{1F35A}',
      'rice_ball': '\u{1F359}',
      'rice_cracker': '\u{1F358}',
      'curry': '\u{1F35B}',
      'oden': '\u{1F362}',
      'dango': '\u{1F361}',
      'shaved_ice': '\u{1F367}',
      'ice_cream': '\u{1F368}',
      'icecream': '\u{1F366}',
      'cake': '\u{1F370}',
      'birthday': '\u{1F382}',
      'custard': '\u{1F36E}',
      'candy': '\u{1F36C}',
      'lollipop': '\u{1F36D}',
      'chocolate_bar': '\u{1F36B}',
      'doughnut': '\u{1F369}',
      'cookie': '\u{1F36A}',
      'coffee': '\u{2615}',
      'tea': '\u{1F375}',
      'beer': '\u{1F37A}',
      'beers': '\u{1F37B}',
      'wine_glass': '\u{1F377}',
      'cocktail': '\u{1F378}',
      'tropical_drink': '\u{1F379}',
      'champagne': '\u{1F37E}',

      // Celebration
      'tada': '\u{1F389}',
      'confetti_ball': '\u{1F38A}',
      'balloon': '\u{1F388}',
      'gift': '\u{1F381}',
      'ribbon': '\u{1F380}',
      'fireworks': '\u{1F386}',
      'sparkler': '\u{1F387}',
      'jack_o_lantern': '\u{1F383}',
      'ghost': '\u{1F47B}',
      'skull': '\u{1F480}',
      'skull_and_crossbones': '\u{2620}\u{FE0F}',

      // Objects
      'soccer': '\u{26BD}',
      'basketball': '\u{1F3C0}',
      'football': '\u{1F3C8}',
      'baseball': '\u{26BE}',
      'tennis': '\u{1F3BE}',
      '8ball': '\u{1F3B1}',
      'bowling': '\u{1F3B3}',
      'golf': '\u{26F3}',
      'trophy': '\u{1F3C6}',
      'medal': '\u{1F3C5}',
      'medal_sports': '\u{1F3C5}',
      'first_place_medal': '\u{1F947}',
      'second_place_medal': '\u{1F948}',
      'third_place_medal': '\u{1F949}',
      'checkered_flag': '\u{1F3C1}',
      'rocket': '\u{1F680}',
      'airplane': '\u{2708}\u{FE0F}',
      'car': '\u{1F697}',
      'blue_car': '\u{1F699}',
      'bus': '\u{1F68C}',
      'ambulance': '\u{1F691}',
      'fire_engine': '\u{1F692}',
      'police_car': '\u{1F693}',
      'taxi': '\u{1F695}',
      'truck': '\u{1F69A}',
      'train': '\u{1F683}',
      'tram': '\u{1F68A}',
      'metro': '\u{1F687}',
      'ship': '\u{1F6A2}',
      'bike': '\u{1F6B2}',
      'helicopter': '\u{1F681}',
      'sailboat': '\u{26F5}',
      'anchor': '\u{2693}',
      'house': '\u{1F3E0}',
      'house_with_garden': '\u{1F3E1}',
      'school': '\u{1F3EB}',
      'office': '\u{1F3E2}',
      'hospital': '\u{1F3E5}',
      'bank': '\u{1F3E6}',
      'convenience_store': '\u{1F3EA}',
      'hotel': '\u{1F3E8}',
      'love_hotel': '\u{1F3E9}',
      'church': '\u{26EA}',
      'fountain': '\u{26F2}',
      'tent': '\u{26FA}',
      'factory': '\u{1F3ED}',
      'tokyo_tower': '\u{1F5FC}',
      'statue_of_liberty': '\u{1F5FD}',
      'moyai': '\u{1F5FF}',
      'phone': '\u{260E}\u{FE0F}',
      'telephone_receiver': '\u{1F4DE}',
      'iphone': '\u{1F4F1}',
      'calling': '\u{1F4F2}',
      'computer': '\u{1F4BB}',
      'keyboard': '\u{2328}\u{FE0F}',
      'desktop_computer': '\u{1F5A5}\u{FE0F}',
      'printer': '\u{1F5A8}\u{FE0F}',
      'mouse_three_button': '\u{1F5B1}\u{FE0F}',
      'cd': '\u{1F4BF}',
      'dvd': '\u{1F4C0}',
      'floppy_disk': '\u{1F4BE}',
      'camera': '\u{1F4F7}',
      'movie_camera': '\u{1F3A5}',
      'clapper': '\u{1F3AC}',
      'tv': '\u{1F4FA}',
      'radio': '\u{1F4FB}',
      'vhs': '\u{1F4FC}',
      'mag': '\u{1F50D}',
      'mag_right': '\u{1F50E}',
      'microscope': '\u{1F52C}',
      'telescope': '\u{1F52D}',
      'bulb': '\u{1F4A1}',
      'flashlight': '\u{1F526}',
      'electric_plug': '\u{1F50C}',
      'battery': '\u{1F50B}',
      'wrench': '\u{1F527}',
      'hammer': '\u{1F528}',
      'nut_and_bolt': '\u{1F529}',
      'gear': '\u{2699}\u{FE0F}',
      'link': '\u{1F517}',
      'paperclip': '\u{1F4CE}',
      'scissors': '\u{2702}\u{FE0F}',
      'lock': '\u{1F512}',
      'unlock': '\u{1F513}',
      'key': '\u{1F511}',
      'old_key': '\u{1F5DD}\u{FE0F}',
      'bell': '\u{1F514}',
      'no_bell': '\u{1F515}',
      'bookmark': '\u{1F516}',
      'books': '\u{1F4DA}',
      'book': '\u{1F4D6}',
      'open_book': '\u{1F4D6}',
      'green_book': '\u{1F4D7}',
      'blue_book': '\u{1F4D8}',
      'orange_book': '\u{1F4D9}',
      'notebook': '\u{1F4D3}',
      'notebook_with_decorative_cover': '\u{1F4D4}',
      'ledger': '\u{1F4D2}',
      'closed_book': '\u{1F4D5}',
      'page_with_curl': '\u{1F4C3}',
      'scroll': '\u{1F4DC}',
      'page_facing_up': '\u{1F4C4}',
      'newspaper': '\u{1F4F0}',
      'bookmark_tabs': '\u{1F4D1}',
      'bar_chart': '\u{1F4CA}',
      'chart_with_upwards_trend': '\u{1F4C8}',
      'chart_with_downwards_trend': '\u{1F4C9}',
      'clipboard': '\u{1F4CB}',
      'pushpin': '\u{1F4CC}',
      'round_pushpin': '\u{1F4CD}',
      'straight_ruler': '\u{1F4CF}',
      'triangular_ruler': '\u{1F4D0}',
      'memo': '\u{1F4DD}',
      'pencil2': '\u{270F}\u{FE0F}',
      'pen': '\u{1F58A}\u{FE0F}',
      'crayon': '\u{1F58D}\u{FE0F}',
      'paintbrush': '\u{1F58C}\u{FE0F}',
      'file_folder': '\u{1F4C1}',
      'open_file_folder': '\u{1F4C2}',
      'card_index_dividers': '\u{1F5C2}\u{FE0F}',
      'calendar': '\u{1F4C6}',
      'date': '\u{1F4C5}',
      'card_index': '\u{1F4C7}',
      'chart': '\u{1F4C8}',
      'inbox_tray': '\u{1F4E5}',
      'outbox_tray': '\u{1F4E4}',
      'package': '\u{1F4E6}',
      'email': '\u{1F4E7}',
      'e-mail': '\u{1F4E7}',
      'incoming_envelope': '\u{1F4E8}',
      'envelope_with_arrow': '\u{1F4E9}',
      'mailbox_closed': '\u{1F4EA}',
      'mailbox': '\u{1F4EB}',
      'mailbox_with_mail': '\u{1F4EC}',
      'mailbox_with_no_mail': '\u{1F4ED}',
      'postbox': '\u{1F4EE}',

      // Symbols
      'heavy_check_mark': '\u{2714}\u{FE0F}',
      'white_check_mark': '\u{2705}',
      'ballot_box_with_check': '\u{2611}\u{FE0F}',
      'heavy_multiplication_x': '\u{2716}\u{FE0F}',
      'x': '\u{274C}',
      'negative_squared_cross_mark': '\u{274E}',
      'heavy_plus_sign': '\u{2795}',
      'heavy_minus_sign': '\u{2796}',
      'heavy_division_sign': '\u{2797}',
      'bangbang': '\u{203C}\u{FE0F}',
      'interrobang': '\u{2049}\u{FE0F}',
      'tm': '\u{2122}\u{FE0F}',
      'copyright': '\u{00A9}\u{FE0F}',
      'registered': '\u{00AE}\u{FE0F}',
      'hundred': '\u{1F4AF}',
      '100': '\u{1F4AF}',
      'keycap_ten': '\u{1F51F}',
      'hash': '\u{0023}\u{FE0F}\u{20E3}',
      'zero': '\u{0030}\u{FE0F}\u{20E3}',
      'one': '\u{0031}\u{FE0F}\u{20E3}',
      'two': '\u{0032}\u{FE0F}\u{20E3}',
      'three': '\u{0033}\u{FE0F}\u{20E3}',
      'four': '\u{0034}\u{FE0F}\u{20E3}',
      'five': '\u{0035}\u{FE0F}\u{20E3}',
      'six': '\u{0036}\u{FE0F}\u{20E3}',
      'seven': '\u{0037}\u{FE0F}\u{20E3}',
      'eight': '\u{0038}\u{FE0F}\u{20E3}',
      'nine': '\u{0039}\u{FE0F}\u{20E3}',
      'arrow_right': '\u{27A1}\u{FE0F}',
      'arrow_left': '\u{2B05}\u{FE0F}',
      'arrow_up': '\u{2B06}\u{FE0F}',
      'arrow_down': '\u{2B07}\u{FE0F}',
      'arrow_upper_right': '\u{2197}\u{FE0F}',
      'arrow_lower_right': '\u{2198}\u{FE0F}',
      'arrow_lower_left': '\u{2199}\u{FE0F}',
      'arrow_upper_left': '\u{2196}\u{FE0F}',
      'arrow_up_down': '\u{2195}\u{FE0F}',
      'left_right_arrow': '\u{2194}\u{FE0F}',
      'arrows_counterclockwise': '\u{1F504}',
      'arrow_backward': '\u{25C0}\u{FE0F}',
      'arrow_forward': '\u{25B6}\u{FE0F}',
      'arrow_up_small': '\u{1F53C}',
      'arrow_down_small': '\u{1F53D}',
      'leftwards_arrow_with_hook': '\u{21A9}\u{FE0F}',
      'arrow_right_hook': '\u{21AA}\u{FE0F}',
      'information_source': '\u{2139}\u{FE0F}',
      'rewind': '\u{23EA}',
      'fast_forward': '\u{23E9}',
      'arrow_double_up': '\u{23EB}',
      'arrow_double_down': '\u{23EC}',
      'ok': '\u{1F197}',
      'new': '\u{1F195}',
      'up': '\u{1F199}',
      'cool': '\u{1F192}',
      'free': '\u{1F193}',
      'ng': '\u{1F196}',
      'signal_strength': '\u{1F4F6}',
      'cinema': '\u{1F3A6}',
      'koko': '\u{1F201}',
      'six_pointed_star': '\u{1F52F}',
      'no_entry_sign': '\u{1F6AB}',
      'no_entry': '\u{26D4}',
      'name_badge': '\u{1F4DB}',
      'no_pedestrians': '\u{1F6B7}',
      'do_not_litter': '\u{1F6AF}',
      'no_bicycles': '\u{1F6B3}',
      'non-potable_water': '\u{1F6B1}',
      'underage': '\u{1F51E}',
      'no_mobile_phones': '\u{1F4F5}',
      'no_smoking': '\u{1F6AD}',
      'accept': '\u{1F251}',
      'ideograph_advantage': '\u{1F250}',
      'white_flower': '\u{1F4AE}',
      'secret': '\u{3299}\u{FE0F}',
      'congratulations': '\u{3297}\u{FE0F}',
      'u5408': '\u{1F234}',
      'u6e80': '\u{1F235}',
      'u5272': '\u{1F239}',
      'u7981': '\u{1F232}',
      'a': '\u{1F170}\u{FE0F}',
      'b': '\u{1F171}\u{FE0F}',
      'ab': '\u{1F18E}',
      'cl': '\u{1F191}',
      'o2': '\u{1F17E}\u{FE0F}',
      'sos': '\u{1F198}',
      'parking': '\u{1F17F}\u{FE0F}',
      'wc': '\u{1F6BE}',
      'restroom': '\u{1F6BB}',
      'mens': '\u{1F6B9}',
      'womens': '\u{1F6BA}',
      'baby_symbol': '\u{1F6BC}',
      'wheelchair': '\u{267F}',
      'potable_water': '\u{1F6B0}',
      'put_litter_in_its_place': '\u{1F6AE}',
      'atm': '\u{1F3E7}',
      'passport_control': '\u{1F6C2}',
      'customs': '\u{1F6C3}',
      'baggage_claim': '\u{1F6C4}',
      'left_luggage': '\u{1F6C5}',
      'warning': '\u{26A0}\u{FE0F}',
      'children_crossing': '\u{1F6B8}',
      'trident': '\u{1F531}',
      'fleur_de_lis': '\u{269C}\u{FE0F}',
      'beginner': '\u{1F530}',
      'recycle': '\u{267B}\u{FE0F}',
      'chart': '\u{1F4B9}',
      'sparkle': '\u{2747}\u{FE0F}',
      'eight_spoked_asterisk': '\u{2733}\u{FE0F}',
      'negative_squared_cross_mark': '\u{274E}',
      'globe_with_meridians': '\u{1F310}',
      'diamond_shape_with_a_dot_inside': '\u{1F4A0}',
      'm': '\u{24C2}\u{FE0F}',
      'cyclone': '\u{1F300}',
      'yen': '\u{1F4B4}',
      'dollar': '\u{1F4B5}',
      'euro': '\u{1F4B6}',
      'pound': '\u{1F4B7}',
      'money_with_wings': '\u{1F4B8}',
      'credit_card': '\u{1F4B3}',
      'moneybag': '\u{1F4B0}',
      'gem': '\u{1F48E}',

      // Flags
      'flag-us': '\u{1F1FA}\u{1F1F8}',
      'us': '\u{1F1FA}\u{1F1F8}',
      'flag-gb': '\u{1F1EC}\u{1F1E7}',
      'gb': '\u{1F1EC}\u{1F1E7}',
      'uk': '\u{1F1EC}\u{1F1E7}',
      'flag-de': '\u{1F1E9}\u{1F1EA}',
      'de': '\u{1F1E9}\u{1F1EA}',
      'flag-fr': '\u{1F1EB}\u{1F1F7}',
      'fr': '\u{1F1EB}\u{1F1F7}',
      'flag-es': '\u{1F1EA}\u{1F1F8}',
      'es': '\u{1F1EA}\u{1F1F8}',
      'flag-it': '\u{1F1EE}\u{1F1F9}',
      'it': '\u{1F1EE}\u{1F1F9}',
      'flag-jp': '\u{1F1EF}\u{1F1F5}',
      'jp': '\u{1F1EF}\u{1F1F5}',
      'flag-kr': '\u{1F1F0}\u{1F1F7}',
      'kr': '\u{1F1F0}\u{1F1F7}',
      'flag-cn': '\u{1F1E8}\u{1F1F3}',
      'cn': '\u{1F1E8}\u{1F1F3}',
      'flag-ru': '\u{1F1F7}\u{1F1FA}',
      'ru': '\u{1F1F7}\u{1F1FA}',
      'flag-ca': '\u{1F1E8}\u{1F1E6}',
      'flag-au': '\u{1F1E6}\u{1F1FA}',
      'flag-br': '\u{1F1E7}\u{1F1F7}',
      'flag-mx': '\u{1F1F2}\u{1F1FD}',
      'flag-in': '\u{1F1EE}\u{1F1F3}',
      'checkered_flag': '\u{1F3C1}',
      'crossed_flags': '\u{1F38C}',
      'waving_white_flag': '\u{1F3F3}\u{FE0F}',
      'waving_black_flag': '\u{1F3F4}',
      'rainbow_flag': '\u{1F3F3}\u{FE0F}\u{200D}\u{1F308}',
      'pirate_flag': '\u{1F3F4}\u{200D}\u{2620}\u{FE0F}',
      'triangular_flag_on_post': '\u{1F6A9}',

      // Additional common Slack emojis
      'eyes': '\u{1F440}',
      'eye': '\u{1F441}\u{FE0F}',
      'ear': '\u{1F442}',
      'nose': '\u{1F443}',
      'lips': '\u{1F444}',
      'tongue': '\u{1F445}',
      'raised_eyebrow': '\u{1F928}',
      'monocle_face': '\u{1F9D0}',
      'zipper_mouth_face': '\u{1F910}',
      'money_mouth_face': '\u{1F911}',
      'face_with_thermometer': '\u{1F912}',
      'nerd_face': '\u{1F913}',
      'thinking_face': '\u{1F914}',
      'thinking': '\u{1F914}',
      'face_with_head_bandage': '\u{1F915}',
      'robot_face': '\u{1F916}',
      'robot': '\u{1F916}',
      'hugging_face': '\u{1F917}',
      'hugs': '\u{1F917}',
      'cowboy_hat_face': '\u{1F920}',
      'clown_face': '\u{1F921}',
      'nauseated_face': '\u{1F922}',
      'rolling_on_the_floor_laughing': '\u{1F923}',
      'rofl': '\u{1F923}',
      'drooling_face': '\u{1F924}',
      'lying_face': '\u{1F925}',
      'sneezing_face': '\u{1F927}',
      'face_with_raised_eyebrow': '\u{1F928}',
      'star_struck': '\u{1F929}',
      'zany_face': '\u{1F92A}',
      'shushing_face': '\u{1F92B}',
      'face_with_symbols_on_mouth': '\u{1F92C}',
      'face_with_hand_over_mouth': '\u{1F92D}',
      'face_vomiting': '\u{1F92E}',
      'exploding_head': '\u{1F92F}',
      'slightly_smiling_face': '\u{1F642}',
      'upside_down_face': '\u{1F643}',
      'face_without_mouth': '\u{1F636}',
      'smiling_face_with_tear': '\u{1F972}',
      'partying_face': '\u{1F973}',
      'woozy_face': '\u{1F974}',
      'hot_face': '\u{1F975}',
      'cold_face': '\u{1F976}',
      'pleading_face': '\u{1F97A}',
      'yawning_face': '\u{1F971}',
      'face_exhaling': '\u{1F62E}\u{200D}\u{1F4A8}',
      'face_in_clouds': '\u{1F636}\u{200D}\u{1F32B}\u{FE0F}',
      'face_with_spiral_eyes': '\u{1F635}\u{200D}\u{1F4AB}',
      'melting_face': '\u{1FAE0}',
      'saluting_face': '\u{1FAE1}',
      'face_with_open_eyes_and_hand_over_mouth': '\u{1FAE2}',
      'face_with_peeking_eye': '\u{1FAE3}',
      'face_holding_back_tears': '\u{1F979}',
      'shaking_face': '\u{1FAE8}',
      'dotted_line_face': '\u{1FAE5}',
    };

    // Look up emoji
    String? emoji = emojiMap[name];

    // If not found, try without underscores
    if (emoji == null) {
      final normalized = name.replaceAll('_', '').replaceAll('-', '');
      emoji = emojiMap.entries.firstWhere(
        (e) => e.key.replaceAll('_', '').replaceAll('-', '') == normalized,
        orElse: () => MapEntry('', ''),
      ).value;
      if (emoji != null && emoji.isEmpty) emoji = null;
    }

    // Apply skin tone modifier if applicable
    if (emoji != null && skinTone != null) {
      final modifier = skinToneModifiers[skinTone];
      if (modifier != null) {
        // Insert skin tone modifier after base emoji (for ZWJ sequences this is complex)
        // For simple emojis, append after first codepoint
        final codeUnits = emoji.runes.toList();
        if (codeUnits.isNotEmpty) {
          // Insert skin tone after the first character
          final result = StringBuffer();
          result.writeCharCode(codeUnits.first);
          result.write(modifier);
          if (codeUnits.length > 1) {
            for (int i = 1; i < codeUnits.length; i++) {
              result.writeCharCode(codeUnits[i]);
            }
          }
          emoji = result.toString();
        }
      }
    }

    return emoji;
  }
}

enum _MatchType { link, mailto, bold, channelMention, userMention, emoji }

class _Match {
  final int start;
  final int end;
  final _MatchType type;
  final RegExpMatch match;

  _Match(this.start, this.end, this.type, this.match);
}

enum _SegmentType { plain, bold, link, channelMention, userMention, emoji }

class _Segment {
  final String text;
  final _SegmentType type;
  final String? url;
  final String? userId;
  final String? memberId;

  _Segment({
    required this.text,
    required this.type,
    this.url,
    this.userId,
    this.memberId,
  });
}
