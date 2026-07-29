import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 회전 가능한 3D 포인트클라우드 뷰어.
///
/// 현재는 처리 백엔드 연동 전이라 데모용 점군(표면 회전체)을 렌더링한다.
/// 실제 재구성 결과(.ply/.las 등)는 백엔드 연동 시 이 점군을 대체하면 된다.
class PointCloudViewerScreen extends StatefulWidget {
  const PointCloudViewerScreen({super.key, required this.projectName});
  final String projectName;

  @override
  State<PointCloudViewerScreen> createState() => _PointCloudViewerScreenState();
}

class _PointCloudViewerScreenState extends State<PointCloudViewerScreen>
    with SingleTickerProviderStateMixin {
  late final List<_P3> _points;
  late final Ticker _ticker;
  double _rotX = -0.25;
  double _rotY = 0.0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _points = _generatePoints();
    _ticker = createTicker((_) {
      if (!_dragging) setState(() => _rotY += 0.005);
    })..start();
  }

  /// 회전체(꽃병 형태) 표면을 샘플링한 데모 점군.
  List<_P3> _generatePoints() {
    final rnd = Random(42);
    final pts = <_P3>[];
    const rings = 40;
    const seg = 68;
    for (int i = 0; i <= rings; i++) {
      final t = i / rings; // 0..1 (높이)
      final y = (t - 0.5) * 1.7;
      final r = 0.26 + 0.42 * sin(t * pi) * (0.7 + 0.3 * sin(t * pi * 3));
      for (int j = 0; j < seg; j++) {
        final theta = (j / seg) * 2 * pi;
        final jitter = (rnd.nextDouble() - 0.5) * 0.025;
        final rr = r + jitter;
        pts.add(_P3(rr * cos(theta), y + jitter, rr * sin(theta), t));
      }
    }
    return pts;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('${widget.projectName} · 3D'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onPanStart: (_) => _dragging = true,
              onPanUpdate: (d) => setState(() {
                _rotY += d.delta.dx * 0.01;
                _rotX = (_rotX + d.delta.dy * 0.01).clamp(-1.4, 1.4);
              }),
              onPanEnd: (_) => _dragging = false,
              child: CustomPaint(
                painter: _PointCloudPainter(_points, _rotX, _rotY),
                size: Size.infinite,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            color: Colors.black.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.blur_on, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('포인트클라우드 · ${_points.length}점',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.threed_rotation,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('드래그해서 회전',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '데모 점군입니다. 실제 재구성 결과는 처리 백엔드 연동 시 표시됩니다.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _P3 {
  const _P3(this.x, this.y, this.z, this.h);
  final double x, y, z;
  final double h; // 높이 0..1 (색상용)
}

class _Proj {
  const _Proj(this.dx, this.dy, this.depth, this.h);
  final double dx, dy, depth, h;
}

class _PointCloudPainter extends CustomPainter {
  _PointCloudPainter(this.points, this.rotX, this.rotY);
  final List<_P3> points;
  final double rotX, rotY;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = min(size.width, size.height) * 0.34;
    const persp = 3.6;

    final cosY = cos(rotY), sinY = sin(rotY);
    final cosX = cos(rotX), sinX = sin(rotX);

    final projected = <_Proj>[];
    for (final p in points) {
      final x1 = p.x * cosY - p.z * sinY;
      final z1 = p.x * sinY + p.z * cosY;
      final y2 = p.y * cosX - z1 * sinX;
      final z2 = p.y * sinX + z1 * cosX;
      final f = persp / (persp - z2);
      projected.add(_Proj(cx + x1 * scale * f, cy - y2 * scale * f, z2, p.h));
    }
    projected.sort((a, b) => a.depth.compareTo(b.depth)); // 먼 점 먼저

    final paint = Paint()..style = PaintingStyle.fill;
    for (final pr in projected) {
      final depth = ((pr.depth + 1.0) / 2.0).clamp(0.0, 1.0);
      final base = Color.lerp(
        const Color(0xFF4C6FFF),
        const Color(0xFF35E0D0),
        pr.h,
      )!;
      paint.color = base.withValues(alpha: 0.30 + depth * 0.70);
      canvas.drawCircle(Offset(pr.dx, pr.dy), 1.1 + depth * 1.9, paint);
    }
  }

  @override
  bool shouldRepaint(_PointCloudPainter old) =>
      old.rotX != rotX || old.rotY != rotY;
}
