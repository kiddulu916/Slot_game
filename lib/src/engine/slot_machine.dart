import 'dart:math';

import 'game_symbol.dart';
import 'paytable.dart';
import 'reel_strips.dart';
import 'spin_result.dart';

/// The rules of the game, with no UI and no state beyond its RNG.
///
/// A spin is two steps: pick a stop position per reel, then score the window
/// those stops expose. Nothing here looks at the player's balance, which keeps
/// the maths honest and easy to simulate.
class SlotMachine {
  SlotMachine({List<List<GameSymbol>>? strips, Random? random})
    : strips = strips ?? ReelStrips.standard,
      _random = random ?? Random.secure() {
    if (this.strips.length != Paytable.reelCount) {
      throw ArgumentError(
        'Expected ${Paytable.reelCount} reel strips, '
        'got ${this.strips.length}',
      );
    }
    for (int reel = 0; reel < this.strips.length; reel++) {
      if (this.strips[reel].length < Paytable.rowCount) {
        throw ArgumentError('Reel $reel is shorter than the visible window');
      }
    }
  }

  final List<List<GameSymbol>> strips;
  final Random _random;

  /// Spin every reel and score the result.
  ///
  /// [betPerLine] is staked on each of [Paytable.lineCount] paylines.
  /// [multiplier] scales every win, used for the free-spin bonus.
  SpinResult spin({
    required int betPerLine,
    int multiplier = 1,
    bool isFreeSpin = false,
  }) {
    if (betPerLine <= 0) {
      throw ArgumentError.value(betPerLine, 'betPerLine', 'must be positive');
    }
    final List<int> stops = <int>[
      for (final List<GameSymbol> strip in strips)
        _random.nextInt(strip.length),
    ];
    return evaluate(
      stops: stops,
      betPerLine: betPerLine,
      multiplier: multiplier,
      isFreeSpin: isFreeSpin,
    );
  }

  /// Score a known set of stop positions.
  ///
  /// Separating this from [spin] is what makes the engine testable: a test can
  /// hand-place a jackpot instead of spinning until one shows up.
  SpinResult evaluate({
    required List<int> stops,
    required int betPerLine,
    int multiplier = 1,
    bool isFreeSpin = false,
  }) {
    final List<List<GameSymbol>> grid = windowAt(stops);
    final List<LineWin> lineWins = <LineWin>[];
    for (int line = 0; line < Paytable.lineCount; line++) {
      final LineWin? win = _scoreLine(grid, line, betPerLine, multiplier);
      if (win != null) {
        lineWins.add(win);
      }
    }
    return SpinResult(
      grid: grid,
      stops: List<int>.unmodifiable(stops),
      lineWins: List<LineWin>.unmodifiable(lineWins),
      scatterWin: _scoreScatters(grid, betPerLine, multiplier),
      betPerLine: betPerLine,
      totalBet: betPerLine * Paytable.lineCount,
      multiplier: multiplier,
      isFreeSpin: isFreeSpin,
    );
  }

  /// The visible `[reel][row]` symbols for the given stop positions.
  ///
  /// Bands are loops, so the window wraps past the end of a strip.
  List<List<GameSymbol>> windowAt(List<int> stops) {
    if (stops.length != strips.length) {
      throw ArgumentError(
        'Expected ${strips.length} stops, got '
        '${stops.length}',
      );
    }
    return List<List<GameSymbol>>.unmodifiable(<List<GameSymbol>>[
      for (int reel = 0; reel < strips.length; reel++)
        List<GameSymbol>.unmodifiable(<GameSymbol>[
          for (int row = 0; row < Paytable.rowCount; row++)
            symbolAt(reel, stops[reel] + row),
        ]),
    ]);
  }

  /// The symbol at any band index, wrapping in both directions.
  GameSymbol symbolAt(int reel, int bandIndex) {
    final List<GameSymbol> strip = strips[reel];
    return strip[bandIndex % strip.length];
  }

  /// Score one payline of the grid, left to right.
  LineWin? _scoreLine(
    List<List<GameSymbol>> grid,
    int lineIndex,
    int betPerLine,
    int multiplier,
  ) {
    final List<int> line = Paytable.paylines[lineIndex];
    return scoreLine(
      onLine: <GameSymbol>[
        for (int reel = 0; reel < Paytable.reelCount; reel++)
          grid[reel][line[reel]],
      ],
      lineIndex: lineIndex,
      betPerLine: betPerLine,
      multiplier: multiplier,
    );
  }

  /// Score five symbols sitting on a payline, left to right.
  ///
  /// Wilds substitute for any regular symbol, and a run that opens with wilds
  /// is paid whichever way is worth more: as wilds in their own right, or as
  /// the symbol they stand in for. Scatters never carry a line.
  ///
  /// Public and static because the exact return-to-player calculation in
  /// `rtp.dart` scores lines with it, so the published figure comes from the
  /// code that actually pays the player rather than from a second
  /// implementation that could drift away from it.
  static LineWin? scoreLine({
    required List<GameSymbol> onLine,
    required int betPerLine,
    int lineIndex = 0,
    int multiplier = 1,
  }) {
    final Set<GameSymbol> candidates = <GameSymbol>{};
    if (onLine.first.isWild) {
      candidates.add(GameSymbol.wild);
    }
    for (final GameSymbol symbol in onLine) {
      if (symbol.isWild) {
        continue;
      }
      // A scatter cannot open or extend a line, so the search stops here.
      if (!symbol.isScatter) {
        candidates.add(symbol);
      }
      break;
    }

    LineWin? best;
    for (final GameSymbol candidate in candidates) {
      int matchCount = 0;
      for (final GameSymbol symbol in onLine) {
        // When the candidate is wild this only accepts wilds, which is exactly
        // what an all-wild run needs.
        if (symbol == candidate || symbol.isWild) {
          matchCount++;
        } else {
          break;
        }
      }
      if (matchCount < Paytable.minMatch) {
        continue;
      }
      final int payout =
          Paytable.linePay(candidate, matchCount) * betPerLine * multiplier;
      if (payout <= 0) {
        continue;
      }
      if (best == null || payout > best.payout) {
        best = LineWin(
          lineIndex: lineIndex,
          symbol: candidate,
          matchCount: matchCount,
          payout: payout,
        );
      }
    }
    return best;
  }

  ScatterWin? _scoreScatters(
    List<List<GameSymbol>> grid,
    int betPerLine,
    int multiplier,
  ) {
    final List<({int reel, int row})> cells = <({int reel, int row})>[];
    for (int reel = 0; reel < Paytable.reelCount; reel++) {
      for (int row = 0; row < Paytable.rowCount; row++) {
        if (grid[reel][row].isScatter) {
          cells.add((reel: reel, row: row));
        }
      }
    }
    final int count = cells.length;
    final int payout =
        Paytable.scatterPay(count) *
        betPerLine *
        Paytable.lineCount *
        multiplier;
    final int freeSpins = Paytable.freeSpinsFor(count);
    if (payout == 0 && freeSpins == 0) {
      return null;
    }
    return ScatterWin(
      count: count,
      payout: payout,
      freeSpinsAwarded: freeSpins,
      cells: List<({int reel, int row})>.unmodifiable(cells),
    );
  }
}
