import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  static bool enabled = true;

  // Plays alongside whatever is playing — no ducking, no focus change.
  // Uses media content type so it goes through the media volume, not touch sounds.
  static final _softCtx = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  // Full media focus for workout-finish celebrations.
  static final _finishCtx = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
  );

  Future<void> _play(String file, {AudioContext? ctx, double volume = 1.0}) async {
    if (!enabled) return;
    try {
      final p = AudioPlayer();
      await p.setAudioContext(ctx ?? _softCtx);
      await p.setVolume(volume);
      await p.play(AssetSource('sounds/$file'));
      p.onPlayerComplete.listen((_) => p.dispose());
    } catch (_) {}
  }

  Future<void> setComplete() => _play('checkmark_revised.mp3');
  Future<void> restOver()    => _play('boxing_bell.mp3');
  Future<void> workoutFinish()   => _play('finish_normal.mp3', ctx: _finishCtx);
  Future<void> workoutFinishPR() => _play('finish_pr.mp3',    ctx: _finishCtx);
  Future<void> swipeDelete() => _play('swipe_delete.mp3');
}
