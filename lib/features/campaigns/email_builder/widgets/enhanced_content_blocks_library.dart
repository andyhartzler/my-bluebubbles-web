import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/email_component.dart';
import '../providers/email_builder_provider.dart';

class EnhancedContentBlocksLibrary extends StatefulWidget {
  const EnhancedContentBlocksLibrary({super.key});

  @override
  State<EnhancedContentBlocksLibrary> createState() =>
      _EnhancedContentBlocksLibraryState();
}

class _EnhancedContentBlocksLibraryState
    extends State<EnhancedContentBlocksLibrary> {
  String _selectedCategory = 'Basic';
  String _searchQuery = '';

  final Map<String, List<BlockDefinition>> _blocksByCategory = {
    'Basic': [
      BlockDefinition(
        id: 'text',
        name: 'Text',
        icon: Icons.text_fields,
        description: 'Add a text block with formatting',
        builder: () => EmailComponent.text(
          id: const Uuid().v4(),
          content: 'Enter your text here...',
        ),
      ),
      BlockDefinition(
        id: 'image',
        name: 'Image',
        icon: Icons.image,
        description: 'Add an image',
        builder: () => EmailComponent.image(
          id: const Uuid().v4(),
          url: 'https://via.placeholder.com/600x300',
          alt: 'Image',
        ),
      ),
      BlockDefinition(
        id: 'button',
        name: 'Button',
        icon: Icons.smart_button,
        description: 'Add a call-to-action button',
        builder: () => EmailComponent.button(
          id: const Uuid().v4(),
          text: 'Click Here',
          url: 'https://moyoungdemocrats.org',
        ),
      ),
      BlockDefinition(
        id: 'divider',
        name: 'Divider',
        icon: Icons.horizontal_rule,
        description: 'Add a horizontal line',
        builder: () => EmailComponent.divider(
          id: const Uuid().v4(),
        ),
      ),
      BlockDefinition(
        id: 'spacer',
        name: 'Spacer',
        icon: Icons.space_bar,
        description: 'Add vertical spacing',
        builder: () => EmailComponent.spacer(
          id: const Uuid().v4(),
          height: 40,
        ),
      ),
    ],
    'Layout': [
      BlockDefinition(
        id: 'section-1col',
        name: 'Single Column',
        icon: Icons.view_agenda,
        description: 'Full width section',
        isSection: true,
        columnLayout: [1],
      ),
      BlockDefinition(
        id: 'section-2col',
        name: '2 Columns',
        icon: Icons.view_column,
        description: '50/50 split',
        isSection: true,
        columnLayout: [1, 1],
      ),
      BlockDefinition(
        id: 'section-3col',
        name: '3 Columns',
        icon: Icons.view_week,
        description: '33/33/33 split',
        isSection: true,
        columnLayout: [1, 1, 1],
      ),
      BlockDefinition(
        id: 'section-sidebar-left',
        name: 'Sidebar Left',
        icon: Icons.view_sidebar,
        description: '2/3 + 1/3',
        isSection: true,
        columnLayout: [2, 1],
      ),
      BlockDefinition(
        id: 'section-sidebar-right',
        name: 'Sidebar Right',
        icon: Icons.view_sidebar_outlined,
        description: '1/3 + 2/3',
        isSection: true,
        columnLayout: [1, 2],
      ),
    ],
    'Media': [
      BlockDefinition(
        id: 'social',
        name: 'Social Links',
        icon: Icons.share,
        description: 'Social media buttons',
        builder: () => EmailComponent.social(
          id: const Uuid().v4(),
          links: const [
            SocialLink(
                platform: 'facebook', url: 'https://facebook.com/moyoungdems'),
            SocialLink(
                platform: 'twitter', url: 'https://twitter.com/moyoungdems'),
            SocialLink(
                platform: 'instagram',
                url: 'https://instagram.com/moyoungdems'),
          ],
        ),
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content Blocks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search blocks...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ],
            ),
          ),

          // Category tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: _blocksByCategory.keys.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = category),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Blocks grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: _getFilteredBlocks().length,
              itemBuilder: (context, index) {
                final block = _getFilteredBlocks()[index];
                return _BlockCard(block: block);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<BlockDefinition> _getFilteredBlocks() {
    final blocks = _blocksByCategory[_selectedCategory] ?? [];
    if (_searchQuery.isEmpty) return blocks;

    return blocks.where((block) {
      return block.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          block.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }
}

class _BlockCard extends StatefulWidget {
  final BlockDefinition block;

  const _BlockCard({required this.block});

  @override
  State<_BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends State<_BlockCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.block.isSection) {
      // Section blocks don't support drag (just tap to add)
      return _buildCard(context, isDraggable: false);
    }

    // Regular components support drag and drop
    return Draggable<EmailComponent>(
      data: widget.block.builder!(),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.block.icon, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(
                widget.block.name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildCard(context, isDraggable: true),
      ),
      child: _buildCard(context, isDraggable: true),
    );
  }

  Widget _buildCard(BuildContext context, {required bool isDraggable}) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        elevation: _isHovered ? 4 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        child: InkWell(
          onTap: () {
            final provider = context.read<EmailBuilderProvider>();
            if (widget.block.isSection) {
              // Add section with layout
              provider.addSectionWithLayout(widget.block.columnLayout!);
            } else if (widget.block.builder != null) {
              // Add component to first column of last section (or create section if none)
              if (provider.document.sections.isEmpty) {
                provider.addSection();
              }
              final lastSection = provider.document.sections.last;
              final firstColumn = lastSection.columns.first;
              provider.addComponent(
                  lastSection.id, firstColumn.id, widget.block.builder!());
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.block.name} added'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.block.icon,
                    size: 36, color: Theme.of(context).primaryColor),
                const SizedBox(height: 8),
                Text(
                  widget.block.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BlockDefinition {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final EmailComponent Function()? builder;
  final bool isSection;
  final List<int>? columnLayout;

  BlockDefinition({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.builder,
    this.isSection = false,
    this.columnLayout,
  });
}
