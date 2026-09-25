/// How long the reels take to come to rest.
///
/// The controller banks a win only once the last reel has stopped, and the
/// reel widgets animate to the same schedule, so both read these numbers
/// rather than keeping their own copies in sync by hand.
class SpinTiming {
  const SpinTiming._();

  /// How long the first reel spins for.
  static const Duration firstReelSpin = Duration(milliseconds: 900);

  /// Extra spin time added per reel, so they stop left to right.
  static const Duration perReelDelay = Duration(milliseconds: 220);

  /// Cut to this fraction of the usual time when turbo is on.
  static const double turboFactor = 0.35;

  /// Pause after the reels stop before the next autoplay spin.
  static const Duration autoplayPause = Duration(milliseconds: 900);

  /// How long the credit counter takes to roll up to a win.
  static const Duration winCountUp = Duration(milliseconds: 700);

  /// Time for reel [index] to settle.
  static Duration reelStop(int index, {bool turbo = false}) {
    final int millis =
        firstReelSpin.inMilliseconds + perReelDelay.inMilliseconds * index;
    return Duration(
      milliseconds: turbo ? (millis * turboFactor).round() : millis,
    );
  }

  /// Time for every reel to settle.
  static Duration allReelsStopped(int reelCount, {bool turbo = false}) =>
      reelStop(reelCount - 1, turbo: turbo);
}
