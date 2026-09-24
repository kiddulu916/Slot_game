import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/paytable.dart';
import '../engine/spin_result.dart';
import 'symbol_art.dart';

/// Traces the winning paylines across the grid.
///
/// Every win is drawn faintly so the player can see how many came in, and one
/// at a time is brought forward with its payout, cycling until the next spin.
/// That is how a real machine explains a win that covers several lines at once.
class PaylineOverlay extends StatefulWidget {
  const PaylineOverlay({
    required this.wins,
    required this.cellWidth,
    required this.cellHeight,
    required this.reelGap,
    super.key,
  });

  final List<LineWin> wins;

  final double cellWidth;
  final double cellHeight;

  /// Horizontal space between reels.
  final double reelGap;

  /// How long each line is held in front.
  static const Duration cycleInterval = Duration(milliseconds: 1100);

  @override
  State<PaylineOverlay> createState() => _PaylineOverlayState();
}

class _PaylineOverlayState extends State<PaylineOverlay> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartCycle();
  }

  @override
  void didUpdateWidget(PaylineOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wins.length != oldWidget.wins.length ||
        !identical(widget.wins, oldWidget.wins)) {
      _index = 0;
      _restartCycle();
    }
  }

  void _restartCycle() {
    _timer?.cancel();
    if (widget.wins.length < 2) {
      return;
    }
    _timer = Timer.periodic(PaylineOverlay.cycleInterval, (Timer timer) {
      if (!mounted) {
        return;
      }
      setState(() => _index = (_index + 1) % widget.wins.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wins.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _PaylinePainter(
          wins: widget.wins,
          focused: _index % widget.wins.length,
          cellWidth: widget.cellWidth,
          cellHeight: widget.cellHeight,
          reelGap: widget.reelGap,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _PaylinePainter extends CustomPainter {
  _PaylinePainter({
    required this.wins,
    required this.focused,
    required this.cellWidth,
    required this.cellHeight,
    required this.reelGap,
    required this.textDirection,
  });

  final List<LineWin> wins;
  final int focused;
  final double cellWidth;
  final double cellHeight;
  final double reelGap;
  final TextDirection textDirection;

  Offset _centreOf(int reel, int row) => Offset(
    reel * (cellWidth + reelGap) + cellWidth / 2,
    row * cellHeight + cellHeight / 2,
  );

  /// The path a payline takes across the cells it won on.
  Path _pathFor(LineWin win) {
    final List<int> line = Paytable.paylines[win.lineIndex];
    final Path path = Path();
    // Start at the left edge and finish past the last winning reel so the line
    // reads as running through the grid rather than stopping inside a cell.
    path.moveTo(0, _centreOf(0, line[0]).dy);
    for (int reel = 0; reel < win.matchCount; reel++) {
      final Offset centre = _centreOf(reel, line[reel]);
      path.lineTo(centre.dx, centre.dy);
    }
    final Offset last = _centreOf(win.matchCount - 1, line[win.matchCount - 1]);
    path.lineTo(last.dx + cellWidth / 2, last.dy);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < wins.length; i++) {
      final bool isFocused = i == focused;
      final LineWin win = wins[i];
      final Color tint = SymbolStyle.of(win.symbol).tint;
      final Path path = _pathFor(win);

      if (isFocused) {
        // A soft wide stroke under the line reads as a glow.
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = tint.withValues(alpha: 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isFocused ? 3 : 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = tint.withValues(alpha: isFocused ? 0.95 : 0.22),
      );

      if (isFocused) {
        _paintBadge(canvas, win, tint, _pathStart(win));
      }
    }
  }

  Offset _pathStart(LineWin win) {
    final List<int> line = Paytable.paylines[win.lineIndex];
    return Offset(0, _centreOf(0, line[0]).dy);
  }

  /// The line number and its payout, pinned to the left edge of the line.
  void _paintBadge(Canvas canvas, LineWin win, Color tint, Offset anchor) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: ' ${win.lineIndex + 1} · ${win.payout} ',
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.88),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    final Rect box = Rect.fromLTWH(
      anchor.dx + 2,
      anchor.dy - painter.height / 2 - 2,
      painter.width,
      painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(7)),
      Paint()..color = tint,
    );
    painter.paint(canvas, Offset(box.left, box.top + 2));
  }

  @override
  bool shouldRepaint(_PaylinePainter oldDelegate) =>
      oldDelegate.focused != focused ||
      oldDelegate.wins != wins ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight;
}
