import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';

/// Canvas node widget for displaying geometric shapes
class ShapeCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;

  const ShapeCanvasNode({
    super.key,
    required this.node,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
  });

  Color get shapeColor {
    if (node.shapeColor != null) {
      try {
        final hex = node.shapeColor!.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        debugPrint('ShapeCanvasNode.shapeColor parse error: $e');
      }
    }
    return Colors.blue;
  }

  // Check metadata for render type (used when DB constraint limits shape_type values)
  String? get _renderAs => node.metadata?['render_as'] as String?;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine effective shape type based on metadata
    // The DB only allows 'rectangle' and 'circle', so we use 'render_as' metadata
    // for lines, arrows, and freehand drawings
    String effectiveShapeType = _renderAs ?? node.shapeType ?? 'rectangle';

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: SizedBox(
        width: node.width,
        height: node.height,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(node.width, node.height),
              painter: _ShapePainter(
                shapeType: effectiveShapeType,
                color: shapeColor,
                strokeWidth: node.strokeWidth ?? 2.0,
                pathData: node.pathData,
                isSelected: isSelected,
                selectedColor: theme.colorScheme.primary,
              ),
            ),
            if (node.label != null)
              Center(
                child: Text(
                  node.label!,
                  style: TextStyle(
                    color: _getContrastColor(shapeColor),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

class _ShapePainter extends CustomPainter {
  final String shapeType;
  final Color color;
  final double strokeWidth;
  final String? pathData;
  final bool isSelected;
  final Color selectedColor;

  _ShapePainter({
    required this.shapeType,
    required this.color,
    required this.strokeWidth,
    this.pathData,
    required this.isSelected,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = isSelected ? selectedColor : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? strokeWidth + 1 : strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shapeType) {
      case 'rectangle':
        _drawRectangle(canvas, size, fillPaint, strokePaint);
        break;
      case 'ellipse':
      case 'circle':
        _drawEllipse(canvas, size, fillPaint, strokePaint);
        break;
      case 'triangle':
        _drawTriangle(canvas, size, fillPaint, strokePaint);
        break;
      case 'diamond':
        _drawDiamond(canvas, size, fillPaint, strokePaint);
        break;
      case 'line':
        _drawLine(canvas, size, strokePaint);
        break;
      case 'arrow':
        _drawArrow(canvas, size, strokePaint);
        break;
      case 'freehand':
        _drawFreehand(canvas, size, strokePaint);
        break;
      default:
        _drawRectangle(canvas, size, fillPaint, strokePaint);
    }
  }

  void _drawRectangle(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final rect = Rect.fromLTWH(
      strokeWidth,
      strokeWidth,
      size.width - strokeWidth * 2,
      size.height - strokeWidth * 2,
    );
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  void _drawEllipse(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final rect = Rect.fromLTWH(
      strokeWidth,
      strokeWidth,
      size.width - strokeWidth * 2,
      size.height - strokeWidth * 2,
    );
    canvas.drawOval(rect, fill);
    canvas.drawOval(rect, stroke);
  }

  void _drawTriangle(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final path = Path()
      ..moveTo(size.width / 2, strokeWidth)
      ..lineTo(size.width - strokeWidth, size.height - strokeWidth)
      ..lineTo(strokeWidth, size.height - strokeWidth)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawDiamond(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final path = Path()
      ..moveTo(size.width / 2, strokeWidth)
      ..lineTo(size.width - strokeWidth, size.height / 2)
      ..lineTo(size.width / 2, size.height - strokeWidth)
      ..lineTo(strokeWidth, size.height / 2)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawLine(Canvas canvas, Size size, Paint stroke) {
    // Parse path data for line endpoints
    if (pathData != null) {
      final points = _parsePathData(pathData!);
      if (points.length >= 2) {
        canvas.drawLine(points[0], points[1], stroke);
        return;
      }
    }
    // Default diagonal line
    canvas.drawLine(
      Offset(strokeWidth, strokeWidth),
      Offset(size.width - strokeWidth, size.height - strokeWidth),
      stroke,
    );
  }

  void _drawFreehand(Canvas canvas, Size size, Paint stroke) {
    if (pathData == null) return;

    final points = _parsePathData(pathData!);
    if (points.length < 2) return;

    // Calculate the offset to adjust points relative to the node bounds
    double minX = double.infinity, minY = double.infinity;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
    }

    final path = Path();
    final adjustedPoints = points.map((p) => Offset(
      p.dx - minX + strokeWidth,
      p.dy - minY + strokeWidth,
    )).toList();

    path.moveTo(adjustedPoints[0].dx, adjustedPoints[0].dy);
    for (int i = 1; i < adjustedPoints.length; i++) {
      path.lineTo(adjustedPoints[i].dx, adjustedPoints[i].dy);
    }

    canvas.drawPath(path, stroke);
  }

  void _drawArrow(Canvas canvas, Size size, Paint stroke) {
    Offset startPoint;
    Offset endPoint;

    // Parse path data for arrow endpoints
    if (pathData != null) {
      final points = _parsePathData(pathData!);
      if (points.length >= 2) {
        startPoint = points[0];
        endPoint = points[1];
      } else {
        startPoint = Offset(strokeWidth, size.height / 2);
        endPoint = Offset(size.width - strokeWidth, size.height / 2);
      }
    } else {
      startPoint = Offset(strokeWidth, size.height / 2);
      endPoint = Offset(size.width - strokeWidth, size.height / 2);
    }

    // Draw line
    canvas.drawLine(startPoint, endPoint, stroke);

    // Draw arrowhead
    const arrowSize = 12.0;
    final angle = (endPoint - startPoint).direction;

    final point1 = Offset(
      endPoint.dx - arrowSize * math.cos(angle - math.pi / 6),
      endPoint.dy - arrowSize * math.sin(angle - math.pi / 6),
    );
    final point2 = Offset(
      endPoint.dx - arrowSize * math.cos(angle + math.pi / 6),
      endPoint.dy - arrowSize * math.sin(angle + math.pi / 6),
    );

    final arrowPath = Path()
      ..moveTo(endPoint.dx, endPoint.dy)
      ..lineTo(point1.dx, point1.dy)
      ..lineTo(point2.dx, point2.dy)
      ..close();

    final arrowPaint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);
  }

  List<Offset> _parsePathData(String data) {
    final points = <Offset>[];
    final segments = data.split(';');
    for (final segment in segments) {
      final coords = segment.split(',');
      if (coords.length >= 2) {
        try {
          final x = double.parse(coords[0].trim());
          final y = double.parse(coords[1].trim());
          points.add(Offset(x, y));
        } catch (_) {
          // Skip invalid coordinates
        }
      }
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) {
    return oldDelegate.shapeType != shapeType ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.pathData != pathData ||
        oldDelegate.isSelected != isSelected;
  }
}
