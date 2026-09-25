import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/paytable.dart';
import '../engine/reel_strips.dart';
import '../engine/spin_result.dart';
import '../game/audio_service.dart';
import '../game/game_controller.dart';
import '../game/game_sound.dart';
import '../game/spin_timing.dart';
import 'app_theme.dart';
import 'controls_bar.dart';
import 'payline_overlay.dart';
import 'paytable_sheet.dart';
import 'readouts.dart';
import 'reel_view.dart';
import 'win_banner.dart';

/// The machine itself: display strip, reels and controls.
class SlotScreen extends StatefulWidget {
  const SlotScreen({required this.game, required this.audio, super.key});

  final GameController game;
  final AudioService audio;

  @override
  State<SlotScreen> createState() => _SlotScreenState();
}

class _SlotScreenState extends State<SlotScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the glow on every winning cell, shared so they breathe together.
  ///
  /// Only run while a win is on screen — a permanently repeating controller
  /// would keep the whole cabinet rebuilding at 60fps for nothing.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );

  int _lastCelebratedSpin = -1;
  Timer? _creditTicker;

  @override
  void initState() {
    super.initState();
    widget.game.addListener(_onGameChanged);
  }

  /// Ticks a coin sound while the credit counter rolls up a win.
  void _startCreditTicks() {
    _creditTicker?.cancel();
    const Duration interval = Duration(milliseconds: 90);
    int remaining =
        SpinTiming.winCountUp.inMilliseconds ~/ interval.inMilliseconds;
    _creditTicker = Timer.periodic(interval, (Timer timer) {
      if (!mounted || remaining-- <= 0) {
        timer.cancel();
        return;
      }
      widget.audio.play(GameSound.creditTick);
    });
  }

  /// Runs the win pulse and fires the haptic once per spin, as the reels rest.
  void _onGameChanged() {
    final GameController game = widget.game;
    final SpinResult? result = game.result;

    final bool showingWin =
        result != null && result.isWin && game.phase != SpinPhase.spinning;
    if (showingWin && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!showingWin && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }

    if (result == null ||
        game.phase != SpinPhase.paying ||
        game.spinsPlayed == _lastCelebratedSpin) {
      return;
    }
    _lastCelebratedSpin = game.spinsPlayed;

    final WinTier tier = WinTier.of(result);
    if (tier.isCelebrated) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    widget.audio.play(tier.sound);
    _startCreditTicks();

    // The bonus gets its own flourish on top of the win it came with.
    if (result.freeSpinsAwarded > 0) {
      widget.audio.play(GameSound.bonus);
    }
  }

  @override
  void dispose() {
    _creditTicker?.cancel();
    widget.game.removeListener(_onGameChanged);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.background),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: widget.game,
          builder: (BuildContext context, Widget? child) {
            final GameController game = widget.game;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: <Widget>[
                  _Header(game: game, audio: widget.audio),
                  const SizedBox(height: 10),
                  _DisplayStrip(game: game),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Center(
                      child: _ReelPanel(
                        game: game,
                        pulse: _pulse,
                        onReelSettled: () =>
                            widget.audio.play(GameSound.reelStop),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ControlsBar(
                    game: game,
                    audio: widget.audio,
                    onShowPaytable: () => PaytableSheet.show(
                      context,
                      betPerLine: game.betPerLine,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.game, required this.audio});

  final GameController game;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'LUCKY FIVE',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.5,
              foreground: Paint()
                ..shader = AppTheme.goldSheen.createShader(
                  const Rect.fromLTWH(0, 0, 220, 26),
                ),
            ),
          ),
        ),
        if (game.sessionReturn case final double returned)
          Tooltip(
            message: 'What this session has paid back so far',
            child: Text(
              'SESSION ${(returned * 100).toStringAsFixed(0)}%',
              style: AppTheme.label,
            ),
          ),
        // Sits up here rather than in the controls, which are already full.
        ListenableBuilder(
          listenable: audio,
          builder: (BuildContext context, Widget? child) => IconButton(
            onPressed: () => audio.setMuted(!audio.muted),
            visualDensity: VisualDensity.compact,
            tooltip: audio.muted ? 'Unmute' : 'Mute',
            icon: Icon(
              audio.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 20,
              color: audio.muted ? AppTheme.textDim : AppTheme.gold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Credits, stake and the last win.
class _DisplayStrip extends StatelessWidget {
  const _DisplayStrip({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final SpinResult? result = game.result;
    // Hide the previous win while the reels are turning; it belongs to a spin
    // that is over.
    final int shownWin = game.phase == SpinPhase.spinning
        ? 0
        : (result?.totalPayout ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.feltDeep.withValues(alpha: 0.6),
        border: Border.all(color: AppTheme.cabinetEdge),
      ),
      // The three readouts share the strip evenly, so a long balance cannot
      // squeeze the others out.
      child: Row(
        children: <Widget>[
          Expanded(
            child: RollingNumber(
              label: 'CREDITS',
              value: game.credits,
              accent: AppTheme.gold,
              emphasise: true,
            ),
          ),
          Expanded(
            child: Readout(
              label: game.inFreeSpins ? 'FREE SPINS' : 'BET',
              // During the bonus, how many are left out of how many were won —
              // a retrigger visibly grows the total.
              value: game.inFreeSpins
                  ? '${game.freeSpinsRemaining}/${game.freeSpinsWon}'
                  : '${game.totalBet}',
              accent: game.inFreeSpins ? AppTheme.mint : Colors.white,
            ),
          ),
          Expanded(
            child: RollingNumber(
              label: 'WIN',
              value: shownWin,
              accent: shownWin > 0 ? AppTheme.mint : AppTheme.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// The gold-framed window the reels turn behind.
class _ReelPanel extends StatelessWidget {
  const _ReelPanel({
    required this.game,
    required this.pulse,
    required this.onReelSettled,
  });

  final GameController game;
  final Animation<double> pulse;

  /// Fired as each reel comes to rest, once per reel.
  final VoidCallback onReelSettled;

  static const double _reelGap = 5;
  static const double _framePadding = 9;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Size a square-ish cell to the width available, but never so tall that
        // the grid pushes the controls off a short screen.
        final double gaps = _reelGap * (Paytable.reelCount - 1);
        final double byWidth =
            (constraints.maxWidth - 2 * _framePadding - gaps) /
            Paytable.reelCount;
        final double byHeight =
            (constraints.maxHeight - 2 * _framePadding) / Paytable.rowCount;
        final double cell = byWidth < byHeight ? byWidth : byHeight;

        final double gridWidth = cell * Paytable.reelCount + gaps;
        final double gridHeight = cell * Paytable.rowCount;

        final SpinResult? result = game.result;
        final bool spinning = game.phase == SpinPhase.spinning;
        // Highlights and paylines belong to a settled result only.
        final bool showWins = !spinning && (result?.isWin ?? false);

        return Container(
          padding: const EdgeInsets.all(_framePadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: AppTheme.goldSheen,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.22),
                blurRadius: 30,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: AppTheme.feltDeep,
            ),
            child: SizedBox(
              width: gridWidth,
              height: gridHeight,
              child: Stack(
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int reel = 0; reel < Paytable.reelCount; reel++) ...[
                        if (reel > 0) const SizedBox(width: _reelGap),
                        ReelView(
                          reelIndex: reel,
                          band: ReelStrips.standard[reel],
                          stop: result?.stops[reel] ?? reel * 3,
                          spinning: spinning,
                          turbo: game.turbo,
                          cellSize: cell,
                          highlightedRows: showWins
                              ? _winningRowsOn(result!, reel)
                              : const <int>{},
                          pulse: pulse,
                          onSettled: onReelSettled,
                        ),
                      ],
                    ],
                  ),
                  if (showWins)
                    Positioned.fill(
                      child: PaylineOverlay(
                        wins: result!.lineWins,
                        cellWidth: cell,
                        cellHeight: cell,
                        reelGap: _reelGap,
                      ),
                    ),
                  if (game.phase == SpinPhase.paying)
                    Positioned.fill(child: WinBanner(result: result)),
                  if (game.inFreeSpins)
                    const Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: _FreeSpinsRibbon(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Rows on [reel] that took part in a win.
  Set<int> _winningRowsOn(SpinResult result, int reel) => <int>{
    for (final ({int reel, int row}) cell in result.winningCells)
      if (cell.reel == reel) cell.row,
  };
}

class _FreeSpinsRibbon extends StatelessWidget {
  const _FreeSpinsRibbon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.mint.withValues(alpha: 0.18),
          border: Border.all(color: AppTheme.mint.withValues(alpha: 0.7)),
        ),
        child: Text(
          'FREE SPINS  ·  ${Paytable.freeSpinMultiplier}x WINS',
          style: AppTheme.label.copyWith(color: AppTheme.mint, fontSize: 9),
        ),
      ),
    );
  }
}
