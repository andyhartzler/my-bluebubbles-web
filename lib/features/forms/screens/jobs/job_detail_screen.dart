import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/jobs_service.dart';
import 'job_builder_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;

  const JobDetailScreen({
    Key? key,
    required this.jobId,
  }) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _jobsService = JobsService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openInBrowser(),
            tooltip: 'View on Website',
          ),
        ],
      ),
      body: FutureBuilder<Job>(
        future: _jobsService.getJob(widget.jobId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final job = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Banner
                if (job.status == 'pending')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.orange[100],
                    child: Row(
                      children: [
                        Icon(Icons.pending_outlined, color: Colors.orange[900]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This job is pending approval',
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Job Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Organization
                      Text(
                        job.organization,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChip(job.jobType, Colors.blue),
                          if (job.locationType != null)
                            _buildChip(job.locationType!, Colors.green),
                          if (job.isPaid)
                            _buildChip('Paid', Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Location
                      if (job.location != null) ...[
                        _buildSection('Location', job.location!),
                        const SizedBox(height: 16),
                      ],

                      // Description
                      _buildSection('Description', job.description),
                      const SizedBox(height: 16),

                      // Requirements
                      if (job.requirements != null) ...[
                        _buildSection('Requirements', job.requirements!),
                        const SizedBox(height: 16),
                      ],

                      // Qualifications
                      if (job.qualifications != null) ...[
                        _buildSection('Qualifications', job.qualifications!),
                        const SizedBox(height: 16),
                      ],

                      // Contact Info
                      _buildSection('Contact Email', job.contactEmail),
                      const SizedBox(height: 16),

                      // Submitter Info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Submitted By',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Name: ${job.submitterName}'),
                              Text('Email: ${job.submitterEmail}'),
                              if (job.submitterOrganization != null)
                                Text('Organization: ${job.submitterOrganization}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<Job>(
        future: _jobsService.getJob(widget.jobId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final job = snapshot.data!;

          if (job.status != 'pending') {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _editJob(job),
                child: const Text('Edit Job'),
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _rejectJob(job),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _approveJob(job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Approve & Publish'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(content),
      ],
    );
  }

  Future<void> _approveJob(Job job) async {
    setState(() => _isLoading = true);

    try {
      await _jobsService.approveJob(job.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job approved and published!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _rejectJob(Job job) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectJobDialog(),
    );

    if (reason == null) return;

    setState(() => _isLoading = true);

    try {
      await _jobsService.rejectJob(job.id, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _editJob(Job job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobBuilderScreen(jobId: job.id),
      ),
    ).then((_) {
      setState(() {}); // Refresh after edit
    });
  }

  void _openInBrowser() {
    // Open in web browser
    // TODO: Implement URL launcher
  }
}

class _RejectJobDialog extends StatefulWidget {
  @override
  State<_RejectJobDialog> createState() => _RejectJobDialogState();
}

class _RejectJobDialogState extends State<_RejectJobDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Job'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Reason for rejection',
          hintText: 'Provide feedback to the submitter...',
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
