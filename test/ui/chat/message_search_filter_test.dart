import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rust_demo/domain/models/message_search_result.dart';
import 'package:flutter_rust_demo/ui/chat/widgets/message_search_filter.dart';

MessageSearchResult _result({
  required int contentType,
  required String content,
}) {
  return MessageSearchResult(
    conversationId: 'si_a_b',
    clientMsgId: 'm1',
    serverMsgId: '',
    sendId: 'other',
    recvId: 'me',
    senderPlatformId: 0,
    senderNickName: '张三',
    senderFaceUrl: '',
    sessionType: 1,
    msgFrom: 0,
    contentType: contentType,
    content: content,
    isRead: true,
    status: 2,
    seq: 1,
    sendTime: 0,
    createTime: 0,
    attachedInfo: '',
    ex: '',
    localEx: '',
    groupId: '',
  );
}

void main() {
  test('图片视频/文件下推的 content_type 白名单正确', () {
    expect(ChatMessageSearchFilter.media.messageTypes, [102, 104]);
    expect(ChatMessageSearchFilter.files.messageTypes, [105]);
    expect(ChatMessageSearchFilter.all.messageTypes, isEmpty);
  });

  test('链接按 http(s) 内容二次过滤，只保留文本类消息', () {
    const filter = ChatMessageSearchFilter.links;
    expect(
      filter.matches(
        _result(contentType: 101, content: '看这个 https://example.com/a?b=1'),
      ),
      isTrue,
    );
    expect(
      filter.matches(
        _result(contentType: 106, content: '{"content":"http://intranet/x"}'),
      ),
      isTrue,
    );
    expect(filter.matches(_result(contentType: 101, content: '没有链接')), isFalse);
    expect(
      filter.matches(
        _result(contentType: 102, content: '{"url":"https://img/x.png"}'),
      ),
      isFalse,
      reason: '图片不是链接消息',
    );
  });

  test('文件/图片过滤按类型命中', () {
    expect(
      ChatMessageSearchFilter.files.matches(
        _result(contentType: 105, content: '{"fileName":"a.pdf"}'),
      ),
      isTrue,
    );
    expect(
      ChatMessageSearchFilter.files.matches(
        _result(contentType: 102, content: '{"url":"x.png"}'),
      ),
      isFalse,
    );
    expect(
      ChatMessageSearchFilter.media.matches(
        _result(contentType: 104, content: '{"url":"x.mp4"}'),
      ),
      isTrue,
    );
  });
}
