import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  /// 播放语音，返回是否成功开始播放。
  ///
  /// 本地临时文件被清理、远端 URL 不可达等情况下播放器会直接抛错；
  /// 这里必须把播放态复位，否则气泡会永远停在「播放中」的停止图标上。
  Future<bool> play(String source) async {
    final player = _ensurePlayer;
    if (_currentSource == source && isPlaying) {
      await player.stop();
      _currentSource = null;
      playback.value = const AudioPlaybackState();
      return true;
    }
    _currentSource = source;
    await player.stop();
    playback.value = AudioPlaybackState(source: source, isPlaying: true);
    try {
      // 远端语音先落盘再播：`/object/...` 是 302 跳转到对象存储的地址，
      // Android 平台的 MediaPlayer 走这条链路会卡住不返回（真机 MIUI 实测
      // 30s 超时后报「Future not completed」），Dart 侧下载后按文件播最稳。
      final playPath = await _localFileFor(source) ?? source;
      await player.play(DeviceFileSource(playPath));
      return true;
    } catch (e) {
      debugPrint('[AudioPlayer] 播放失败: source=$source err=$e');
      _currentSource = null;
      playback.value = const AudioPlaybackState();
      return false;
    }
  }

  /// 远端地址返回本地缓存文件路径（已缓存则直接复用）；本地路径返回 null。
  Future<String?> _localFileFor(String source) async {
    if (!source.startsWith('http')) return null;
    final dir = Directory('${(await getTemporaryDirectory()).path}/audio_cache');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final rawName = source.split('/').last.split('?').first;
    final safeName = rawName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final file = File('${dir.path}/${_stableKey(source)}_$safeName');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;

    final resp = await http
        .get(Uri.parse(source))
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw Exception('语音下载失败: HTTP ${resp.statusCode}');
    }
    await file.writeAsBytes(resp.bodyBytes, flush: true);
    return file.path;
  }

  /// 稳定的缓存键（String.hashCode 跨进程不保证一致，会让缓存文件越攒越多）
  String _stableKey(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
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
