import 'package:go_router/go_router.dart';

import '../generated/rust/model/message.dart' show MessageInfo;
import '../ui/chat/views/chat_detail_screen.dart';
import '../ui/chat/views/chat_settings_screen.dart';
import '../ui/chat/views/merge_message_detail_screen.dart';
import '../ui/chat/widgets/media_viewer.dart';
import '../ui/shared/views/route_error_page.dart';
import 'app_paths.dart';

/// 聊天域路由：会话详情 / 会话设置 / 合并消息 / 媒体预览
List<RouteBase> buildChatRoutes() {
  return [
    GoRoute(
      path: AppPaths.chatDetail,
      builder: (context, state) {
        final conversationId = state.pathParameters['id'];
        final preLoaded = state.uri.queryParameters['preLoaded'] == 'true';
        if (conversationId == null || conversationId.isEmpty) {
          return const RouteErrorPage(message: '会话ID不存在');
        }
        return ChatDetailScreen(
          conversationId: conversationId,
          preLoaded: preLoaded,
        );
      },
    ),
    GoRoute(
      path: AppPaths.chatSettings,
      builder: (context, state) {
        final conversationId = state.pathParameters['id'];
        if (conversationId == null || conversationId.isEmpty) {
          return const RouteErrorPage(message: '会话ID不存在');
        }
        return ChatSettingsScreen(conversationId: conversationId);
      },
    ),
    GoRoute(
      path: AppPaths.mergeMessage,
      builder: (context, state) {
        final message = state.extra as MessageInfo?;
        if (message == null) {
          return const RouteErrorPage(message: '消息不存在');
        }
        return MergeMessageDetailScreen(message: message);
      },
    ),
    GoRoute(
      path: AppPaths.mediaImage,
      pageBuilder: (context, state) {
        final query = state.uri.queryParameters;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, _, _, child) => child,
          child: ImagePreviewScreen(
            source: query['source'] ?? '',
            suggestedName: query['name'] ?? 'image.jpg',
          ),
        );
      },
    ),
    GoRoute(
      path: AppPaths.mediaVideo,
      pageBuilder: (context, state) {
        final source = state.uri.queryParameters['source'] ?? '';
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, _, _, child) => child,
          child: VideoPreviewScreen(source: source),
        );
      },
    ),
  ];
}
