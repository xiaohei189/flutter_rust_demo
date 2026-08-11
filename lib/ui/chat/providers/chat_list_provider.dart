import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/chat_list_view_model.dart';

/// 会话列表 ViewModel Provider
final chatListViewModelProvider =
    NotifierProvider<ChatListViewModel, ChatListState>(ChatListViewModel.new);
