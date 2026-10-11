import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 语音播放状态（供气泡展示播放中动画/进度）。
class AudioPlaybackState {
  const AudioPlaybackState({
    this.source,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  /// 当前播放/暂停的音频地址；没有播放任务时为 null。
  final String? source;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  /// 指定地址是否正在播放（同一条语音才展示播放态）。
  bool isPlayingSource(String value) => isPlaying && source == value;

  /// 播放进度 0~1；时长未知时为 0。
  double get progress {
    final total = duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  AudioPlaybackState copyWith({
    String? source,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return AudioPlaybackState(
      source: source ?? this.source,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  String? _currentSource;

  /// 播放器实例按需创建：`AudioPlayer()` 构造即初始化平台通道，
  /// 在测试/预览等没有插件实现的环境里直接创建会抛 MissingPluginException。
  AudioPlayer? _player;

  /// 播放状态（ValueNotifier：气泡用 ValueListenableBuilder 订阅，
  /// 只重建语音气泡，不牵动整页）。
  final ValueNotifier<AudioPlaybackState> playback =
      ValueNotifier<AudioPlaybackState>(const AudioPlaybackState());

  AudioPlayerService._internal();

  AudioPlayer get _ensurePlayer {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    player.onPositionChanged.listen((position) {
      playback.value = playback.value.copyWith(position: position);
    });
    player.onDurationChanged.listen((duration) {
      playback.value = playback.value.copyWith(duration: duration);
    });
    player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      playback.value = playback.value.copyWith(
        isPlaying: playing,
        source: _currentSource,
      );
    });
    player.onPlayerComplete.listen((_) {
      _currentSource = null;
      playback.value = const AudioPlaybackState();
    });
    _player = player;
    return player;
  }

  bool get isPlaying => _player?.state == PlayerState.playing;

  Future<void> play(String source) async {
    final player = _ensurePlayer;
    if (_currentSource == source && isPlaying) {
      await player.stop();
      _currentSource = null;
      playback.value = const AudioPlaybackState();
      return;
    }
    _currentSource = source;
    await player.stop();
    playback.value = AudioPlaybackState(source: source, isPlaying: true);
    await player.play(
      source.startsWith('http') ? UrlSource(source) : DeviceFileSource(source),
    );
  }

  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      // 容错：插件在测试/预览环境可能不可用，停止播放属于尽力而为。
      try {
        await player.stop();
      } catch (_) {
        // ignore: 平台通道缺失或已释放，不需要向上传播
      }
    }
    _currentSource = null;
    playback.value = const AudioPlaybackState();
  }
}
