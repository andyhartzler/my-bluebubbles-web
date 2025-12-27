import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_assistant_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_input_field.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/suggestion_chips.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIAssistantProvider>().loadSessions();
    });
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  void _handleSendMessage(String message) {
    context.read<AIAssistantProvider>().sendMessage(message);
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Consumer<AIAssistantProvider>(
          builder: (context, provider, _) {
            final title = provider.currentSession?.title ?? 'AI Assistant';
            return Text(
              title,
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          // New chat button
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              context.read<AIAssistantProvider>().createNewSession();
            },
            tooltip: 'New Chat',
          ),
          // History button
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showChatHistory(context),
            tooltip: 'Chat History',
          ),
          // More menu
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: ListTile(
                  leading: Icon(Icons.analytics_outlined),
                  title: Text('View Stats'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'admin',
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined),
                  title: Text('Knowledge Admin'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Archive Chat'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AIAssistantProvider>(
        builder: (context, provider, child) {
          // Show error snackbar
          if (provider.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.error!),
                  backgroundColor: colorScheme.error,
                  action: SnackBarAction(
                    label: 'Dismiss',
                    textColor: colorScheme.onError,
                    onPressed: () => provider.clearError(),
                  ),
                ),
              );
              provider.clearError();
            });
          }

          return Column(
            children: [
              // Messages list
              Expanded(
                child: provider.messages.isEmpty
                    ? _buildEmptyState(context)
                    : _buildMessagesList(context, provider),
              ),

              // Typing indicator
              if (provider.isSending)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TypingIndicator(),
                ),

              // Input field
              ChatInputField(
                focusNode: _inputFocusNode,
                onSend: _handleSendMessage,
                isEnabled: !provider.isSending,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Ask me anything about MOYD!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'I can help you find information about members, chapters, campaigns, events, legislation, and more.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SuggestionChips(
              suggestions: const [
                'How many members do we have?',
                'List active chapters',
                'Show recent email campaign stats',
                'What bills are we tracking?',
                'Who are our top donors?',
                'Upcoming events this month',
              ],
              onTap: _handleSendMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, AIAssistantProvider provider) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final message = provider.messages[index];
        final isLast = index == provider.messages.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
          child: ChatMessageBubble(
            message: message,
            showSources: message.role == 'assistant' &&
                         message.sourceDocuments.isNotEmpty,
          ),
        );
      },
    );
  }

  void _showChatHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _ChatHistorySheet(scrollController: scrollController);
        },
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    final provider = context.read<AIAssistantProvider>();

    switch (action) {
      case 'stats':
        _showStatsDialog(context);
        break;
      case 'admin':
        Navigator.pushNamed(context, '/ai-assistant/admin');
        break;
      case 'archive':
        if (provider.hasCurrentSession) {
          _showArchiveConfirmation(context);
        }
        break;
    }
  }

  void _showStatsDialog(BuildContext context) async {
    final provider = context.read<AIAssistantProvider>();
    await provider.loadStats();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return Consumer<AIAssistantProvider>(
          builder: (context, provider, _) {
            final stats = provider.stats;

            return AlertDialog(
              title: const Text('Knowledge Base Stats'),
              content: stats == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatRow('Total Documents', '${stats.totalDocuments}'),
                          _StatRow('Ready', '${stats.completedDocuments}'),
                          _StatRow('Pending', '${stats.pendingEmbeddings}'),
                          _StatRow('Failed', '${stats.failedEmbeddings}'),
                          const Divider(),
                          _StatRow('Queries This Month', '${stats.totalQueries}'),
                          _StatRow('Monthly Cost', '\$${stats.monthlyUsageDollars.toStringAsFixed(2)}'),
                          const Divider(),
                          const Text('Documents by Table:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...stats.documentsByTable.entries.map(
                            (e) => _StatRow(e.key, '${e.value}'),
                          ),
                        ],
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showArchiveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Chat?'),
        content: const Text('This chat will be moved to your archive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AIAssistantProvider>().archiveCurrentSession();
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ChatHistorySheet extends StatelessWidget {
  final ScrollController scrollController;

  const _ChatHistorySheet({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chat History',
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Sessions list
        Expanded(
          child: Consumer<AIAssistantProvider>(
            builder: (context, provider, _) {
              if (provider.sessions.isEmpty) {
                return const Center(
                  child: Text('No chat history yet'),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: provider.sessions.length,
                itemBuilder: (context, index) {
                  final session = provider.sessions[index];
                  final isSelected = session.id == provider.currentSession?.id;

                  return ListTile(
                    leading: Icon(
                      Icons.chat_bubble_outline,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                    title: Text(
                      session.title ?? 'New Chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isSelected
                          ? TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            )
                          : null,
                    ),
                    subtitle: Text(
                      _formatDate(session.updatedAt),
                      style: theme.textTheme.bodySmall,
                    ),
                    selected: isSelected,
                    onTap: () {
                      provider.selectSession(session.id);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
