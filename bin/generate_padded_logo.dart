// ignore_for_file: avoid_print, prefer_final_locals
import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final originalFile = File('/Users/aravindh/Downloads/ChatGPT Image Jun 18, 2026, 08_30_55 PM.png');
  if (!originalFile.existsSync()) {
    print('Original download file not found!');
    return;
  }

  // 1. Decode the image
  final bytes = originalFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  // 2. Find the bounding box of the non-black pixels
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

  print('Cropped image size: ${cropped.width}x${cropped.height}');

  // 3. Flood fill starting from all 4 corners to make background transparent
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

  // 4. Create a 1024x1024 transparent canvas
  const canvasSize = 1024;
  final transparentCanvas = img.Image(width: canvasSize, height: canvasSize);
  for (final pixel in transparentCanvas) {
    pixel.r = 0;
    pixel.g = 0;
    pixel.b = 0;
    pixel.a = 0;
  }

  // Scale the cropped transparent flower to occupy exactly 65% of the canvas size
  // (65% of 1024 is ~665px)
  final targetContentSize = (canvasSize * 0.65).toInt(); // 665 px
  final scaledFlower = img.copyResize(
    cropped,
    width: targetContentSize,
    height: targetContentSize,
    interpolation: img.Interpolation.cubic,
  );

  // Composite the scaled flower in the center of the 1024x1024 canvas
  final offset = (canvasSize - targetContentSize) ~/ 2;
  img.compositeImage(
    transparentCanvas,
    scaledFlower,
    dstX: offset,
    dstY: offset,
    blend: img.BlendMode.alpha,
  );

  // Save the padded transparent logo
  final transparentLogoFile = File('assets/images/logo_transparent.png');
  transparentLogoFile.parent.createSync(recursive: true);
  transparentLogoFile.writeAsBytesSync(img.encodePng(transparentCanvas));
  print('Successfully generated assets/images/logo_transparent.png (padded content, transparent bg)');

  // 5. Create a 1024x1024 solid background canvas (brand pink color #FCF7FC)
  final solidCanvas = img.Image(width: canvasSize, height: canvasSize);
  for (final pixel in solidCanvas) {
    pixel.r = 252;
    pixel.g = 247;
    pixel.b = 252;
    pixel.a = 255;
  }

  // Composite the transparent canvas on top of the solid background
  img.compositeImage(
    solidCanvas,
    transparentCanvas,
    dstX: 0,
    dstY: 0,
    blend: img.BlendMode.alpha,
  );

  // Save the padded solid background logo as logo.png
  final logoFile = File('assets/images/logo.png');
  logoFile.writeAsBytesSync(img.encodePng(solidCanvas));
  print('Successfully generated assets/images/logo.png (padded content, solid pink bg)');
}
