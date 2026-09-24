import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/game_symbol.dart';
import '../engine/paytable.dart';
import '../game/spin_timing.dart';
import 'app_theme.dart';
import 'symbol_art.dart';

/// One spinning column.
///
/// The reel scrolls its band to a stop the engine has already chosen, so the
/// animation reveals the outcome rather than deciding it. Position is measured
/// in band steps: at rest, a position of `n` puts band symbol `n` in the top
/// row. Spinning counts the position *down* so symbols travel downwards and
/// new ones arrive from above, the way a physical reel turns.
class ReelView extends StatefulWidget {
  const ReelView({
    required this.reelIndex,
    required this.band,
    required this.stop,
    required this.spinning,
    required this.turbo,
    required this.cellSize,
    required this.highlightedRows,
    required this.pulse,
    super.key,
  });

  final int reelIndex;
  final List<GameSymbol> band;

  /// Band position the reel is resting at, or travelling towards.
  final int stop;

  /// True while this spin's reels are still turning.
  final bool spinning;

  final bool turbo;
  final double cellSize;

  /// Rows that took part in a win, highlighted once the reels stop.
  final Set<int> highlightedRows;

  /// Shared 0..1 pulse that makes every winning cell breathe in step.
  final Animation<double> pulse;

  @override
  State<ReelView> createState() => _ReelViewState();
}

class _ReelViewState extends State<ReelView>
    with SingleTickerProviderStateMixin {
  /// Whole turns of the band before it settles, so the reel looks like it
  /// picked up real speed. Later reels spin longer, so they turn more.
  static const int _baseRotations = 3;

  late final AnimationController _controller;
  late Animation<double> _position;

  /// The curve the reel is following, kept so the motion blur can sample its
  /// slope. An [Animation] only exposes its value at the current instant.
  Animatable<double>? _positionCurve;

  double _restPosition = 0;

  @override
  void initState() {
    super.initState();
    _restPosition = widget.stop.toDouble();
    _controller = AnimationController(vsync: this);
    _position = AlwaysStoppedAnimation<double>(_restPosition);
    if (widget.spinning) {
      _startSpin();
    }
  }

  @override
  void didUpdateWidget(ReelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !oldWidget.spinning) {
      _startSpin();
    } else if (!widget.spinning &&
        !_controller.isAnimating &&
        widget.stop != oldWidget.stop) {
      // Landed a result without animating, e.g. restored state.
      setState(() {
        _restPosition = widget.stop.toDouble();
        _positionCurve = null;
        _position = AlwaysStoppedAnimation<double>(_restPosition);
      });
    }
  }

  void _startSpin() {
    final int bandLength = widget.band.length;
    final double from = _restPosition;

    // Counting down lands on the target once the whole turns are stripped off.
    final double stepsToTarget = (from - widget.stop) % bandLength;
    final int rotations = _baseRotations + widget.reelIndex;
    final double travel = rotations * bandLength + stepsToTarget;
    final double to = from - travel;

    // The reel runs past its stop and eases back, which reads as the band
    // catching on its detent.
    const double overshoot = 0.34;

    _controller
      ..stop()
      ..duration = SpinTiming.reelStop(widget.reelIndex, turbo: widget.turbo)
      ..value = 0;

    final Animatable<double> curve = TweenSequence<double>(
      <TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: from,
            end: to - overshoot,
          ).chain(CurveTween(curve: Curves.easeOutQuart)),
          weight: 86,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: to - overshoot,
            end: to,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 14,
        ),
      ],
    );
    _positionCurve = curve;
    _position = curve.animate(_controller);

    _restPosition = to;
    _controller.forward();
  }

  /// Blur that tracks how fast the band is moving, in band steps per second.
  double _blurFor(double stepsPerSecond) {
    const double maxSigma = 13;
    final double sigma = stepsPerSecond * widget.cellSize / 420;
    return sigma.clamp(0, maxSigma);
  }

  @override
  Widget build(BuildContext context) {
    final double cell = widget.cellSize;
    final double height = cell * Paytable.rowCount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: cell,
        height: height,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_position, widget.pulse]),
          builder: (BuildContext context, Widget? child) {
            final double position = _position.value;
            final int base = position.floor();
            final double fraction = position - base;

            // Rate of change of the tween, used for the motion blur.
            final double speed = _controller.isAnimating
                ? _instantaneousSpeed()
                : 0;
            final double sigma = _blurFor(speed);

            // One extra cell above and below keeps the scroll seamless.
            final List<Widget> cells = <Widget>[
              for (int offset = -1; offset <= Paytable.rowCount; offset++)
                Positioned(
                  left: 0,
                  right: 0,
                  top: (offset - fraction) * cell,
                  height: cell,
                  child: _ReelCell(
                    symbol: widget.band[(base + offset) % widget.band.length],
                    size: cell,
                    // Highlights only make sense once the reel has stopped.
                    highlight:
                        !widget.spinning &&
                        widget.highlightedRows.contains(offset),
                    pulse: widget.pulse.value,
                  ),
                ),
            ];

            final Widget stack = Stack(children: cells);

            return sigma < 0.4
                ? stack
                : ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaY: sigma,
                      tileMode: TileMode.decal,
                    ),
                    child: stack,
                  );
          },
        ),
      ),
    );
  }

  /// Band steps per second at this instant, sampled off the tween.
  double _instantaneousSpeed() {
    final Animatable<double>? curve = _positionCurve;
    final Duration? duration = _controller.duration;
    if (curve == null || duration == null || duration.inMilliseconds == 0) {
      return 0;
    }
    // Slope of the curve either side of now, in band steps per second.
    const double delta = 0.008;
    final double t = _controller.value;
    final double ahead = (t + delta).clamp(0.0, 1.0);
    final double behind = (t - delta).clamp(0.0, 1.0);
    if (ahead == behind) {
      return 0;
    }
    final double seconds = (ahead - behind) * duration.inMilliseconds / 1000;
    final double steps = (curve.transform(ahead) - curve.transform(behind))
        .abs();
    return steps / seconds;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// A single symbol cell, with its win highlight.
class _ReelCell extends StatelessWidget {
  const _ReelCell({
    required this.symbol,
    required this.size,
    required this.highlight,
    required this.pulse,
  });

  final GameSymbol symbol;
  final double size;
  final bool highlight;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final Color tint = SymbolStyle.of(symbol).tint;
    // 0 at the bottom of the pulse, 1 at the top.
    final double glow = highlight ? pulse : 0;

    return Padding(
      padding: EdgeInsets.all(size * 0.045),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(const Color(0xFF1B2438), tint, 0.10 + 0.28 * glow)!,
              Color.lerp(const Color(0xFF111827), tint, 0.04 + 0.16 * glow)!,
            ],
          ),
          border: Border.all(
            color: highlight
                ? Color.lerp(tint.withValues(alpha: 0.5), tint, glow)!
                : AppTheme.cabinetEdge.withValues(alpha: 0.7),
            width: highlight ? 2 : 1,
          ),
          boxShadow: highlight
              ? <BoxShadow>[
                  BoxShadow(
                    color: tint.withValues(alpha: 0.25 + 0.35 * glow),
                    blurRadius: 12 + 14 * glow,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: SymbolArt(symbol: symbol, size: size, highlighted: highlight),
      ),
    );
  }
}
