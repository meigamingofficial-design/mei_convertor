// ignore_for_file: avoid_print, prefer_final_locals, unnecessary_brace_in_string_interps
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

  int minX = image.width;
  int maxX = 0;
  int minY = image.height;
  int maxY = 0;

  // Scan all pixels to find the bounding box of non-black pixels.
  // We assume "black background" has R, G, B values below a threshold (e.g., 20)
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      final a = pixel.a;

      // If it's not black/transparent
      if (a > 10 && (r > 20 || g > 20 || b > 20)) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX <= minX || maxY <= minY) {
    print('Could not find non-black bounding box');
    return;
  }

  int width = maxX - minX + 1;
  int height = maxY - minY + 1;
  
  // Make it a perfect square
  int size = width < height ? width : height;
  int startX = minX + (width - size) ~/ 2;
  int startY = minY + (height - size) ~/ 2;

  print('Cropping to square: X: $startX, Y: $startY, Size: ${size}x${size}');

  // Crop the image
  final cropped = img.copyCrop(
    image,
    x: startX,
    y: startY,
    width: size,
    height: size,
  );

  // Write the cropped image back to assets/images/logo.png
  file.writeAsBytesSync(img.encodePng(cropped));
  print('Successfully cropped and saved assets/images/logo.png as a perfect square.');
}
