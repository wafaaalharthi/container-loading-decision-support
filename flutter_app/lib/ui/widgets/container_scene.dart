import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Slowly rotating 20GP container with the first boxes of the SH-102 plan.
/// Every box shows its ID on the top face and on the side facing the viewer.
class RotatingContainer extends StatefulWidget {
  final double height;
  const RotatingContainer({super.key, this.height = 280});

  @override
  State<RotatingContainer> createState() => _RotatingContainerState();
}

class _RotatingContainerState extends State<RotatingContainer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(painter: _ScenePainter(_c.value * 2 * math.pi)),
        ),
      ),
    );
  }
}

class _Box {
  final String id;
  final double x, y, z, dx, dy, dz; // mm
  const _Box(this.id, this.x, this.y, this.z, this.dx, this.dy, this.dz);
  String get group => id.substring(0, 3);
}

class _V {
  final double x, y, z;
  const _V(this.x, this.y, this.z);
}

// 20GP inner size (mm)
const double contL = 5900, contW = 2352, contH = 2395;

// Group colors (same as the prototype)
const Map<String, Color> groupColors = {
  'B01': Color(0xFF498BFF),
  'B02': Color(0xFFFF9D55),
  'B03': Color(0xFF50E5AA),
  'B04': Color(0xFFFFD25E),
  'B05': Color(0xFFFF71B3),
  'B06': Color(0xFFAF79FF),
};

// First boxes of the engine plan for SH-102 (loading order)
const List<_Box> _cargo = [
  _Box('B02-24', 0, 0, 0, 1000, 750, 800),
  _Box('B02-23', 0, 750, 0, 1000, 750, 800),
  _Box('B02-22', 0, 1500, 0, 1000, 750, 800),
  _Box('B02-21', 1000, 0, 0, 1000, 750, 800),
  _Box('B02-20', 1000, 750, 0, 1000, 750, 800),
  _Box('B02-19', 1000, 1500, 0, 1000, 750, 800),
  _Box('B02-18', 2000, 0, 0, 1000, 750, 800),
  _Box('B02-17', 2000, 750, 0, 1000, 750, 800),
  _Box('B02-16', 2000, 1500, 0, 1000, 750, 800),
  _Box('B02-15', 3000, 0, 0, 1000, 750, 800),
  _Box('B02-14', 3000, 750, 0, 1000, 750, 800),
  _Box('B02-13', 3000, 1500, 0, 1000, 750, 800),
  _Box('B02-12', 0, 0, 800, 1000, 750, 800),
  _Box('B02-11', 0, 750, 800, 1000, 750, 800),
  _Box('B02-10', 0, 1500, 800, 1000, 750, 800),
  _Box('B02-09', 1000, 0, 800, 1000, 750, 800),
  _Box('B02-08', 1000, 750, 800, 1000, 750, 800),
  _Box('B02-07', 1000, 1500, 800, 1000, 750, 800),
  _Box('B02-06', 2000, 0, 800, 1000, 750, 800),
  _Box('B02-05', 2000, 750, 800, 1000, 750, 800),
  _Box('B02-04', 2000, 1500, 800, 1000, 750, 800),
  _Box('B02-03', 3000, 0, 800, 1000, 750, 800),
  _Box('B02-02', 3000, 750, 800, 1000, 750, 800),
  _Box('B02-01', 3000, 1500, 800, 1000, 750, 800),
  _Box('B04-02', 4000, 0, 0, 1100, 1500, 900),
  _Box('B03-50', 0, 0, 1600, 600, 500, 600),
  _Box('B03-49', 0, 500, 1600, 600, 500, 600),
  _Box('B03-48', 0, 1000, 1600, 600, 500, 600),
  _Box('B03-47', 0, 1500, 1600, 600, 500, 600),
];

// Text is laid out once per ID at this size, then scaled.
const double _baseFont = 20;
final Map<String, TextPainter> _labelCache = {};

TextPainter _label(String id, bool dark) {
  final key = '$id|$dark';
  return _labelCache.putIfAbsent(key, () {
    return TextPainter(
      text: TextSpan(
        text: id,
        style: TextStyle(
          fontSize: _baseFont,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: dark ? const Color(0xFF0A1024) : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  });
}

class _ScenePainter extends CustomPainter {
  final double yaw;
  _ScenePainter(this.yaw);

  static const _pitch = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosP = math.cos(_pitch), sinP = math.sin(_pitch);
    final scale = math.min(size.width / 8.0, size.height / 6.6) / 1000; // px per mm
    final center = Offset(size.width / 2, size.height / 2);

    // World point -> (screen x, depth, screen up), centred on the container
    (double, double, double) rot(_V p) {
      final x = p.x - contL / 2, y = p.y - contW / 2, z = p.z - contH / 2;
      final x1 = x * cosY - y * sinY;
      final y1 = x * sinY + y * cosY;
      return (x1, y1 * cosP - z * sinP, z * cosP + y1 * sinP);
    }

    Offset proj(_V p) {
      final (x1, depth, up) = rot(p);
      final f = 14000 / (14000 + depth); // mild perspective
      return center + Offset(x1 * f * scale, -up * f * scale);
    }

    // > 0 means the face looks toward the camera
    double facing(_V n) {
      final ny = n.x * sinY + n.y * cosY;
      return -ny * cosP + n.z * sinP;
    }

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.cyan.withValues(alpha: 0.55);

    final floor = Path()
      ..addPolygon([
        proj(const _V(0, 0, 0)),
        proj(const _V(contL, 0, 0)),
        proj(const _V(contL, contW, 0)),
        proj(const _V(0, contW, 0)),
      ], true);
    canvas.drawPath(floor, Paint()..color = AppColors.blue.withValues(alpha: 0.16));

    // Painter's order: farthest box first
    double depthOf(_Box b) => rot(_V(b.x + b.dx / 2, b.y + b.dy / 2, b.z + b.dz / 2)).$2;
    final sorted = [..._cargo]..sort((a, b) => depthOf(b).compareTo(depthOf(a)));

    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = AppColors.bgDeep.withValues(alpha: 0.9);

    for (final b in sorted) {
      final x0 = b.x, x1 = b.x + b.dx, y0 = b.y, y1 = b.y + b.dy, z0 = b.z, z1 = b.z + b.dz;
      final base = groupColors[b.group] ?? AppColors.muted;
      final faces = <(_V, List<_V>, double)>[
        (const _V(0, 0, 1), [_V(x0, y0, z1), _V(x1, y0, z1), _V(x1, y1, z1), _V(x0, y1, z1)], 1.0),
        (const _V(1, 0, 0), [_V(x1, y0, z0), _V(x1, y1, z0), _V(x1, y1, z1), _V(x1, y0, z1)], 0.8),
        (const _V(-1, 0, 0), [_V(x0, y0, z0), _V(x0, y1, z0), _V(x0, y1, z1), _V(x0, y0, z1)], 0.8),
        (const _V(0, 1, 0), [_V(x0, y1, z0), _V(x1, y1, z0), _V(x1, y1, z1), _V(x0, y1, z1)], 0.66),
        (const _V(0, -1, 0), [_V(x0, y0, z0), _V(x1, y0, z0), _V(x1, y0, z1), _V(x0, y0, z1)], 0.66),
      ];

      // Side face that looks most toward the viewer gets a label too
      var bestSide = -1;
      var bestFacing = 0.0;
      for (var i = 1; i < faces.length; i++) {
        final f = facing(faces[i].$1);
        if (f > bestFacing) {
          bestFacing = f;
          bestSide = i;
        }
      }

      for (var i = 0; i < faces.length; i++) {
        final (n, pts, shade) = faces[i];
        final f = facing(n);
        if (f <= 0) continue;
        final quad = pts.map(proj).toList();
        final color = Color.lerp(AppColors.bgDeep, base, shade)!;
        final path = Path()..addPolygon(quad, true);
        fill.color = color;
        canvas.drawPath(path, fill);
        canvas.drawPath(path, line);
        if ((i == 0 || i == bestSide) && f > 0.2) {
          _drawSticker(canvas, quad, b.id, color.computeLuminance() > 0.35);
        }
      }
    }

    const corners = [
      _V(0, 0, 0), _V(contL, 0, 0), _V(contL, contW, 0), _V(0, contW, 0),
      _V(0, 0, contH), _V(contL, 0, contH), _V(contL, contW, contH), _V(0, contW, contH),
    ];
    const edges = [
      [0, 1], [1, 2], [2, 3], [3, 0],
      [4, 5], [5, 6], [6, 7], [7, 4],
      [0, 4], [1, 5], [2, 6], [3, 7],
    ];
    for (final e in edges) {
      canvas.drawLine(proj(corners[e[0]]), proj(corners[e[1]]), edge);
    }
  }

  /// Draws the ID on a projected face, following the face's slant.
  void _drawSticker(Canvas canvas, List<Offset> q, String id, bool darkText) {
    final c = (q[0] + q[1] + q[2] + q[3]) / 4;
    // Two face axes (mid-edge to mid-edge)
    var u = ((q[1] + q[2]) - (q[0] + q[3])) / 2;
    var v = ((q[2] + q[3]) - (q[0] + q[1])) / 2;
    // Text runs along the more horizontal axis
    if (v.dx.abs() > u.dx.abs()) {
      final t = u;
      u = v;
      v = t;
    }
    if (u.dx < 0) u = -u; // left to right
    if (v.dy < 0) v = -v; // top to bottom
    final lu = u.distance, lv = v.distance;
    if (lu < 14 || lv < 8) return;
    final uu = u / lu, vv = v / lv;
    // Skip faces seen almost edge-on (axes nearly parallel)
    final det = uu.dx * vv.dy - uu.dy * vv.dx;
    if (det < 0.35) return;

    final tp = _label(id, darkText);
    final k = math.min(lu * 0.84 / tp.width, lv * 0.5 / tp.height);
    if (tp.height * k < 5.5) return; // too small to read

    canvas.save();
    canvas.transform(Float64List.fromList([
      uu.dx, uu.dy, 0, 0,
      vv.dx, vv.dy, 0, 0,
      0, 0, 1, 0,
      c.dx, c.dy, 0, 1,
    ]));
    canvas.scale(k);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.yaw != yaw;
}
