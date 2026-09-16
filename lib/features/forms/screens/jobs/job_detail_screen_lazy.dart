import 'package:flutter/material.dart';

import 'package:bluebubbles/widgets/deferred_module_lazy.dart';

import 'job_detail_screen.dart' deferred as jds;

/// Lazy wrapper around [JobDetailScreen] (8.3K dominated lines).
///
/// Pushed as a route from the personalized-home assignments panel, which was
/// its only eager importer outside `lib/features/forms/`.
class JobDetailScreenLazy extends StatelessWidget {
  const JobDetailScreenLazy({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return DeferredModule(
      moduleName: 'job detail',
      load: () => jds.loadLibrary(),
      builder: (_) => jds.JobDetailScreen(jobId: jobId),
    );
  }
}
