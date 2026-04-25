import 'package:bluebubbles/features/mail/_tmail/core/presentation/state/failure.dart';
import 'package:dartz/dartz.dart';
import 'package:bluebubbles/features/mail/_tmail/tmail_ui_user/features/base/base_controller.dart';

mixin EmitStateMixin {
  void emitFailure({
    required BaseController controller,
    required FeatureFailure failure,
  }) {
    controller.consumeState(Stream.value(Left(failure)));
  }
}
