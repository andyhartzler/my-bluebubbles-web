/// Represents a canvas board for a committee workspace
class CanvasBoard {
  final String id;
  final String committeeId;
  final String name;
  final String? description;
  final double viewportX;
  final double viewportY;
  final double zoomLevel;
  final Map<String, dynamic>? canvasData;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? lastModifiedBy;

  const CanvasBoard({
    required this.id,
    required this.committeeId,
    required this.name,
    this.description,
    this.viewportX = 0.0,
    this.viewportY = 0.0,
    this.zoomLevel = 1.0,
    this.canvasData,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.lastModifiedBy,
  });

  factory CanvasBoard.fromJson(Map<String, dynamic> json) {
    return CanvasBoard(
      id: json['id'] as String,
      committeeId: json['committee_id'] as String,
      name: json['name'] as String? ?? 'Committee Board',
      description: json['description'] as String?,
      viewportX: (json['viewport_x'] as num?)?.toDouble() ?? 0.0,
      viewportY: (json['viewport_y'] as num?)?.toDouble() ?? 0.0,
      zoomLevel: (json['zoom_level'] as num?)?.toDouble() ?? 1.0,
      canvasData: json['canvas_data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
      lastModifiedBy: json['last_modified_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'committee_id': committeeId,
      'name': name,
      'description': description,
      'viewport_x': viewportX,
      'viewport_y': viewportY,
      'zoom_level': zoomLevel,
      'canvas_data': canvasData,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
      'last_modified_by': lastModifiedBy,
    };
  }

  CanvasBoard copyWith({
    String? id,
    String? committeeId,
    String? name,
    String? description,
    double? viewportX,
    double? viewportY,
    double? zoomLevel,
    Map<String, dynamic>? canvasData,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? lastModifiedBy,
  }) {
    return CanvasBoard(
      id: id ?? this.id,
      committeeId: committeeId ?? this.committeeId,
      name: name ?? this.name,
      description: description ?? this.description,
      viewportX: viewportX ?? this.viewportX,
      viewportY: viewportY ?? this.viewportY,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      canvasData: canvasData ?? this.canvasData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
    );
  }

  /// Create an empty board for a committee
  factory CanvasBoard.empty(String committeeId) {
    final now = DateTime.now();
    return CanvasBoard(
      id: '',
      committeeId: committeeId,
      name: 'Committee Board',
      viewportX: 0.0,
      viewportY: 0.0,
      zoomLevel: 1.0,
      createdAt: now,
      updatedAt: now,
    );
  }
}
