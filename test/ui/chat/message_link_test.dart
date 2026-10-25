import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/ui/chat/utils/message_link.dart';

void main() {
  test('生成 flutterrustdemo 消息深链', () {
    final link = buildMessageLink(conversationId: 'sg_123', clientMsgId: 'm1');
    expect(link, 'flutterrustdemo:///chat/sg_123?message=m1');
  });

  test('解析深链可还原会话与消息 id', () {
    final uri = Uri.parse(
      buildMessageLink(conversationId: 'si_1_2', clientMsgId: 'c-3'),
    );
    final parsed = parseMessageLink(uri);
    expect(parsed?.conversationId, 'si_1_2');
    expect(parsed?.clientMsgId, 'c-3');
  });

  test('非本 App 链接或缺少参数时返回 null', () {
    expect(
      parseMessageLink(Uri.parse('https://example.com/chat/sg_1?message=m')),
      isNull,
    );
    expect(parseMessageLink(Uri.parse('flutterrustdemo:///chat/sg_1')), isNull);
    expect(
      parseMessageLink(Uri.parse('flutterrustdemo:///other/sg_1?message=m')),
      isNull,
    );
  });

  test('id 含特殊字符时转义后可还原，且路径与 /chat/:id 路由一致', () {
    final uri = Uri.parse(
      buildMessageLink(conversationId: 'sg_1/2', clientMsgId: 'm 1&x=2'),
    );

    // go_router 的 /chat/:id 只按 path 匹配，query 里带 message
    expect(uri.pathSegments, ['chat', 'sg_1/2']);
    expect(uri.queryParameters['message'], 'm 1&x=2');

    final parsed = parseMessageLink(uri)!;
    expect(parsed.conversationId, 'sg_1/2');
    expect(parsed.clientMsgId, 'm 1&x=2');
  });
}
