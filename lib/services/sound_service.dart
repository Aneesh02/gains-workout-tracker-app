import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  static bool enabled = true;

  // Ducks music for short in-workout beeps
  static final _beepCtx = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  // Full media volume for finish sounds — takes focus, plays loud
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
      await p.setAudioContext(ctx ?? _beepCtx);
      await p.setVolume(volume);
      await p.play(AssetSource('sounds/$file'));
      p.onPlayerComplete.listen((_) => p.dispose());
    } catch (_) {}
  }

  Future<void> setComplete() => _play('checkmark_revised.mp3');
  Future<void> restOver() => _play('boxing_bell.mp3');
  Future<void> workoutFinish() => _play('finish_normal.mp3', ctx: _finishCtx, volume: 1.0);
  Future<void> workoutFinishPR() => _play('finish_pr.mp3', ctx: _finishCtx, volume: 1.0);
  Future<void> swipeDelete() => _play('swipe_delete.mp3');
}
