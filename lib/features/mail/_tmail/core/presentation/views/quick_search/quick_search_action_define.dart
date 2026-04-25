import 'dart:async';

import 'package:bluebubbles/features/mail/_tmail/core/presentation/views/quick_search/quick_search_suggestion_list.dart';
import 'package:bluebubbles/features/mail/_tmail/core/utils/platform_info.dart';
import 'package:flutter/material.dart';

typedef SuggestionsCallback<T> = FutureOr<List<T>> Function(String pattern);

typedef FetchRecentActionCallback<R> = FutureOr<List<R>> Function(
  String pattern,
);

typedef ItemBuilder<T> = Widget Function(BuildContext context, T itemData);

typedef SuggestionSelectionCallback<T> = void Function(T suggestion);

typedef RecentSelectionCallback<R> = void Function(R recent);

typedef ErrorBuilder = Widget Function(BuildContext context, Object? error);

typedef ButtonActionBuilder = Widget Function(
  BuildContext context,
  dynamic action,
  QuickSearchSuggestionListState suggestionsListState,
);

typedef ButtonActionCallback = void Function(dynamic action);

typedef AnimationTransitionBuilder = Widget Function(
  BuildContext context,
  Widget child,
  AnimationController? controller,
);

final supportedPlatform =
    (PlatformInfo.isWeb || PlatformInfo.isAndroid || PlatformInfo.isIOS);
