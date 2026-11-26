import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/containers.dart';
import '../../domain/planning.dart';

/// Interactive 3D view of a plan: drag to rotate, pinch to zoom, tap a box to select it.
/// Every box shows its ID on the top face and on the side facing the viewer.
class PlanView extends StatefulWidget {
  final ContainerDims container;
  final List<PlanBox> boxes; // loading order
  final int? visibleCount; // steps mode: only the first n boxes
  final String? highlightId;
  final ValueChanged<PlanBox?>? onTapBox;
  final double height;

  const PlanView({
    super.key,
    required this.container,
    required this.boxes,
    this.visibleCount,
    this.highlightId,
    this.onTapBox,
    this.height = 300,
  });

  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  double _yaw = -0.65;
  double _pitch = 0.5;
  double _zoom = 1.0;
  double _startZoom = 1.0;

  List<PlanBox> get _shown {
    final n = widget.visibleCount;
    return n == null ? widget.boxes : widget.boxes.take(n).toList();
  }

  void _reset() => setState(() {
        _yaw = -0.65;
        _pitch = 0.5;
        _zoom = 1.0;
      });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = Size(box.maxWidth, widget.height);
          final scene = Scene3D(size, widget.container, _shown, _yaw, _pitch, _zoom);
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onScaleStart: (_) => _startZoom = _zoom,
                  onScaleUpdate: (d) => setState(() {
                    if (d.pointerCount > 1) {
                      _zoom = (_startZoom * d.scale).clamp(0.6, 4.0);
                    } else {
                      _yaw += d.focalPointDelta.dx * 0.01;
                      _pitch = (_pitch + d.focalPointDelta.dy * 0.006).clamp(0.08, 1.4);
                    }
                  }),
                  onTapUp: widget.onTapBox == null ? null : (d) => widget.onTapBox!(scene.hit(d.localPosition)),
                  onDoubleTap: _reset,
                  child: CustomPaint(
                    painter: _PlanPainter(scene, widget.highlightId),
                    size: size,
                  ),
                ),
              ),
              PositionedDirectional(
                top: 6,
                end: 6,
                child: IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.center_focus_strong, size: 18),
                  onPressed: _reset,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Camera, projection and drawing order for one frame.
class Scene3D {
  final Size size;
  final ContainerDims c;
  final List<PlanBox> boxes;
  late final double _cy, _sy, _cp, _sp, _scale;
  late final Offset _center;
  late final List<PlanBox> order; // back to front

  Scene3D(this.size, this.c, this.boxes, double yaw, double pitch, double zoom) {
    _cy = math.cos(yaw);
    _sy = math.sin(yaw);
    _cp = math.cos(pitch);
    _sp = math.sin(pitch);
    final span = math.sqrt(c.length * c.length + c.width * c.width).toDouble();
    _scale = math.min(size.width / (span * 1.12), size.height / ((c.height + span * 0.5) * 1.15)) * zoom;
    _center = Offset(size.width / 2, size.height / 2);
    order = _sortBackToFront();
  }

  (double, double, double) _rot(double x, double y, double z) {
    final px = x - c.length / 2, py = y - c.width / 2, pz = z - c.height / 2;
    final x1 = px * _cy - py * _sy;
    final y1 = px * _sy + py * _cy;
    return (x1, y1 * _cp - pz * _sp, pz * _cp + y1 * _sp);
  }

  Offset proj(double x, double y, double z) {
    final (x1, depth, up) = _rot(x, y, z);
    final focal = 4.0 * math.max(c.length, c.width);
    final f = focal / (focal + depth);
    return _center + Offset(x1 * f * _scale, -up * f * _scale);
  }

  /// > 0 when a face with this world normal looks toward the camera
  double facing(double nx, double ny, double nz) {
    final n1 = nx * _sy + ny * _cy;
    return -n1 * _cp + nz * _sp;
  }

  // Depth grows along these world directions (used for ordering)
  double get _gx => _sy * _cp;
  double get _gy => _cy * _cp;
  double get _gz => -_sp;

  /// True when [a] must be drawn before [b] (a is behind b), null when the order does not
  /// matter. If several axes separate the boxes and disagree, their images cannot overlap.
  bool? _behind(PlanBox a, PlanBox b) {
    var yes = 0, no = 0;
    void vote(bool v) => v ? yes++ : no++;
    if (a.x + a.dx <= b.x) vote(_gx < 0);
    if (b.x + b.dx <= a.x) vote(_gx > 0);
    if (a.y + a.dy <= b.y) vote(_gy < 0);
    if (b.y + b.dy <= a.y) vote(_gy > 0);
    if (a.z + a.dz <= b.z) vote(_gz < 0);
    if (b.z + b.dz <= a.z) vote(_gz > 0);
    if (yes > 0 && no == 0) return true;
    if (no > 0 && yes == 0) return false;
    return null;
  }

  Rect _screenRect(PlanBox b) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final x in [b.x, b.x + b.dx]) {
      for (final y in [b.y, b.y + b.dy]) {
        for (final z in [b.z, b.z + b.dz]) {
          final o = proj(x.toDouble(), y.toDouble(), z.toDouble());
          minX = math.min(minX, o.dx);
          minY = math.min(minY, o.dy);
          maxX = math.max(maxX, o.dx);
          maxY = math.max(maxY, o.dy);
        }
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Topological sort on "is behind" for boxes whose screen areas overlap.
  List<PlanBox> _sortBackToFront() {
    final n = boxes.length;
    final rects = [for (final b in boxes) _screenRect(b)];
    final after = List.generate(n, (_) => <int>[]);
    final indeg = List.filled(n, 0);
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (!rects[i].overlaps(rects[j])) continue;
        final r = _behind(boxes[i], boxes[j]);
        if (r == null) continue;
        if (r) {
          after[i].add(j);
          indeg[j]++;
        } else {
          after[j].add(i);
          indeg[i]++;
        }
      }
    }
    // Kahn, ties broken by depth of the centre
    double depth(int i) {
      final b = boxes[i];
      return _rot(b.x + b.dx / 2, b.y + b.dy / 2, b.z + b.dz / 2).$2;
    }

    final ready = [for (var i = 0; i < n; i++) if (indeg[i] == 0) i]..sort((a, b) => depth(b).compareTo(depth(a)));
    final out = <PlanBox>[];
    final done = List.filled(n, false);
    while (ready.isNotEmpty) {
      final i = ready.removeAt(0);
      done[i] = true;
      out.add(boxes[i]);
      for (final j in after[i]) {
        if (--indeg[j] == 0) ready.add(j);
      }
    }
    // A cycle should not happen; fall back to depth order for anything left
    if (out.length < n) {
      final rest = [for (var i = 0; i < n; i++) if (!done[i]) i]..sort((a, b) => depth(b).compareTo(depth(a)));
      out.addAll(rest.map((i) => boxes[i]));
    }
    return out;
  }

  /// Visible faces of a box: (normal facing, corner points, shade, isTop).
  List<(double, List<Offset>, double, bool)> faces(PlanBox b) {
    final x0 = b.x.toDouble(), x1 = (b.x + b.dx).toDouble();
    final y0 = b.y.toDouble(), y1 = (b.y + b.dy).toDouble();
    final z0 = b.z.toDouble(), z1 = (b.z + b.dz).toDouble();
    final all = <(double, List<Offset>, double, bool)>[
      (facing(0, 0, 1), [proj(x0, y0, z1), proj(x1, y0, z1), proj(x1, y1, z1), proj(x0, y1, z1)], 1.0, true),
      (facing(1, 0, 0), [proj(x1, y0, z0), proj(x1, y1, z0), proj(x1, y1, z1), proj(x1, y0, z1)], 0.8, false),
      (facing(-1, 0, 0), [proj(x0, y0, z0), proj(x0, y1, z0), proj(x0, y1, z1), proj(x0, y0, z1)], 0.8, false),
      (facing(0, 1, 0), [proj(x0, y1, z0), proj(x1, y1, z0), proj(x1, y1, z1), proj(x0, y1, z1)], 0.66, false),
      (facing(0, -1, 0), [proj(x0, y0, z0), proj(x1, y0, z0), proj(x1, y0, z1), proj(x0, y0, z1)], 0.66, false),
    ];
    return [for (final f in all) if (f.$1 > 0) f];
  }

  /// Front-most box under a screen point.
  PlanBox? hit(Offset p) {
    for (final b in order.reversed) {
      for (final f in faces(b)) {
        if ((Path()..addPolygon(f.$2, true)).contains(p)) return b;
      }
    }
    return null;
  }
}

// Labels are laid out once per text and then scaled.
const double _baseFont = 20;
final Map<String, TextPainter> _labels = {};

TextPainter _label(String text, bool dark) => _labels.putIfAbsent('$text|$dark', () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: _baseFont,
            fontWeight: FontWeight.w800,
            color: dark ? const Color(0xFF0A1024) : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });

class _PlanPainter extends CustomPainter {
  final Scene3D s;
  final String? highlightId;
  _PlanPainter(this.s, this.highlightId);

  @override
  void paint(Canvas canvas, Size size) {
    final c = s.c;
    final cl = c.length.toDouble(), cw = c.width.toDouble(), chh = c.height.toDouble();

    canvas.drawPath(
      Path()..addPolygon([s.proj(0, 0, 0), s.proj(cl, 0, 0), s.proj(cl, cw, 0), s.proj(0, cw, 0)], true),
      Paint()..color = AppColors.blue.withValues(alpha: 0.16),
    );
    // Door marker at x = length
    canvas.drawPath(
      Path()..addPolygon([s.proj(cl, 0, 0), s.proj(cl, cw, 0), s.proj(cl, cw, chh), s.proj(cl, 0, chh)], true),
      Paint()..color = AppColors.cyan.withValues(alpha: 0.05),
    );

    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.bgDeep.withValues(alpha: 0.9);
    final hl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.white;

    for (final b in s.order) {
      final base = AppColors.group(b.group);
      final faces = s.faces(b);
      var bestSide = -1;
      var bestFacing = 0.0;
      for (var i = 0; i < faces.length; i++) {
        if (!faces[i].$4 && faces[i].$1 > bestFacing) {
          bestFacing = faces[i].$1;
          bestSide = i;
        }
      }
      final isHl = b.id == highlightId;
      for (var i = 0; i < faces.length; i++) {
        final (f, quad, shade, top) = faces[i];
        final color = Color.lerp(AppColors.bgDeep, base, isHl ? 1.0 : shade)!;
        final path = Path()..addPolygon(quad, true);
        fill.color = color;
        canvas.drawPath(path, fill);
        canvas.drawPath(path, isHl ? hl : line);
        if ((top || i == bestSide) && f > 0.2) _sticker(canvas, quad, b.label, color.computeLuminance() > 0.35);
      }
    }

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = AppColors.cyan.withValues(alpha: 0.6);
    final k = [
      [0.0, 0.0, 0.0], [cl, 0.0, 0.0], [cl, cw, 0.0], [0.0, cw, 0.0],
      [0.0, 0.0, chh], [cl, 0.0, chh], [cl, cw, chh], [0.0, cw, chh],
    ].map((v) => s.proj(v[0], v[1], v[2])).toList();
    const edges = [
      [0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7],
    ];
    for (final e in edges) {
      canvas.drawLine(k[e[0]], k[e[1]], edge);
    }
  }

  void _sticker(Canvas canvas, List<Offset> q, String text, bool darkText) {
    final c = (q[0] + q[1] + q[2] + q[3]) / 4;
    var u = ((q[1] + q[2]) - (q[0] + q[3])) / 2;
    var v = ((q[2] + q[3]) - (q[0] + q[1])) / 2;
    if (v.dx.abs() > u.dx.abs()) {
      final t = u;
      u = v;
      v = t;
    }
    if (u.dx < 0) u = -u;
    if (v.dy < 0) v = -v;
    final lu = u.distance, lv = v.distance;
    if (lu < 14 || lv < 8) return;
    final uu = u / lu, vv = v / lv;
    if (uu.dx * vv.dy - uu.dy * vv.dx < 0.35) return;
    final tp = _label(text, darkText);
    final k = math.min(lu * 0.84 / tp.width, lv * 0.5 / tp.height);
    if (tp.height * k < 5.5) return;
    canvas.save();
    canvas.transform(Float64List.fromList([uu.dx, uu.dy, 0, 0, vv.dx, vv.dy, 0, 0, 0, 0, 1, 0, c.dx, c.dy, 0, 1]));
    canvas.scale(k);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanPainter old) => true;
}

/// Draws a plan into a PNG without showing it on screen (used by the PDF report).
Future<Uint8List?> renderPlanPng(ContainerDims c, List<PlanBox> boxes,
    {double width = 1100, double height = 760}) async {
  final size = Size(width, height);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.panel2);
  _PlanPainter(Scene3D(size, c, boxes, -0.65, 0.5, 1.0), null).paint(canvas, size);
  final image = await recorder.endRecording().toImage(width.round(), height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
