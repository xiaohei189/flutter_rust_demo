import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/user.dart';
import '../../src/rust/model/local.dart';

/// 导航服务 - 封装导航逻辑，提供统一的导航方法
/// 
/// 使用方式:
/// ```dart
/// // 在 Widget 中
/// NavigationService.of(context).goToMain();
/// 
/// // 或使用全局实例（需要确保 BuildContext 可用）
/// NavigationService.instance.goToMain();
/// ```
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
  
  /// 导航到登录页
  void goToLogin() {
    final context = _context;
    if (context != null) {
      context.go('/login');
    }
  }
  
  /// 导航到主页面
  void goToMain() {
    final context = _context;
    if (context != null) {
      context.go('/main');
    }
  }
  
  /// 导航到聊天详情页
  void goToChatDetail(
    LocalConversation conversation, {
    bool preLoaded = false,
  }) {
    final context = _context;
    if (context != null) {
      final queryParams = preLoaded ? '?preLoaded=true' : '';
      context.push('/chat/${conversation.conversationId}$queryParams');
    }
  }

  /// 导航到聊天详情页（通过ID）
  void goToChatDetailById(
    String conversationId, {
    bool preLoaded = false,
  }) {
    final context = _context;
    if (context != null) {
      final queryParams = preLoaded ? '?preLoaded=true' : '';
      context.push('/chat/$conversationId$queryParams');
    }
  }

  /// 导航到聊天设置页
  void goToChatSettings(LocalConversation conversation) {
    final context = _context;
    if (context != null) {
      context.push('/chat/${conversation.conversationId}/settings');
    }
  }

  /// 导航到聊天设置页（通过ID）
  void goToChatSettingsById(String conversationId) {
    final context = _context;
    if (context != null) {
      context.push('/chat/$conversationId/settings');
    }
  }

  /// 导航到群组信息页
  void goToGroupInfo(LocalConversation conversation) {
    final context = _context;
    if (context != null) {
      context.push('/group/${conversation.conversationId}/info');
    }
  }

  /// 导航到群组信息页（通过ID）
  void goToGroupInfoById(String conversationId) {
    final context = _context;
    if (context != null) {
      context.push('/group/$conversationId/info');
    }
  }
  
  /// 导航到我的个人资料页
  void goToMyProfile() {
    final context = _context;
    if (context != null) {
      context.push('/profile/my');
    }
  }
  
  /// 导航到用户资料页
  void goToUserProfile({String? userId, User? user}) {
    final context = _context;
    if (context == null) return;
    
    if (userId != null && userId.isNotEmpty) {
      context.push('/profile/user/$userId', extra: user);
    } else if (user != null) {
      context.push('/profile/user/unknown', extra: user);
    }
  }
  
  /// 导航到搜索页
  void goToSearch() {
    final context = _context;
    if (context != null) {
      context.push('/search');
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
      context.push('/profile/edit-field', extra: {
        'title': title,
        'hint': hint,
        'initialValue': initialValue,
      });
    }
  }
  
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
