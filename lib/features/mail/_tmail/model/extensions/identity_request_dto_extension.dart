import 'package:jmap_dart_client/jmap/identities/identity.dart';
import 'package:bluebubbles/features/mail/_tmail/model/identity/identity_request_dto.dart';

extension IdentityRequestDtoExtension on IdentityRequestDto {
  Identity toIdentityWithId(IdentityId identityId) => Identity(
    id: identityId,
    name: name,
    replyTo: replyTo,
    bcc: bcc,
    textSignature: textSignature,
    htmlSignature: htmlSignature,
    sortOrder: sortOrder,
  );
}