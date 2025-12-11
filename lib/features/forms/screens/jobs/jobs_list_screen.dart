import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/jobs_service.dart';
import '../../widgets/job_card.dart';
import 'job_builder_screen.dart';
import 'job_detail_screen.dart';

class JobsListScreen extends StatefulWidget {
  const JobsListScreen({Key? key}) : super(key: key);

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen>
    with AutomaticKeepAliveClientMixin {
  final _jobsService = JobsService();
  String _statusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending', badge: true),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', 'approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),

          // Jobs List
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: _jobsService.watchJobs(_statusFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final jobs = snapshot.data ?? [];

                if (jobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_off_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_statusFilter == 'all' ? '' : _statusFilter} jobs',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _createJob,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Job'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {}); // Trigger rebuild
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return JobCard(
                        job: job,
                        onTap: () => _viewJob(context, job),
                        onEdit: () => _editJob(job),
                        onDelete: () => _confirmDeleteJob(job),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createJob,
        tooltip: 'Create Job',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool badge = false}) {
    final isSelected = _statusFilter == value;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badge) ...[
            const SizedBox(width: 4),
            StreamBuilder<int>(
              stream: _jobsService.watchPendingCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  void _viewJob(BuildContext context, Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(jobId: job.id),
      ),
    );
  }

  void _createJob() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const JobBuilderScreen(),
      ),
    );
  }

  void _editJob(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobBuilderScreen(jobId: job.id),
      ),
    );
  }

  void _confirmDeleteJob(Job job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: Text('Are you sure you want to delete "${job.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _jobsService.deleteJob(job.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Job deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete job: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
