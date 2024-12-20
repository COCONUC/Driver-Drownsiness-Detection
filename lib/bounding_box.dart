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

    // Calculate aspect ratio scaling
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;

    // Use the smaller scaling factor to maintain aspect ratio
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Adjust bounding box height
    final double heightAdjustment = 20.0; // Increase height by this value
    final Rect adjustedBoundingBox = Rect.fromLTRB(
      boundingBox.left,
      boundingBox.top - heightAdjustment, // Extend upwards
      boundingBox.right,
      boundingBox.bottom + heightAdjustment, // Extend downwards
    );

    // Scale and center the bounding box
    final double dx = (size.width - imageSize.width * scale) / 2;
    final double dy = (size.height - imageSize.height * scale) / 2;

    final scaledRect = Rect.fromLTRB(
      adjustedBoundingBox.left * scale + dx,
      adjustedBoundingBox.top * scale + dy,
      adjustedBoundingBox.right * scale + dx,
      adjustedBoundingBox.bottom * scale + dy,
    );

    // Draw the scaled bounding box
    canvas.drawRect(scaledRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

