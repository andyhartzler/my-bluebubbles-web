import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:bluebubbles/features/committees/models/committee.dart';
import 'package:bluebubbles/features/committees/services/committee_repository.dart';
import 'package:bluebubbles/features/canvas_board/models/canvas_board.dart';
import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/models/canvas_connection.dart';
import 'package:bluebubbles/features/canvas_board/services/canvas_board_service.dart';
import 'package:bluebubbles/features/canvas_board/services/canvas_file_service.dart';
import 'package:bluebubbles/features/canvas_board/widgets/canvas_toolbar.dart';
import 'package:bluebubbles/features/canvas_board/widgets/canvas_sidebar.dart';
import 'package:bluebubbles/features/canvas_board/widgets/entity_picker_dialog.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/member_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/event_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/chapter_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/donor_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/note_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/image_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/file_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/shape_canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/text_canvas_node.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/event.dart' show Event;
import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/services/crm/event_repository.dart';

/// The main canvas tab for committee workspaces
class CommitteeCanvasTab extends StatefulWidget {
  final Committee committee;
  final bool isFullscreen;
  final ValueChanged<bool>? onFullscreenChanged;

  const CommitteeCanvasTab({
    super.key,
    required this.committee,
    this.isFullscreen = false,
    this.onFullscreenChanged,
  });

  @override
  State<CommitteeCanvasTab> createState() => _CommitteeCanvasTabState();
}

class _CommitteeCanvasTabState extends State<CommitteeCanvasTab> with SingleTickerProviderStateMixin {
  final _canvasBoardService = CanvasBoardService();
  final _canvasFileService = CanvasFileService();
  final _committeeRepository = CommitteeRepository();
  final _eventRepository = EventRepository();
  final _uuid = const Uuid();

  // Board state
  CanvasBoard? _board;
  List<CanvasNode> _nodes = [];
  List<CanvasConnection> _connections = [];
  bool _loading = true;
  String? _error;

  // Canvas interaction state
  CanvasTool _selectedTool = CanvasTool.select;
  String? _selectedNodeId;
  Set<String> _selectedNodeIds = {};
  Offset _viewportOffset = Offset.zero;
  double _zoomLevel = 1.0;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 2.0;

  // Entity cache
  final Map<String, Member> _memberCache = {};
  final Map<String, Event> _eventCache = {};
  final Map<String, Chapter> _chapterCache = {};
  final Map<String, Donor> _donorCache = {};

  // Edit state
  String? _editingNodeId;
  final _noteTextController = TextEditingController();
  final FocusNode _canvasFocusNode = FocusNode();

  // Undo/Redo
  final List<_CanvasAction> _undoStack = [];
  final List<_CanvasAction> _redoStack = [];

  // Debounced save
  Timer? _saveTimer;
  bool _hasUnsavedChanges = false;

  // Save indicator animation
  late AnimationController _saveIndicatorController;
  late Animation<double> _saveIndicatorOpacity;
  bool _showSaveIndicator = false;
  String _saveStatus = 'Saved';

  // Drag state
  Offset? _dragStartOffset;
  Offset? _nodeDragStart;

  // Drawing state for shapes/lines
  Offset? _drawStartPoint;
  List<Offset> _currentDrawingPoints = [];
  bool _isDrawing = false;

  Committee get committee => widget.committee;
  bool get _isFullscreen => widget.isFullscreen;

  void _toggleFullscreen(bool value) {
    if (widget.onFullscreenChanged != null) {
      widget.onFullscreenChanged!(value);
    }
  }

  @override
  void initState() {
    super.initState();
    _saveIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _saveIndicatorOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _saveIndicatorController, curve: Curves.easeInOut),
    );
    _loadBoard();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _noteTextController.dispose();
    _canvasFocusNode.dispose();
    _saveIndicatorController.dispose();
    super.dispose();
  }

  Future<void> _loadBoard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Get or create board for this committee
      final board = await _canvasBoardService.getOrCreateBoard(committee.id);

      // Load nodes and connections
      final nodes = await _canvasBoardService.getNodes(board.id);
      final connections = await _canvasBoardService.getConnections(board.id);

      // Load viewport state
      final viewportOffset = Offset(board.viewportX, board.viewportY);
      final zoomLevel = board.zoomLevel;

      if (!mounted) return;

      setState(() {
        _board = board;
        _nodes = nodes;
        _connections = connections;
        _viewportOffset = viewportOffset;
        _zoomLevel = zoomLevel;
        _loading = false;
      });

      // Pre-fetch entity data for existing nodes
      _prefetchEntityData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load canvas: $e';
        _loading = false;
      });
    }
  }

  Future<void> _prefetchEntityData() async {
    for (final node in _nodes) {
      if (node.entityId != null) {
        switch (node.nodeType) {
          case CanvasNodeType.member:
            _fetchMember(node.entityId!);
            break;
          case CanvasNodeType.event:
            _fetchEvent(node.entityId!);
            break;
          case CanvasNodeType.chapter:
            _fetchChapter(node.entityId!);
            break;
          case CanvasNodeType.donor:
            _fetchDonor(node.entityId!);
            break;
          default:
            break;
        }
      }
    }
  }

  Future<void> _fetchMember(String memberId) async {
    if (_memberCache.containsKey(memberId)) return;
    try {
      final member = await _committeeRepository.getMemberById(memberId);
      if (member != null && mounted) {
        setState(() => _memberCache[memberId] = member);
      }
    } catch (e) {
      // Silently fail - will show error state in node
    }
  }

  Future<void> _fetchEvent(String eventId) async {
    if (_eventCache.containsKey(eventId)) return;
    try {
      // Fetch event by ID - we fetch all and filter since there's no getById method
      final events = await _eventRepository.fetchEvents();
      final event = events.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw Exception('Event not found'),
      );
      if (mounted) {
        setState(() => _eventCache[eventId] = event);
      }
    } catch (e) {
      // Silently fail - will show error state in node
    }
  }

  Future<void> _fetchChapter(String chapterId) async {
    if (_chapterCache.containsKey(chapterId)) return;
    // TODO: Implement chapter fetching when ChapterRepository is available
  }

  Future<void> _fetchDonor(String donorId) async {
    if (_donorCache.containsKey(donorId)) return;
    // TODO: Implement donor fetching when DonorRepository is available
  }

  void _scheduleSave() {
    _hasUnsavedChanges = true;
    _saveTimer?.cancel();

    // Show saving indicator
    setState(() {
      _showSaveIndicator = true;
      _saveStatus = 'Saving...';
    });
    _saveIndicatorController.forward();

    _saveTimer = Timer(const Duration(milliseconds: 800), _saveBoard);
  }

  Future<void> _saveBoard() async {
    if (_board == null || !_hasUnsavedChanges) return;

    try {
      await _canvasBoardService.saveViewport(
        _board!.id,
        viewportX: _viewportOffset.dx,
        viewportY: _viewportOffset.dy,
        zoomLevel: _zoomLevel,
      );
      _hasUnsavedChanges = false;

      if (mounted) {
        setState(() {
          _saveStatus = 'Saved';
        });

        // Fade out after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_hasUnsavedChanges) {
            _saveIndicatorController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showSaveIndicator = false;
                });
              }
            });
          }
        });
      }
    } catch (e) {
      // Show error toast
      if (mounted) {
        setState(() {
          _saveStatus = 'Failed to save';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============ Node Operations ============

  Future<void> _addNode(CanvasNode node) async {
    if (_board == null) return;

    try {
      final zIndex = await _canvasBoardService.getNextZIndex(_board!.id);
      final newNode = node.copyWith(
        id: _uuid.v4(),
        boardId: _board!.id,
        zIndex: zIndex,
      );

      final createdNode = await _canvasBoardService.createNode(newNode);

      setState(() {
        _nodes.add(createdNode);
        _selectedNodeId = createdNode.id;
        _selectedNodeIds = {createdNode.id};
      });

      _undoStack.add(_CanvasAction.addNode(createdNode));
      _redoStack.clear();
    } catch (e) {
      _showError('Failed to add node: $e');
    }
  }

  Future<void> _updateNode(CanvasNode node) async {
    try {
      await _canvasBoardService.updateNode(node);

      setState(() {
        final index = _nodes.indexWhere((n) => n.id == node.id);
        if (index >= 0) {
          _nodes[index] = node;
        }
      });
    } catch (e) {
      _showError('Failed to update node: $e');
    }
  }

  Future<void> _deleteSelectedNodes() async {
    if (_selectedNodeIds.isEmpty) return;

    final nodesToDelete = _nodes.where((n) => _selectedNodeIds.contains(n.id)).toList();

    try {
      await _canvasBoardService.deleteNodes(_selectedNodeIds.toList());

      // Also delete associated files/images
      for (final node in nodesToDelete) {
        if (node.imageUrl != null) {
          await _canvasFileService.deleteImage(node.imageUrl!);
        }
        if (node.fileUrl != null) {
          await _canvasFileService.deleteFile(node.fileUrl!);
        }
      }

      setState(() {
        _nodes.removeWhere((n) => _selectedNodeIds.contains(n.id));
        _connections.removeWhere(
          (c) => _selectedNodeIds.contains(c.fromNodeId) ||
              _selectedNodeIds.contains(c.toNodeId),
        );
        _selectedNodeIds.clear();
        _selectedNodeId = null;
      });

      _undoStack.add(_CanvasAction.deleteNodes(nodesToDelete));
      _redoStack.clear();
    } catch (e) {
      _showError('Failed to delete: $e');
    }
  }

  // ============ Entity Addition ============

  Future<void> _addMemberNode() async {
    final member = await EntityPickerDialog.showMemberPicker(
      context,
      searchFunction: (query) => _committeeRepository.searchMembers(query),
    );

    if (member != null && mounted) {
      _memberCache[member.id] = member;

      await _addNode(CanvasNode(
        id: '',
        boardId: _board?.id ?? '',
        offsetX: _getViewportCenter().dx,
        offsetY: _getViewportCenter().dy,
        width: 240,
        height: 100,
        nodeType: CanvasNodeType.member,
        entityId: member.id,
      ));
    }
  }

  Future<void> _addEventNode() async {
    final event = await EntityPickerDialog.showEventPicker(
      context,
      searchFunction: (query) => _eventRepository.fetchEvents(searchQuery: query),
    );

    if (event != null && event.id != null && mounted) {
      _eventCache[event.id!] = event;

      await _addNode(CanvasNode(
        id: '',
        boardId: _board?.id ?? '',
        offsetX: _getViewportCenter().dx,
        offsetY: _getViewportCenter().dy,
        width: 280,
        height: 120,
        nodeType: CanvasNodeType.event,
        entityId: event.id,
      ));
    }
  }

  Future<void> _addChapterNode() async {
    // TODO: Implement chapter picker when chapter search is available
    _showError('Chapter picker not yet implemented');
  }

  Future<void> _addDonorNode() async {
    // TODO: Implement donor picker when donor search is available
    _showError('Donor picker not yet implemented');
  }

  Future<void> _addNoteNode() async {
    await _addNode(CanvasNode(
      id: '',
      boardId: _board?.id ?? '',
      offsetX: _getViewportCenter().dx,
      offsetY: _getViewportCenter().dy,
      width: 200,
      height: 150,
      nodeType: CanvasNodeType.note,
      noteColor: '#FFF59D',
      noteContent: '',
    ));
  }

  Future<void> _addImageNode() async {
    if (_board == null) return;

    try {
      final result = await _canvasFileService.uploadImageFromGallery(_board!.id);
      if (result == null) return;

      await _addNode(CanvasNode(
        id: '',
        boardId: _board!.id,
        offsetX: _getViewportCenter().dx,
        offsetY: _getViewportCenter().dy,
        width: 250,
        height: 200,
        nodeType: CanvasNodeType.image,
        imageUrl: result.imageUrl,
        imageThumbnailUrl: result.thumbnailUrl,
        fileName: result.fileName,
        fileSize: result.fileSize,
      ));
    } catch (e) {
      _showError('Failed to upload image: $e');
    }
  }

  Future<void> _addFileNode() async {
    if (_board == null) return;

    try {
      final result = await _canvasFileService.pickAndUploadFile(_board!.id);
      if (result == null) return;

      await _addNode(CanvasNode(
        id: '',
        boardId: _board!.id,
        offsetX: _getViewportCenter().dx,
        offsetY: _getViewportCenter().dy,
        width: 200,
        height: 140,
        nodeType: CanvasNodeType.file,
        fileUrl: result.fileUrl,
        fileName: result.fileName,
        fileType: result.mimeType,
        fileSize: result.fileSize,
      ));
    } catch (e) {
      _showError('Failed to upload file: $e');
    }
  }

  // ============ View Operations ============

  Offset _getViewportCenter() {
    final size = MediaQuery.of(context).size;
    return Offset(
      (-_viewportOffset.dx + size.width / 2) / _zoomLevel,
      (-_viewportOffset.dy + size.height / 2) / _zoomLevel,
    );
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel * 1.2).clamp(0.1, 5.0);
    });
    _scheduleSave();
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel / 1.2).clamp(0.1, 5.0);
    });
    _scheduleSave();
  }

  void _fitView() {
    if (_nodes.isEmpty) {
      _resetView();
      return;
    }

    // Calculate bounds of all nodes
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in _nodes) {
      minX = math.min(minX, node.offsetX);
      minY = math.min(minY, node.offsetY);
      maxX = math.max(maxX, node.offsetX + node.width);
      maxY = math.max(maxY, node.offsetY + node.height);
    }

    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;

    final size = MediaQuery.of(context).size;
    final availableWidth = size.width - 180; // Subtract sidebar width
    final availableHeight = size.height - 100; // Subtract toolbar height

    final scaleX = availableWidth / (contentWidth + 100);
    final scaleY = availableHeight / (contentHeight + 100);
    final scale = math.min(scaleX, scaleY).clamp(0.1, 2.0);

    setState(() {
      _zoomLevel = scale;
      _viewportOffset = Offset(
        -(minX - 50) * scale + (availableWidth - contentWidth * scale) / 2,
        -(minY - 50) * scale + (availableHeight - contentHeight * scale) / 2,
      );
    });
    _scheduleSave();
  }

  void _resetView() {
    setState(() {
      _zoomLevel = 1.0;
      _viewportOffset = Offset.zero;
    });
    _scheduleSave();
  }

  // ============ Undo/Redo ============

  void _undo() {
    if (_undoStack.isEmpty) return;
    final action = _undoStack.removeLast();
    _redoStack.add(action);
    // TODO: Implement undo logic for each action type
    setState(() {});
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final action = _redoStack.removeLast();
    _undoStack.add(action);
    // TODO: Implement redo logic for each action type
    setState(() {});
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ============ Build Methods ============

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadBoard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Focus(
      focusNode: _canvasFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          Column(
            children: [
              // Toolbar - always visible (including fullscreen)
              CanvasToolbar(
                selectedTool: _selectedTool,
                onToolSelected: (tool) => setState(() => _selectedTool = tool),
                selectedColor: _selectedColor,
                onColorSelected: (color) => setState(() => _selectedColor = color),
                strokeWidth: _strokeWidth,
                onStrokeWidthChanged: (width) =>
                    setState(() => _strokeWidth = width),
                onUndo: _undo,
                onRedo: _redo,
                onDelete: _deleteSelectedNodes,
                canUndo: _undoStack.isNotEmpty,
                canRedo: _redoStack.isNotEmpty,
                hasSelection: _selectedNodeIds.isNotEmpty,
              ),
              // Main content
              Expanded(
                child: Row(
                  children: [
                    // Sidebar - always visible (including fullscreen)
                    CanvasSidebar(
                      onAddMember: _addMemberNode,
                      onAddEvent: _addEventNode,
                      onAddChapter: _addChapterNode,
                      onAddDonor: _addDonorNode,
                      onAddNote: _addNoteNode,
                      onAddImage: _addImageNode,
                      onAddFile: _addFileNode,
                      onZoomIn: _zoomIn,
                      onZoomOut: _zoomOut,
                      onFitView: _fitView,
                      onResetView: _resetView,
                      onToggleFullscreen: () => _toggleFullscreen(!_isFullscreen),
                      zoomLevel: _zoomLevel,
                      showDonors: committee.hasDonorsTab,
                      showChapters: committee.hasChaptersTab,
                      isFullscreen: _isFullscreen,
                    ),
                    // Canvas
                    Expanded(
                      child: _buildCanvas(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Floating save indicator
          if (_showSaveIndicator)
            Positioned(
              bottom: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _saveIndicatorOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _saveIndicatorOpacity.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_saveStatus == 'Saving...')
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          else if (_saveStatus == 'Saved')
                            const Icon(Icons.check, size: 14, color: Colors.green)
                          else
                            const Icon(Icons.error_outline, size: 14, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            _saveStatus,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      // Handle pinch to zoom on trackpad
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onTapDown: _onCanvasTap,
      onDoubleTap: _onCanvasDoubleTap,
      child: Container(
        color: Colors.grey[100],
        child: ClipRect(
          child: CustomPaint(
            painter: _GridPainter(
              offset: _viewportOffset,
              zoom: _zoomLevel,
            ),
            foregroundPainter: _isDrawing ? _DrawingPainter(
              tool: _selectedTool,
              points: _currentDrawingPoints,
              startPoint: _drawStartPoint,
              color: _selectedColor,
              strokeWidth: _strokeWidth,
              zoom: _zoomLevel,
              offset: _viewportOffset,
            ) : null,
            child: Stack(
              children: [
                // Nodes
                ..._nodes.map((node) => _buildPositionedNode(node)),
                // Connections (draw on top for visibility)
                ..._buildConnections(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _baseZoom = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _scaleStartFocalPoint = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _zoomLevel;
    _baseOffset = _viewportOffset;
    _scaleStartFocalPoint = details.focalPoint;

    // Check if we're starting a drawing operation
    if (_isDrawingTool(_selectedTool)) {
      _isDrawing = true;
      final canvasPoint = _screenToCanvas(details.focalPoint);
      _drawStartPoint = canvasPoint;
      _currentDrawingPoints = [canvasPoint];
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isDrawing && _isDrawingTool(_selectedTool)) {
      // Continue drawing
      final canvasPoint = _screenToCanvas(details.focalPoint);
      setState(() {
        if (_selectedTool == CanvasTool.draw) {
          _currentDrawingPoints.add(canvasPoint);
        } else {
          // For shapes, just update the end point
          if (_currentDrawingPoints.length == 1) {
            _currentDrawingPoints.add(canvasPoint);
          } else {
            _currentDrawingPoints[1] = canvasPoint;
          }
        }
      });
      return;
    }

    // Pinch to zoom
    if (details.scale != 1.0) {
      final newZoom = (_baseZoom * details.scale).clamp(0.1, 5.0);

      // Calculate new offset to keep focal point stationary
      final focalOffset = details.focalPoint - _scaleStartFocalPoint;
      final scaleFactor = newZoom / _baseZoom;

      setState(() {
        _zoomLevel = newZoom;
        _viewportOffset = Offset(
          _baseOffset.dx + focalOffset.dx + (_scaleStartFocalPoint.dx - _baseOffset.dx) * (1 - scaleFactor),
          _baseOffset.dy + focalOffset.dy + (_scaleStartFocalPoint.dy - _baseOffset.dy) * (1 - scaleFactor),
        );
      });
    } else {
      // Pan (single finger drag)
      if (_selectedTool == CanvasTool.pan ||
          (_selectedTool == CanvasTool.select && _selectedNodeIds.isEmpty)) {
        setState(() {
          _viewportOffset = _baseOffset + (details.focalPoint - _scaleStartFocalPoint);
        });
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isDrawing && _isDrawingTool(_selectedTool)) {
      _finishDrawing();
    }
    _scheduleSave();
  }

  bool _isDrawingTool(CanvasTool tool) {
    return tool == CanvasTool.draw ||
           tool == CanvasTool.arrow ||
           tool == CanvasTool.line ||
           tool == CanvasTool.rectangle ||
           tool == CanvasTool.circle ||
           tool == CanvasTool.text;
  }

  Offset _screenToCanvas(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - _viewportOffset.dx) / _zoomLevel,
      (screenPoint.dy - _viewportOffset.dy) / _zoomLevel,
    );
  }

  Future<void> _finishDrawing() async {
    if (!_isDrawing || _drawStartPoint == null) return;

    final startPoint = _drawStartPoint!;
    final endPoint = _currentDrawingPoints.length > 1
        ? _currentDrawingPoints.last
        : startPoint;

    setState(() {
      _isDrawing = false;
    });

    // Create the appropriate node based on tool
    switch (_selectedTool) {
      case CanvasTool.draw:
        if (_currentDrawingPoints.length > 2) {
          await _addFreehandNode(_currentDrawingPoints);
        }
        break;
      case CanvasTool.arrow:
      case CanvasTool.line:
        if ((endPoint - startPoint).distance > 10) {
          await _addConnectionLine(startPoint, endPoint, _selectedTool == CanvasTool.arrow);
        }
        break;
      case CanvasTool.rectangle:
        if ((endPoint - startPoint).distance > 10) {
          await _addShapeNode(startPoint, endPoint, 'rectangle');
        }
        break;
      case CanvasTool.circle:
        if ((endPoint - startPoint).distance > 10) {
          await _addShapeNode(startPoint, endPoint, 'circle');
        }
        break;
      case CanvasTool.text:
        await _addTextNodeAt(startPoint);
        break;
      default:
        break;
    }

    _currentDrawingPoints = [];
    _drawStartPoint = null;
  }

  Future<void> _addFreehandNode(List<Offset> points) async {
    if (_board == null || points.isEmpty) return;

    // Convert points to path string
    final pathPoints = points.map((p) => '${p.dx},${p.dy}').join(';');

    // Calculate bounds
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }

    await _addNode(CanvasNode(
      id: '',
      boardId: _board!.id,
      offsetX: minX,
      offsetY: minY,
      width: maxX - minX + _strokeWidth * 2,
      height: maxY - minY + _strokeWidth * 2,
      nodeType: CanvasNodeType.shape, // Use 'shape' type (DB doesn't allow 'freehand')
      shapeType: 'line', // Store as line type with path data for freehand
      shapeColor: '#${_selectedColor.value.toRadixString(16).substring(2)}',
      strokeWidth: _strokeWidth,
      pathData: pathPoints,
      metadata: {'is_freehand': true}, // Mark as freehand in metadata
    ));
  }

  Future<void> _addConnectionLine(Offset start, Offset end, bool isArrow) async {
    if (_board == null) return;

    // For lines/arrows, we create a shape node
    final minX = math.min(start.dx, end.dx);
    final minY = math.min(start.dy, end.dy);
    final width = (end.dx - start.dx).abs() + _strokeWidth * 2;
    final height = (end.dy - start.dy).abs() + _strokeWidth * 2;

    // Store relative start/end points
    final relStart = Offset(start.dx - minX + _strokeWidth, start.dy - minY + _strokeWidth);
    final relEnd = Offset(end.dx - minX + _strokeWidth, end.dy - minY + _strokeWidth);

    await _addNode(CanvasNode(
      id: '',
      boardId: _board!.id,
      offsetX: minX - _strokeWidth,
      offsetY: minY - _strokeWidth,
      width: width,
      height: height,
      nodeType: CanvasNodeType.shape,
      shapeType: 'line', // Use 'line' for both line and arrow (DB constraint)
      shapeColor: '#${_selectedColor.value.toRadixString(16).substring(2)}',
      strokeWidth: _strokeWidth,
      pathData: '${relStart.dx},${relStart.dy};${relEnd.dx},${relEnd.dy}',
      metadata: isArrow ? {'has_arrow': true} : null, // Store arrow flag in metadata
    ));
  }

  Future<void> _addShapeNode(Offset start, Offset end, String shapeType) async {
    if (_board == null) return;

    final minX = math.min(start.dx, end.dx);
    final minY = math.min(start.dy, end.dy);
    final width = (end.dx - start.dx).abs();
    final height = (end.dy - start.dy).abs();

    await _addNode(CanvasNode(
      id: '',
      boardId: _board!.id,
      offsetX: minX,
      offsetY: minY,
      width: width,
      height: height,
      nodeType: CanvasNodeType.shape,
      shapeType: shapeType,
      shapeColor: '#${_selectedColor.value.toRadixString(16).substring(2)}',
      strokeWidth: _strokeWidth,
    ));
  }

  Future<void> _addTextNodeAt(Offset position) async {
    await _addNode(CanvasNode(
      id: '',
      boardId: _board?.id ?? '',
      offsetX: position.dx,
      offsetY: position.dy,
      width: 200,
      height: 50,
      nodeType: CanvasNodeType.text,
      textContent: '',
    ));

    // Start editing the new text node after a small delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_nodes.isNotEmpty) {
        final newNode = _nodes.last;
        if (newNode.nodeType == CanvasNodeType.text) {
          _startEditingText(newNode);
        }
      }
    });
  }

  void _onCanvasDoubleTap() {
    // Toggle fullscreen on double tap
    _toggleFullscreen(!_isFullscreen);
  }

  Widget _buildPositionedNode(CanvasNode node) {
    final isSelected = _selectedNodeIds.contains(node.id);
    final isEditing = _editingNodeId == node.id;

    final position = Offset(
      node.offsetX * _zoomLevel + _viewportOffset.dx,
      node.offsetY * _zoomLevel + _viewportOffset.dy,
    );

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Transform.scale(
        scale: _zoomLevel,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onPanStart: (details) => _onNodeDragStart(node, details),
          onPanUpdate: (details) => _onNodeDragUpdate(node, details),
          onPanEnd: (details) => _onNodeDragEnd(node),
          child: _buildNodeWidget(node, isSelected, isEditing),
        ),
      ),
    );
  }

  Widget _buildNodeWidget(CanvasNode node, bool isSelected, bool isEditing) {
    switch (node.nodeType) {
      case CanvasNodeType.member:
        return MemberCanvasNode(
          node: node,
          member: _memberCache[node.entityId],
          isSelected: isSelected,
          isLoading: node.entityId != null && !_memberCache.containsKey(node.entityId),
          onTap: () => _selectNode(node),
          onDoubleTap: () => _openNodeDetail(node),
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.event:
        return EventCanvasNode(
          node: node,
          event: _eventCache[node.entityId],
          isSelected: isSelected,
          isLoading: node.entityId != null && !_eventCache.containsKey(node.entityId),
          onTap: () => _selectNode(node),
          onDoubleTap: () => _openNodeDetail(node),
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.chapter:
        return ChapterCanvasNode(
          node: node,
          chapter: _chapterCache[node.entityId],
          isSelected: isSelected,
          isLoading: node.entityId != null && !_chapterCache.containsKey(node.entityId),
          onTap: () => _selectNode(node),
          onDoubleTap: () => _openNodeDetail(node),
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.donor:
        return DonorCanvasNode(
          node: node,
          donor: _donorCache[node.entityId],
          isSelected: isSelected,
          isLoading: node.entityId != null && !_donorCache.containsKey(node.entityId),
          onTap: () => _selectNode(node),
          onDoubleTap: () => _openNodeDetail(node),
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.note:
        return NoteCanvasNode(
          node: node,
          isSelected: isSelected,
          isEditing: isEditing,
          onTap: () => _selectNode(node),
          onDoubleTap: () => _startEditingNote(node),
          onDelete: () => _deleteSelectedNodes(),
          textController: isEditing ? _noteTextController : null,
          onContentChanged: (content) => _updateNoteContent(node, content),
        );
      case CanvasNodeType.text:
        return TextCanvasNode(
          node: node,
          isSelected: isSelected,
          isEditing: isEditing,
          onTap: () => _selectNode(node),
          onDoubleTap: () => _startEditingText(node),
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.image:
        return ImageCanvasNode(
          node: node,
          isSelected: isSelected,
          onTap: () => _selectNode(node),
          onDoubleTap: () => _openImageViewer(node),
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.file:
        return FileCanvasNode(
          node: node,
          isSelected: isSelected,
          onTap: () => _selectNode(node),
          onDoubleTap: () => _downloadFile(node),
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.shape:
        return ShapeCanvasNode(
          node: node,
          isSelected: isSelected,
          onTap: () => _selectNode(node),
          onDoubleTap: () {},
          onDelete: () => _deleteSelectedNodes(),
        );
      case CanvasNodeType.freehand:
        // TODO: Implement freehand drawing node
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _buildConnections() {
    return _connections.map((connection) {
      final fromNode = _nodes.firstWhere(
        (n) => n.id == connection.fromNodeId,
        orElse: () => _nodes.first,
      );
      final toNode = _nodes.firstWhere(
        (n) => n.id == connection.toNodeId,
        orElse: () => _nodes.first,
      );

      final fromCenter = Offset(
        (fromNode.offsetX + fromNode.width / 2) * _zoomLevel + _viewportOffset.dx,
        (fromNode.offsetY + fromNode.height / 2) * _zoomLevel + _viewportOffset.dy,
      );
      final toCenter = Offset(
        (toNode.offsetX + toNode.width / 2) * _zoomLevel + _viewportOffset.dx,
        (toNode.offsetY + toNode.height / 2) * _zoomLevel + _viewportOffset.dy,
      );

      return CustomPaint(
        painter: _ConnectionPainter(
          from: fromCenter,
          to: toCenter,
          type: connection.connectionType,
          color: _parseColor(connection.color),
          strokeWidth: connection.strokeWidth * _zoomLevel,
        ),
      );
    }).toList();
  }

  // ============ Interaction Handlers ============

  void _selectNode(CanvasNode node) {
    setState(() {
      if (HardwareKeyboard.instance.isControlPressed) {
        // Toggle selection with Ctrl
        if (_selectedNodeIds.contains(node.id)) {
          _selectedNodeIds.remove(node.id);
        } else {
          _selectedNodeIds.add(node.id);
        }
      } else {
        _selectedNodeIds = {node.id};
      }
      _selectedNodeId = _selectedNodeIds.isNotEmpty ? node.id : null;

      // Clear editing state
      if (_editingNodeId != null && _editingNodeId != node.id) {
        _saveEditingNode();
        _editingNodeId = null;
      }
    });
  }

  void _onCanvasTap(TapDownDetails details) {
    // Request focus for the canvas to receive keyboard events
    _canvasFocusNode.requestFocus();

    setState(() {
      _selectedNodeIds.clear();
      _selectedNodeId = null;
      if (_editingNodeId != null) {
        _saveEditingNode();
        _editingNodeId = null;
      }
    });
  }

  void _onNodeDragStart(CanvasNode node, DragStartDetails details) {
    if (!_selectedNodeIds.contains(node.id)) {
      _selectNode(node);
    }
    _nodeDragStart = Offset(node.offsetX, node.offsetY);
  }

  void _onNodeDragUpdate(CanvasNode node, DragUpdateDetails details) {
    final delta = details.delta / _zoomLevel;

    setState(() {
      for (final nodeId in _selectedNodeIds) {
        final index = _nodes.indexWhere((n) => n.id == nodeId);
        if (index >= 0) {
          final n = _nodes[index];
          _nodes[index] = n.copyWith(
            offsetX: n.offsetX + delta.dx,
            offsetY: n.offsetY + delta.dy,
          );
        }
      }
    });
  }

  void _onNodeDragEnd(CanvasNode node) {
    // Save all moved nodes
    for (final nodeId in _selectedNodeIds) {
      final movedNode = _nodes.firstWhere((n) => n.id == nodeId);
      _canvasBoardService.updateNodePosition(
        movedNode.id,
        movedNode.offsetX,
        movedNode.offsetY,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Don't intercept keyboard shortcuts when editing text
    if (_editingNodeId != null) {
      // Only handle Escape to exit editing
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() {
          _saveEditingNode();
          _editingNodeId = null;
        });
        return KeyEventResult.handled;
      }
      // Let all other keys pass through to the text field
      return KeyEventResult.ignored;
    }

    // Delete key
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_selectedNodeIds.isNotEmpty) {
        _deleteSelectedNodes();
        return KeyEventResult.handled;
      }
    }

    // Ctrl+Z - Undo
    if (HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _redo();
      } else {
        _undo();
      }
      return KeyEventResult.handled;
    }

    // Escape - Deselect or exit fullscreen
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _toggleFullscreen(false);
      } else {
        setState(() {
          _selectedNodeIds.clear();
          _selectedNodeId = null;
        });
      }
      return KeyEventResult.handled;
    }

    // F key - Toggle fullscreen
    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      _toggleFullscreen(!_isFullscreen);
      return KeyEventResult.handled;
    }

    // Tool shortcuts (only when not editing)
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      setState(() => _selectedTool = CanvasTool.select);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyH) {
      setState(() => _selectedTool = CanvasTool.pan);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyD) {
      setState(() => _selectedTool = CanvasTool.draw);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyA) {
      setState(() => _selectedTool = CanvasTool.arrow);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyL) {
      setState(() => _selectedTool = CanvasTool.line);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyR) {
      setState(() => _selectedTool = CanvasTool.rectangle);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyO) {
      setState(() => _selectedTool = CanvasTool.circle);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyT) {
      setState(() => _selectedTool = CanvasTool.text);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyN) {
      _addNoteNode();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ============ Edit Operations ============

  void _startEditingNote(CanvasNode node) {
    setState(() {
      _editingNodeId = node.id;
      _noteTextController.text = node.noteContent ?? '';
    });
  }

  void _startEditingText(CanvasNode node) {
    setState(() {
      _editingNodeId = node.id;
      _noteTextController.text = node.textContent ?? '';
    });
  }

  void _updateNoteContent(CanvasNode node, String content) {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index >= 0) {
      _nodes[index] = node.copyWith(noteContent: content);
    }
  }

  void _saveEditingNode() {
    if (_editingNodeId == null) return;

    final node = _nodes.firstWhere(
      (n) => n.id == _editingNodeId,
      orElse: () => _nodes.first,
    );

    if (node.nodeType == CanvasNodeType.note) {
      _updateNode(node.copyWith(noteContent: _noteTextController.text));
    } else if (node.nodeType == CanvasNodeType.text) {
      _updateNode(node.copyWith(textContent: _noteTextController.text));
    }
  }

  void _openNodeDetail(CanvasNode node) {
    // TODO: Navigate to entity detail screen based on node type
  }

  void _openImageViewer(CanvasNode node) {
    // TODO: Open full screen image viewer
  }

  void _downloadFile(CanvasNode node) {
    // TODO: Download file
  }

  Color _parseColor(String colorString) {
    try {
      final hex = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

/// Action for undo/redo stack
class _CanvasAction {
  final String type;
  final dynamic data;

  const _CanvasAction(this.type, this.data);

  factory _CanvasAction.addNode(CanvasNode node) =>
      _CanvasAction('add_node', node);

  factory _CanvasAction.deleteNodes(List<CanvasNode> nodes) =>
      _CanvasAction('delete_nodes', nodes);

  factory _CanvasAction.moveNodes(Map<String, Offset> positions) =>
      _CanvasAction('move_nodes', positions);
}

/// Painter for the canvas grid background
class _GridPainter extends CustomPainter {
  final Offset offset;
  final double zoom;

  _GridPainter({required this.offset, required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    final gridSize = 50.0 * zoom;

    // Calculate starting points
    final startX = offset.dx % gridSize;
    final startY = offset.dy % gridSize;

    // Draw vertical lines
    for (double x = startX; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = startY; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.zoom != zoom;
  }
}

/// Painter for connections between nodes
class _ConnectionPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final CanvasConnectionType type;
  final Color color;
  final double strokeWidth;

  _ConnectionPainter({
    required this.from,
    required this.to,
    required this.type,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    if (type == CanvasConnectionType.dashed) {
      // Draw dashed line
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);

      const dashWidth = 8.0;
      const dashSpace = 4.0;
      double distance = 0.0;
      final pathMetrics = path.computeMetrics().first;
      final totalLength = pathMetrics.length;

      while (distance < totalLength) {
        final start = distance;
        final end = (distance + dashWidth).clamp(0.0, totalLength);
        final extractedPath = pathMetrics.extractPath(start, end);
        canvas.drawPath(extractedPath, paint);
        distance += dashWidth + dashSpace;
      }
    } else {
      // Draw solid line
      canvas.drawLine(from, to, paint);
    }

    // Draw arrow head for arrow type
    if (type == CanvasConnectionType.arrow) {
      _drawArrowHead(canvas, from, to, paint);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const arrowSize = 12.0;
    final angle = (to - from).direction;

    final point1 = Offset(
      to.dx - arrowSize * math.cos(angle - math.pi / 6),
      to.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    final point2 = Offset(
      to.dx - arrowSize * math.cos(angle + math.pi / 6),
      to.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    final arrowPath = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(point1.dx, point1.dy)
      ..lineTo(point2.dx, point2.dy)
      ..close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.type != type ||
        oldDelegate.color != color;
  }
}

/// Painter for live drawing preview
class _DrawingPainter extends CustomPainter {
  final CanvasTool tool;
  final List<Offset> points;
  final Offset? startPoint;
  final Color color;
  final double strokeWidth;
  final double zoom;
  final Offset offset;

  _DrawingPainter({
    required this.tool,
    required this.points,
    this.startPoint,
    required this.color,
    required this.strokeWidth,
    required this.zoom,
    required this.offset,
  });

  Offset _canvasToScreen(Offset canvasPoint) {
    return Offset(
      canvasPoint.dx * zoom + offset.dx,
      canvasPoint.dy * zoom + offset.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth * zoom
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (tool) {
      case CanvasTool.draw:
        _drawFreehand(canvas, paint);
        break;
      case CanvasTool.line:
        _drawLine(canvas, paint);
        break;
      case CanvasTool.arrow:
        _drawArrow(canvas, paint);
        break;
      case CanvasTool.rectangle:
        _drawRectangle(canvas, paint);
        break;
      case CanvasTool.circle:
        _drawEllipse(canvas, paint);
        break;
      default:
        break;
    }
  }

  void _drawFreehand(Canvas canvas, Paint paint) {
    if (points.length < 2) return;

    final path = Path();
    final screenPoints = points.map(_canvasToScreen).toList();

    path.moveTo(screenPoints.first.dx, screenPoints.first.dy);
    for (int i = 1; i < screenPoints.length; i++) {
      path.lineTo(screenPoints[i].dx, screenPoints[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  void _drawLine(Canvas canvas, Paint paint) {
    if (points.length < 2) return;

    final start = _canvasToScreen(points.first);
    final end = _canvasToScreen(points.last);
    canvas.drawLine(start, end, paint);
  }

  void _drawArrow(Canvas canvas, Paint paint) {
    if (points.length < 2) return;

    final start = _canvasToScreen(points.first);
    final end = _canvasToScreen(points.last);

    // Draw the line
    canvas.drawLine(start, end, paint);

    // Draw arrow head
    const arrowSize = 12.0;
    final angle = (end - start).direction;

    final point1 = Offset(
      end.dx - arrowSize * math.cos(angle - math.pi / 6),
      end.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    final point2 = Offset(
      end.dx - arrowSize * math.cos(angle + math.pi / 6),
      end.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(point1.dx, point1.dy)
      ..lineTo(point2.dx, point2.dy)
      ..close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, fillPaint);
  }

  void _drawRectangle(Canvas canvas, Paint paint) {
    if (points.length < 2) return;

    final start = _canvasToScreen(points.first);
    final end = _canvasToScreen(points.last);

    final rect = Rect.fromPoints(start, end);
    canvas.drawRect(rect, paint);
  }

  void _drawEllipse(Canvas canvas, Paint paint) {
    if (points.length < 2) return;

    final start = _canvasToScreen(points.first);
    final end = _canvasToScreen(points.last);

    final rect = Rect.fromPoints(start, end);
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.tool != tool ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
