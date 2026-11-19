import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_layout.dart';

/// Text recognition (OCR) for scanned PDF pages on the phone, with Google ML Kit (on-device, offline).
/// The words and their positions go through the same layout code as real PDF text (segmentsFromOcr).
class PdfOcr {
  PdfOcr(this.tempDir);
  final String tempDir;
  final _rec = TextRecognizer(script: TextRecognitionScript.latin);

  static final _hasLetter = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// Renders [page], recognizes its words and lays them out; null when nothing could be read.
  Future<PageLayout?> page(PdfPage page) async {
    final scale = math.min(3.0, 2200 / math.max(page.width, page.height / 1.4));
    final w = (page.width * scale).round(), h = (page.height * scale).round();
    final img = await page.renderForDisplay(width: w, height: h, fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xffffffff);
    if (img == null) return null;
    final File f;
    try {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      f = File('$tempDir/lantern_ocr_page.png');
      await f.writeAsBytes(png.buffer.asUint8List(), flush: true);
    } finally {
      img.dispose();
    }
    final res = await _rec.processImage(InputImage.fromFilePath(f.path));
    final lines = <List<OcrWord>>[];
    for (final b in res.blocks) {
      for (final l in b.lines) {
        final words = [
          for (final e in l.elements)
            if (_hasLetter.hasMatch(e.text) && (e.confidence == null || e.confidence! >= 0.35))
              OcrWord(e.text, LRect(e.boundingBox.left / scale, e.boundingBox.top / scale, e.boundingBox.right / scale, e.boundingBox.bottom / scale))
        ];
        if (words.isNotEmpty) lines.add(words);
      }
    }
    if (lines.isEmpty) return null;
    return layoutPage(segmentsFromOcr(lines), page.width, page.height);
  }

  Future<void> close() async {
    await _rec.close();
    try {
      await File('$tempDir/lantern_ocr_page.png').delete();
    } catch (_) {}
  }
}
