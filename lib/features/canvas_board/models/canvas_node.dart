/// Types of nodes that can be placed on the canvas
enum CanvasNodeType {
  member,
  event,
  chapter,
  donor,
  vote,
  note,
  text,
  shape,
  image,
  file,
  freehand,
}

/// Represents a node on the canvas board
class CanvasNode {
  final String id;
  final String boardId;
  final double offsetX;
  final double offsetY;
  final double width;
  final double height;
  final CanvasNodeType nodeType;
  final String? entityId;
  final String? noteContent;
  final String? noteColor;
  final String? textContent;
  final String? shapeType; // Can be 'rectangle', 'ellipse', 'line', 'arrow', etc.
  final String? shapeColor;
  final double? strokeWidth;
  final String? pathData; // For freehand and line shapes: "x1,y1;x2,y2;..."
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final String? imageUrl;
  final String? imageThumbnailUrl;
  final int zIndex;
  final bool isLocked;
  final String? label;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CanvasNode({
    required this.id,
    required this.boardId,
    required this.offsetX,
    required this.offsetY,
    this.width = 200,
    this.height = 150,
    required this.nodeType,
    this.entityId,
    this.noteContent,
    this.noteColor,
    this.textContent,
    this.shapeType,
    this.shapeColor,
    this.strokeWidth,
    this.pathData,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.imageUrl,
    this.imageThumbnailUrl,
    this.zIndex = 0,
    this.isLocked = false,
    this.label,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory CanvasNode.fromJson(Map<String, dynamic> json) {
    // Try to get stroke_width and path_data from metadata if not directly available
    final metadata = json['metadata'] as Map<String, dynamic>?;
    double? strokeWidth = (json['stroke_width'] as num?)?.toDouble();
    String? pathData = json['path_data'] as String?;

    if (metadata != null) {
      strokeWidth ??= (metadata['stroke_width'] as num?)?.toDouble();
      pathData ??= metadata['path_data'] as String?;
    }

    return CanvasNode(
      id: json['id'] as String,
      boardId: json['board_id'] as String,
      offsetX: (json['offset_x'] as num).toDouble(),
      offsetY: (json['offset_y'] as num).toDouble(),
      width: (json['width'] as num?)?.toDouble() ?? 200,
      height: (json['height'] as num?)?.toDouble() ?? 150,
      nodeType: _parseNodeType(json['node_type'] as String),
      entityId: json['entity_id'] as String?,
      noteContent: json['note_content'] as String?,
      noteColor: json['note_color'] as String?,
      textContent: json['text_content'] as String?,
      shapeType: json['shape_type'] as String?,
      shapeColor: json['shape_color'] as String?,
      strokeWidth: strokeWidth,
      pathData: pathData,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileType: json['file_type'] as String?,
      fileSize: json['file_size'] as int?,
      imageUrl: json['image_url'] as String?,
      imageThumbnailUrl: json['image_thumbnail_url'] as String?,
      zIndex: json['z_index'] as int? ?? 0,
      isLocked: json['is_locked'] as bool? ?? false,
      label: json['label'] as String?,
      metadata: metadata,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    // Store stroke_width and path_data in metadata since they may not exist as columns
    final extendedMetadata = Map<String, dynamic>.from(metadata ?? {});
    if (strokeWidth != null) {
      extendedMetadata['stroke_width'] = strokeWidth;
    }
    if (pathData != null) {
      extendedMetadata['path_data'] = pathData;
    }

    return {
      'id': id,
      'board_id': boardId,
      'offset_x': offsetX,
      'offset_y': offsetY,
      'width': width,
      'height': height,
      'node_type': nodeType.name,
      'entity_id': entityId,
      'note_content': noteContent,
      'note_color': noteColor,
      'text_content': textContent,
      'shape_type': shapeType,
      'shape_color': shapeColor,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'image_url': imageUrl,
      'image_thumbnail_url': imageThumbnailUrl,
      'z_index': zIndex,
      'is_locked': isLocked,
      'label': label,
      'metadata': extendedMetadata.isNotEmpty ? extendedMetadata : null,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  CanvasNode copyWith({
    String? id,
    String? boardId,
    double? offsetX,
    double? offsetY,
    double? width,
    double? height,
    CanvasNodeType? nodeType,
    String? entityId,
    String? noteContent,
    String? noteColor,
    String? textContent,
    String? shapeType,
    String? shapeColor,
    double? strokeWidth,
    String? pathData,
    String? fileUrl,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? imageUrl,
    String? imageThumbnailUrl,
    int? zIndex,
    bool? isLocked,
    String? label,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CanvasNode(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      width: width ?? this.width,
      height: height ?? this.height,
      nodeType: nodeType ?? this.nodeType,
      entityId: entityId ?? this.entityId,
      noteContent: noteContent ?? this.noteContent,
      noteColor: noteColor ?? this.noteColor,
      textContent: textContent ?? this.textContent,
      shapeType: shapeType ?? this.shapeType,
      shapeColor: shapeColor ?? this.shapeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      pathData: pathData ?? this.pathData,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      imageUrl: imageUrl ?? this.imageUrl,
      imageThumbnailUrl: imageThumbnailUrl ?? this.imageThumbnailUrl,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
      label: label ?? this.label,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static CanvasNodeType _parseNodeType(String type) {
    return CanvasNodeType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => CanvasNodeType.note,
    );
  }

  /// Get display name for the node type
  String get displayName {
    switch (nodeType) {
      case CanvasNodeType.member:
        return 'Member';
      case CanvasNodeType.event:
        return 'Event';
      case CanvasNodeType.chapter:
        return 'Chapter';
      case CanvasNodeType.donor:
        return 'Donor';
      case CanvasNodeType.vote:
        return 'Vote';
      case CanvasNodeType.note:
        return 'Note';
      case CanvasNodeType.text:
        return 'Text';
      case CanvasNodeType.shape:
        return 'Shape';
      case CanvasNodeType.image:
        return 'Image';
      case CanvasNodeType.file:
        return 'File';
      case CanvasNodeType.freehand:
        return 'Drawing';
    }
  }
}

/// Stroke data for freehand drawing
class CanvasStroke {
  final List<StrokePoint> points;
  final String color;
  final double strokeWidth;

  const CanvasStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  factory CanvasStroke.fromJson(Map<String, dynamic> json) {
    return CanvasStroke(
      points: (json['points'] as List)
          .map((p) => StrokePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      color: json['color'] as String,
      strokeWidth: (json['stroke_width'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => p.toJson()).toList(),
      'color': color,
      'stroke_width': strokeWidth,
    };
  }
}

/// A point in a stroke with pressure data
class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
  });

  factory StrokePoint.fromJson(Map<String, dynamic> json) {
    return StrokePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'pressure': pressure,
    };
  }
}
