import 'package:bluebubbles/features/mail/_tmail/labels/labels.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/mailbox_dashboard/presentation/controller/advanced_filter_controller.dart';

extension UpdateLabelInAdvancedSearchExtension on AdvancedFilterController {
  void setSelectedLabel(Label? newLabel) {
    if (selectedLabel.value?.id == newLabel?.id) {
      selectedLabel.value = null;
    } else {
      selectedLabel.value = newLabel;
    }
  }
}
