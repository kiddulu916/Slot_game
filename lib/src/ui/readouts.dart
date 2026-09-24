import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A labelled number in the machine's display strip.
class Readout extends StatelessWidget {
  const Readout({
    required this.label,
    required this.value,
    this.accent = Colors.white,
    this.emphasise = false,
    super.key,
  });

  final String label;
  final String value;
  final Color accent;

  /// Draws the value larger, for the credit balance.
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    // Both lines scale down rather than overflow: a seven-figure balance and
    // a long label like FREE SPINS both have to fit the same slot.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: AppTheme.label, maxLines: 1),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: AppTheme.counter.copyWith(
              fontSize: emphasise ? 24 : 17,
              color: accent,
              shadows: <Shadow>[
                Shadow(color: accent.withValues(alpha: 0.45), blurRadius: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A number that rolls up to its new value instead of jumping.
///
/// Watching credits climb is a large part of why winning feels good, so the
/// balance and the win counter both animate.
class RollingNumber extends StatelessWidget {
  const RollingNumber({
    required this.value,
    required this.label,
    this.accent = Colors.white,
    this.emphasise = false,
    this.duration = const Duration(milliseconds: 650),
    this.prefix = '',
    super.key,
  });

  final int value;
  final String label;
  final Color accent;
  final bool emphasise;
  final Duration duration;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return _RollingInt(
      value: value,
      duration: duration,
      builder: (BuildContext context, int shown) => Readout(
        label: label,
        value: '$prefix${_grouped(shown)}',
        accent: accent,
        emphasise: emphasise,
      ),
    );
  }

  static String _grouped(int value) {
    final String digits = value.abs().toString();
    final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        out.write(',');
      }
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// Animates an integer towards [value] whenever it changes.
///
/// Named to avoid confusion with Flutter's own TweenAnimationBuilder; this one
/// keeps the on-screen figure as its start point so a win landing mid-roll
/// continues smoothly instead of snapping back.
class _RollingInt extends StatefulWidget {
  const _RollingInt({
    required this.value,
    required this.duration,
    required this.builder,
  });

  final int value;
  final Duration duration;
  final Widget Function(BuildContext context, int shown) builder;

  @override
  State<_RollingInt> createState() => _RollingIntState();
}

class _RollingIntState extends State<_RollingInt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _from;
  late int _to;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
    _to = _from;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..value = 1;
  }

  @override
  void didUpdateWidget(_RollingInt oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int next = widget.value;
    if (next == _to) {
      return;
    }
    // Start from whatever is on screen so rapid changes do not jump.
    _from = _currentValue;
    _to = next;
    _controller
      ..duration = widget.duration
      ..forward(from: 0);
  }

  int get _currentValue {
    final double eased = Curves.easeOutCubic.transform(_controller.value);
    return (_from + (_to - _from) * eased).round();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) =>
          widget.builder(context, _currentValue),
    );
  }
}
