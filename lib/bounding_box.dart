import 'package:flutter/material.dart';

class FaceBoundingBoxPainter extends CustomPainter {
  final Rect boundingBox;
  final Size imageSize;

  FaceBoundingBoxPainter({
    required this.boundingBox,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Scale the bounding box to fit the screen
    final rect = Rect.fromLTRB(
      boundingBox.left * size.width / imageSize.width,
      boundingBox.top * size.height / imageSize.height,
      boundingBox.right * size.width / imageSize.width,
      boundingBox.bottom * size.height / imageSize.height,
    );

    // Draw the bounding box
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
