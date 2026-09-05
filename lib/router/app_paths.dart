/// 应用路由路径常量（唯一来源）
///
/// 约定：
/// - 无参数路径：`static const String xxx = '/path'`
/// - 带参数路径：提供模式常量（含 `:param`，用于 GoRoute 定义）
///   和 `xxxOf(param)` 实际路径生成方法（用于导航跳转），
///   避免调用方手工拼接字符串。
abstract final class AppPaths {
  // ==================== 认证 ====================
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // ==================== 主框架 ====================
  /// 主框架（StatefulShellRoute 父路径，Tab 子路径见下）
  static const String main = '/main';
  static const String tabChat = '/main/chat';
  static const String tabContacts = '/main/contacts';
  static const String tabCalendar = '/main/calendar';
  static const String tabWorkbench = '/main/workbench';
  static const String tabCloud = '/main/cloud';
  static const String tabMore = '/main/more';

  // ==================== 聊天 ====================
  static const String chatDetail = '/chat/:id';
  static String chatDetailOf(String id) => '/chat/$id';
  static const String chatSettings = '/chat/:id/settings';
  static String chatSettingsOf(String id) => '/chat/$id/settings';
  static const String mergeMessage = '/merge-message';
  static const String mediaImage = '/media/image';
  static const String mediaVideo = '/media/video';

  // ==================== 群组 ====================
  static const String groupInfo = '/group/:id/info';
  static String groupInfoOf(String id) => '/group/$id/info';
  static const String groupList = '/group-list';
  static const String createGroup = '/create-group';
  static const String groupApplications = '/group-applications';

  // ==================== 联系人 ====================
  static const String friendList = '/friend-list';
  static const String friendRequests = '/friend-requests';
  static const String friendSetup = '/friend-setup/:userId';
  static String friendSetupOf(String userId) => '/friend-setup/$userId';
  static const String addContact = '/add-contact';
  static const String contactPicker = '/contact-picker';
  static const String blacklist = '/blacklist';

  // ==================== 个人资料 ====================
  static const String myProfile = '/profile/my';
  static const String userProfile = '/profile/user/:id';
  static String userProfileOf(String id) => '/profile/user/$id';
  static const String accountSettings = '/account-settings';
  static const String profileEditField = '/profile/edit-field';

  // ==================== 共享 ====================
  static const String search = '/search';
  static const String scan = '/scan';
  static const String qr = '/qr';
}
