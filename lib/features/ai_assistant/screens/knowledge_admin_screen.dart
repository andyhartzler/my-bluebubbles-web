import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../models/knowledge_stats.dart';

class KnowledgeAdminScreen extends StatefulWidget {
  const KnowledgeAdminScreen({super.key});

  @override
  State<KnowledgeAdminScreen> createState() => _KnowledgeAdminScreenState();
}

class _KnowledgeAdminScreenState extends State<KnowledgeAdminScreen> {
  bool _isProcessing = false;
  String? _lastActionResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIAssistantProvider>().loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Base Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AIAssistantProvider>().loadStats(),
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: Consumer<AIAssistantProvider>(
        builder: (context, provider, _) {
          final stats = provider.stats;

          if (provider.isLoading && stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status result banner
                if (_lastActionResult != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastActionResult!,
                            style: TextStyle(
                                color: colorScheme.onPrimaryContainer),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: colorScheme.onPrimaryContainer),
                          onPressed: () =>
                              setState(() => _lastActionResult = null),
                          iconSize: 18,
                        ),
                      ],
                    ),
                  ),

                // Overview Stats
                Text('Overview',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (stats != null) _buildOverviewCards(context, stats),

                const SizedBox(height: 24),

                // Quick Actions
                Text('Quick Actions',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildQuickActions(context),

                const SizedBox(height: 24),

                // Table Configuration
                Text('Table Configuration',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (stats != null) _buildTableConfigs(context, stats),

                const SizedBox(height: 24),

                // Documents by Table
                Text('Documents by Table',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (stats != null) _buildDocumentsByTable(context, stats),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, KnowledgeStats stats) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          title: 'Total Documents',
          value: '${stats.totalDocuments}',
          icon: Icons.storage,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'Ready',
          value: '${stats.completedDocuments}',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Pending',
          value: '${stats.pendingEmbeddings}',
          icon: Icons.pending,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Failed',
          value: '${stats.failedEmbeddings}',
          icon: Icons.error,
          color: Colors.red,
        ),
        _StatCard(
          title: 'Queries This Month',
          value: '${stats.totalQueries}',
          icon: Icons.search,
          color: Colors.purple,
        ),
        _StatCard(
          title: 'Monthly Cost',
          value: '\$${stats.monthlyUsageDollars.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final provider = context.read<AIAssistantProvider>();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          label: 'Process Embeddings',
          icon: Icons.memory,
          isLoading: _isProcessing,
          onPressed: () async {
            setState(() => _isProcessing = true);
            try {
              final result = await provider.processEmbeddings();
              setState(() {
                _lastActionResult =
                    'Processed ${result['processed'] ?? 0} embeddings';
              });
              await provider.loadStats();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            } finally {
              setState(() => _isProcessing = false);
            }
          },
        ),
        _ActionButton(
          label: 'Index Storage Files',
          icon: Icons.folder_open,
          isLoading: _isProcessing,
          onPressed: () async {
            setState(() => _isProcessing = true);
            try {
              final result = await provider.indexStorageFiles();
              setState(() {
                _lastActionResult = 'Indexed ${result['indexed'] ?? 0} files';
              });
              await provider.loadStats();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            } finally {
              setState(() => _isProcessing = false);
            }
          },
        ),
        _ActionButton(
          label: 'Discover Tables',
          icon: Icons.search,
          isLoading: _isProcessing,
          onPressed: () async {
            setState(() => _isProcessing = true);
            try {
              final result = await provider.discoverTables();
              setState(() {
                _lastActionResult = 'Discovered ${result.length} tables';
              });
              await provider.loadStats();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            } finally {
              setState(() => _isProcessing = false);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTableConfigs(BuildContext context, KnowledgeStats stats) {
    if (stats.tableConfigs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No tables configured yet. Use "Discover Tables" to find tables.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stats.tableConfigs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final config = stats.tableConfigs[index];
          return _TableConfigTile(config: config);
        },
      ),
    );
  }

  Widget _buildDocumentsByTable(BuildContext context, KnowledgeStats stats) {
    if (stats.documentsByTable.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No documents indexed yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final sortedEntries = stats.documentsByTable.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedEntries.length,
        itemBuilder: (context, index) {
          final entry = sortedEntries[index];
          return ListTile(
            leading: Icon(_getTableIcon(entry.key)),
            title: Text(entry.key),
            trailing: Chip(
              label: Text('${entry.value}'),
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
            ),
          );
        },
      ),
    );
  }

  IconData _getTableIcon(String tableName) {
    switch (tableName) {
      case 'members':
        return Icons.person;
      case 'chapters':
        return Icons.groups;
      case 'subscribers':
        return Icons.email;
      case 'donors':
        return Icons.volunteer_activism;
      case 'donations':
        return Icons.payments;
      case 'campaigns':
        return Icons.campaign;
      case 'events':
        return Icons.event;
      case 'jobs':
        return Icons.work;
      case 'meetings':
        return Icons.meeting_room;
      case 'legislation_tracked_bills':
        return Icons.gavel;
      case 'form_schemas':
        return Icons.description;
      case 'slack_messages':
        return Icons.chat;
      case 'calendar_events':
        return Icons.calendar_today;
      default:
        return Icons.table_chart;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
    );
  }
}

class _TableConfigTile extends StatelessWidget {
  final TableConfig config;

  const _TableConfigTile({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(
        config.isEnabled ? Icons.check_circle : Icons.circle_outlined,
        color: config.isEnabled ? Colors.green : Colors.grey,
      ),
      title: Text(config.tableName),
      subtitle: Row(
        children: [
          if (config.triggerInstalled)
            _StatusChip(
              label: 'Trigger',
              color: Colors.blue,
            ),
          if (config.lastSyncAt != null) ...[
            const SizedBox(width: 4),
            _StatusChip(
              label: 'Synced',
              color: Colors.green,
            ),
          ],
          if (config.rowCount != null) ...[
            const SizedBox(width: 4),
            Text(
              '${config.rowCount} rows',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      trailing: Switch(
        value: config.isEnabled,
        onChanged: (value) async {
          final provider = context.read<AIAssistantProvider>();
          // Note: You would need to add enableTable/disableTable methods
          // to the provider for this to work
          await provider.loadStats();
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
