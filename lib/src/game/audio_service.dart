import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_sound.dart';

/// Plays the game's sound effects.
///
/// A [ChangeNotifier] so the mute button can redraw itself. Kept behind an
/// interface because audio needs a real platform: tests use
/// [SilentAudioService], which records what would have played instead.
///
/// Every implementation must treat playback as best effort. Sound is decoration
/// and a spin has already been paid for by the time a clip is asked for, so a
/// missing asset, a denied audio focus or a busy output device must never
/// interrupt the game.
abstract class AudioService extends ChangeNotifier {
  /// Whether playback is currently suppressed.
  bool get muted;

  /// Silences or restores playback, remembering the choice.
  Future<void> setMuted(bool value);

  /// Starts [sound]. Returns immediately; failures are swallowed.
  void play(GameSound sound);

  /// Reads the stored mute setting and warms up the clips.
  Future<void> load();
}

/// The real thing, backed by `audioplayers`.
class PlayerAudioService extends AudioService {
  PlayerAudioService({this._voices = 4});

  static const String _mutedKey = 'audio_muted';

  /// Several players are kept so overlapping effects do not cut each other
  /// off — five reels stopping in sequence overlap a win chime, and one player
  /// can only hold one clip at a time.
  final int _voices;
  final List<AudioPlayer> _players = <AudioPlayer>[];
  int _nextVoice = 0;

  bool _muted = false;
  bool _ready = false;
  bool _disposed = false;

  @override
  bool get muted => _muted;

  @override
  Future<void> load() async {
    if (_ready) {
      return;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _muted = prefs.getBool(_mutedKey) ?? false;
    } catch (error, stack) {
      // A wallet that cannot be read is worth surfacing; a mute flag is not.
      debugPrint('Audio: could not read mute setting: $error\n$stack');
    }
    if (_disposed) {
      return;
    }

    try {
      for (int i = 0; i < _voices; i++) {
        final AudioPlayer player = AudioPlayer();
        // Stop at the end rather than loop or release, so a voice is reusable.
        await player.setReleaseMode(ReleaseMode.stop);
        _players.add(player);
      }
      // The default player mode is used on purpose: PlayerMode.lowLatency
      // routes through SoundPool on Android, which changes how playback is
      // started and is fussier about being driven this way. Latency is instead
      // handled by priming the cache below, which copies each clip out of the
      // bundle so the first tap does not pay for the decode.
      await AudioCache.instance.loadAll(
        GameSound.values.map((GameSound s) => s.asset).toList(),
      );
      _ready = true;
    } catch (error, stack) {
      debugPrint('Audio: unavailable, continuing silently: $error\n$stack');
      _ready = false;
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  Future<void> setMuted(bool value) async {
    if (_muted == value) {
      return;
    }
    _muted = value;
    notifyListeners();
    if (value) {
      for (final AudioPlayer player in _players) {
        _ignoreFailure(player.stop());
      }
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedKey, value);
    } catch (error) {
      debugPrint('Audio: could not save mute setting: $error');
    }
  }

  @override
  void play(GameSound sound) {
    if (_muted || !_ready || _disposed || _players.isEmpty) {
      return;
    }
    final AudioPlayer player = _players[_nextVoice];
    _nextVoice = (_nextVoice + 1) % _players.length;
    // Fire and forget: a clip that fails to start is not worth a frame of delay.
    _ignoreFailure(player.play(AssetSource(_relative(sound.asset))));
  }

  /// `audioplayers` resolves [AssetSource] against the `assets/` prefix itself.
  static String _relative(String asset) =>
      asset.startsWith('assets/') ? asset.substring('assets/'.length) : asset;

  static void _ignoreFailure(Future<void> operation) {
    operation.catchError((Object error) {
      debugPrint('Audio: playback failed: $error');
    });
  }

  @override
  void dispose() {
    _disposed = true;
    for (final AudioPlayer player in _players) {
      _ignoreFailure(player.dispose());
    }
    _players.clear();
    super.dispose();
  }
}

/// Plays nothing, and remembers what it was asked for.
///
/// Used by the widget tests, which have no audio platform, and usable as a
/// permanent mute.
class SilentAudioService extends AudioService {
  SilentAudioService({this._muted = false});

  bool _muted;

  /// Sounds that would have played, oldest first.
  final List<GameSound> played = <GameSound>[];

  @override
  bool get muted => _muted;

  @override
  Future<void> load() async {}

  @override
  Future<void> setMuted(bool value) async {
    if (_muted == value) {
      return;
    }
    _muted = value;
    notifyListeners();
  }

  @override
  void play(GameSound sound) {
    if (_muted) {
      return;
    }
    played.add(sound);
  }
}
