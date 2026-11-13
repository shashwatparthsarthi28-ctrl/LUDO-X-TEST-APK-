import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'board_geometry.dart';

/// Static board: yards, 52-square track, home columns, safe stars, centre.
class BoardPainter extends CustomPainter {
  const BoardPainter();

  static const Set<int> _stars = {8, 21, 34, 47};

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 15;
    final full = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cs * 0.6));
    canvas.drawRRect(full, Paint()..color = const Color(0xFF0C0C0C));

    // yards
    for (var seat = 0; seat < 4; seat++) {
      final o = BoardGeometry.yardOrigin(seat);
      final rect = Rect.fromLTWH(o[1] * cs, o[0] * cs, 6 * cs, 6 * cs).deflate(cs * 0.06);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.55)), Paint()..color = Gx.seat[seat]);
      final inner = Rect.fromLTWH((o[1] + 1) * cs, (o[0] + 1) * cs, 4 * cs, 4 * cs);
      canvas.drawRRect(RRect.fromRectAndRadius(inner, Radius.circular(cs * 0.4)), Paint()..color = const Color(0xFF141414));
      for (var t = 0; t < 4; t++) {
        final c = BoardGeometry.yardSlot(seat, t) * cs;
        canvas.drawCircle(c, cs * 0.52, Paint()..color = Gx.seat[seat].withOpacity(0.18));
        canvas.drawCircle(
            c,
            cs * 0.52,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cs * 0.07
              ..color = Gx.seat[seat].withOpacity(0.7));
      }
    }

    // track
    final plain = Paint()..color = const Color(0xFFEFE9D8);
    for (var i = 0; i < BoardGeometry.track.length; i++) {
      final cell = BoardGeometry.track[i];
      final rect = Rect.fromLTWH(cell[1] * cs, cell[0] * cs, cs, cs).deflate(cs * 0.04);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.14));
      final startSeat = i % 13 == 0 ? i ~/ 13 : -1;
      canvas.drawRRect(rr, startSeat >= 0 ? (Paint()..color = Gx.seat[startSeat]) : plain);
      if (_stars.contains(i)) {
        _star(canvas, rect.center, cs * 0.34, Paint()..color = const Color(0xFF8C6D1F));
      }
      if (startSeat >= 0) {
        // small arrow-ish dot to mark the start square
        canvas.drawCircle(rect.center, cs * 0.16, Paint()..color = Colors.white.withOpacity(0.85));
      }
    }

    // home columns
    for (var seat = 0; seat < 4; seat++) {
      for (final cell in BoardGeometry.homeColumn(seat)) {
        final rect = Rect.fromLTWH(cell[1] * cs, cell[0] * cs, cs, cs).deflate(cs * 0.04);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.14)), Paint()..color = Gx.seat[seat].withOpacity(0.9));
      }
    }

    // centre triangles (x = col, y = row)
    Path tri(Offset a, Offset b) => Path()
      ..moveTo(a.dx * cs, a.dy * cs)
      ..lineTo(b.dx * cs, b.dy * cs)
      ..lineTo(7.5 * cs, 7.5 * cs)
      ..close();
    canvas.drawPath(tri(const Offset(6, 6), const Offset(6, 9)), Paint()..color = Gx.seat[0]);
    canvas.drawPath(tri(const Offset(6, 6), const Offset(9, 6)), Paint()..color = Gx.seat[1]);
    canvas.drawPath(tri(const Offset(9, 6), const Offset(9, 9)), Paint()..color = Gx.seat[2]);
    canvas.drawPath(tri(const Offset(6, 9), const Offset(9, 9)), Paint()..color = Gx.seat[3]);
    canvas.drawRect(
        Rect.fromLTWH(6 * cs, 6 * cs, 3 * cs, 3 * cs),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cs * 0.05
          ..color = Colors.black.withOpacity(0.5));
    canvas.drawCircle(Offset(7.5 * cs, 7.5 * cs), cs * 0.22, Paint()..color = Gx.gold);

    // gold frame
    canvas.drawRRect(
        full.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Gx.gold.withOpacity(0.8));
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TokenSpec {
  final int seat;
  final int token;
  final Offset pos;
  final bool movable;
  _TokenSpec(this.seat, this.token, this.pos, this.movable);
}

/// Board + animated tokens. [tokens] is the DISPLAY state (the controller steps
/// it cell by cell for the hop animation). Only seat 0 (the human) is tappable.
class BoardView extends StatefulWidget {
  final List<List<int>> tokens;
  final Set<int> movable;
  final int activeSeat;
  final void Function(int token) onTokenTap;

  const BoardView({
    super.key,
    required this.tokens,
    required this.movable,
    required this.activeSeat,
    required this.onTokenTap,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const List<Offset> _stack = [Offset(-0.2, -0.2), Offset(0.2, -0.2), Offset(-0.2, 0.2), Offset(0.2, 0.2)];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, cons) {
        final cs = cons.maxWidth / 15;
        final specs = <_TokenSpec>[];
        final counts = <String, int>{};
        String keyOf(Offset o) => '${o.dx.toStringAsFixed(2)},${o.dy.toStringAsFixed(2)}';
        for (var s = 0; s < 4; s++) {
          for (var t = 0; t < 4; t++) {
            final pos = BoardGeometry.position(s, t, widget.tokens[s][t]);
            counts[keyOf(pos)] = (counts[keyOf(pos)] ?? 0) + 1;
            specs.add(_TokenSpec(s, t, pos, s == 0 && widget.movable.contains(t)));
          }
        }
        final seen = <String, int>{};
        final children = <Widget>[
          const Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: BoardPainter()))),
        ];

        // glow around the yard of the seat whose turn it is
        final o = BoardGeometry.yardOrigin(widget.activeSeat);
        children.add(Positioned(
          left: o[1] * cs,
          top: o[0] * cs,
          width: 6 * cs,
          height: 6 * cs,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cs * 0.6),
                  border: Border.all(color: Gx.goldLight.withOpacity(0.35 + 0.55 * _pulse.value), width: 2.5),
                ),
              ),
            ),
          ),
        ));

        specs.sort((a, b) {
          if (a.movable != b.movable) return a.movable ? 1 : -1;
          return a.seat.compareTo(b.seat);
        });

        for (final sp in specs) {
          final k = keyOf(sp.pos);
          final n = counts[k]!;
          final idx = seen[k] ?? 0;
          seen[k] = idx + 1;
          final stacked = n > 1;
          final off = stacked ? _stack[idx % 4] : Offset.zero;
          final center = (sp.pos + off) * cs;
          final box = cs * 0.98;
          final d = stacked ? cs * 0.5 : cs * 0.72;
          children.add(AnimatedPositioned(
            key: ValueKey('tok-${sp.seat}-${sp.token}'),
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOutCubic,
            left: center.dx - box / 2,
            top: center.dy - box / 2,
            width: box,
            height: box,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: sp.movable ? () => widget.onTokenTap(sp.token) : null,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) {
                    final scale = sp.movable ? 1.0 + 0.14 * _pulse.value : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: _TokenDot(color: Gx.seat[sp.seat], diameter: d, highlight: sp.movable, label: stacked ? null : '${sp.token + 1}'),
                ),
              ),
            ),
          ));
        }
        return Stack(clipBehavior: Clip.none, children: children);
      }),
    );
  }
}

class _TokenDot extends StatelessWidget {
  final Color color;
  final double diameter;
  final bool highlight;
  final String? label;
  const _TokenDot({required this.color, required this.diameter, required this.highlight, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.35)!],
          stops: const [0.0, 0.55, 1.0],
          center: const Alignment(-0.3, -0.35),
        ),
        border: Border.all(color: highlight ? Gx.goldLight : Colors.white, width: highlight ? 3 : 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 5, offset: const Offset(0, 2)),
          if (highlight) BoxShadow(color: Gx.gold.withOpacity(0.7), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      alignment: Alignment.center,
      child: label == null
          ? null
          : Text(label!,
              style: TextStyle(
                fontSize: diameter * 0.42,
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.65),
              )),
    );
  }
}
