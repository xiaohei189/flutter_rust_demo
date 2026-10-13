import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/data/services/audio_player_service.dart'
    show AudioPlaybackState;
import 'package:flutter_rust_demo/domain/models/chat_message.dart'
    show ChatMessage;
import 'package:flutter_rust_demo/ui/chat/widgets/bubble/parts/media_message_content.dart'
    show AudioMessageContent, AudioProgressTrack;
import 'package:flutter_rust_demo/ui/chat/widgets/bubble/message_bubble.dart';
import 'package:flutter_rust_demo/domain/models/user.dart' show User;

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

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      final track = tester.widget<AudioProgressTrack>(
        find.byType(AudioProgressTrack),
      );
      expect(track.progress, 0);
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

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      final track = tester.widget<AudioProgressTrack>(
        find.byType(AudioProgressTrack),
      );
      expect(track.progress, 0.5);
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

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('窄屏（真机 1080x2340 @2.75）下语音气泡不溢出', (tester) async {
      // 回归：气泡最大宽度受屏宽限制，固定宽度的按钮+轨道+时长会把时长挤出气泡，
      // 真机上表现为「RIGHT OVERFLOWED BY 15 PIXELS」。
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      final windowWidth = 1080 / 2.75;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerLeft,
              child: MessageBubble(
                message: _audioMessage(),
                otherUser: const User(id: 'me', name: '我'),
                // sendId='other' 且 currentUserId='other' → 己方气泡（真机溢出的正是这种）
                currentUserId: 'other',
                maxBubbleWidth: windowWidth * 0.65,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0:08'), findsOneWidget);
      // 轨道按可用宽度收缩，把空间让给时长（固定 72 宽会溢出）
      expect(
        tester.getSize(find.byType(AudioProgressTrack)).width,
        lessThan(72),
      );
    });
  });
}
