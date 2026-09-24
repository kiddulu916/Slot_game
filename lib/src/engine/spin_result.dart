import 'game_symbol.dart';
import 'paytable.dart';

/// One winning payline.
class LineWin {
  const LineWin({
    required this.lineIndex,
    required this.symbol,
    required this.matchCount,
    required this.payout,
  });

  /// Index into [Paytable.paylines].
  final int lineIndex;

  /// The symbol that paid. Wilds that substituted still report the symbol
  /// they stood in for.
  final GameSymbol symbol;

  /// How many reels from the left took part, always >= [Paytable.minMatch].
  final int matchCount;

  /// Credits awarded for this line.
  final int payout;

  /// The winning cells as `(reel, row)` pairs, left to right.
  List<({int reel, int row})> get cells {
    final List<int> line = Paytable.paylines[lineIndex];
    return <({int reel, int row})>[
      for (int reel = 0; reel < matchCount; reel++)
        (reel: reel, row: line[reel]),
    ];
  }

  @override
  String toString() => 'LineWin(line $lineIndex, '
      '${symbol.displayName} x$matchCount, $payout credits)';
}

/// Scatters pay wherever they land, so they are tracked separately.
class ScatterWin {
  const ScatterWin({
    required this.count,
    required this.payout,
    required this.freeSpinsAwarded,
    required this.cells,
  });

  final int count;
  final int payout;
  final int freeSpinsAwarded;
  final List<({int reel, int row})> cells;

  @override
  String toString() =>
      'ScatterWin(x$count, $payout credits, $freeSpinsAwarded free spins)';
}

/// Everything the UI needs to animate and settle a single spin.
class SpinResult {
  const SpinResult({
    required this.grid,
    required this.stops,
    required this.lineWins,
    required this.scatterWin,
    required this.betPerLine,
    required this.totalBet,
    required this.multiplier,
    required this.isFreeSpin,
  });

  /// Visible symbols as `grid[reel][row]`.
  final List<List<GameSymbol>> grid;

  /// Where each band came to rest — the reel widgets animate to these.
  final List<int> stops;

  final List<LineWin> lineWins;
  final ScatterWin? scatterWin;

  final int betPerLine;
  final int totalBet;

  /// Applied to every win; greater than 1 during free spins.
  final int multiplier;

  /// True when the spin was paid for out of the free-spin bank.
  final bool isFreeSpin;

  int get lineWinTotal =>
      lineWins.fold<int>(0, (int sum, LineWin win) => sum + win.payout);

  int get scatterTotal => scatterWin?.payout ?? 0;

  int get totalPayout => lineWinTotal + scatterTotal;

  int get freeSpinsAwarded => scatterWin?.freeSpinsAwarded ?? 0;

  bool get isWin => totalPayout > 0;

  /// Net credits for the spin. Free spins cost nothing, so they can only
  /// ever be positive.
  int get netChange => totalPayout - (isFreeSpin ? 0 : totalBet);

  /// Ratio of win to stake, used to pick the celebration tier.
  double get winMultiple => totalBet == 0 ? 0 : totalPayout / totalBet;

  /// Every cell that took part in a win, for highlighting.
  Set<({int reel, int row})> get winningCells => <({int reel, int row})>{
        for (final LineWin win in lineWins) ...win.cells,
        ...?scatterWin?.cells,
      };

  @override
  String toString() => 'SpinResult(stops: $stops, payout: $totalPayout, '
      'lines: ${lineWins.length}, scatter: $scatterWin)';
}
