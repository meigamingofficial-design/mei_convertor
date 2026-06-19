// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

class Target {
  final String path;
  final int size;
  Target(this.path, this.size);
}

void main() {
  final logoFile = File('assets/images/logo.png');
  if (!logoFile.existsSync()) {
    print('Error: logo.png not found at assets/images/logo.png');
    exit(1);
  }

  final bytes = logoFile.readAsBytesSync();
  final logo = img.decodeImage(bytes);
  if (logo == null) {
    print('Error: Failed to decode assets/images/logo.png');
    exit(1);
  }

  print('Successfully decoded logo.png (${logo.width}x${logo.height})');

  final targets = [
    // Android launcher icons
    Target('android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48),
    Target('android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72),
    Target('android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96),
    Target('android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144),
    Target('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192),

    // iOS App Icons
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png', 20),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png', 40),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png', 60),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png', 29),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png', 58),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png', 87),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png', 40),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png', 80),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png', 120),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png', 120),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png', 180),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png', 76),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png', 152),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png', 167),
    Target('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 1024),

    // macOS App Icons
    Target('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png', 16),
    Target('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png', 32),
    Target('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png', 64),
    Target('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png', 128),
    Target('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png', 256),
    Target('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png', 512),
    Target('macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png', 1024),

    // Web Icons
    Target('web/favicon.png', 32),
    Target('web/icons/Icon-192.png', 192),
    Target('web/icons/Icon-maskable-192.png', 192),
    Target('web/icons/Icon-512.png', 512),
    Target('web/icons/Icon-maskable-512.png', 512),
  ];

  // 1. Generate PNGs
  for (final target in targets) {
    final file = File(target.path);
    // Create directory if not exists
    file.parent.createSync(recursive: true);

    final resized = img.copyResize(
      logo,
      width: target.size,
      height: target.size,
      interpolation: img.Interpolation.cubic,
    );

    file.writeAsBytesSync(img.encodePng(resized));
    print('Generated: ${target.path} (${target.size}x${target.size})');
  }

  // 2. Generate Windows ICO file
  final icoFile = File('windows/runner/resources/app_icon.ico');
  icoFile.parent.createSync(recursive: true);
  final icoResized = img.copyResize(
    logo,
    width: 256,
    height: 256,
    interpolation: img.Interpolation.cubic,
  );
  icoFile.writeAsBytesSync(img.encodeIco(icoResized));
  print('Generated: windows/runner/resources/app_icon.ico (256x256 ICO)');

  print('Launcher icon generation completed successfully!');
}
