import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/services/audio_player_service.dart'
    show AudioPlaybackState;
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/ui/chat/widgets/bubble/parts/media_message_content.dart'
    show AudioMessageContent;

ChatMessage _audioMessage({String source = 'https://cdn.example.com/a.mp3'}) {
  return ChatMessage(
    clientMsgId: 'm1',
    serverMsgId: '',
    sendId: 'other',
    recvId: 'me',
    groupId: '',
    senderPlatformId: 0,
    senderNickname: '张三',
    senderFaceUrl: '',
    sessionType: 1,
    msgFrom: 0,
    contentType: 103,
    // 对齐 OpenIM soundElem 的真实结构：字段在顶层，另有嵌套 elem
    content:
        '{"sourceUrl":"$source","duration":8,'
        '"soundElem":{"sourceUrl":"$source","duration":8}}',
    seq: 1,
    sendTime: DateTime.now().millisecondsSinceEpoch,
    createTime: DateTime.now().millisecondsSinceEpoch,
    status: 2,
    isRead: true,
    attachedInfo: '',
    ex: '',
  );
}

void main() {
  group('AudioPlaybackState', () {
    test('只有同一条语音在播放时才算播放中', () {
      const state = AudioPlaybackState(
        source: 'a.mp3',
        isPlaying: true,
        position: Duration(seconds: 2),
        duration: Duration(seconds: 8),
      );

      expect(state.isPlayingSource('a.mp3'), isTrue);
      expect(state.isPlayingSource('b.mp3'), isFalse);
      expect(
        state.copyWith(isPlaying: false).isPlayingSource('a.mp3'),
        isFalse,
      );
    });

    test('进度按时长归一化，时长未知时为 0', () {
      expect(
        const AudioPlaybackState(
          position: Duration(seconds: 2),
          duration: Duration(seconds: 8),
        ).progress,
        0.25,
      );
      expect(
        const AudioPlaybackState(
          position: Duration(seconds: 20),
          duration: Duration(seconds: 8),
        ).progress,
        1.0,
      );
      expect(const AudioPlaybackState().progress, 0);
    });
  });

  group('语音气泡', () {
    Widget host(AudioPlaybackState? playback) {
      return MaterialApp(
        home: Scaffold(
          body: AudioMessageContent(
            message: _audioMessage(),
            isFromMe: false,
            playback: playback,
          ),
        ),
      );
    }

    testWidgets('未播放时展示播放图标、进度为 0', (tester) async {
      await tester.pumpWidget(host(null));

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0);
    });

    testWidgets('播放中变成停止图标并显示进度', (tester) async {
      await tester.pumpWidget(
        host(
          const AudioPlaybackState(
            source: 'https://cdn.example.com/a.mp3',
            isPlaying: true,
            position: Duration(seconds: 4),
            duration: Duration(seconds: 8),
          ),
        ),
      );

      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
    });

    testWidgets('别的语音在播放时，本条仍是播放图标', (tester) async {
      await tester.pumpWidget(
        host(
          const AudioPlaybackState(
            source: 'https://cdn.example.com/other.mp3',
            isPlaying: true,
            position: Duration(seconds: 4),
            duration: Duration(seconds: 8),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });
  });
}
