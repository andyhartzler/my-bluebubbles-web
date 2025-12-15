import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/job.dart';
import '../../services/jobs_service.dart';
import '../../widgets/job_card.dart';
import 'job_builder_screen.dart';
import 'job_detail_screen.dart';
import 'job_applicants_screen.dart';
import 'job_notification_templates_screen.dart';

class JobsListScreen extends StatefulWidget {
  const JobsListScreen({super.key});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen>
    with AutomaticKeepAliveClientMixin {
  final _jobsService = JobsService();
  String _statusFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Cache application counts to avoid multiple fetches
  Map<String, int> _applicationCounts = {};
  Timer? _countRefreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Refresh application counts periodically
    _countRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshApplicationCounts(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _countRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshApplicationCounts() async {
    // Refresh counts for visible jobs
    if (_applicationCounts.isNotEmpty) {
      final newCounts = <String, int>{};
      for (final jobId in _applicationCounts.keys) {
        try {
          newCounts[jobId] = await _jobsService.getApplicationCount(jobId);
        } catch (_) {
          newCounts[jobId] = _applicationCounts[jobId] ?? 0;
        }
      }
      if (mounted) {
        setState(() {
          _applicationCounts = newCounts;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Stats Summary Bar
          _buildStatsSummary(theme),

          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search jobs...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', Icons.list_alt),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending', Icons.pending_outlined, badge: true),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', 'approved', Icons.check_circle_outline),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected', Icons.cancel_outlined),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Jobs List
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: _jobsService.watchJobs(_statusFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorState(theme, snapshot.error.toString());
                }

                var jobs = snapshot.data ?? [];

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  jobs = jobs.where((job) =>
                    job.title.toLowerCase().contains(_searchQuery) ||
                    job.organization.toLowerCase().contains(_searchQuery) ||
                    (job.location?.toLowerCase().contains(_searchQuery) ?? false)
                  ).toList();
                }

                // Fetch application counts for these jobs
                _fetchApplicationCounts(jobs);

                if (jobs.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return _buildListLayout(jobs);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createJob,
        tooltip: 'Create Job',
        icon: const Icon(Icons.add),
        label: const Text('Create Job'),
      ),
    );
  }

  Widget _buildStatsSummary(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<List<Job>>(
        stream: _jobsService.watchJobs('all'),
        builder: (context, snapshot) {
          final jobs = snapshot.data ?? [];
          final pending = jobs.where((j) => j.status == 'pending').length;
          final approved = jobs.where((j) => j.status == 'approved').length;
          final totalApplications = _applicationCounts.values.fold(0, (a, b) => a + b);

          return Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  theme,
                  '${jobs.length}',
                  'Total Jobs',
                  Icons.work_outline,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  theme,
                  '$pending',
                  'Pending',
                  Icons.pending_outlined,
                  color: Colors.orange,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  theme,
                  '$approved',
                  'Approved',
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  theme,
                  '$totalApplications',
                  'Applicants',
                  Icons.people_outline,
                  color: theme.colorScheme.primary,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              // Notifications settings button
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _openNotificationTemplates,
                tooltip: 'Notification Templates',
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openNotificationTemplates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const JobNotificationTemplatesScreen(),
      ),
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    String value,
    String label,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: color ?? theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color ?? theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon, {bool badge = false}) {
    final isSelected = _statusFilter == value;
    final theme = Theme.of(context);

    return FilterChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
      ),
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
                      fontSize: 11,
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

  Widget _buildListLayout(List<Job> jobs) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await _refreshApplicationCounts();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) => _buildJobCard(jobs[index]),
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    return JobCard(
      job: job,
      applicationCount: _applicationCounts[job.id],
      onTap: () => _viewJob(context, job),
      onEdit: () => _editJob(job),
      onDelete: () => _confirmDeleteJob(job),
      onViewApplicants: () => _viewApplicants(job),
    );
  }

  void _fetchApplicationCounts(List<Job> jobs) async {
    for (final job in jobs) {
      if (!_applicationCounts.containsKey(job.id)) {
        try {
          final count = await _jobsService.getApplicationCount(job.id);
          if (mounted) {
            setState(() {
              _applicationCounts[job.id] = count;
            });
          }
        } catch (_) {
          // Ignore errors
        }
      }
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.work_off_outlined,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No jobs match your search'
                : 'No ${_statusFilter == 'all' ? '' : _statusFilter} jobs',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_searchQuery.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
            )
          else
            ElevatedButton.icon(
              onPressed: _createJob,
              icon: const Icon(Icons.add),
              label: const Text('Create Job'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading jobs',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
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

  void _viewApplicants(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JobApplicantsScreen(job: job),
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
        content: Text(
          'Are you sure you want to delete "${job.title}"? This will also delete all ${_applicationCounts[job.id] ?? 0} applications. This action cannot be undone.',
        ),
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
                _applicationCounts.remove(job.id);
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
