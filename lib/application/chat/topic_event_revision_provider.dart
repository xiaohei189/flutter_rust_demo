import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 话题控制事件的轻量 revision 信号。
///
/// Topic Pin/关闭/模式切换等事件不是用户消息，不应写入消息列表；
/// 消息层只递增该版本号，话题页面和会话摘要据此重新查询服务端状态。
final topicEventRevisionProvider = StateProvider<int>((ref) => 0);

/// 订阅/已读控制事件 revision。与 [topicEventRevisionProvider] 分开，避免详情页因
/// 自己补写阅读游标而反复触发“刷新 → 再标已读”的循环。
final topicReadRevisionProvider = StateProvider<int>((ref) => 0);
