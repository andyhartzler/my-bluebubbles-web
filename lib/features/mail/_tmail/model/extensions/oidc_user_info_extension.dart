import 'package:bluebubbles/features/mail/_tmail/model/oidc/response/oidc_user_info.dart';

extension OidcUserInfoExtension on OidcUserInfo {
  bool get isWorkplaceFqdnValid => workplaceFqdn?.trim().isNotEmpty == true;
}
