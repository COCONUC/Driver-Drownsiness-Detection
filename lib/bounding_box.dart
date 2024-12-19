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
    print("CustomPaint size: $size");
    print("Drawing bounding box: $boundingBox on screen size: $size with image size: $imageSize");

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Scale bounding box to fit the screen
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    final scaledRect = Rect.fromLTRB(
      boundingBox.left * scaleX,
      boundingBox.top * scaleY,
      boundingBox.right * scaleX,
      boundingBox.bottom * scaleY,
    );

    canvas.drawRect(scaledRect, paint);
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
