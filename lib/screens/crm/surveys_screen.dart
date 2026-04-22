import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/survey_model.dart';
import 'package:bluebubbles/services/crm/survey_repository.dart';
import 'package:bluebubbles/screens/crm/survey_builder_screen.dart';
import 'package:bluebubbles/screens/crm/survey_results_widget.dart';

class SurveysScreen extends StatefulWidget {
  const SurveysScreen({super.key});

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen>
    with TickerProviderStateMixin {
  final _repo = SurveyRepository();
  late TabController _tabController;

  List<Survey> _allSurveys = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  // Status filters per tab index; null = "all".
  static const List<String?> _tabStatusFilters = [
    null,
    'active',
    'draft',
    'completed',
  ];

  List<Survey> _surveysForTab(int tabIndex) {
    var filtered = _allSurveys;

    // Text search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((s) => s.title.toLowerCase().contains(q))
          .toList();
    }

    // Tab filter: 0=All, 1=Active, 2=Drafts, 3=Completed
    final tabFilter = _tabStatusFilters[tabIndex];
    if (tabFilter != null) {
      filtered = filtered.where((s) => s.status == tabFilter).toList();
    }

    return filtered;
  }


  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // rebuild for new filter
      }
    });
    _loadSurveys();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _loadSurveys() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final surveys = await _repo.fetchSurveys(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() {
          _allSurveys = surveys;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load surveys: $e';
          _loading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _openBuilder({Survey? existing}) async {
    await Navigator.of(context).push<Survey>(
      MaterialPageRoute(
        builder: (_) => SurveyBuilderScreen(existingSurvey: existing),
      ),
    );
    // Always reload when returning from builder — survey may have been
    // created, updated, or sent regardless of pop result.
    _loadSurveys();
  }

  void _openResults(Survey survey) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(survey.title),
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: BrandColors.tileGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            foregroundColor: Colors.white,
          ),
          body: SurveyResultsWidget(
            surveyId: survey.id!,
            surveyTitle: survey.title,
          ),
        ),
      ),
    );
    // Reload counts when returning — sessions may have progressed
    _loadSurveys();
  }

  Future<void> _duplicateSurvey(Survey survey) async {
    try {
      final duplicated = await _repo.duplicateSurvey(survey.id!);
      _loadSurveys();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duplicated as "${duplicated.title}"')),
        );
        // Open the builder so the user can change the title/audience
        _openBuilder(existing: duplicated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error duplicating survey: $e')),
        );
      }
    }
  }

  Future<void> _deleteSurvey(Survey survey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Survey?'),
        content: Text('Delete "${survey.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repo.deleteSurvey(survey.id!);
      _loadSurveys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildTabBar(),
        Expanded(
          child: BrandedBackground(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
                    ? _buildErrorState()
                    : TabBarView(
                        controller: _tabController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: List.generate(
                          4,
                          (tabIndex) => _buildSurveyList(tabIndex),
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.poll_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          // Title + count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Surveys', style: BrandTextStyles.title),
                Text(
                  '${_allSurveys.length} survey${_allSurveys.length == 1 ? '' : 's'}',
                  style: BrandTextStyles.subtitle,
                ),
              ],
            ),
          ),
          // Create button
          ElevatedButton.icon(
            onPressed: () => _openBuilder(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Survey'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.sunriseGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      color: BrandColors.unityBlue,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search surveys...',
          hintStyle: const TextStyle(color: Colors.white70),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadSurveys();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _debounceTimer?.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 300), () {
            _loadSurveys();
          });
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab bar
  // ---------------------------------------------------------------------------

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(color: BrandColors.unityBlue),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: BrandColors.sunriseGold,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
        tabs: [
          Tab(text: 'All (${_countForStatus(null)})'),
          Tab(text: 'Active (${_countForStatus('active')})'),
          Tab(text: 'Drafts (${_countForStatus('draft')})'),
          Tab(text: 'Completed (${_countForStatus('completed')})'),
        ],
      ),
    );
  }

  int _countForStatus(String? status) {
    if (status == null) return _allSurveys.length;
    return _allSurveys.where((s) => s.status == status).length;
  }

  // ---------------------------------------------------------------------------
  // Survey list (per tab)
  // ---------------------------------------------------------------------------

  Widget _buildSurveyList(int tabIndex) {
    final surveys = _surveysForTab(tabIndex);

    if (surveys.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadSurveys,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: surveys.length,
        itemBuilder: (context, index) => _buildSurveyCard(surveys[index]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Survey card
  // ---------------------------------------------------------------------------

  Widget _buildSurveyCard(Survey survey) {
    final dateFmt = DateFormat('MMM d, y');
    final statusColor = _statusColor(survey.status);
    final statusLabel = _statusLabel(survey.status);
    final hasProgress = survey.sessionCount > 0;
    final progressValue =
        hasProgress ? survey.completedCount / survey.sessionCount : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BrandColors.tileGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: BrandColors.unityBlue.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => survey.status == 'draft'
              ? _openBuilder(existing: survey)
              : _openResults(survey),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Title + Status badge + Menu ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        survey.title,
                        style: BrandTextStyles.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(statusLabel, statusColor),
                    const SizedBox(width: 4),
                    _buildPopupMenu(survey),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Row 2: Metadata chips ──
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (survey.eventId != null)
                      _buildInfoChip(Icons.event, 'Event-linked', BrandColors.sunriseGold),
                    _buildInfoChip(
                      Icons.help_outline,
                      '${survey.questions.length} question${survey.questions.length == 1 ? '' : 's'}',
                      Colors.white70,
                    ),
                    if (hasProgress)
                      _buildInfoChip(
                        Icons.people,
                        '${survey.completedCount}/${survey.sessionCount} completed',
                        Colors.white70,
                      ),
                    if (survey.createdAt != null)
                      _buildInfoChip(
                        Icons.calendar_today,
                        dateFmt.format(survey.createdAt!),
                        Colors.white70,
                      ),
                  ],
                ),

                // ── Row 3: Progress bar (if sessions exist) ──
                if (hasProgress) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressValue >= 1.0
                                  ? BrandColors.success
                                  : BrandColors.sunriseGold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(progressValue * 100).round()}%',
                        style: BrandTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.35),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPopupMenu(Survey survey) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _openBuilder(existing: survey);
            break;
          case 'results':
            _openResults(survey);
            break;
          case 'duplicate':
            _duplicateSurvey(survey);
            break;
          case 'delete':
            _deleteSurvey(survey);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (survey.status != 'draft')
          const PopupMenuItem(value: 'results', child: Text('View Results')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final isTabFiltered = _tabController.index != 0;
    final isSearchFiltered = _searchQuery.isNotEmpty;

    String title;
    String subtitle;

    if (isSearchFiltered) {
      title = 'No matching surveys';
      subtitle = 'Try a different search term.';
    } else if (isTabFiltered) {
      final tabName = const ['', 'active', 'draft', 'completed'][_tabController.index];
      title = 'No $tabName surveys';
      subtitle = 'Surveys with "$tabName" status will appear here.';
    } else {
      title = 'No surveys yet';
      subtitle = 'Create your first survey to start collecting feedback.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.poll_outlined,
                size: 64,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (!isSearchFiltered && !isTabFiltered) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openBuilder(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Survey'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.sunriseGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSurveys,
              // Translucent pill on the navy error backdrop; matches the
              // command-center's chip style instead of a harsh solid-white
              // rectangle.
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white.withOpacity(0.28)),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return BrandColors.success;
      case 'draft':
        return Colors.grey;
      case 'paused':
        return BrandColors.sunriseGold;
      case 'completed':
        return BrandColors.momentumBlue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'draft':
        return 'Draft';
      case 'paused':
        return 'Paused';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
