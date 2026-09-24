// Simulates the machine and reports its long-run behaviour.
//
//   dart run tool/rtp.dart              # 2,000,000 spins
//   dart run tool/rtp.dart 10000000     # more spins, tighter estimate
//
// Run this after touching lib/src/engine/paytable.dart or reel_strips.dart.
// Return-to-player is the single number that decides whether the game feels
// generous or punishing; commercial slots ship between roughly 88% and 97%.

import 'dart:math';

import 'package:slot_game/src/engine/game_symbol.dart';
import 'package:slot_game/src/engine/paytable.dart';
import 'package:slot_game/src/engine/slot_machine.dart';
import 'package:slot_game/src/engine/spin_result.dart';

void main(List<String> args) {
  final int spins = args.isEmpty ? 2000000 : int.parse(args.first);
  // Fixed seed so a tuning change is the only thing that moves the numbers.
  final SlotMachine machine = SlotMachine(random: Random(20260924));

  const int betPerLine = 1;
  final int totalBet = betPerLine * Paytable.lineCount;

  int wagered = 0;
  int returned = 0;
  int paidSpins = 0;
  int scatterTriggers = 0;
  int freeSpinsAwarded = 0;
  int biggestWin = 0;
  final Map<GameSymbol, int> hitsBySymbol = <GameSymbol, int>{};
  final Map<GameSymbol, int> paidBySymbol = <GameSymbol, int>{};

  for (int i = 0; i < spins; i++) {
    final SpinResult result = machine.spin(betPerLine: betPerLine);
    wagered += totalBet;
    returned += result.totalPayout;
    if (result.isWin) {
      paidSpins++;
    }
    if (result.totalPayout > biggestWin) {
      biggestWin = result.totalPayout;
    }
    for (final LineWin win in result.lineWins) {
      hitsBySymbol.update(win.symbol, (int v) => v + 1, ifAbsent: () => 1);
      paidBySymbol.update(win.symbol, (int v) => v + win.payout,
          ifAbsent: () => win.payout);
    }
    final ScatterWin? scatter = result.scatterWin;
    if (scatter != null) {
      hitsBySymbol.update(GameSymbol.scatter, (int v) => v + 1,
          ifAbsent: () => 1);
      paidBySymbol.update(GameSymbol.scatter, (int v) => v + scatter.payout,
          ifAbsent: () => scatter.payout);
      if (scatter.freeSpinsAwarded > 0) {
        scatterTriggers++;
        freeSpinsAwarded += scatter.freeSpinsAwarded;
      }
    }
  }

  // Free spins are paid for by the house, so their stake-free wins count
  // towards RTP without adding to the amount wagered.
  final double baseRtp = returned / wagered;
  final double freeSpinShare = freeSpinsAwarded / spins;
  final double effectiveRtp =
      baseRtp * (1 + freeSpinShare * Paytable.freeSpinMultiplier);

  String pct(double v) => '${(v * 100).toStringAsFixed(2)}%';

  print('Spins:              $spins');
  print('Wagered:            $wagered credits');
  print('Returned:           $returned credits');
  print('Base game RTP:      ${pct(baseRtp)}');
  print('Effective RTP:      ${pct(effectiveRtp)}  (incl. free spins)');
  print('Hit frequency:      ${pct(paidSpins / spins)}');
  print('Biggest win:        $biggestWin credits '
      '(${(biggestWin / totalBet).toStringAsFixed(0)}x bet)');
  print('Scatter triggers:   $scatterTriggers '
      '(1 in ${(spins / max(scatterTriggers, 1)).toStringAsFixed(0)} spins)');
  print('Free spins awarded: $freeSpinsAwarded');
  print('');
  print('Contribution by symbol');
  final List<GameSymbol> ordered = paidBySymbol.keys.toList()
    ..sort((GameSymbol a, GameSymbol b) =>
        paidBySymbol[b]!.compareTo(paidBySymbol[a]!));
  for (final GameSymbol symbol in ordered) {
    final int hits = hitsBySymbol[symbol] ?? 0;
    final double share = paidBySymbol[symbol]! / wagered;
    print('  ${symbol.displayName.padRight(12)} '
        '${pct(share).padLeft(7)} of stake   '
        '1 in ${(spins / max(hits, 1)).toStringAsFixed(0)} spins');
  }
}
