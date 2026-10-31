import 'package:flutter_rust_demo/domain/models/message_search_result.dart'
    show MessageSearchResult;

import 'message_service_notifier.dart';

/// 会话内本地消息搜索：空关键字（且无类型过滤）短路 + 委托 MessageService。
class SearchMessagesUseCase {
  SearchMessagesUseCase({required this.messageService});

  final MessageServiceNotifier messageService;

  Future<List<MessageSearchResult>> search(
    String conversationId,
    String keyword, {
    List<int> messageTypes = const [],
    int count = 50,
    bool allowEmptyKeyword = false,
  }) {
    if (keyword.trim().isEmpty && messageTypes.isEmpty && !allowEmptyKeyword) {
      return Future.value(const []);
    }
    return messageService.searchLocalMessages(
      conversationId: conversationId,
      keyword: keyword,
      messageTypes: messageTypes,
      count: count,
      allowEmptyKeyword: allowEmptyKeyword,
    );
  }
}
