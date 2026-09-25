import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slot_game/src/engine/game_symbol.dart';
import 'package:slot_game/src/engine/paytable.dart';
import 'package:slot_game/src/engine/rtp.dart';
import 'package:slot_game/src/engine/slot_machine.dart';
import 'package:slot_game/src/game/audio_service.dart';
import 'package:slot_game/src/game/game_controller.dart';
import 'package:slot_game/src/game/game_sound.dart';
import 'package:slot_game/src/game/spin_timing.dart';
import 'package:slot_game/src/game/wallet.dart';
import 'package:slot_game/src/ui/paytable_sheet.dart';
import 'package:slot_game/src/ui/reel_view.dart';
import 'package:slot_game/src/ui/slot_screen.dart';

import '../support/test_machines.dart';

void main() {
  /// Mounts the screen on a phone-sized surface.
  late SilentAudioService audio;

  Future<GameController> pumpGame(
    WidgetTester tester, {
    SlotMachine? machine,
    int credits = Wallet.startingCredits,
    bool muted = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2280)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final GameController game = GameController(
      machine: machine ?? neverWins(),
      wallet: MemoryWallet(credits: credits),
    );
    addTearDown(game.dispose);
    await game.load();

    audio = SilentAudioService(muted: muted);
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotScreen(game: game, audio: audio),
        ),
      ),
    );
    return game;
  }

  /// Advances past the reel animation and the payout roll-up.
  Future<void> settleSpin(WidgetTester tester) async {
    // A frame first: tapping does not pump, so without this the clock would be
    // advanced before the reels have been told to start, and they would still
    // be turning when the helper returns.
    await tester.pump();
    await tester.pump(SpinTiming.allReelsStopped(Paytable.reelCount));
    await tester.pump(SpinTiming.winCountUp);
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Runs the free-spin bonus to its end, so no timer outlives the test.
  Future<void> drainFreeSpins(WidgetTester tester, GameController game) async {
    for (int guard = 0; game.inFreeSpins && guard < 200; guard++) {
      await settleSpin(tester);
      await tester.pump(SpinTiming.autoplayPause);
    }
    expect(game.inFreeSpins, isFalse, reason: 'bonus never ended');
  }

  testWidgets('lays out one reel per column with no overflow', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester);

    expect(find.byType(ReelView), findsNWidgets(Paytable.reelCount));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the balance, the stake and the machine name', (
    WidgetTester tester,
  ) async {
    final GameController game = await pumpGame(tester, credits: 5000);

    expect(find.text('LUCKY FIVE'), findsOneWidget);
    expect(find.text('CREDITS'), findsOneWidget);
    expect(find.text('5,000'), findsOneWidget);
    expect(find.text('${game.totalBet}'), findsOneWidget);
  });

  testWidgets('spinning takes the stake and settles back to idle', (
    WidgetTester tester,
  ) async {
    final GameController game = await pumpGame(tester);
    final int stake = game.totalBet;
    final int before = game.credits;

    await tester.tap(find.text('SPIN'));
    await tester.pump();

    expect(game.phase, SpinPhase.spinning);
    expect(game.credits, before - stake);

    await settleSpin(tester);

    expect(game.phase, SpinPhase.idle);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a winning spin shows the win and its paylines', (
    WidgetTester tester,
  ) async {
    final GameController game = await pumpGame(tester, machine: alwaysWins());

    await tester.tap(find.text('SPIN'));
    await tester.pump();
    await tester.pump(SpinTiming.allReelsStopped(Paytable.reelCount));

    expect(game.result!.isWin, isTrue);
    expect(game.phase, SpinPhase.paying);
    // Five sevens on all ten lines is comfortably a jackpot.
    expect(find.text('JACKPOT'), findsOneWidget);

    await settleSpin(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the free-spin bonus is announced on the reels', (
    WidgetTester tester,
  ) async {
    final GameController game = await pumpGame(
      tester,
      machine: scattersThenCold(),
    );

    await tester.tap(find.text('SPIN'));
    await settleSpin(tester);

    expect(game.inFreeSpins, isTrue);
    expect(find.text('FREE SPINS'), findsOneWidget);
    expect(
      find.text('FREE SPINS  ·  ${Paytable.freeSpinMultiplier}x WINS'),
      findsOneWidget,
    );

    // The bonus plays itself out, and its timers must not outlive the test.
    await drainFreeSpins(tester, game);
    expect(find.text('FREE SPINS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bet steppers move the stake', (WidgetTester tester) async {
    final GameController game = await pumpGame(tester);
    final int before = game.totalBet;

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(game.totalBet, greaterThan(before));

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();

    expect(game.totalBet, before);
  });

  testWidgets('max bet raises the stake to the top of the ladder', (
    WidgetTester tester,
  ) async {
    final GameController game = await pumpGame(tester, credits: 1000000);

    await tester.tap(find.textContaining('MAX BET'));
    await tester.pump();

    expect(game.betPerLine, Paytable.betPerLineSteps.last);
  });

  testWidgets('the paytable opens and states the return to player', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester);

    await tester.tap(find.text('Pays'));
    // The winning-cell pulse repeats forever, so pumpAndSettle would never
    // return; pump past the sheet's entrance instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PaytableSheet), findsOneWidget);
    expect(find.text('PAYTABLE'), findsOneWidget);

    // Every paying symbol is listed. BAR names itself in its own artwork, so
    // its name legitimately appears more than once inside the sheet.
    for (final GameSymbol symbol in Paytable.payingSymbolsByValue) {
      expect(
        find.descendant(
          of: find.byType(PaytableSheet),
          matching: find.text(symbol.displayName),
        ),
        findsAtLeastNWidgets(1),
        reason: '${symbol.displayName} missing from the paytable',
      );
    }

    // The rules sit below the fold of a lazily built list, so scroll to them.
    await tester.scrollUntilVisible(
      find.text('RETURN TO PLAYER'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('RETURN TO PLAYER'), findsOneWidget);
    // The figure is computed from the live paytable, not hardcoded.
    expect(
      find.textContaining(
        '${(computeExactRtp().effectiveRtp * 100).toStringAsFixed(2)}%',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a broke player is offered a top-up instead of a spin', (
    WidgetTester tester,
  ) async {
    final GameController game = await pumpGame(tester, credits: 0);

    expect(game.isBroke, isTrue);
    expect(find.text('SPIN'), findsNothing);

    await tester.tap(find.text('TOP\nUP'));
    await tester.pump();

    expect(game.credits, Wallet.startingCredits);
    expect(find.text('SPIN'), findsOneWidget);
  });

  testWidgets('turbo can be toggled', (WidgetTester tester) async {
    final GameController game = await pumpGame(tester);

    await tester.tap(find.text('Turbo'));
    await tester.pump();

    expect(game.turbo, isTrue);
  });

  testWidgets('pressing spin sounds the reels being let go', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester);

    await tester.tap(find.text('SPIN'));
    await tester.pump();

    expect(audio.played, contains(GameSound.spinStart));

    // Let the spin finish so its timers do not outlive the test.
    await settleSpin(tester);
  });

  testWidgets('every reel coming to rest is heard once', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester);

    await tester.tap(find.text('SPIN'));
    await settleSpin(tester);

    expect(
      audio.played.where((GameSound s) => s == GameSound.reelStop).length,
      Paytable.reelCount,
      reason: 'one stop per reel, no more and no fewer',
    );
  });

  testWidgets('a jackpot plays the top-tier clip, a loss plays none', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester, machine: alwaysWins());

    await tester.tap(find.text('SPIN'));
    await settleSpin(tester);

    expect(audio.played, contains(GameSound.winJackpot));
    expect(audio.played, isNot(contains(GameSound.winSmall)));
    expect(audio.played, contains(GameSound.creditTick));
  });

  testWidgets('a losing spin plays no win clip at all', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester);

    await tester.tap(find.text('SPIN'));
    await settleSpin(tester);

    const Set<GameSound> winClips = <GameSound>{
      GameSound.winSmall,
      GameSound.winBig,
      GameSound.winJackpot,
      GameSound.bonus,
      GameSound.creditTick,
    };
    expect(audio.played.where(winClips.contains), isEmpty);
  });

  testWidgets('the bonus is announced when free spins are won', (
    WidgetTester tester,
  ) async {
    final GameController game = await pumpGame(
      tester,
      machine: scattersThenCold(),
    );

    await tester.tap(find.text('SPIN'));
    await settleSpin(tester);

    expect(audio.played, contains(GameSound.bonus));

    await drainFreeSpins(tester, game);
  });

  testWidgets('controls click when pressed', (WidgetTester tester) async {
    await pumpGame(tester);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(audio.played, contains(GameSound.uiTap));
  });

  testWidgets('muting silences everything and survives a spin', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester, machine: alwaysWins(), muted: true);

    await tester.tap(find.text('SPIN'));
    await settleSpin(tester);

    expect(audio.played, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mute button toggles and shows its state', (
    WidgetTester tester,
  ) async {
    await pumpGame(tester);

    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();

    expect(audio.muted, isTrue);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_off_rounded));
    await tester.pump();

    expect(audio.muted, isFalse);
  });

  testWidgets('survives a short screen without overflowing', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(720, 1280)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final GameController game = GameController(
      machine: neverWins(),
      wallet: MemoryWallet(),
    );
    addTearDown(game.dispose);
    final SilentAudioService shortScreenAudio = SilentAudioService();
    addTearDown(shortScreenAudio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlotScreen(game: game, audio: shortScreenAudio),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ReelView), findsNWidgets(Paytable.reelCount));
  });
}
