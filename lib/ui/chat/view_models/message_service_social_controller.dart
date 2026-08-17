import 'dart:async';

import '../../../data/services/online_status_service.dart';
import '../../../generated/rust/event/events/friend.dart';
import '../../../generated/rust/event/events/group.dart';
import '../../../generated/rust/event/events/message.dart'
    show GroupReadReceipt;
import '../../../generated/rust/event/events/user.dart';
import '../../../core/utils/app_logger.dart';
import 'message_service_notifier.dart';
import 'message_service_reducer.dart';

/// 好友、群组、用户事件与群已读统计。
class MessageServiceSocialController {
  MessageServiceSocialController(this.service);

  final MessageServiceNotifier service;

  void handleFriendEvent(FriendEvent event) {
    appLog.i('[MsgSvc] friendEvent: ${event.runtimeType}');
    service.updateState(
      service.currentState.copyWith(
        friendRevision: service.currentState.friendRevision + 1,
      ),
    );
  }

  void handleGroupEvent(GroupEvent event) {
    appLog.i('[MsgSvc] groupEvent: ${event.runtimeType}');
    event.maybeWhen(
      groupReadReceipt: (receipts) => applyGroupReadReceipts(receipts),
      orElse: () {
        service.updateState(
          service.currentState.copyWith(
            groupRevision: service.currentState.groupRevision + 1,
          ),
        );
      },
    );
  }

  void applyGroupReadReceipts(List<GroupReadReceipt> receipts) {
    service.updateState(
      MessageServiceReducer.applyGroupReadReceipts(
        service.currentState,
        receipts,
      ),
    );
  }

  void handleUserEvent(UserEvent event) {
    event.when(
      userInfoUpdated: (user) {
        appLog.i('[MsgSvc] userInfoUpdated: ${user.userId}');
        if (user.userId == service.currentState.currentUserId) {
          unawaited(service.refreshLoginUserProfile());
        }
      },
      userStatusChanged: (userId, status, platformIds) {
        appLog.i(
          '[MsgSvc] userStatusChanged: userId=$userId status=$status platformIds=$platformIds',
        );
        OnlineStatusService.instance.applyUserStatusChanged(
          userId: userId,
          status: status,
          platformIds: platformIds,
        );
      },
    );
  }
}
