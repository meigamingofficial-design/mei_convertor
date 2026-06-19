// ignore_for_file: avoid_print, use_string_buffers, prefer_final_locals
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/logo.png');
  if (!file.existsSync()) {
    print('logo.png not found');
    return;
  }
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  print('Top-Left 5x5 pixels:');
  for (int y = 0; y < 5; y++) {
    String row = '';
    for (int x = 0; x < 5; x++) {
      final p = image.getPixel(x, y);
      row += '(${p.r.toInt()},${p.g.toInt()},${p.b.toInt()},${p.a.toInt()}) ';
    }
    print(row);
  }

  print('Center 5x5 pixels:');
  int cx = image.width ~/ 2;
  int cy = image.height ~/ 2;
  for (int y = cy - 2; y < cy + 3; y++) {
    String row = '';
    for (int x = cx - 2; x < cx + 3; x++) {
      final p = image.getPixel(x, y);
      row += '(${p.r.toInt()},${p.g.toInt()},${p.b.toInt()},${p.a.toInt()}) ';
    }
    print(row);
  }
}
