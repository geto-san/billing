import 'package:just_audio/just_audio.dart';

class MoneySound {
  MoneySound._();
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> play() async {
    try {
      await _player.stop();
      await _player.setAsset('assets/sounds/cash_register.wav');
      await _player.play();
    } catch (_) {}
  }
}
