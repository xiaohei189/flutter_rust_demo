import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../generated/rust/constant/enums.dart' show SessionType;
import '../../chat/providers/conversation_provider.dart';
import '../../chat/providers/message_service_provider.dart';
import '../providers/friend_provider.dart';

/// 好友设置页状态
class FriendSetupState {
  final bool isLoading;
  final bool isMuted;
  final bool isPinned;
  final bool isBlacklisted;
  final String? conversationId;
  final String? error;

  const FriendSetupState({
    this.isLoading = false,
    this.isMuted = false,
    this.isPinned = false,
    this.isBlacklisted = false,
    this.conversationId,
    this.error,
  });

  FriendSetupState copyWith({
    bool? isLoading,
    bool? isMuted,
    bool? isPinned,
    bool? isBlacklisted,
    String? conversationId,
    String? error,
    bool clearError = false,
  }) {
    return FriendSetupState(
      isLoading: isLoading ?? this.isLoading,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isBlacklisted: isBlacklisted ?? this.isBlacklisted,
      conversationId: conversationId ?? this.conversationId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 好友设置 ViewModel：负责备注、免打扰、置顶、黑名单与删除好友。
class FriendSetupViewModel extends FamilyNotifier<FriendSetupState, String> {
  @override
  FriendSetupState build(String userId) {
    return const FriendSetupState();
  }

  FriendSetupState get currentState => state;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(messageRepositoryProvider);
      final conversationId = await repository.getConversationIdBySessionType(
        sourceId: arg,
        sessionType: SessionType.singleChat,
      );
      final conversation = ref
          .read(conversationsProvider)
          .where((c) => c.conversationId == conversationId)
          .firstOrNull;
      final isBlacklisted = await repository.isInBlacklist(arg);
      state = state.copyWith(
        isLoading: false,
        conversationId: conversationId,
        isMuted: conversation?.recvMsgOpt == 1,
        isPinned: conversation?.isPinned ?? false,
        isBlacklisted: isBlacklisted,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载好友设置失败: $e');
    }
  }

  Future<bool> updateRemark(String remark) async {
    state = state.copyWith(clearError: true);
    try {
      await ref
          .read(friendRepositoryProvider)
          .updateFriends(arg, remark: remark);
      return true;
    } catch (e) {
      state = state.copyWith(error: '更新备注失败: $e');
      return false;
    }
  }

  Future<bool> setMuted(bool value) async {
    final conversationId = state.conversationId;
    if (conversationId == null) return false;
    state = state.copyWith(isMuted: value, clearError: true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .setConversation(
            conversationId: conversationId,
            recvMsgOpt: value ? 1 : 0,
          );
      return true;
    } catch (e) {
      state = state.copyWith(error: '设置失败: $e');
      return false;
    }
  }

  Future<bool> setPinned(bool value) async {
    final conversationId = state.conversationId;
    if (conversationId == null) return false;
    state = state.copyWith(isPinned: value, clearError: true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .setConversationPinned(
            conversationId: conversationId,
            isPinned: value,
          );
      return true;
    } catch (e) {
      state = state.copyWith(error: '设置失败: $e');
      return false;
    }
  }

  Future<bool> setBlacklisted(bool value) async {
    state = state.copyWith(clearError: true);
    final ok = value
        ? await ref.read(blackListProvider.notifier).add(arg)
        : await ref.read(blackListProvider.notifier).remove(arg);
    if (!ok) {
      state = state.copyWith(
        error: ref.read(blackListProvider).error ?? '操作失败',
      );
      return false;
    }
    state = state.copyWith(isBlacklisted: value);
    return true;
  }

  Future<bool> deleteFriend() async {
    state = state.copyWith(clearError: true);
    final ok = await ref.read(friendListProvider.notifier).deleteFriend(arg);
    if (!ok) {
      state = state.copyWith(
        error: ref.read(friendListProvider).error ?? '删除失败',
      );
      return false;
    }
    return true;
  }
}
