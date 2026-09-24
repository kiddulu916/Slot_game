import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/paytable.dart';
import '../game/game_controller.dart';
import 'app_theme.dart';

/// The bet ladder, the spin button and the toggles beside it.
class ControlsBar extends StatelessWidget {
  const ControlsBar({
    required this.game,
    required this.onShowPaytable,
    super.key,
  });

  final GameController game;
  final VoidCallback onShowPaytable;

  @override
  Widget build(BuildContext context) {
    // Free spins are played at the bet that triggered them, so the ladder locks.
    final bool betLocked = game.isSpinning || game.inFreeSpins;

    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _IconToggle(
              icon: Icons.table_rows_rounded,
              label: 'Pays',
              onPressed: onShowPaytable,
            ),
            _IconToggle(
              icon: Icons.bolt_rounded,
              label: 'Turbo',
              active: game.turbo,
              onPressed: () => game.setTurbo(!game.turbo),
            ),
            _IconToggle(
              icon: game.autoplay
                  ? Icons.stop_circle_outlined
                  : Icons.all_inclusive_rounded,
              label: game.autoplay ? 'Stop' : 'Auto',
              active: game.autoplay,
              onPressed: game.canSpin || game.autoplay
                  ? game.toggleAutoplay
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _BetStepper(
              icon: Icons.remove_rounded,
              onPressed: betLocked
                  ? null
                  : () => game.changeBet(increase: false),
            ),
            _SpinButton(game: game),
            _BetStepper(
              icon: Icons.add_rounded,
              onPressed: betLocked
                  ? null
                  : () => game.changeBet(increase: true),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: betLocked ? null : game.betMax,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.gold,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            'MAX BET  ·  ${Paytable.betPerLineSteps.last * Paytable.lineCount}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _SpinButton extends StatelessWidget {
  const _SpinButton({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final bool busy = game.isSpinning;
    final bool broke = game.isBroke;
    final bool enabled = broke ? !busy : game.canSpin;

    final String caption = broke
        ? 'TOP\nUP'
        : busy
        ? '···'
        : game.inFreeSpins
        ? 'FREE\nSPIN'
        : 'SPIN';

    return Semantics(
      button: true,
      enabled: enabled,
      label: broke ? 'Top up credits' : 'Spin the reels',
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                if (broke) {
                  game.topUp();
                } else {
                  game.spin();
                }
              }
            : null,
        child: AnimatedScale(
          scale: busy ? 0.94 : 1,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: enabled
                  ? AppTheme.goldSheen
                  : const LinearGradient(
                      colors: <Color>[Color(0xFF2A3348), Color(0xFF1B2233)],
                    ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (enabled ? AppTheme.gold : Colors.black).withValues(
                    alpha: enabled ? 0.45 : 0.4,
                  ),
                  blurRadius: enabled ? 26 : 10,
                  spreadRadius: enabled ? 1 : 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? const Color(0xFF3A2606) : AppTheme.textDim,
                  fontSize: caption.contains('\n') ? 16 : 20,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BetStepper extends StatelessWidget {
  const _BetStepper({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return IconButton(
      onPressed: enabled
          ? () {
              HapticFeedback.selectionClick();
              onPressed!();
            }
          : null,
      iconSize: 24,
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.cabinet,
        foregroundColor: enabled ? AppTheme.gold : AppTheme.textDim,
        fixedSize: const Size.square(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: enabled ? AppTheme.cabinetEdge : Colors.transparent,
          ),
        ),
      ),
      icon: Icon(icon),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.icon,
    required this.label,
    this.active = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Color tint = onPressed == null
        ? AppTheme.textDim
        : active
        ? AppTheme.gold
        : Colors.white70;

    return TextButton.icon(
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed!();
            },
      icon: Icon(icon, size: 18, color: tint),
      label: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: active
            ? AppTheme.gold.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
