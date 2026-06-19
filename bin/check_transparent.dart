// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/images/logo_transparent.png');
  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) {
    print('Failed to decode');
    return;
  }
  print('Image dimensions: ${image.width}x${image.height}');
  int count = 0;
  // Let's scan the top-left 150x150 region of the 1024x1024 image
  for (int y = 0; y < 200; y++) {
    for (int x = 0; x < 200; x++) {
      final p = image.getPixel(x, y);
      if (p.a > 0) {
        // It's not fully transparent!
        if (p.r < 50 && p.g < 50 && p.b < 50) {
          count++;
        }
      }
    }
  }
  print('Found $count opaque dark pixels in top-left 200x200 region');
  
  // Let's print some pixel values around the top-left corner of the actual flower card
  // Wait, let's find the first non-transparent pixel from top-left
  int firstX = -1, firstY = -1;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      if (p.a > 0) {
        firstX = x;
        firstY = y;
        break;
      }
    }
    if (firstX != -1) break;
  }
  print('First non-transparent pixel found at X: $firstX, Y: $firstY');
  if (firstX != -1) {
    final p = image.getPixel(firstX, firstY);
    print('Pixel color: (${p.r}, ${p.g}, ${p.b}, ${p.a})');
  }
}
