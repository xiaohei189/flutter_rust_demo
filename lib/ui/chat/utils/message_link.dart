/// 消息深链：`flutterrustdemo:///chat/<conversationId>?message=<clientMsgId>`。
///
/// 用「空 host + /chat/... 路径」而不是 `flutterrustdemo://chat/...`：
/// go_router 只按 path 匹配路由，这样可以直接命中已有的 `/chat/:id`。
const String kMessageLinkScheme = 'flutterrustdemo';

String buildMessageLink({
  required String conversationId,
  required String clientMsgId,
}) {
  final conv = Uri.encodeComponent(conversationId);
  final msg = Uri.encodeComponent(clientMsgId);
  return '$kMessageLinkScheme:///chat/$conv?message=$msg';
}

/// 解析消息深链；不是本 App 的消息链接或缺少参数时返回 `null`。
({String conversationId, String clientMsgId})? parseMessageLink(Uri uri) {
  if (uri.scheme != kMessageLinkScheme) return null;
  final segments = uri.pathSegments;
  if (segments.length < 2 || segments.first != 'chat') return null;
  final conversationId = segments[1];
  final clientMsgId = uri.queryParameters['message'] ?? '';
  if (conversationId.isEmpty || clientMsgId.isEmpty) return null;
  return (conversationId: conversationId, clientMsgId: clientMsgId);
}
