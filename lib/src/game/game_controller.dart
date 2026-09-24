import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/paytable.dart';
import '../engine/slot_machine.dart';
import '../engine/spin_result.dart';
import 'spin_timing.dart';
import 'wallet.dart';

/// What the machine is doing right now.
enum SpinPhase {
  /// Waiting for the player.
  idle,

  /// Reels are turning; the outcome is already decided.
  spinning,

  /// Reels have stopped and the win is being paid.
  paying,
}

/// Owns the player's money and drives a spin from stake to payout.
///
/// The outcome is decided the moment the player presses spin — the animation
/// only reveals a result the engine has already produced, which is how a real
/// machine works and keeps the UI from being able to influence the odds.
class GameController extends ChangeNotifier {
  GameController({SlotMachine? machine, Wallet? wallet})
    : _machine = machine ?? SlotMachine(),
      _wallet = wallet ?? MemoryWallet();

  final SlotMachine _machine;
  final Wallet _wallet;

  int _credits = Wallet.startingCredits;
  int _betPerLine = Paytable.betPerLineSteps.first;
  SpinPhase _phase = SpinPhase.idle;
  SpinResult? _result;
  int _freeSpinsRemaining = 0;
  int _freeSpinsWon = 0;
  bool _autoplay = false;
  bool _turbo = false;
  bool _loaded = false;

  int _spinsPlayed = 0;
  int _totalWagered = 0;
  int _totalWon = 0;
  int _bestWin = 0;

  Timer? _settleTimer;
  Timer? _autoplayTimer;
  bool _disposed = false;

  int get credits => _credits;
  int get betPerLine => _betPerLine;
  int get totalBet => _betPerLine * Paytable.lineCount;
  SpinPhase get phase => _phase;

  /// The most recent outcome, or null before the first spin.
  ///
  /// During [SpinPhase.spinning] this is the result the reels are travelling
  /// towards, which is what lets them animate to their final stops.
  SpinResult? get result => _result;

  int get freeSpinsRemaining => _freeSpinsRemaining;

  /// How many free spins the current bonus round started with.
  int get freeSpinsWon => _freeSpinsWon;

  bool get inFreeSpins => _freeSpinsRemaining > 0;
  bool get autoplay => _autoplay;
  bool get turbo => _turbo;

  /// True once the saved balance has been read.
  bool get isLoaded => _loaded;

  int get spinsPlayed => _spinsPlayed;
  int get totalWagered => _totalWagered;
  int get totalWon => _totalWon;
  int get bestWin => _bestWin;

  /// What this session has actually returned, for the stats panel.
  double? get sessionReturn =>
      _totalWagered == 0 ? null : _totalWon / _totalWagered;

  /// The multiplier applied to the next spin.
  int get currentMultiplier => inFreeSpins ? Paytable.freeSpinMultiplier : 1;

  bool get isSpinning => _phase != SpinPhase.idle;

  /// Whether the player can afford another paid spin.
  bool get canAffordSpin => _credits >= totalBet;

  bool get canSpin => !isSpinning && (inFreeSpins || canAffordSpin);

  /// True when the player has run dry and needs a top-up.
  bool get isBroke =>
      !inFreeSpins &&
      _credits < Paytable.betPerLineSteps.first * Paytable.lineCount;

  /// Reads the stored balance and bet. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final int credits = await _wallet.loadCredits();
    final int bet = await _wallet.loadBetPerLine();
    if (_disposed) {
      return;
    }
    _credits = credits;
    _betPerLine = bet;
    _loaded = true;
    _clampBetToBalance();
    notifyListeners();
  }

  /// Moves the stake one step up or down the ladder.
  ///
  /// Ignored mid-spin and during free spins, which are played at the bet that
  /// triggered them.
  void changeBet({required bool increase}) {
    if (isSpinning || inFreeSpins) {
      return;
    }
    final List<int> steps = Paytable.betPerLineSteps;
    final int index = steps.indexOf(_betPerLine);
    final int next = increase ? index + 1 : index - 1;
    if (next < 0 || next >= steps.length) {
      return;
    }
    if (increase && steps[next] * Paytable.lineCount > _credits) {
      return;
    }
    _betPerLine = steps[next];
    _persist();
    notifyListeners();
  }

  /// Raises the stake to the most the balance can cover.
  void betMax() {
    if (isSpinning || inFreeSpins) {
      return;
    }
    final int affordable = Paytable.betPerLineSteps
        .where((int step) => step * Paytable.lineCount <= _credits)
        .fold<int>(
          Paytable.betPerLineSteps.first,
          (int a, int b) => a > b ? a : b,
        );
    if (affordable == _betPerLine) {
      return;
    }
    _betPerLine = affordable;
    _persist();
    notifyListeners();
  }

  void setTurbo(bool value) {
    if (_turbo == value) {
      return;
    }
    _turbo = value;
    notifyListeners();
  }

  /// Starts or stops unattended spinning.
  void toggleAutoplay() {
    _autoplay = !_autoplay;
    notifyListeners();
    if (_autoplay && !isSpinning) {
      spin();
    }
  }

  void stopAutoplay() {
    if (!_autoplay) {
      return;
    }
    _autoplay = false;
    _autoplayTimer?.cancel();
    notifyListeners();
  }

  /// Grants a fresh stake once the player is out of credits.
  void topUp() {
    if (isSpinning || !isBroke) {
      return;
    }
    _credits = Wallet.startingCredits;
    _clampBetToBalance();
    _persist();
    notifyListeners();
  }

  /// Stakes the bet, decides the outcome, then lets the reels catch up.
  void spin() {
    if (!canSpin) {
      stopAutoplay();
      return;
    }

    final bool isFreeSpin = inFreeSpins;
    if (isFreeSpin) {
      _freeSpinsRemaining--;
    } else {
      _credits -= totalBet;
      _totalWagered += totalBet;
    }
    _spinsPlayed++;

    _result = _machine.spin(
      betPerLine: _betPerLine,
      // A free spin already knows its multiplier because the bonus is running.
      multiplier: isFreeSpin ? Paytable.freeSpinMultiplier : 1,
      isFreeSpin: isFreeSpin,
    );
    _phase = SpinPhase.spinning;
    notifyListeners();

    _settleTimer?.cancel();
    _settleTimer = Timer(
      SpinTiming.allReelsStopped(Paytable.reelCount, turbo: _turbo),
      _settle,
    );
  }

  /// Pays the spin out once the last reel has stopped.
  void _settle() {
    final SpinResult? result = _result;
    if (result == null) {
      return;
    }

    _credits += result.totalPayout;
    _totalWon += result.totalPayout;
    if (result.totalPayout > _bestWin) {
      _bestWin = result.totalPayout;
    }

    // Scatters landing during the bonus extend it rather than starting a new
    // one, which is what "retrigger" means.
    if (result.freeSpinsAwarded > 0) {
      _freeSpinsRemaining += result.freeSpinsAwarded;
      _freeSpinsWon = result.isFreeSpin
          ? _freeSpinsWon + result.freeSpinsAwarded
          : result.freeSpinsAwarded;
    } else if (!inFreeSpins) {
      _freeSpinsWon = 0;
    }

    _phase = result.isWin ? SpinPhase.paying : SpinPhase.idle;
    _clampBetToBalance();
    _persist();
    notifyListeners();

    if (_phase == SpinPhase.paying) {
      _settleTimer = Timer(SpinTiming.winCountUp, () {
        _phase = SpinPhase.idle;
        notifyListeners();
        _queueAutoplay();
      });
    } else {
      _queueAutoplay();
    }
  }

  void _queueAutoplay() {
    // Free spins play themselves out whether or not autoplay is on.
    if (!_autoplay && !inFreeSpins) {
      return;
    }
    if (!inFreeSpins && !canAffordSpin) {
      stopAutoplay();
      return;
    }
    _autoplayTimer?.cancel();
    _autoplayTimer = Timer(
      _turbo
          ? SpinTiming.autoplayPause * SpinTiming.turboFactor
          : SpinTiming.autoplayPause,
      () {
        if (canSpin) {
          spin();
        } else {
          stopAutoplay();
        }
      },
    );
  }

  /// Drops the stake if the balance can no longer cover it.
  void _clampBetToBalance() {
    if (inFreeSpins || totalBet <= _credits) {
      return;
    }
    for (final int step in Paytable.betPerLineSteps.reversed) {
      if (step * Paytable.lineCount <= _credits) {
        _betPerLine = step;
        return;
      }
    }
    _betPerLine = Paytable.betPerLineSteps.first;
  }

  void _persist() {
    unawaited(_wallet.save(credits: _credits, betPerLine: _betPerLine));
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
    _autoplayTimer?.cancel();
    super.dispose();
  }
}
