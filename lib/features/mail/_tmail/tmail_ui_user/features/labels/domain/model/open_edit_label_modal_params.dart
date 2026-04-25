import 'package:equatable/equatable.dart';
import 'package:jmap_dart_client/jmap/account_id.dart';
import 'package:bluebubbles/features/mail/_tmail/labels/model/label.dart';

class OpenEditLabelModalParams with EquatableMixin {
  final Label selectedLabel;
  final AccountId? accountId;

  const OpenEditLabelModalParams({
    required this.selectedLabel,
    required this.accountId,
  });

  @override
  List<Object?> get props => [
        selectedLabel,
        accountId,
      ];
}
