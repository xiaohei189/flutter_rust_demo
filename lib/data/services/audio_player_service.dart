import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();
  String? _currentSource;

  AudioPlayerService._internal();

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> play(String source) async {
    if (_currentSource == source && isPlaying) {
      await _player.stop();
      return;
    }
    _currentSource = source;
    await _player.stop();
    await _player.play(
      source.startsWith('http') ? UrlSource(source) : DeviceFileSource(source),
    );
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
