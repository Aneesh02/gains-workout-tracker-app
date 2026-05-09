// Run with: dart run tools/generate_icon.dart
// Generates assets/icon/icon.png and assets/icon/icon_fg.png for flutter_launcher_icons.
//
// Design: barbell plate (concentric rings) + horizontal bar through the centre.
// Colour palette matches the app: dark bg #2A2D35, electric blue #4A9EFF.

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  const cx = size ~/ 2; // 512
  const cy = size ~/ 2; // 512

  final bg = img.ColorRgba8(0x2A, 0x2D, 0x35, 0xFF);
  final blue = img.ColorRgba8(0x4A, 0x9E, 0xFF, 0xFF);
  final blueDark = img.ColorRgba8(0x28, 0x72, 0xCC, 0xFF);   // outer ring
  final blueLight = img.ColorRgba8(0x6B, 0xB8, 0xFF, 0xFF);  // inner highlight

  // ── Full icon (dark bg + plate + bar) ────────────────────────────────────
  final full = img.Image(width: size, height: size);
  _draw(full, cx, cy, bg, blue, blueDark, blueLight, darkBg: true);

  Directory('assets/icon').createSync(recursive: true);
  File('assets/icon/icon.png')
      .writeAsBytesSync(img.encodePng(full));

  // ── Adaptive foreground (transparent bg, plate + bar centred) ────────────
  final fg = img.Image(width: size, height: size);
  final transparent = img.ColorRgba8(0, 0, 0, 0);
  img.fill(fg, color: transparent);
  _draw(fg, cx, cy, transparent, blue, blueDark, blueLight, darkBg: false);

  File('assets/icon/icon_fg.png')
      .writeAsBytesSync(img.encodePng(fg));

  print('✓  assets/icon/icon.png');
  print('✓  assets/icon/icon_fg.png');
  print('Now run: dart run flutter_launcher_icons');
}

void _draw(
  img.Image canvas,
  int cx,
  int cy,
  img.Color bg,
  img.Color blue,
  img.Color blueDark,
  img.Color blueLight, {
  required bool darkBg,
}) {
  if (darkBg) img.fill(canvas, color: bg);

  // ── Plate rings (outside → inside) ───────────────────────────────────────
  // Outer rim — slightly darker blue for depth
  img.fillCircle(canvas, x: cx, y: cy, radius: 420, color: blueDark);
  // Gap (background)
  img.fillCircle(canvas, x: cx, y: cy, radius: 370, color: bg);
  // Main plate face
  img.fillCircle(canvas, x: cx, y: cy, radius: 300, color: blue);
  // Inner highlight (lighter centre gives a convex 3-D feel)
  img.fillCircle(canvas, x: cx, y: cy, radius: 200, color: blueLight);
  // Centre hole — slightly larger than bar so it reads clearly
  img.fillCircle(canvas, x: cx, y: cy, radius: 70, color: bg);

  // ── Bar (horizontal, passes through hole) ────────────────────────────────
  img.fillRect(
    canvas,
    x1: 0, y1: cy - 24,
    x2: 1024, y2: cy + 24,
    color: blueDark,
  );
  // Bar highlight strip (top edge, 6px)
  img.fillRect(
    canvas,
    x1: 0, y1: cy - 24,
    x2: 1024, y2: cy - 18,
    color: blueLight,
  );

  // Re-punch centre hole so bar doesn't fill it
  img.fillCircle(canvas, x: cx, y: cy, radius: 70, color: bg);
}
