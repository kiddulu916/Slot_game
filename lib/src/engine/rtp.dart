import 'game_symbol.dart';
import 'paytable.dart';
import 'reel_strips.dart';
import 'slot_machine.dart';
import 'spin_result.dart';

/// What the machine pays back over the long run, computed exactly.
class RtpReport {
  const RtpReport({
    required this.lineRtp,
    required this.scatterRtp,
    required this.expectedFreeSpins,
    required this.lineHitRate,
    required this.scatterHitRate,
    required this.stopCombinations,
    required this.stakeShareBySymbol,
    required this.lineRateBySymbol,
    required this.stakeShareByCombination,
  });

  /// Share of stake returned through paylines.
  final double lineRtp;

  /// Share of stake returned through scatter pays.
  final double scatterRtp;

  /// Free spins granted per paid spin.
  final double expectedFreeSpins;

  /// Chance that any one payline pays.
  final double lineHitRate;

  /// Chance that a spin lands a paying number of scatters.
  final double scatterHitRate;

  /// How many distinct stop positions the reels can take between them.
  final int stopCombinations;

  final Map<GameSymbol, double> stakeShareBySymbol;
  final Map<GameSymbol, double> lineRateBySymbol;
  final Map<String, double> stakeShareByCombination;

  /// Return to player before the free-spin bonus.
  double get baseRtp => lineRtp + scatterRtp;

  /// Free spins a single paid spin eventually generates, retriggers included.
  ///
  /// A free spin can award more free spins, so the total is a geometric
  /// series. Above one the bonus would never end, which would mean a broken
  /// paytable rather than a very generous one.
  double get freeSpinChain => expectedFreeSpins < 1
      ? expectedFreeSpins / (1 - expectedFreeSpins)
      : double.infinity;

  /// Return to player including free-spin winnings.
  ///
  /// Free spins are staked by the house, so their wins add to the return
  /// without adding to the amount wagered.
  double get effectiveRtp =>
      baseRtp * (1 + Paytable.freeSpinMultiplier * freeSpinChain);

  /// The house's long-run margin.
  double get houseEdge => 1 - effectiveRtp;
}

/// Computes the machine's exact return to player — no sampling involved.
///
/// A payline takes one row from each reel. As a band's stop position runs over
/// all of its positions the symbol landing on that row runs over the whole band
/// exactly once, so the symbol on a line follows the band's symbol frequencies,
/// independently per reel — and every payline has the same expectation. That
/// turns a sum over every stop combination into a weighted sum over symbol
/// combinations, which is small enough to enumerate outright.
///
/// Scatters pay off the whole grid, but the number of scatters inside one
/// reel's window depends only on that reel's stop, so the totals are the
/// convolution of five small per-reel distributions.
///
/// Lines are scored with [SlotMachine.scoreLine] — the same code that pays the
/// player — so the published figure cannot drift away from the real game.
RtpReport computeExactRtp({List<List<GameSymbol>>? strips}) {
  final List<List<GameSymbol>> bands = strips ?? ReelStrips.standard;

  // How often each symbol occupies a given row, per reel.
  final List<Map<GameSymbol, int>> weights = <Map<GameSymbol, int>>[
    for (final List<GameSymbol> band in bands)
      <GameSymbol, int>{
        for (final GameSymbol symbol in band)
          symbol: band.where((GameSymbol s) => s == symbol).length,
      },
  ];
  final int stopCombinations = bands.fold<int>(
    1,
    (int product, List<GameSymbol> band) => product * band.length,
  );

  final Map<GameSymbol, double> shareBySymbol = <GameSymbol, double>{};
  final Map<GameSymbol, double> rateBySymbol = <GameSymbol, double>{};
  final Map<String, double> shareByCombination = <String, double>{};
  double expectedLinePayout = 0;
  double lineHitRate = 0;

  void walk(int reel, List<GameSymbol> run, int weight) {
    if (reel == Paytable.reelCount) {
      final LineWin? win = SlotMachine.scoreLine(onLine: run, betPerLine: 1);
      if (win == null) {
        return;
      }
      final double probability = weight / stopCombinations;
      final double share = probability * win.payout;
      expectedLinePayout += share;
      lineHitRate += probability;
      shareBySymbol.update(
        win.symbol,
        (double v) => v + share,
        ifAbsent: () => share,
      );
      rateBySymbol.update(
        win.symbol,
        (double v) => v + probability,
        ifAbsent: () => probability,
      );
      shareByCombination.update(
        '${win.symbol.displayName} x${win.matchCount}',
        (double v) => v + share,
        ifAbsent: () => share,
      );
      return;
    }
    weights[reel].forEach((GameSymbol symbol, int count) {
      run.add(symbol);
      walk(reel + 1, run, weight * count);
      run.removeLast();
    });
  }

  walk(0, <GameSymbol>[], 1);

  // Chance of 0..reelCount*rowCount scatters on the grid, built up one reel at
  // a time.
  List<double> scatterTotals = <double>[1];
  for (final List<GameSymbol> band in bands) {
    final List<double> perReel = List<double>.filled(Paytable.rowCount + 1, 0);
    for (int stop = 0; stop < band.length; stop++) {
      int scatters = 0;
      for (int row = 0; row < Paytable.rowCount; row++) {
        if (band[(stop + row) % band.length].isScatter) {
          scatters++;
        }
      }
      perReel[scatters] += 1 / band.length;
    }
    final List<double> merged = List<double>.filled(
      scatterTotals.length + Paytable.rowCount,
      0,
    );
    for (int carried = 0; carried < scatterTotals.length; carried++) {
      if (scatterTotals[carried] == 0) {
        continue;
      }
      for (int added = 0; added < perReel.length; added++) {
        merged[carried + added] += scatterTotals[carried] * perReel[added];
      }
    }
    scatterTotals = merged;
  }

  double scatterRtp = 0;
  double scatterHitRate = 0;
  double expectedFreeSpins = 0;
  for (int count = 0; count < scatterTotals.length; count++) {
    final double probability = scatterTotals[count];
    // Scatter pays multiply the total bet, so as a share of stake the number
    // of paylines cancels out.
    scatterRtp += probability * Paytable.scatterPay(count);
    if (Paytable.scatterPay(count) > 0) {
      scatterHitRate += probability;
    }
    expectedFreeSpins += probability * Paytable.freeSpinsFor(count);
  }

  return RtpReport(
    // Total bet is lineCount * lineBet across lineCount lines, so the line
    // share of stake is just the expected payout of a single line.
    lineRtp: expectedLinePayout,
    scatterRtp: scatterRtp,
    expectedFreeSpins: expectedFreeSpins,
    lineHitRate: lineHitRate,
    scatterHitRate: scatterHitRate,
    stopCombinations: stopCombinations,
    stakeShareBySymbol: Map<GameSymbol, double>.unmodifiable(shareBySymbol),
    lineRateBySymbol: Map<GameSymbol, double>.unmodifiable(rateBySymbol),
    stakeShareByCombination: Map<String, double>.unmodifiable(
      shareByCombination,
    ),
  );
}
