import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/success.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/paywall/domain/repository/paywall_repository.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/paywall/domain/state/get_paywall_url_state.dart';

class GetPaywallUrlInteractor {
  final PaywallRepository _paywallRepository;

  GetPaywallUrlInteractor(this._paywallRepository);

  Stream<Either<Failure, Success>> execute(String baseUrl) async* {
    try {
      yield Right(GettingPaywallUrl());
      final paywallUrl = await _paywallRepository.getPaywallUrl(baseUrl);
      yield Right(GetPaywallUrlSuccess(paywallUrl));
    } catch (e) {
      yield Left(GetPaywallUrlFailure(e));
    }
  }
}
