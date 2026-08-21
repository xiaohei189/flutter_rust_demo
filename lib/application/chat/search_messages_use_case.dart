import 'package:flutter_rust_demo/domain/models/message_search_result.dart'
    show MessageSearchResult;

import 'message_service_notifier.dart';

/// 会话内本地消息搜索：空关键字短路 + 委托 MessageService。
class SearchMessagesUseCase {
  SearchMessagesUseCase({required this.messageService});

  final MessageServiceNotifier messageService;

  Future<List<MessageSearchResult>> search(
    String conversationId,
    String keyword,
  ) {
    if (keyword.trim().isEmpty) return Future.value(const []);
    return messageService.searchLocalMessages(
      conversationId: conversationId,
      keyword: keyword,
    );
  }
}
