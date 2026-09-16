import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'submission_detail_screen.dart' deferred as sds;

/// Lazy wrapper around [SubmissionDetailScreen], the endorsement questionnaire
/// review surface (it dominates the ~3.2K-line submission review body).
///
/// Only the id-based constructor is exposed, because the one eager importer
/// outside `lib/features/forms/` (`member_detail_screen.dart`) uses that form.
/// The pre-loaded `submission`+`form` constructor stays available to callers
/// inside the forms module, which are already behind the forms boundary.
class SubmissionDetailScreenLazy extends StatelessWidget {
  const SubmissionDetailScreenLazy({
    super.key,
    required this.formId,
    required this.submissionId,
  });

  final String formId;
  final String submissionId;

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'submission review',
      load: () => sds.loadLibrary(),
      builder: (_) => sds.SubmissionDetailScreen(
        formId: formId,
        submissionId: submissionId,
      ),
    );
  }
}
