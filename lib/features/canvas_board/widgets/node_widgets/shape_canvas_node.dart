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
      } catch (_) {}
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                shapeType: node.shapeType ?? CanvasShapeType.rectangle,
                color: shapeColor,
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
  final CanvasShapeType shapeType;
  final Color color;
  final bool isSelected;
  final Color selectedColor;

  _ShapePainter({
    required this.shapeType,
    required this.color,
    required this.isSelected,
    required this.selectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = isSelected ? selectedColor : color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 3 : 2;

    switch (shapeType) {
      case CanvasShapeType.rectangle:
        _drawRectangle(canvas, size, paint, strokePaint);
        break;
      case CanvasShapeType.circle:
        _drawCircle(canvas, size, paint, strokePaint);
        break;
      case CanvasShapeType.triangle:
        _drawTriangle(canvas, size, paint, strokePaint);
        break;
      case CanvasShapeType.diamond:
        _drawDiamond(canvas, size, paint, strokePaint);
        break;
      case CanvasShapeType.line:
        _drawLine(canvas, size, strokePaint);
        break;
      case CanvasShapeType.arrow:
        _drawArrow(canvas, size, strokePaint);
        break;
    }
  }

  void _drawRectangle(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, stroke);
  }

  void _drawCircle(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 4;
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
  }

  void _drawTriangle(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final path = Path()
      ..moveTo(size.width / 2, 8)
      ..lineTo(size.width - 8, size.height - 8)
      ..lineTo(8, size.height - 8)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawDiamond(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final path = Path()
      ..moveTo(size.width / 2, 8)
      ..lineTo(size.width - 8, size.height / 2)
      ..lineTo(size.width / 2, size.height - 8)
      ..lineTo(8, size.height / 2)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  void _drawLine(Canvas canvas, Size size, Paint stroke) {
    canvas.drawLine(
      const Offset(4, 4),
      Offset(size.width - 4, size.height - 4),
      stroke,
    );
  }

  void _drawArrow(Canvas canvas, Size size, Paint stroke) {
    final endPoint = Offset(size.width - 8, size.height / 2);
    final startPoint = Offset(8, size.height / 2);

    // Draw line
    canvas.drawLine(startPoint, endPoint, stroke);

    // Draw arrowhead
    const arrowSize = 12.0;
    final arrowPath = Path()
      ..moveTo(endPoint.dx, endPoint.dy)
      ..lineTo(endPoint.dx - arrowSize, endPoint.dy - arrowSize / 2)
      ..lineTo(endPoint.dx - arrowSize, endPoint.dy + arrowSize / 2)
      ..close();

    final arrowPaint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _ShapePainter oldDelegate) {
    return oldDelegate.shapeType != shapeType ||
        oldDelegate.color != color ||
        oldDelegate.isSelected != isSelected;
  }
}
