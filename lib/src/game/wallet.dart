import 'package:shared_preferences/shared_preferences.dart';

import '../engine/paytable.dart';

/// Stores the player's balance and chosen bet across launches.
///
/// The interface is deliberately small so tests can swap in [MemoryWallet]
/// instead of touching platform storage.
abstract class Wallet {
  /// Credits a new player starts with, and the top-up amount when broke.
  static const int startingCredits = 5000;

  Future<int> loadCredits();

  Future<int> loadBetPerLine();

  Future<void> save({required int credits, required int betPerLine});
}

/// Wallet backed by Android's shared preferences.
class PreferencesWallet implements Wallet {
  PreferencesWallet();

  static const String _creditsKey = 'credits';
  static const String _betKey = 'bet_per_line';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int> loadCredits() async {
    final SharedPreferences prefs = await _prefs;
    return prefs.getInt(_creditsKey) ?? Wallet.startingCredits;
  }

  @override
  Future<int> loadBetPerLine() async {
    final SharedPreferences prefs = await _prefs;
    final int stored = prefs.getInt(_betKey) ?? Paytable.betPerLineSteps.first;
    // A stored bet from an older build might no longer be on the ladder.
    return Paytable.betPerLineSteps.contains(stored)
        ? stored
        : Paytable.betPerLineSteps.first;
  }

  @override
  Future<void> save({required int credits, required int betPerLine}) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setInt(_creditsKey, credits);
    await prefs.setInt(_betKey, betPerLine);
  }
}

/// Wallet that forgets everything, for tests and for a guest mode.
class MemoryWallet implements Wallet {
  MemoryWallet({this.credits = Wallet.startingCredits, int? betPerLine})
    : betPerLine = betPerLine ?? Paytable.betPerLineSteps.first;

  int credits;
  int betPerLine;

  @override
  Future<int> loadCredits() async => credits;

  @override
  Future<int> loadBetPerLine() async => betPerLine;

  @override
  Future<void> save({required int credits, required int betPerLine}) async {
    this.credits = credits;
    this.betPerLine = betPerLine;
  }
}
