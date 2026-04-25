
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/mixin/app_loader_mixin.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/thread/domain/state/search_email_state.dart';

class SearchEmailLoadingBarWidget extends StatelessWidget with AppLoaderMixin {

  final Either<Failure, Success> resultSearchViewState;
  final Either<Failure, Success> suggestionViewState;

  const SearchEmailLoadingBarWidget({
    super.key,
    required this.resultSearchViewState,
    required this.suggestionViewState
  });

  @override
  Widget build(BuildContext context) {
    return resultSearchViewState.fold(
      (failure) => _suggestionViewStateToUI(suggestionViewState),
      (success) {
        if (success is SearchingState) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: loadingWidget
          );
        } else {
          return _suggestionViewStateToUI(suggestionViewState);
        }
      }
    );
  }

  Widget _suggestionViewStateToUI(Either<Failure, Success> viewState) {
    return viewState.fold(
      (failure) => const SizedBox.shrink(),
      (success) {
        if (success is LoadingState) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: loadingWidget
          );
        } else {
          return const SizedBox.shrink();
        }
      }
    );
  }
}