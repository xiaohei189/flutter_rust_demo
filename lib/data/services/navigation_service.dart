import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/conversation.dart';
import '../../domain/models/user.dart';
import '../../router/app_router.dart';

/// 导航服务 - 提供无 BuildContext 场景的全局导航与 UI 辅助方法
///
/// 导航实现统一委托给 [AppRouter]（唯一实现），本类只做两件事：
/// 1. 通过全局 navigatorKey 在无 context 场景下导航（如服务层/通知回调）
/// 2. 提供对话框 / 底部弹窗 / SnackBar 等 UI 辅助方法
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();

  /// 全局单例实例
  static NavigationService get instance => _instance;

  /// 全局导航键，用于无 BuildContext 导航
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  NavigationService._internal();

  /// 从 BuildContext 获取 NavigationService
  static NavigationService of(BuildContext context) {
    return _instance;
  }

  /// 获取当前上下文
  BuildContext? get _context => navigatorKey.currentContext;

  // ==================== 导航方法（委托 AppRouter） ====================

  /// 导航到登录页
  void goToLogin() {
    final context = _context;
    if (context != null) {
      AppRouter.goToLogin(context);
    }
  }

  /// 导航到主页面
  void goToMain() {
    final context = _context;
    if (context != null) {
      AppRouter.goToMain(context);
    }
  }

  /// 导航到聊天详情页
  void goToChatDetail(Conversation conversation, {bool preLoaded = false}) {
    final context = _context;
    if (context != null) {
      AppRouter.goToChatDetail(context, conversation, preLoaded: preLoaded);
    }
  }

  /// 导航到聊天详情页（通过ID）
  void goToChatDetailById(String conversationId, {bool preLoaded = false}) {
    final context = _context;
    if (context != null) {
      AppRouter.goToChatDetailById(
        context,
        conversationId,
        preLoaded: preLoaded,
      );
    }
  }

  /// 导航到聊天设置页
  void goToChatSettings(Conversation conversation) {
    final context = _context;
    if (context != null) {
      AppRouter.goToChatSettings(context, conversation);
    }
  }

  /// 导航到聊天设置页（通过ID）
  void goToChatSettingsById(String conversationId) {
    final context = _context;
    if (context != null) {
      AppRouter.goToChatSettingsById(context, conversationId);
    }
  }

  /// 导航到群组信息页
  void goToGroupInfo(Conversation conversation) {
    final context = _context;
    if (context != null) {
      AppRouter.goToGroupInfo(context, conversation);
    }
  }

  /// 导航到群组信息页（通过ID）
  void goToGroupInfoById(String conversationId) {
    final context = _context;
    if (context != null) {
      AppRouter.goToGroupInfoById(context, conversationId);
    }
  }

  /// 导航到我的个人资料页
  void goToMyProfile() {
    final context = _context;
    if (context != null) {
      AppRouter.goToMyProfile(context);
    }
  }

  /// 导航到用户资料页
  void goToUserProfile({String? userId, User? user}) {
    final context = _context;
    if (context != null) {
      AppRouter.goToUserProfile(context, userId: userId, user: user);
    }
  }

  /// 导航到搜索页
  void goToSearch() {
    final context = _context;
    if (context != null) {
      AppRouter.goToSearch(context);
    }
  }

  /// 导航到个人资料字段编辑页
  void goToProfileEditField({
    required String title,
    required String hint,
    required String initialValue,
  }) {
    final context = _context;
    if (context != null) {
      AppRouter.goToProfileEditField(
        context,
        title: title,
        hint: hint,
        initialValue: initialValue,
      );
    }
  }

  // ==================== UI 辅助方法 ====================

  /// 返回上一页
  void goBack() {
    final context = _context;
    if (context != null && context.canPop()) {
      context.pop();
    }
  }

  /// 返回上一页并携带结果
  void goBackWithResult<T>(T result) {
    final context = _context;
    if (context != null && context.canPop()) {
      context.pop(result);
    }
  }

  /// 检查是否可以返回
  bool canPop() {
    final context = _context;
    return context != null && context.canPop();
  }

  /// 显示对话框（使用全局导航键）
  Future<T?> showAppDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final context = _context;
    if (context == null) return Future.value(null);

    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// 显示底部弹窗（使用全局导航键）
  Future<T?> showAppBottomSheet<T>({
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    final context = _context;
    if (context == null) return Future.value(null);

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: builder,
    );
  }

  /// 显示 SnackBar（使用全局导航键）
  void showSnackBar(String message, {Duration? duration}) {
    final context = _context;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }
}
