/// Types of connections between nodes
enum CanvasConnectionType {
  arrow,
  line,
  dashed,
}

/// Represents a connection (arrow/line) between two nodes on the canvas
class CanvasConnection {
  final String id;
  final String boardId;
  final String fromNodeId;
  final String toNodeId;
  final CanvasConnectionType connectionType;
  final String color;
  final double strokeWidth;
  final String? label;
  final DateTime? createdAt;

  const CanvasConnection({
    required this.id,
    required this.boardId,
    required this.fromNodeId,
    required this.toNodeId,
    this.connectionType = CanvasConnectionType.arrow,
    this.color = '#424242',
    this.strokeWidth = 2.0,
    this.label,
    this.createdAt,
  });

  factory CanvasConnection.fromJson(Map<String, dynamic> json) {
    return CanvasConnection(
      id: json['id'] as String,
      boardId: json['board_id'] as String,
      fromNodeId: json['from_node_id'] as String,
      toNodeId: json['to_node_id'] as String,
      connectionType: _parseConnectionType(json['connection_type'] as String?),
      color: json['color'] as String? ?? '#424242',
      strokeWidth: (json['stroke_width'] as num?)?.toDouble() ?? 2.0,
      label: json['label'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'board_id': boardId,
      'from_node_id': fromNodeId,
      'to_node_id': toNodeId,
      'connection_type': connectionType.name,
      'color': color,
      'stroke_width': strokeWidth,
      'label': label,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  CanvasConnection copyWith({
    String? id,
    String? boardId,
    String? fromNodeId,
    String? toNodeId,
    CanvasConnectionType? connectionType,
    String? color,
    double? strokeWidth,
    String? label,
    DateTime? createdAt,
  }) {
    return CanvasConnection(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      connectionType: connectionType ?? this.connectionType,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static CanvasConnectionType _parseConnectionType(String? type) {
    if (type == null) return CanvasConnectionType.arrow;
    return CanvasConnectionType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => CanvasConnectionType.arrow,
    );
  }
}
