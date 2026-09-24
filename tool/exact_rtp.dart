// Prints the machine's exact return-to-player. No sampling involved.
//
//   dart run tool/exact_rtp.dart
//
// Run this after editing lib/src/engine/paytable.dart or reel_strips.dart.
// The maths lives in lib/src/engine/rtp.dart, where the app and the test suite
// can reach it too; this file only formats the answer.

import 'package:slot_game/src/engine/game_symbol.dart';
import 'package:slot_game/src/engine/rtp.dart';

String pct(double value) => '${(value * 100).toStringAsFixed(2)}%';

void main() {
  final RtpReport report = computeExactRtp();

  print('Stop combinations:   ${report.stopCombinations}');
  print('Line RTP:            ${pct(report.lineRtp)}');
  print('Scatter RTP:         ${pct(report.scatterRtp)}');
  print('Base game RTP:       ${pct(report.baseRtp)}');
  print('Effective RTP:       ${pct(report.effectiveRtp)}  (with free spins)');
  print('House edge:          ${pct(report.houseEdge)}');
  print('Any one line pays:   ${pct(report.lineHitRate)}');
  print('Scatter pays:        ${pct(report.scatterHitRate)} of spins');
  print('Free spins per spin: ${report.expectedFreeSpins.toStringAsFixed(4)}');
  print('');

  print('Share of stake by symbol');
  final List<GameSymbol> symbols = report.stakeShareBySymbol.keys.toList()
    ..sort((GameSymbol a, GameSymbol b) => report.stakeShareBySymbol[b]!
        .compareTo(report.stakeShareBySymbol[a]!));
  for (final GameSymbol symbol in symbols) {
    final double rate = report.lineRateBySymbol[symbol]!;
    print('  ${symbol.displayName.padRight(12)}'
        '${pct(report.stakeShareBySymbol[symbol]!).padLeft(8)}'
        '   1 line in ${(1 / rate).toStringAsFixed(0)}');
  }
  print('  ${'Scatter'.padRight(12)}${pct(report.scatterRtp).padLeft(8)}');
  print('');

  print('Share of stake by combination');
  final List<String> combos = report.stakeShareByCombination.keys.toList()
    ..sort((String a, String b) => report.stakeShareByCombination[b]!
        .compareTo(report.stakeShareByCombination[a]!));
  for (final String combo in combos) {
    print('  ${combo.padRight(18)}'
        '${pct(report.stakeShareByCombination[combo]!).padLeft(8)}');
  }
}
