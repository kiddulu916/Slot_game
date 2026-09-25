import 'package:flutter/material.dart';

import '../engine/spin_result.dart';
import '../game/game_sound.dart';
import 'app_theme.dart';

/// How loudly a win is celebrated.
///
/// Tiers are set against the stake rather than the credit total, so a big win
/// feels big at every bet level.
enum WinTier {
  /// Below the stake: the reels paid, but the spin still lost money.
  small(0, '', Colors.white, GameSound.winSmall),
  nice(2, 'NICE WIN', AppTheme.mint, GameSound.winSmall),
  big(8, 'BIG WIN', AppTheme.gold, GameSound.winBig),
  mega(25, 'MEGA WIN', AppTheme.violet, GameSound.winBig),
  jackpot(100, 'JACKPOT', AppTheme.crimson, GameSound.winJackpot);

  const WinTier(this.minMultiple, this.title, this.colour, this.sound);

  /// Win-to-stake ratio this tier starts at.
  final int minMultiple;
  final String title;
  final Color colour;

  /// The clip that plays when a win of this size lands.
  final GameSound sound;

  static WinTier of(SpinResult result) {
    if (!result.isWin) {
      return WinTier.small;
    }
    WinTier tier = WinTier.small;
    for (final WinTier candidate in WinTier.values) {
      if (result.winMultiple >= candidate.minMultiple) {
        tier = candidate;
      }
    }
    return tier;
  }

  bool get isCelebrated => title.isNotEmpty;
}

/// The banner that flies in over the reels on a sizeable win.
class WinBanner extends StatefulWidget {
  const WinBanner({required this.result, super.key});

  /// The spin being celebrated, or null when there is nothing to shout about.
  final SpinResult? result;

  @override
  State<WinBanner> createState() => _WinBannerState();
}

class _WinBannerState extends State<WinBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    if (_tier.isCelebrated) {
      _controller.forward();
    }
  }

  WinTier get _tier {
    final SpinResult? result = widget.result;
    return result == null ? WinTier.small : WinTier.of(result);
  }

  @override
  void didUpdateWidget(WinBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result == oldWidget.result) {
      return;
    }
    if (_tier.isCelebrated) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SpinResult? result = widget.result;
    final WinTier tier = _tier;
    if (result == null || !tier.isCelebrated) {
      return const SizedBox.shrink();
    }

    final Animation<double> entrance = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: entrance,
          builder: (BuildContext context, Widget? child) => Opacity(
            opacity: _controller.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.7 + 0.3 * entrance.value,
              child: child,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppTheme.feltDeep.withValues(alpha: 0.88),
              border: Border.all(color: tier.colour, width: 2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tier.colour.withValues(alpha: 0.5),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  tier.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: tier.colour,
                    shadows: <Shadow>[
                      Shadow(color: tier.colour, blurRadius: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.totalPayout} credits',
                  style: AppTheme.counter.copyWith(fontSize: 18),
                ),
                Text(
                  '${result.winMultiple.toStringAsFixed(1)}x bet',
                  style: AppTheme.label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
