import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/data/model/composer_cache.dart';

class GetComposerCacheSuccess extends UIState {

  final List<ComposerCache> listComposerCache;

  GetComposerCacheSuccess(this.listComposerCache);

  @override
  List<Object> get props => [listComposerCache];
}

class GetComposerCacheFailure extends FeatureFailure {

  GetComposerCacheFailure(dynamic exception) : super(exception: exception);
}