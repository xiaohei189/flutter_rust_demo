import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/chat_detail_screen.dart';
import '../screens/chat_settings_screen.dart';
import '../screens/group_info_screen.dart';
import '../screens/my_profile_screen.dart' show MyProfileScreen, ProfileFieldEditScreen;
import '../screens/search_screen.dart';
import '../screens/user_profile_screen.dart';
import '../models/user.dart';
import '../services/navigation_service.dart';
import '../src/rust/infra/database/models.dart' show LocalConversation;

/// 应用路由配置
class AppRouter {
  /// 使用 NavigationService 的 navigatorKey 确保全局导航一致性
  static GlobalKey<NavigatorState> get _rootNavigatorKey => 
      NavigationService.instance.navigatorKey;

  /// 路由路径常量
  static const String splash = '/';
  static const String login = '/login';
  static const String main = '/main';
  static const String chatDetail = '/chat/:id';
  static const String chatSettings = '/chat/:id/settings';
  static const String groupInfo = '/group/:id/info';
  static const String myProfile = '/profile/my';
  static const String userProfile = '/profile/user/:id';
  static const String search = '/search';
  static const String profileEditField = '/profile/edit-field';

  /// 构建路由配置
  static GoRouter createRouter({
    required String wsUrl,
    required String apiBaseUrl,
  }) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: splash,
      debugLogDiagnostics: true,
      routes: [
        // 启动页
        GoRoute(
          path: splash,
          builder: (context, state) => SplashScreen(
            wsUrl: wsUrl,
            apiBaseUrl: apiBaseUrl,
          ),
        ),
        // 登录页
        GoRoute(
          path: login,
          builder: (context, state) => LoginScreen(
            wsUrl: wsUrl,
            apiBaseUrl: apiBaseUrl,
          ),
        ),
        // 主页面（底部导航）
        GoRoute(
          path: main,
          builder: (context, state) => const MainScreen(),
        ),
        // 聊天详情页
        GoRoute(
          path: chatDetail,
          builder: (context, state) {
            final conversationId = state.pathParameters['id'];
            final preLoaded = state.uri.queryParameters['preLoaded'] == 'true';
            if (conversationId == null || conversationId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('会话ID不存在')),
              );
            }
            return ChatDetailScreen(
              conversationId: conversationId,
              preLoaded: preLoaded,
            );
          },
        ),
        // 聊天设置页
        GoRoute(
          path: chatSettings,
          builder: (context, state) {
            final conversationId = state.pathParameters['id'];
            if (conversationId == null || conversationId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('会话ID不存在')),
              );
            }
            return ChatSettingsScreen(conversationId: conversationId);
          },
        ),
        // 群组信息页
        GoRoute(
          path: groupInfo,
          builder: (context, state) {
            final conversationId = state.pathParameters['id'];
            if (conversationId == null || conversationId.isEmpty) {
              return const Scaffold(
                body: Center(child: Text('会话ID不存在')),
              );
            }
            return GroupInfoScreen(conversationId: conversationId);
          },
        ),
        // 我的个人资料页
        GoRoute(
          path: myProfile,
          builder: (context, state) => const MyProfileScreen(),
        ),
        // 用户资料页
        GoRoute(
          path: userProfile,
          builder: (context, state) {
            final user = state.extra as User?;
            if (user == null) {
              return const Scaffold(
                body: Center(child: Text('用户信息不存在')),
              );
            }
            return UserProfileScreen(
              user: user,
              isCurrentUser: false,
            );
          },
        ),
        // 搜索页
        GoRoute(
          path: search,
          builder: (context, state) => const SearchScreen(),
        ),
        // 个人资料字段编辑页
        GoRoute(
          path: profileEditField,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            if (extra == null) {
              return const Scaffold(
                body: Center(child: Text('参数错误')),
              );
            }
            return ProfileFieldEditScreen(
              title: extra['title'] as String? ?? '编辑',
              hint: extra['hint'] as String? ?? '',
              initialValue: extra['initialValue'] as String? ?? '',
            );
          },
        ),
      ],
    );
  }

  /// 导航到登录页
  static void goToLogin(BuildContext context) {
    context.go(login);
  }

  /// 导航到主页面
  static void goToMain(BuildContext context) {
    context.go(main);
  }

  /// 导航到聊天详情页
  static void goToChatDetail(
    BuildContext context,
    LocalConversation conversation, {
    bool preLoaded = false,
  }) {
    final queryParams = preLoaded ? '?preLoaded=true' : '';
    context.push('/chat/${conversation.conversationId}$queryParams');
  }

  /// 导航到聊天详情页（通过ID）
  static void goToChatDetailById(
    BuildContext context,
    String conversationId, {
    bool preLoaded = false,
  }) {
    final queryParams = preLoaded ? '?preLoaded=true' : '';
    context.push('/chat/$conversationId$queryParams');
  }

  /// 导航到聊天设置页
  static void goToChatSettings(
    BuildContext context,
    LocalConversation conversation,
  ) {
    context.push('/chat/${conversation.conversationId}/settings');
  }

  /// 导航到聊天设置页（通过ID）
  static void goToChatSettingsById(
    BuildContext context,
    String conversationId,
  ) {
    context.push('/chat/$conversationId/settings');
  }

  /// 导航到群组信息页
  static void goToGroupInfo(
    BuildContext context,
    LocalConversation conversation,
  ) {
    context.push('/group/${conversation.conversationId}/info');
  }

  /// 导航到群组信息页（通过ID）
  static void goToGroupInfoById(
    BuildContext context,
    String conversationId,
  ) {
    context.push('/group/$conversationId/info');
  }

  /// 导航到我的个人资料页
  static void goToMyProfile(BuildContext context) {
    context.push(myProfile);
  }

  /// 导航到用户资料页
  static void goToUserProfile(
    BuildContext context, {
    String? userId,
    dynamic user,
  }) {
    if (userId != null && userId.isNotEmpty) {
      context.push('/profile/user/$userId', extra: user);
    } else if (user != null) {
      context.push(userProfile.replaceAll(':id', 'unknown'), extra: user);
    }
  }

  /// 导航到搜索页
  static void goToSearch(BuildContext context) {
    context.push(search);
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
