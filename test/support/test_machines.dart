import 'dart:math';

import 'package:slot_game/src/engine/game_symbol.dart';
import 'package:slot_game/src/engine/paytable.dart';
import 'package:slot_game/src/engine/slot_machine.dart';
import 'package:slot_game/src/engine/spin_result.dart';

/// Machines with known outcomes, so a test can choose what the reels land.
///
/// Each band is a single symbol repeated, so wherever a reel stops the visible
/// window is the same — which makes the result of a spin predictable without
/// hunting for a lucky seed.
List<List<GameSymbol>> uniformBands(
  List<GameSymbol> perReel,
) => <List<GameSymbol>>[
  for (final GameSymbol symbol in perReel) List<GameSymbol>.filled(8, symbol),
];

/// Fills every cell with [symbol].
SlotMachine machineShowing(GameSymbol symbol) => SlotMachine(
  strips: uniformBands(List<GameSymbol>.filled(Paytable.reelCount, symbol)),
  random: Random(1),
);

/// Always pays five of a kind on every payline.
SlotMachine alwaysWins() => machineShowing(GameSymbol.seven);

/// Always fills the grid with scatters, triggering the bonus.
SlotMachine alwaysScatters() => machineShowing(GameSymbol.scatter);

/// Can never pay: reels 2 and 3 hold different symbols, and every payline takes
/// one cell from each reel, so no run ever reaches two.
SlotMachine neverWins() => SlotMachine(
  strips: uniformBands(<GameSymbol>[
    GameSymbol.cherry,
    GameSymbol.grape,
    GameSymbol.bell,
    GameSymbol.cherry,
    GameSymbol.grape,
  ]),
  random: Random(1),
);

/// Plays through a scripted sequence of machines, one per spin.
///
/// The last entry is reused once the script runs out, which is what lets a test
/// trigger the bonus on spin one and then watch it drain — an always-scattering
/// machine would retrigger forever.
class ScriptedMachine extends SlotMachine {
  ScriptedMachine(this.sequence) : super(strips: sequence.first.strips);

  final List<SlotMachine> sequence;
  int _spins = 0;

  /// How many spins have been played through the script.
  int get spinsPlayed => _spins;

  @override
  SpinResult spin({
    required int betPerLine,
    int multiplier = 1,
    bool isFreeSpin = false,
  }) {
    final SlotMachine machine = sequence[min(_spins, sequence.length - 1)];
    _spins++;
    return machine.spin(
      betPerLine: betPerLine,
      multiplier: multiplier,
      isFreeSpin: isFreeSpin,
    );
  }
}

/// Triggers the bonus on the first spin, then goes cold so it drains.
SlotMachine scattersThenCold() =>
    ScriptedMachine(<SlotMachine>[alwaysScatters(), neverWins()]);
