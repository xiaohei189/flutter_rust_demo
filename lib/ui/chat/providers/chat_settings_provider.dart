import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/chat_settings_view_model.dart';

/// 聊天设置 ViewModel Provider（按会话 ID）
final chatSettingsViewModelProvider =
    NotifierProvider.family<ChatSettingsViewModel, ChatSettingsState, String>(
      ChatSettingsViewModel.new,
    );
