// ignore_for_file: avoid_print, prefer_final_locals
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // Restore original logo first to make sure we analyze the source image
  final originalFile = File('/Users/aravindh/Downloads/ChatGPT Image Jun 18, 2026, 08_30_55 PM.png');
  final targetFile = File('assets/images/logo.png');
  if (!originalFile.existsSync()) {
    print('Original download file not found!');
    return;
  }
  originalFile.copySync(targetFile.path);

  final bytes = targetFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  // Find bounding box of the entire rounded square (light pink/white background)
  int bgMinX = image.width;
  int bgMaxX = 0;
  int bgMinY = image.height;
  int bgMaxY = 0;

  // Find bounding box of the foreground elements (pink flower and purple arrow)
  // These have more saturated pink/purple colors (e.g. R > 150, B > 100, and R != G/B)
  int fgMinX = image.width;
  int fgMaxX = 0;
  int fgMinY = image.height;
  int fgMaxY = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // Background rounded square detection: not black
      if (r > 30 || g > 30 || b > 30) {
        if (x < bgMinX) bgMinX = x;
        if (x > bgMaxX) bgMaxX = x;
        if (y < bgMinY) bgMinY = y;
        if (y > bgMaxY) bgMaxY = y;
        
        // Foreground elements: pink flower / purple arrow (has distinct pink/purple colors)
        // Usually, pink/purple has R > 180 and G < 200
        if (r > 150 && g < 210) {
          if (x < fgMinX) fgMinX = x;
          if (x > fgMaxX) fgMaxX = x;
          if (y < fgMinY) fgMinY = y;
          if (y > fgMaxY) fgMaxY = y;
        }
      }
    }
  }

  print('Logo image size: ${image.width}x${image.height}');
  print('Rounded Square Background Bounding Box:');
  print('  X: $bgMinX to $bgMaxX (Width: ${bgMaxX - bgMinX + 1})');
  print('  Y: $bgMinY to $bgMaxY (Height: ${bgMaxY - bgMinY + 1})');
  print('Foreground Elements Bounding Box:');
  print('  X: $fgMinX to $fgMaxX (Width: ${fgMaxX - fgMinX + 1})');
  print('  Y: $fgMinY to $fgMaxY (Height: ${fgMaxY - fgMinY + 1})');
}
