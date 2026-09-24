import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:slot_game/src/engine/game_symbol.dart';
import 'package:slot_game/src/engine/paytable.dart';
import 'package:slot_game/src/engine/rtp.dart';
import 'package:slot_game/src/engine/slot_machine.dart';
import 'package:slot_game/src/engine/spin_result.dart';

/// Guards the game's economy.
///
/// The paytable and the reel bands are easy to edit and impossible to eyeball:
/// nudging one payout moves the return to player by a few points and nothing
/// else complains. These tests fail when that happens.
void main() {
  final RtpReport report = computeExactRtp();

  group('return to player', () {
    test('sits in the band commercial slots ship in', () {
      // Real machines run roughly 88%-97%. Outside that the game is either
      // unplayable or gives the house no margin.
      expect(report.effectiveRtp, greaterThan(0.88));
      expect(report.effectiveRtp, lessThan(0.97));
    });

    test('is close to its tuned target of 94.5%', () {
      expect(
        report.effectiveRtp,
        closeTo(0.945, 0.01),
        reason: 'the maths was tuned to this; re-run tool/exact_rtp.dart and '
            'update the target deliberately if you meant to change it',
      );
    });

    test('leaves the house a positive edge', () {
      expect(report.houseEdge, greaterThan(0));
    });

    test('pays most of its return through paylines', () {
      expect(report.lineRtp, greaterThan(report.scatterRtp));
    });

    test('ends the free-spin bonus rather than looping forever', () {
      expect(report.expectedFreeSpins, lessThan(1));
      expect(report.freeSpinChain.isFinite, isTrue);
    });
  });

  group('game feel', () {
    test('pays often enough to stay interesting', () {
      // Roughly the chance at least one of the paylines comes in.
      final double spinHitRate =
          1 - pow(1 - report.lineHitRate, Paytable.lineCount).toDouble();
      expect(spinHitRate, greaterThan(0.25));
      expect(spinHitRate, lessThan(0.65));
    });

    test('triggers free spins occasionally, not constantly', () {
      final double triggerRate = report.expectedFreeSpins /
          Paytable.freeSpinsFor(Paytable.minMatch);
      expect(triggerRate, lessThan(0.02), reason: 'rarer than 1 spin in 50');
      expect(triggerRate, greaterThan(0.002), reason: 'more often than 1 in 500');
    });

    test('spreads its return across symbols instead of one carrying the game',
        () {
      for (final MapEntry<GameSymbol, double> entry
          in report.stakeShareBySymbol.entries) {
        expect(
          entry.value / report.lineRtp,
          lessThan(0.25),
          reason: '${entry.key.displayName} carries too much of the return',
        );
      }
    });

    test('keeps a jackpot worth chasing', () {
      final int topLinePay = Paytable.linePay(GameSymbol.wild, 5);
      // Expressed against the total bet, which is what a player actually sees.
      expect(topLinePay / Paytable.lineCount, greaterThanOrEqualTo(100));
    });
  });

  group('simulation', () {
    test('agrees with the exact figure', () {
      // A long random run should land near the closed-form answer. If these
      // two disagree, one of them is scoring spins wrongly.
      const int spins = 300000;
      const int betPerLine = 1;
      final SlotMachine machine = SlotMachine(random: Random(20260924));

      int wagered = 0;
      int returned = 0;
      for (int i = 0; i < spins; i++) {
        final SpinResult result = machine.spin(betPerLine: betPerLine);
        wagered += result.totalBet;
        returned += result.totalPayout;
      }

      expect(returned / wagered, closeTo(report.baseRtp, 0.02));
    });
  });
}
