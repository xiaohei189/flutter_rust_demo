import 'package:go_router/go_router.dart';

import '../domain/models/chat_message.dart' show ChatMessage;
import '../ui/chat/views/merge_message_detail_screen.dart';
import '../ui/chat/views/chat_settings_screen.dart';
import '../ui/chat/views/chat_detail_screen.dart';
import '../ui/chat/widgets/media_viewer.dart';
import '../ui/shared/views/route_error_page.dart';
import '../ui/topics/views/conversation_detail_router_screen.dart';
import '../ui/topics/views/topic_compose_screen.dart';
import '../ui/topics/views/topic_detail_screen.dart';
import '../ui/topics/views/topic_group_settings_screen.dart';
import '../ui/topics/views/topic_index_ops_screen.dart';
import '../ui/topics/views/topic_notifications_screen.dart';
import 'app_paths.dart';

/// 聊天域路由：会话详情 / 会话设置 / 合并消息 / 媒体预览
List<RouteBase> buildChatRoutes() {
  return [
    GoRoute(
      path: AppPaths.chatDetail,
      builder: (context, state) {
        final conversationId = state.pathParameters['id'];
        final preLoaded = state.uri.queryParameters['preLoaded'] == 'true';
        final focusAtMe = state.uri.queryParameters['focusAtMe'] == 'true';
        final initialMessageId = state.uri.queryParameters['message'];
        if (conversationId == null || conversationId.isEmpty) {
          return const RouteErrorPage(message: '会话ID不存在');
        }
        return ConversationDetailRouterScreen(
          conversationId: conversationId,
          preLoaded: preLoaded,
          focusAtMe: focusAtMe,
          initialMessageId: initialMessageId,
        );
      },
    ),
    GoRoute(
      path: AppPaths.topicDetail,
      builder: (context, state) {
        final topicId = state.pathParameters['id'];
        final groupId = state.uri.queryParameters['groupID'];
        if (topicId == null ||
            topicId.isEmpty ||
            groupId == null ||
            groupId.isEmpty) {
          return const RouteErrorPage(message: '话题不存在');
        }
        return TopicDetailScreen(groupId: groupId, topicId: topicId);
      },
    ),
    GoRoute(
      path: AppPaths.topicCompose,
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'];
        if (groupId == null || groupId.isEmpty) {
          return const RouteErrorPage(message: '话题群不存在');
        }
        return TopicComposeScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: AppPaths.topicNotifications,
      builder: (context, state) => const TopicNotificationsScreen(),
    ),
    GoRoute(
      path: AppPaths.topicIndexOps,
      builder: (context, state) => const TopicIndexOpsScreen(),
    ),
    GoRoute(
      path: AppPaths.topicSettings,
      builder: (context, state) {
        final groupId = state.pathParameters['groupId'];
        if (groupId == null || groupId.isEmpty) {
          return const RouteErrorPage(message: '话题群不存在');
        }
        return TopicGroupSettingsScreen(groupId: groupId);
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
      path: AppPaths.chatHistory,
      builder: (context, state) {
        final conversationId = state.pathParameters['id'];
        if (conversationId == null || conversationId.isEmpty) {
          return const RouteErrorPage(message: '会话ID不存在');
        }
        return ChatDetailScreen(conversationId: conversationId, readOnly: true);
      },
    ),
    GoRoute(
      path: AppPaths.mergeMessage,
      pageBuilder: (context, state) {
        final message = state.extra as ChatMessage?;
        if (message == null) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            transitionsBuilder: (_, _, _, child) => child,
            child: const RouteErrorPage(message: '消息不存在'),
          );
        }
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, _, _, child) => child,
          child: MergeMessageDetailScreen(message: message),
        );
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
