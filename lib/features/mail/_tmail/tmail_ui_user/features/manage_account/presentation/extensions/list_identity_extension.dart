
import 'package:jmap_dart_client/jmap/identities/identity.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/domain/model/identity_signature.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/manage_account/presentation/extensions/identity_extension.dart';

extension ListIdentityExtension on List<Identity> {

  List<IdentitySignature> toListIdentitySignature() {
    return map((identity) => identity.toIdentitySignature())
        .nonNulls
        .toList();
  }
}