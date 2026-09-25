/// The sound effects the game can play.
///
/// The clips are synthesised by `tool/generate_sounds.py` rather than sourced,
/// so they are original and cost nothing to redistribute. Retuning one means
/// editing that script and re-running it.
enum GameSound {
  /// A button or toggle being pressed.
  uiTap('assets/audio/ui_tap.wav'),

  /// The reels being let go.
  spinStart('assets/audio/spin_start.wav'),

  /// One reel settling into place.
  reelStop('assets/audio/reel_stop.wav'),

  /// One credit landing, played repeatedly while a win counts up.
  creditTick('assets/audio/credit_tick.wav'),

  /// An everyday win.
  winSmall('assets/audio/win_small.wav'),

  /// A win worth looking up for.
  winBig('assets/audio/win_big.wav'),

  /// The top tier.
  winJackpot('assets/audio/win_jackpot.wav'),

  /// Free spins being awarded.
  bonus('assets/audio/bonus.wav');

  const GameSound(this.asset);

  /// Path of the clip, as declared in `pubspec.yaml`.
  final String asset;
}
