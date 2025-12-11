import 'package:uuid/uuid.dart';

import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/features/canvas_board/models/canvas_board.dart';
import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/models/canvas_connection.dart';

/// Service for managing canvas boards, nodes, and connections
class CanvasBoardService {
  static final CanvasBoardService _instance = CanvasBoardService._internal();
  factory CanvasBoardService() => _instance;
  CanvasBoardService._internal();

  final _supabase = CRMSupabaseService();
  final _uuid = const Uuid();

  // Table names
  static const _boardsTable = 'canvas_boards';
  static const _nodesTable = 'canvas_nodes';
  static const _connectionsTable = 'canvas_connections';

  // ============ Board Operations ============

  /// Get or create a canvas board for a committee
  Future<CanvasBoard> getOrCreateBoard(String committeeId) async {
    try {
      // First, try to get existing board
      final response = await _supabase.client
          .from(_boardsTable)
          .select()
          .eq('committee_id', committeeId)
          .maybeSingle();

      if (response != null) {
        return CanvasBoard.fromJson(response);
      }

      // Create new board if none exists
      final now = DateTime.now().toUtc();
      final newBoard = {
        'id': _uuid.v4(),
        'committee_id': committeeId,
        'name': 'Committee Board',
        'viewport_x': 0.0,
        'viewport_y': 0.0,
        'zoom_level': 1.0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final insertResponse = await _supabase.client
          .from(_boardsTable)
          .insert(newBoard)
          .select()
          .single();

      return CanvasBoard.fromJson(insertResponse);
    } catch (e) {
      print('Error getting/creating board: $e');
      rethrow;
    }
  }

  /// Update board metadata and viewport
  Future<void> updateBoard(CanvasBoard board) async {
    try {
      await _supabase.client
          .from(_boardsTable)
          .update({
            'name': board.name,
            'description': board.description,
            'viewport_x': board.viewportX,
            'viewport_y': board.viewportY,
            'zoom_level': board.zoomLevel,
            'canvas_data': board.canvasData,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'last_modified_by': board.lastModifiedBy,
          })
          .eq('id', board.id);
    } catch (e) {
      print('Error updating board: $e');
      rethrow;
    }
  }

  /// Save just the viewport state (debounced updates)
  Future<void> saveViewport(
    String boardId, {
    required double viewportX,
    required double viewportY,
    required double zoomLevel,
  }) async {
    try {
      await _supabase.client.from(_boardsTable).update({
        'viewport_x': viewportX,
        'viewport_y': viewportY,
        'zoom_level': zoomLevel,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', boardId);
    } catch (e) {
      print('Error saving viewport: $e');
      // Don't rethrow for viewport saves - they're non-critical
    }
  }

  /// Save the full canvas state (serialized fldraw data)
  Future<void> saveCanvasState(
      String boardId, Map<String, dynamic> canvasData) async {
    try {
      await _supabase.client.from(_boardsTable).update({
        'canvas_data': canvasData,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', boardId);
    } catch (e) {
      print('Error saving canvas state: $e');
      rethrow;
    }
  }

  /// Watch board changes in real-time
  Stream<CanvasBoard?> watchBoard(String boardId) {
    return _supabase.client
        .from(_boardsTable)
        .stream(primaryKey: ['id'])
        .eq('id', boardId)
        .map((data) {
          if (data.isEmpty) return null;
          return CanvasBoard.fromJson(data.first);
        });
  }

  // ============ Node Operations ============

  /// Get all nodes for a board
  Future<List<CanvasNode>> getNodes(String boardId) async {
    try {
      final response = await _supabase.client
          .from(_nodesTable)
          .select()
          .eq('board_id', boardId)
          .order('z_index', ascending: true);

      return (response as List)
          .map((json) => CanvasNode.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting nodes: $e');
      rethrow;
    }
  }

  /// Create a new node
  Future<CanvasNode> createNode(CanvasNode node) async {
    try {
      final nodeData = node.toJson();
      // Generate ID if not provided
      if (nodeData['id'] == null || nodeData['id'].isEmpty) {
        nodeData['id'] = _uuid.v4();
      }
      nodeData['created_at'] = DateTime.now().toUtc().toIso8601String();
      nodeData['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase.client
          .from(_nodesTable)
          .insert(nodeData)
          .select()
          .single();

      return CanvasNode.fromJson(response);
    } catch (e) {
      print('Error creating node: $e');
      rethrow;
    }
  }

  /// Update a node
  Future<void> updateNode(CanvasNode node) async {
    try {
      final nodeData = node.toJson();
      nodeData['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await _supabase.client
          .from(_nodesTable)
          .update(nodeData)
          .eq('id', node.id);
    } catch (e) {
      print('Error updating node: $e');
      rethrow;
    }
  }

  /// Quick update for node position (used during drag)
  Future<void> updateNodePosition(
      String nodeId, double offsetX, double offsetY) async {
    try {
      await _supabase.client.from(_nodesTable).update({
        'offset_x': offsetX,
        'offset_y': offsetY,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', nodeId);
    } catch (e) {
      print('Error updating node position: $e');
      // Don't rethrow for position updates during drag
    }
  }

  /// Update node size
  Future<void> updateNodeSize(
      String nodeId, double width, double height) async {
    try {
      await _supabase.client.from(_nodesTable).update({
        'width': width,
        'height': height,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', nodeId);
    } catch (e) {
      print('Error updating node size: $e');
    }
  }

  /// Delete a node
  Future<void> deleteNode(String nodeId) async {
    try {
      // First delete any connections involving this node
      await _supabase.client
          .from(_connectionsTable)
          .delete()
          .or('from_node_id.eq.$nodeId,to_node_id.eq.$nodeId');

      // Then delete the node
      await _supabase.client.from(_nodesTable).delete().eq('id', nodeId);
    } catch (e) {
      print('Error deleting node: $e');
      rethrow;
    }
  }

  /// Delete multiple nodes
  Future<void> deleteNodes(List<String> nodeIds) async {
    if (nodeIds.isEmpty) return;
    try {
      // Delete connections
      for (final nodeId in nodeIds) {
        await _supabase.client
            .from(_connectionsTable)
            .delete()
            .or('from_node_id.eq.$nodeId,to_node_id.eq.$nodeId');
      }

      // Delete nodes
      await _supabase.client
          .from(_nodesTable)
          .delete()
          .inFilter('id', nodeIds);
    } catch (e) {
      print('Error deleting nodes: $e');
      rethrow;
    }
  }

  /// Watch nodes in real-time
  Stream<List<CanvasNode>> watchNodes(String boardId) {
    return _supabase.client
        .from(_nodesTable)
        .stream(primaryKey: ['id'])
        .eq('board_id', boardId)
        .order('z_index', ascending: true)
        .map((data) => data.map((json) => CanvasNode.fromJson(json)).toList());
  }

  /// Update z-index for multiple nodes (bring to front/send to back)
  Future<void> updateZIndices(Map<String, int> nodeZIndices) async {
    try {
      for (final entry in nodeZIndices.entries) {
        await _supabase.client.from(_nodesTable).update({
          'z_index': entry.value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', entry.key);
      }
    } catch (e) {
      print('Error updating z-indices: $e');
    }
  }

  // ============ Connection Operations ============

  /// Get all connections for a board
  Future<List<CanvasConnection>> getConnections(String boardId) async {
    try {
      final response = await _supabase.client
          .from(_connectionsTable)
          .select()
          .eq('board_id', boardId);

      return (response as List)
          .map((json) => CanvasConnection.fromJson(json))
          .toList();
    } catch (e) {
      print('Error getting connections: $e');
      rethrow;
    }
  }

  /// Create a new connection
  Future<CanvasConnection> createConnection(CanvasConnection connection) async {
    try {
      final connectionData = connection.toJson();
      if (connectionData['id'] == null || connectionData['id'].isEmpty) {
        connectionData['id'] = _uuid.v4();
      }
      connectionData['created_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await _supabase.client
          .from(_connectionsTable)
          .insert(connectionData)
          .select()
          .single();

      return CanvasConnection.fromJson(response);
    } catch (e) {
      print('Error creating connection: $e');
      rethrow;
    }
  }

  /// Update a connection
  Future<void> updateConnection(CanvasConnection connection) async {
    try {
      await _supabase.client
          .from(_connectionsTable)
          .update(connection.toJson())
          .eq('id', connection.id);
    } catch (e) {
      print('Error updating connection: $e');
      rethrow;
    }
  }

  /// Delete a connection
  Future<void> deleteConnection(String connectionId) async {
    try {
      await _supabase.client
          .from(_connectionsTable)
          .delete()
          .eq('id', connectionId);
    } catch (e) {
      print('Error deleting connection: $e');
      rethrow;
    }
  }

  /// Watch connections in real-time
  Stream<List<CanvasConnection>> watchConnections(String boardId) {
    return _supabase.client
        .from(_connectionsTable)
        .stream(primaryKey: ['id'])
        .eq('board_id', boardId)
        .map((data) =>
            data.map((json) => CanvasConnection.fromJson(json)).toList());
  }

  // ============ Utility Methods ============

  /// Get the next z-index for a new node
  Future<int> getNextZIndex(String boardId) async {
    try {
      final response = await _supabase.client
          .from(_nodesTable)
          .select('z_index')
          .eq('board_id', boardId)
          .order('z_index', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 0;
      return (response['z_index'] as int? ?? 0) + 1;
    } catch (e) {
      return 0;
    }
  }

  /// Batch update multiple nodes (for multi-select moves)
  Future<void> batchUpdateNodes(List<CanvasNode> nodes) async {
    try {
      for (final node in nodes) {
        await updateNode(node);
      }
    } catch (e) {
      print('Error batch updating nodes: $e');
      rethrow;
    }
  }
}
