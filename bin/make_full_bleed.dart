// ignore_for_file: avoid_print, prefer_final_locals, directives_ordering
import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  // 1. Copy the original logo from Downloads
  final originalFile = File('/Users/aravindh/Downloads/ChatGPT Image Jun 18, 2026, 08_30_55 PM.png');
  final targetFile = File('assets/images/logo.png');
  if (!originalFile.existsSync()) {
    print('Original download file not found!');
    return;
  }
  originalFile.copySync(targetFile.path);
  print('Restored original logo.png');

  // 2. Decode the image
  final bytes = targetFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  // 3. Find the bounding box of the non-black pixels
  int minX = image.width;
  int maxX = 0;
  int minY = image.height;
  int maxY = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      final a = pixel.a;

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

  // Crop the image
  final cropped = img.copyCrop(
    image,
    x: startX,
    y: startY,
    width: size,
    height: size,
  );

  print('Cropped logo size: ${cropped.width}x${cropped.height}');

  // 4. Perform flood fill starting from all 4 corners to make background transparent
  final visited = List.generate(cropped.width, (_) => List.filled(cropped.height, false));
  final queue = Queue<(int, int)>();

  void addPixel(int x, int y) {
    if (x < 0 || x >= cropped.width || y < 0 || y >= cropped.height) return;
    if (visited[x][y]) return;

    final pixel = cropped.getPixel(x, y);
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    final maxVal = r > g ? (r > b ? r : b) : (g > b ? g : b);

    if (maxVal < 130) {
      visited[x][y] = true;
      if (maxVal <= 25) {
        pixel.a = 0;
      } else {
        final double factor = (maxVal - 25) / (130 - 25);
        pixel.a = (factor * 255).clamp(0, 255).toInt();
      }
      queue.add((x, y));
    }
  }

  addPixel(0, 0);
  addPixel(cropped.width - 1, 0);
  addPixel(0, cropped.height - 1);
  addPixel(cropped.width - 1, cropped.height - 1);

  while (queue.isNotEmpty) {
    final (cx, cy) = queue.removeFirst();
    addPixel(cx + 1, cy);
    addPixel(cx - 1, cy);
    addPixel(cx, cy + 1);
    addPixel(cx, cy - 1);
  }

  // 5. Create a solid background image filled with the light pink brand color
  // Color code: #FCF7FC (252, 247, 252) matching the logo center
  final fullBleed = img.Image(width: cropped.width, height: cropped.height);
  for (final pixel in fullBleed) {
    pixel.r = 252;
    pixel.g = 247;
    pixel.b = 252;
    pixel.a = 255;
  }

  // 6. Draw the transparent cropped logo on top of the solid background
  img.compositeImage(
    fullBleed,
    cropped,
    dstX: 0,
    dstY: 0,
    blend: img.BlendMode.alpha,
  );

  // 7. Save the full-bleed logo image
  targetFile.writeAsBytesSync(img.encodePng(fullBleed));
  print('Successfully generated full-bleed logo.png');
}
