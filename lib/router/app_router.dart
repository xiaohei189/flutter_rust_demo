import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/conversation.dart';
import '../domain/models/chat_message.dart' show ChatMessage;
import '../ui/shared/views/route_error_page.dart';
import 'app_paths.dart';
import 'auth_routes.dart';
import 'chat_routes.dart';
import 'contact_routes.dart';
import 'group_routes.dart';
import 'profile_routes.dart';
import 'shared_routes.dart';
import 'shell_routes.dart';

/// 应用路由配置（聚合入口）
///
/// 路由按业务域拆分在 auth_routes / chat_routes / contact_routes /
/// group_routes / profile_routes / shared_routes / shell_routes，
/// 路径常量统一引用 [AppPaths]，本类只负责聚合与全局配置。
class AppRouter {
  /// 全局根导航 key，由 AppRouter 唯一持有，确保无 context 导航一致。
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  /// 构建路由配置
  static GoRouter createRouter({
    required String wsUrl,
    required String apiBaseUrl,
  }) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: AppPaths.splash,
      debugLogDiagnostics: kDebugMode,
      // 统一 404 错误页
      errorBuilder: (context, state) =>
          const RouteErrorPage(showBackButton: false),
      // go_router 14 的 StatefulShellRoute 不支持父路径，
      // 这里把 /main 重定向到默认 Tab（消息），保持既有跳转兼容
      redirect: (context, state) {
        if (state.uri.path == AppPaths.main) {
          return AppPaths.tabChat;
        }
        return null;
      },
      routes: [
        ...buildAuthRoutes(wsUrl: wsUrl, apiBaseUrl: apiBaseUrl),
        ...buildChatRoutes(),
        ...buildContactRoutes(),
        ...buildGroupRoutes(),
        ...buildProfileRoutes(),
        ...buildSharedRoutes(),
        ...buildShellRoutes(),
      ],
    );
  }

  // ==================== 导航方法 ====================

  /// 导航到登录页
  static void goToLogin(BuildContext context) {
    context.go(AppPaths.login);
  }

  /// 导航到注册页
  static void goToRegister(
    BuildContext context, {
    required String wsUrl,
    required String apiBaseUrl,
  }) {
    context.push(
      AppPaths.register,
      extra: {'wsUrl': wsUrl, 'apiBaseUrl': apiBaseUrl},
    );
  }

  /// 导航到主页面
  static void goToMain(BuildContext context) {
    context.go(AppPaths.main);
  }

  /// 导航到聊天详情页
  static void goToChatDetail(
    BuildContext context,
    Conversation conversation, {
    bool preLoaded = false,
    bool focusAtMe = false,
  }) {
    final queryParams = <String>[
      if (preLoaded) 'preLoaded=true',
      if (focusAtMe) 'focusAtMe=true',
    ].join('&');
    final query = queryParams.isEmpty ? '' : '?$queryParams';
    context.push('${AppPaths.chatDetailOf(conversation.conversationId)}$query');
  }

  /// 导航到聊天详情页（通过ID）
  static void goToChatDetailById(
    BuildContext context,
    String conversationId, {
    bool preLoaded = false,
    bool focusAtMe = false,
  }) {
    final queryParams = <String>[
      if (preLoaded) 'preLoaded=true',
      if (focusAtMe) 'focusAtMe=true',
    ].join('&');
    final query = queryParams.isEmpty ? '' : '?$queryParams';
    context.push('${AppPaths.chatDetailOf(conversationId)}$query');
  }

  /// 导航到聊天设置页
  static void goToChatSettings(
    BuildContext context,
    Conversation conversation,
  ) {
    context.push(AppPaths.chatSettingsOf(conversation.conversationId));
  }

  /// 导航到聊天设置页（通过ID）
  static void goToChatSettingsById(
    BuildContext context,
    String conversationId,
  ) {
    context.push(AppPaths.chatSettingsOf(conversationId));
  }

  /// 导航到群组信息页
  static void goToGroupInfo(BuildContext context, Conversation conversation) {
    context.push(AppPaths.groupInfoOf(conversation.conversationId));
  }

  /// 导航到群组信息页（通过ID）
  static void goToGroupInfoById(BuildContext context, String conversationId) {
    context.push(AppPaths.groupInfoOf(conversationId));
  }

  /// 导航到我的个人资料页
  static void goToMyProfile(BuildContext context) {
    context.push(AppPaths.myProfile);
  }

  /// 导航到用户资料页
  static void goToUserProfile(
    BuildContext context, {
    String? userId,
    dynamic user,
  }) {
    if (userId != null && userId.isNotEmpty) {
      context.push(AppPaths.userProfileOf(userId), extra: user);
    } else if (user != null) {
      context.push(AppPaths.userProfileOf('unknown'), extra: user);
    }
  }

  /// 导航到搜索页
  static void goToSearch(BuildContext context) {
    context.push(AppPaths.search);
  }

  /// 导航到黑名单页
  static void goToBlacklist(BuildContext context) {
    context.push(AppPaths.blacklist);
  }

  /// 导航到群申请页
  static void goToGroupApplications(BuildContext context) {
    context.push(AppPaths.groupApplications);
  }

  /// 导航到添加联系人页
  static void goToAddContact(BuildContext context) {
    context.push(AppPaths.addContact);
  }

  /// 导航到创建群组页
  static void goToCreateGroup(BuildContext context) {
    context.push(AppPaths.createGroup);
  }

  /// 导航到扫码页
  static void goToScan(BuildContext context) {
    context.push(AppPaths.scan);
  }

  /// 导航到二维码页
  static Future<T?> goToQrCode<T>(
    BuildContext context, {
    required String title,
    required String data,
    String? subtitle,
  }) {
    final subtitleQuery = subtitle == null
        ? ''
        : '&subtitle=${Uri.encodeQueryComponent(subtitle)}';
    return context.push<T>(
      '${AppPaths.qr}?title=${Uri.encodeQueryComponent(title)}'
      '&data=${Uri.encodeQueryComponent(data)}$subtitleQuery',
    );
  }

  /// 导航到合并转发消息详情页
  static Future<T?> goToMergeMessage<T>(
    BuildContext context,
    ChatMessage message,
  ) {
    return context.push<T>(AppPaths.mergeMessage, extra: message);
  }

  /// 导航到联系人选择器
  static Future<T?> goToContactPicker<T>(
    BuildContext context, {
    required String title,
    String mode = 'forward',
    bool multiSelect = false,
  }) {
    final resolvedMode = multiSelect ? 'multi' : mode;
    return context.push<T>(
      '${AppPaths.contactPicker}?mode=$resolvedMode'
      '&title=${Uri.encodeQueryComponent(title)}',
    );
  }

  /// 导航到账号设置页
  static void goToAccountSettings(BuildContext context) {
    context.push(AppPaths.accountSettings);
  }

  /// 导航到个人资料字段编辑页
  static void goToProfileEditField(
    BuildContext context, {
    required String title,
    required String hint,
    required String initialValue,
  }) {
    context.push(
      AppPaths.profileEditField,
      extra: {'title': title, 'hint': hint, 'initialValue': initialValue},
    );
  }

  /// 返回上一页
  static void goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    }
  }

  /// 返回上一页并携带结果
  static void goBackWithResult<T>(BuildContext context, T result) {
    if (context.canPop()) {
      context.pop(result);
    }
  }
}
