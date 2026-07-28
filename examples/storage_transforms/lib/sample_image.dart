import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Draws a colorful [size]×[size] PNG entirely in memory.
///
/// This lets the example upload real image bytes without bundling asset files
/// or depending on an image picker. The returned bytes are what get sent to
/// Storage, and the image is large enough that the transformations in the
/// detail view visibly resize it.
Future<Uint8List> generateSampleImagePng({
  required Color color,
  int size = 640,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final bounds = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

  // A diagonal gradient background derived from the seed color.
  final background = Paint()
    ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [
      color,
      Color.lerp(color, Colors.black, 0.6)!,
    ]);
  canvas.drawRect(bounds, background);

  // A few translucent circles for some visual texture.
  final circle = Paint()..color = Colors.white.withValues(alpha: 0.15);
  for (var i = 0; i < 6; i++) {
    final t = (i + 1) / 7;
    canvas.drawCircle(Offset(size * t, size * (1 - t)), size * 0.18, circle);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}
