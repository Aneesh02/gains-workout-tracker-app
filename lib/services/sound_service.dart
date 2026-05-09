import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  Future<void> _play(String file) async {
    try {
      final p = AudioPlayer();
      await p.play(AssetSource('sounds/$file'));
      p.onPlayerComplete.listen((_) => p.dispose());
    } catch (_) {}
  }

  Future<void> setComplete() => _play('checkmark_revised.mp3');
  Future<void> restOver() => _play('boxing_bell.mp3');
  Future<void> workoutFinish() => _play('finish_normal.mp3');
  Future<void> workoutFinishPR() => _play('finish_pr.mp3');
  Future<void> swipeDelete() => _play('swipe_delete.mp3');
}
