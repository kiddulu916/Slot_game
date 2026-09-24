import 'dart:math';

import 'game_symbol.dart';
import 'reel_strips.dart';

/// Static configuration for the machine: grid shape, paylines and payouts.
///
/// Changing the numbers in here changes the personality of the game, so every
/// value is in one place. Run `dart run tool/rtp.dart` after editing to see
/// what it did to the return-to-player.
class Paytable {
  const Paytable._();

  /// Columns of symbols the player spins.
  static const int reelCount = 5;

  /// Visible symbols per reel.
  static const int rowCount = 3;

  /// Shortest run that pays anything, counted from the leftmost reel.
  static const int minMatch = 3;

  /// Each payline lists which row it occupies on reel 0, 1, 2, 3, 4.
  ///
  /// Row 0 is the top of the window, row 2 the bottom, so `[0, 1, 2, 1, 0]`
  /// draws a V across the grid.
  static const List<List<int>> paylines = <List<int>>[
    <int>[1, 1, 1, 1, 1], // centre
    <int>[0, 0, 0, 0, 0], // top
    <int>[2, 2, 2, 2, 2], // bottom
    <int>[0, 1, 2, 1, 0], // V
    <int>[2, 1, 0, 1, 2], // inverted V
    <int>[0, 0, 1, 2, 2], // descending
    <int>[2, 2, 1, 0, 0], // ascending
    <int>[1, 0, 1, 2, 1], // zig
    <int>[1, 2, 1, 0, 1], // zag
    <int>[0, 1, 1, 1, 0], // shallow bowl
  ];

  static int get lineCount => paylines.length;

  /// Payout as a multiple of the *line bet* for an N-of-a-kind run.
  ///
  /// The ranking here mirrors how rare each symbol is on the bands, which is
  /// what makes it fair: cherries crowd the reels and pay least, the lone seven
  /// on each band pays most of the regular symbols, and wilds top the table
  /// because a run of five wilds is rarer than five sevens (wilds can complete
  /// a seven run, but nothing completes a wild run).
  ///
  /// These numbers set the return-to-player together with the band recipe in
  /// [ReelStrips]. Run `dart run tool/exact_rtp.dart` after any edit.
  ///
  /// Scatters are absent on purpose — they pay off [scatterPays] instead.
  static const Map<GameSymbol, Map<int, int>> linePays =
      <GameSymbol, Map<int, int>>{
        GameSymbol.cherry: <int, int>{3: 3, 4: 10, 5: 25},
        GameSymbol.lemon: <int, int>{3: 5, 4: 15, 5: 40},
        GameSymbol.grape: <int, int>{3: 5, 4: 15, 5: 40},
        GameSymbol.bell: <int, int>{3: 8, 4: 25, 5: 100},
        GameSymbol.bar: <int, int>{3: 12, 4: 40, 5: 125},
        GameSymbol.diamond: <int, int>{3: 15, 4: 50, 5: 200},
        GameSymbol.seven: <int, int>{3: 60, 4: 250, 5: 1500},
        GameSymbol.wild: <int, int>{3: 150, 4: 750, 5: 4000},
      };

  /// Scatter pays multiply the *total bet*, because they ignore paylines.
  static const Map<int, int> scatterPays = <int, int>{3: 6, 4: 30, 5: 250};

  /// Free spins granted by a scatter trigger.
  static const Map<int, int> freeSpinAwards = <int, int>{3: 8, 4: 12, 5: 20};

  /// Every free spin multiplies its wins by this much.
  static const int freeSpinMultiplier = 2;

  /// Bet steps offered per line, in credits.
  static const List<int> betPerLineSteps = <int>[1, 2, 5, 10, 25, 50];

  /// Symbols shown in the in-game paytable, best first.
  static const List<GameSymbol> payingSymbolsByValue = <GameSymbol>[
    GameSymbol.wild,
    GameSymbol.seven,
    GameSymbol.diamond,
    GameSymbol.bar,
    GameSymbol.bell,
    GameSymbol.grape,
    GameSymbol.lemon,
    GameSymbol.cherry,
  ];

  static int linePay(GameSymbol symbol, int count) =>
      linePays[symbol]?[count] ?? 0;

  /// The highest scatter count the tables price, currently one per reel.
  static final int _topScatterTier = scatterPays.keys.reduce(max);

  /// Scatters are counted across the whole grid, and a 5x3 window can show
  /// more than one per reel — up to [reelCount] * [rowCount] of them. Counts
  /// above the top priced tier pay that tier rather than dropping to nothing,
  /// so adding a second scatter to a band can never silently rob the player.
  static int _cappedScatterCount(int count) =>
      count < minMatch ? 0 : min(count, _topScatterTier);

  static int scatterPay(int count) =>
      scatterPays[_cappedScatterCount(count)] ?? 0;

  static int freeSpinsFor(int scatterCount) =>
      freeSpinAwards[_cappedScatterCount(scatterCount)] ?? 0;
}
