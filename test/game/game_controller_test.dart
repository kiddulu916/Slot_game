import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slot_game/src/engine/game_symbol.dart';
import 'package:slot_game/src/engine/paytable.dart';
import 'package:slot_game/src/engine/slot_machine.dart';
import 'package:slot_game/src/engine/spin_result.dart';
import 'package:slot_game/src/game/game_controller.dart';
import 'package:slot_game/src/game/spin_timing.dart';
import 'package:slot_game/src/game/wallet.dart';

import '../support/test_machines.dart';

/// Builds a controller with its saved balance already read.
GameController loadedGame({
  required FakeAsync async,
  SlotMachine? machine,
  int credits = Wallet.startingCredits,
  int? betPerLine,
}) {
  final GameController game = GameController(
    machine: machine ?? neverWins(),
    wallet: MemoryWallet(credits: credits, betPerLine: betPerLine),
  );
  game.load();
  async.flushMicrotasks();
  return game;
}

/// Runs the reels and the payout roll-up out to a settled, idle machine.
void settle(FakeAsync async, {bool turbo = false}) {
  async
    ..elapse(SpinTiming.allReelsStopped(Paytable.reelCount, turbo: turbo))
    ..elapse(SpinTiming.winCountUp)
    ..flushMicrotasks();
}

void main() {
  group('stake', () {
    test('starts at the bottom of the ladder', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async);
        addTearDown(game.dispose);

        expect(game.betPerLine, Paytable.betPerLineSteps.first);
        expect(
          game.totalBet,
          Paytable.betPerLineSteps.first * Paytable.lineCount,
        );
      });
    });

    test('steps up and down the ladder', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async);
        addTearDown(game.dispose);

        game.changeBet(increase: true);
        expect(game.betPerLine, Paytable.betPerLineSteps[1]);

        game.changeBet(increase: false);
        expect(game.betPerLine, Paytable.betPerLineSteps.first);
      });
    });

    test('stops at both ends of the ladder', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async, credits: 1000000);
        addTearDown(game.dispose);

        game.changeBet(increase: false);
        expect(game.betPerLine, Paytable.betPerLineSteps.first);

        game.betMax();
        game.changeBet(increase: true);
        expect(game.betPerLine, Paytable.betPerLineSteps.last);
      });
    });

    test('will not rise above what the balance can cover', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          credits: Paytable.lineCount * 2,
        );
        addTearDown(game.dispose);

        game.betMax();
        expect(game.totalBet, lessThanOrEqualTo(game.credits));

        game.changeBet(increase: true);
        expect(game.totalBet, lessThanOrEqualTo(game.credits));
      });
    });

    test('is locked while the reels turn', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async);
        addTearDown(game.dispose);

        game.spin();
        final int betDuringSpin = game.betPerLine;
        game.changeBet(increase: true);

        expect(game.betPerLine, betDuringSpin);
        settle(async);
      });
    });
  });

  group('paid spins', () {
    test('take the stake up front and pay the win back', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: alwaysWins(),
        );
        addTearDown(game.dispose);

        final int before = game.credits;
        final int stake = game.totalBet;
        game.spin();

        // The stake goes the moment the button is pressed.
        expect(game.credits, before - stake);
        expect(game.phase, SpinPhase.spinning);

        settle(async);

        expect(game.phase, SpinPhase.idle);
        expect(game.result!.totalPayout, greaterThan(0));
        expect(game.credits, before - stake + game.result!.totalPayout);
      });
    });

    test('decide the outcome before the reels stop', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: alwaysWins(),
        );
        addTearDown(game.dispose);

        game.spin();
        // The reels are still turning, yet the result already exists — the
        // animation reveals it rather than deciding it.
        expect(game.phase, SpinPhase.spinning);
        expect(game.result, isNotNull);
        expect(game.result!.stops, hasLength(Paytable.reelCount));

        settle(async);
      });
    });

    test('cost the stake when they lose', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async);
        addTearDown(game.dispose);

        final int before = game.credits;
        final int stake = game.totalBet;
        game.spin();
        settle(async);

        expect(game.result!.totalPayout, 0);
        expect(game.credits, before - stake);
        expect(game.phase, SpinPhase.idle);
      });
    });

    test('are refused mid-spin', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async);
        addTearDown(game.dispose);

        game.spin();
        final int afterFirst = game.credits;
        game.spin();

        expect(game.credits, afterFirst, reason: 'a second stake was taken');
        expect(game.spinsPlayed, 1);
        settle(async);
      });
    });

    test('are refused when the balance cannot cover them', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async, credits: 0);
        addTearDown(game.dispose);

        expect(game.canSpin, isFalse);
        game.spin();
        expect(game.spinsPlayed, 0);
      });
    });
  });

  group('free spins', () {
    test('are banked when scatters land', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: alwaysScatters(),
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);

        expect(game.freeSpinsRemaining, greaterThan(0));
        expect(game.inFreeSpins, isTrue);
        expect(game.currentMultiplier, Paytable.freeSpinMultiplier);
      });
    });

    test('cost nothing to play', () {
      fakeAsync((FakeAsync async) {
        // Scatter once, then a machine that cannot pay, so the bonus drains.
        final GameController game = loadedGame(
          async: async,
          machine: scattersThenCold(),
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);

        final int banked = game.freeSpinsRemaining;
        final int before = game.credits;
        expect(banked, greaterThan(0));

        game.spin();
        settle(async);

        expect(game.freeSpinsRemaining, banked - 1, reason: 'one spin used');
        expect(game.credits, before, reason: 'a free spin takes no stake');
        expect(
          game.totalWagered,
          game.totalBet,
          reason: 'only the first, paid spin counts as wagered',
        );
      });
    });

    test('play themselves out to the end of the bonus', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: scattersThenCold(),
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);
        final int banked = game.freeSpinsRemaining;

        // The bonus runs without autoplay being on.
        expect(game.autoplay, isFalse);
        async.elapse(const Duration(seconds: 60));

        expect(game.freeSpinsRemaining, 0);
        expect(game.inFreeSpins, isFalse);
        expect(game.spinsPlayed, banked + 1);
      });
    });

    test('are retriggered by scatters landing during the bonus', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: alwaysScatters(),
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);
        final int banked = game.freeSpinsRemaining;

        game.spin();
        settle(async);

        // One spin was used, but the retrigger added a fresh award on top.
        expect(
          game.freeSpinsRemaining,
          banked - 1 + Paytable.freeSpinsFor(Paytable.reelCount),
        );
      });
    });

    test('keep the stake locked', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: alwaysScatters(),
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);

        final int locked = game.betPerLine;
        game.changeBet(increase: true);
        game.betMax();

        expect(game.betPerLine, locked);
      });
    });

    test('multiply their wins', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: ScriptedMachine(<SlotMachine>[
            alwaysScatters(),
            alwaysWins(),
          ]),
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);

        game.spin();
        async.elapse(SpinTiming.allReelsStopped(Paytable.reelCount));
        final SpinResult bonusSpin = game.result!;

        expect(bonusSpin.isFreeSpin, isTrue);
        expect(bonusSpin.multiplier, Paytable.freeSpinMultiplier);
        expect(
          bonusSpin.lineWins.first.payout,
          Paytable.linePay(GameSymbol.seven, Paytable.reelCount) *
              bonusSpin.betPerLine *
              Paytable.freeSpinMultiplier,
        );
      });
    });
  });

  group('balance', () {
    test('is restored from the wallet', () async {
      final GameController game = GameController(
        wallet: MemoryWallet(credits: 1234, betPerLine: 5),
      );
      addTearDown(game.dispose);

      await game.load();

      expect(game.credits, 1234);
      expect(game.betPerLine, 5);
      expect(game.isLoaded, isTrue);
    });

    test('is written back after a spin', () {
      fakeAsync((FakeAsync async) {
        final MemoryWallet wallet = MemoryWallet();
        final GameController game = GameController(
          machine: neverWins(),
          wallet: wallet,
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);

        expect(wallet.credits, game.credits);
      });
    });

    test('tops up only once the player is broke', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async, credits: 0);
        addTearDown(game.dispose);

        expect(game.isBroke, isTrue);
        game.topUp();
        expect(game.credits, Wallet.startingCredits);

        // A second top-up while solvent must not mint credits.
        game.topUp();
        expect(game.credits, Wallet.startingCredits);
      });
    });

    test('drops the stake when it can no longer be covered', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          // Enough for one spin at the second rung, but not two.
          credits: Paytable.betPerLineSteps[1] * Paytable.lineCount,
          betPerLine: Paytable.betPerLineSteps[1],
        );
        addTearDown(game.dispose);

        game.spin();
        settle(async);

        expect(game.credits, 0);
        expect(game.betPerLine, Paytable.betPerLineSteps.first);
      });
    });
  });

  group('session statistics', () {
    test('track what was staked and won', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          machine: alwaysWins(),
        );
        addTearDown(game.dispose);

        expect(game.sessionReturn, isNull);

        final int stake = game.totalBet;
        game.spin();
        settle(async);

        expect(game.spinsPlayed, 1);
        expect(game.totalWagered, stake);
        expect(game.totalWon, game.result!.totalPayout);
        expect(game.bestWin, game.result!.totalPayout);
        expect(game.sessionReturn, game.totalWon / stake);
      });
    });
  });

  group('autoplay', () {
    test('keeps spinning on its own', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(async: async);
        addTearDown(game.dispose);

        game.toggleAutoplay();
        expect(game.autoplay, isTrue);

        async.elapse(const Duration(seconds: 12));

        expect(game.spinsPlayed, greaterThan(2));
        game.stopAutoplay();
      });
    });

    test('stops when the balance runs out', () {
      fakeAsync((FakeAsync async) {
        final GameController game = loadedGame(
          async: async,
          credits: Paytable.betPerLineSteps.first * Paytable.lineCount * 2,
        );
        addTearDown(game.dispose);

        game.toggleAutoplay();
        async.elapse(const Duration(seconds: 30));

        expect(game.autoplay, isFalse);
        expect(game.credits, 0);
        expect(game.spinsPlayed, 2);
      });
    });

    test('turbo shortens the spin', () {
      expect(
        SpinTiming.allReelsStopped(Paytable.reelCount, turbo: true),
        lessThan(SpinTiming.allReelsStopped(Paytable.reelCount)),
      );
    });
  });
}
