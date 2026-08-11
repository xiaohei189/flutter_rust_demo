import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/chat_detail_view_model.dart';

/// 聊天详情页 ViewModel Provider（按会话 ID）
final chatDetailViewModelProvider =
    NotifierProvider.family<ChatDetailViewModel, ChatDetailState, String>(
      ChatDetailViewModel.new,
    );
