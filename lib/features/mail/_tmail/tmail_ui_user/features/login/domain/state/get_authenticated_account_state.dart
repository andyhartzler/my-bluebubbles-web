import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:bluebubbles/features/mail/_tmail/model/account/personal_account.dart';

class GetAuthenticatedAccountSuccess extends UIState {
  final PersonalAccount account;

  GetAuthenticatedAccountSuccess(this.account);

  @override
  List<Object> get props => [account];
}

class GetAuthenticatedAccountFailure extends FeatureFailure {

  GetAuthenticatedAccountFailure(dynamic exception) : super(exception: exception);
}
