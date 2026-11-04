import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

/// Service responsible for compositing editing layers and exporting the final image.
class MediaExportService {
  MediaExportService._();

  /// Captures the composited image from a RepaintBoundary without editor chrome or selection handles.
  static Future<File> captureAndExport({
    required GlobalKey repaintBoundaryKey,
    double pixelRatio = 2.5,
  }) async {
    final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception('RepaintBoundary render object not found for export');
    }

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to encode composited image to byte data');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final String outputPath =
        '${tempDir.path}/edited_image_${DateTime.now().millisecondsSinceEpoch}.png';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(pngBytes, flush: true);

    return outputFile;
  }
}
