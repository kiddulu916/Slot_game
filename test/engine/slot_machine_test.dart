import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:slot_game/src/engine/game_symbol.dart';
import 'package:slot_game/src/engine/paytable.dart';
import 'package:slot_game/src/engine/slot_machine.dart';
import 'package:slot_game/src/engine/spin_result.dart';

const GameSymbol cherry = GameSymbol.cherry;
const GameSymbol lemon = GameSymbol.lemon;
const GameSymbol grape = GameSymbol.grape;
const GameSymbol bell = GameSymbol.bell;
const GameSymbol seven = GameSymbol.seven;
const GameSymbol wild = GameSymbol.wild;
const GameSymbol scatter = GameSymbol.scatter;

/// A band whose stop 0 shows [column], padded to clear the visible window.
///
/// The padding is one symbol repeated, which cannot start a run of its own on
/// any other payline, so a test grid only shows what the test put there.
List<GameSymbol> bandShowing(List<GameSymbol> column) => <GameSymbol>[
  ...column,
  bell,
  bell,
  bell,
];

/// A grid that cannot pay on any payline.
///
/// Every payline takes exactly one cell from each reel, so filling reel 1 with
/// one symbol and reel 2 with a different one caps every run at a single
/// symbol. No scatters appear, so nothing pays off-line either.
const List<List<GameSymbol>> losingColumns = <List<GameSymbol>>[
  <GameSymbol>[cherry, cherry, cherry],
  <GameSymbol>[grape, grape, grape],
  <GameSymbol>[bell, seven, bell],
  <GameSymbol>[seven, bell, seven],
  <GameSymbol>[lemon, bell, lemon],
];

/// Scores five symbols sitting on one payline, in isolation from the grid.
LineWin? scoreLine(List<GameSymbol> onLine, {int betPerLine = 1}) =>
    SlotMachine.scoreLine(onLine: onLine, betPerLine: betPerLine);

/// Evaluates a grid built column by column, all reels stopped at 0.
SpinResult evaluateGrid(
  List<List<GameSymbol>> columns, {
  int betPerLine = 1,
  int multiplier = 1,
  bool isFreeSpin = false,
}) =>
    SlotMachine(
      strips: <List<GameSymbol>>[
        for (final List<GameSymbol> column in columns) bandShowing(column),
      ],
    ).evaluate(
      stops: List<int>.filled(Paytable.reelCount, 0),
      betPerLine: betPerLine,
      multiplier: multiplier,
      isFreeSpin: isFreeSpin,
    );

void main() {
  group('window', () {
    final SlotMachine machine = SlotMachine(
      strips: List<List<GameSymbol>>.filled(Paytable.reelCount, <GameSymbol>[
        cherry,
        lemon,
        bell,
        seven,
        wild,
      ]),
    );

    test('exposes three consecutive band symbols per reel', () {
      expect(
        machine.windowAt(List<int>.filled(Paytable.reelCount, 1))[0],
        <GameSymbol>[lemon, bell, seven],
      );
    });

    test('wraps around the end of a band', () {
      // Stop 4 is the last position, so rows 1 and 2 come from the top.
      expect(
        machine.windowAt(List<int>.filled(Paytable.reelCount, 4))[0],
        <GameSymbol>[wild, cherry, lemon],
      );
    });

    test('rejects the wrong number of stops', () {
      expect(() => machine.windowAt(<int>[0, 0]), throwsArgumentError);
    });
  });

  group('line scoring', () {
    test('pays three of a kind from the leftmost reel', () {
      final LineWin win = scoreLine(<GameSymbol>[
        seven,
        seven,
        seven,
        bell,
        cherry,
      ])!;

      expect(win.symbol, seven);
      expect(win.matchCount, 3);
      expect(win.payout, Paytable.linePay(seven, 3));
    });

    test('ignores a run that does not start on the leftmost reel', () {
      expect(
        scoreLine(<GameSymbol>[cherry, seven, seven, seven, bell]),
        isNull,
      );
    });

    test('pays the full run when five match', () {
      final LineWin win = scoreLine(<GameSymbol>[
        bell,
        bell,
        bell,
        bell,
        bell,
      ])!;

      expect(win.matchCount, 5);
      expect(win.payout, Paytable.linePay(bell, 5));
    });

    test('does not pay a two-symbol run', () {
      expect(
        scoreLine(<GameSymbol>[seven, seven, bell, cherry, cherry]),
        isNull,
      );
    });

    test('scales with the line bet', () {
      final LineWin win = scoreLine(<GameSymbol>[
        seven,
        seven,
        seven,
        bell,
        cherry,
      ], betPerLine: 25)!;

      expect(win.payout, Paytable.linePay(seven, 3) * 25);
    });

    test('reports the winning cells left to right', () {
      // Payline 0 is the centre row, so every cell sits on row 1.
      final LineWin win = scoreLine(<GameSymbol>[
        seven,
        seven,
        seven,
        bell,
        cherry,
      ])!;

      expect(win.cells, <({int reel, int row})>[
        (reel: 0, row: 1),
        (reel: 1, row: 1),
        (reel: 2, row: 1),
      ]);
    });

    test('ranks every symbol by rarity, longer runs paying more', () {
      // The paytable is only fair if it agrees with the band frequencies, so
      // this pins the intended ordering.
      for (final GameSymbol symbol in Paytable.linePays.keys) {
        expect(
          Paytable.linePay(symbol, 4),
          greaterThan(Paytable.linePay(symbol, 3)),
          reason: '${symbol.displayName} x4 should beat x3',
        );
        expect(
          Paytable.linePay(symbol, 5),
          greaterThan(Paytable.linePay(symbol, 4)),
          reason: '${symbol.displayName} x5 should beat x4',
        );
      }
      final List<GameSymbol> byValue = Paytable.payingSymbolsByValue;
      for (int i = 1; i < byValue.length; i++) {
        expect(
          Paytable.linePay(byValue[i - 1], 5),
          greaterThanOrEqualTo(Paytable.linePay(byValue[i], 5)),
          reason:
              '${byValue[i - 1].displayName} should rank above '
              '${byValue[i].displayName}',
        );
      }
    });
  });

  group('wilds', () {
    test('substitute to extend a run', () {
      final LineWin win = scoreLine(<GameSymbol>[
        seven,
        wild,
        seven,
        cherry,
        cherry,
      ])!;

      expect(win.symbol, seven);
      expect(win.matchCount, 3);
    });

    test('report the symbol they stood in for', () {
      final LineWin win = scoreLine(<GameSymbol>[
        bell,
        bell,
        wild,
        wild,
        bell,
      ])!;

      expect(win.symbol, bell);
      expect(win.matchCount, 5);
      expect(win.payout, Paytable.linePay(bell, 5));
    });

    test('pay as wilds when that beats substituting', () {
      expect(
        Paytable.linePay(wild, 3),
        greaterThan(Paytable.linePay(cherry, 5)),
        reason: 'test premise: three wilds must outrank five cherries',
      );
      final LineWin win = scoreLine(<GameSymbol>[
        wild,
        wild,
        wild,
        cherry,
        cherry,
      ])!;

      expect(win.symbol, wild);
      expect(win.payout, Paytable.linePay(wild, 3));
    });

    test('substitute when that beats paying as wilds', () {
      // Two wilds cannot pay on their own, so the seven run is taken instead.
      final LineWin win = scoreLine(<GameSymbol>[
        wild,
        wild,
        seven,
        seven,
        seven,
      ])!;

      expect(win.symbol, seven);
      expect(win.matchCount, 5);
      expect(win.payout, Paytable.linePay(seven, 5));
    });

    test('pay the top prize for five wilds', () {
      final LineWin win = scoreLine(<GameSymbol>[
        wild,
        wild,
        wild,
        wild,
        wild,
      ])!;

      expect(win.symbol, wild);
      expect(win.payout, Paytable.linePay(wild, 5));
      expect(
        win.payout,
        Paytable.linePays.values
            .map((Map<int, int> pays) => pays[5]!)
            .reduce(max),
        reason: 'five wilds is the best line in the game',
      );
    });

    test('cannot substitute for a scatter', () {
      expect(
        scoreLine(<GameSymbol>[wild, wild, scatter, scatter, scatter]),
        isNull,
      );
    });
  });

  group('scatters', () {
    /// A grid with [count] scatters spread across separate reels and rows.
    SpinResult gridWithScatters(int count, {int betPerLine = 1}) {
      return evaluateGrid(<List<GameSymbol>>[
        for (int reel = 0; reel < Paytable.reelCount; reel++)
          <GameSymbol>[
            for (int row = 0; row < Paytable.rowCount; row++)
              // One scatter per reel while the budget lasts, on a rotating
              // row so no payline collects more than one of them.
              (reel < count && row == reel % Paytable.rowCount)
                  ? scatter
                  : (row.isEven ? cherry : grape),
          ],
      ], betPerLine: betPerLine);
    }

    test('do not carry a payline', () {
      expect(
        scoreLine(<GameSymbol>[scatter, scatter, scatter, bell, cherry]),
        isNull,
      );
    });

    test('pay a multiple of the total bet wherever they land', () {
      final SpinResult result = gridWithScatters(3, betPerLine: 2);
      final ScatterWin win = result.scatterWin!;

      expect(win.count, 3);
      expect(win.payout, Paytable.scatterPay(3) * result.totalBet);
      expect(win.cells, hasLength(3));
    });

    test('award free spins on three or more', () {
      expect(gridWithScatters(3).freeSpinsAwarded, Paytable.freeSpinsFor(3));
      expect(gridWithScatters(4).freeSpinsAwarded, Paytable.freeSpinsFor(4));
      expect(gridWithScatters(5).freeSpinsAwarded, Paytable.freeSpinsFor(5));
      expect(Paytable.freeSpinsFor(3), greaterThan(0));
    });

    test('pay nothing for two', () {
      final SpinResult result = gridWithScatters(2);

      expect(result.scatterWin, isNull);
      expect(result.freeSpinsAwarded, 0);
    });

    test('pay their top tier when the grid shows more than five', () {
      // A 5x3 window can hold up to fifteen scatters, but the table only prices
      // three, four and five. Anything above that must still pay the top tier
      // rather than dropping back to nothing.
      final SpinResult flooded = evaluateGrid(
        List<List<GameSymbol>>.filled(
          Paytable.reelCount,
          List<GameSymbol>.filled(Paytable.rowCount, scatter),
        ),
      );
      final ScatterWin win = flooded.scatterWin!;

      expect(win.count, Paytable.reelCount * Paytable.rowCount);
      expect(
        win.payout,
        Paytable.scatterPay(Paytable.reelCount) * flooded.totalBet,
      );
      expect(win.freeSpinsAwarded, Paytable.freeSpinsFor(Paytable.reelCount));
      expect(win.payout, greaterThan(0));
    });

    test('pay more the more of them land', () {
      expect(
        gridWithScatters(4).scatterTotal,
        greaterThan(gridWithScatters(3).scatterTotal),
      );
      expect(
        gridWithScatters(5).scatterTotal,
        greaterThan(gridWithScatters(4).scatterTotal),
      );
    });
  });

  group('free spins', () {
    test('multiply every win', () {
      final List<List<GameSymbol>> columns = <List<GameSymbol>>[
        <GameSymbol>[cherry, seven, grape],
        <GameSymbol>[grape, seven, cherry],
        <GameSymbol>[cherry, seven, grape],
        <GameSymbol>[grape, cherry, bell],
        <GameSymbol>[bell, grape, cherry],
      ];
      final SpinResult single = evaluateGrid(columns);
      final SpinResult doubled = evaluateGrid(
        columns,
        multiplier: 2,
        isFreeSpin: true,
      );

      expect(single.totalPayout, greaterThan(0));
      expect(doubled.totalPayout, single.totalPayout * 2);
      expect(doubled.isFreeSpin, isTrue);
    });

    test('cost nothing, so they can never lose credits', () {
      final SpinResult losing = evaluateGrid(losingColumns, isFreeSpin: true);

      expect(losing.totalPayout, 0);
      expect(losing.netChange, 0);
    });

    test('a paid losing spin costs the total bet', () {
      final SpinResult losing = evaluateGrid(losingColumns);

      expect(losing.totalPayout, 0);
      expect(losing.netChange, -losing.totalBet);
    });
  });

  group('spin', () {
    test('is reproducible for a given seed', () {
      List<int> stopsFor(int seed) =>
          SlotMachine(random: Random(seed)).spin(betPerLine: 1).stops;

      expect(stopsFor(7), stopsFor(7));
    });

    test('lands on every stop position over enough spins', () {
      final SlotMachine machine = SlotMachine(random: Random(1));
      final Set<int> seen = <int>{};
      for (int i = 0; i < 5000; i++) {
        seen.add(machine.spin(betPerLine: 1).stops.first);
      }

      expect(seen, hasLength(machine.strips.first.length));
    });

    test('always reports a total bet across every payline', () {
      final SpinResult result = SlotMachine(random: Random(3))
          .spin(betPerLine: 5);

      expect(result.totalBet, 5 * Paytable.lineCount);
      expect(result.grid, hasLength(Paytable.reelCount));
      expect(result.grid.first, hasLength(Paytable.rowCount));
    });

    test('rejects a non-positive bet', () {
      expect(() => SlotMachine().spin(betPerLine: 0), throwsArgumentError);
    });

    test('rejects the wrong number of bands', () {
      expect(
        () => SlotMachine(
          strips: <List<GameSymbol>>[
            bandShowing(<GameSymbol>[cherry, lemon, bell]),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a band shorter than the window', () {
      expect(
        () => SlotMachine(
          strips: List<List<GameSymbol>>.filled(
            Paytable.reelCount,
            <GameSymbol>[cherry, lemon],
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('result reporting', () {
    test('totals line and scatter payouts', () {
      final SpinResult result = evaluateGrid(<List<GameSymbol>>[
        <GameSymbol>[scatter, seven, grape],
        <GameSymbol>[grape, seven, scatter],
        <GameSymbol>[scatter, seven, grape],
        <GameSymbol>[grape, cherry, bell],
        <GameSymbol>[bell, grape, cherry],
      ]);

      expect(result.scatterTotal, greaterThan(0));
      expect(result.lineWinTotal, greaterThan(0));
      expect(result.totalPayout, result.lineWinTotal + result.scatterTotal);
      expect(result.isWin, isTrue);
      expect(result.winningCells, isNotEmpty);
      expect(
        result.winMultiple,
        closeTo(result.totalPayout / result.totalBet, 1e-9),
      );
    });
  });
}
