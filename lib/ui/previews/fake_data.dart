/// 预览专用假数据：集中构造各组件所需的模型实例。
///
/// 仅供 `@Preview` 预览函数使用，禁止在生产代码中引用。
/// 所有消息/会话均为静态假数据，图片地址一律留空以走占位分支（预览环境无法加载真实文件）。
library;

import 'dart:convert';

import 'package:flutter_rust_demo/domain/models/conversation.dart';
import 'package:flutter_rust_demo/domain/models/friend.dart';
import 'package:flutter_rust_demo/domain/models/group.dart';
import 'package:flutter_rust_demo/domain/models/group_member.dart';
import 'package:flutter_rust_demo/domain/models/user.dart';
import 'package:flutter_rust_demo/generated/rust/model/message.dart'
    show MessageInfo;

String _json(Map<String, Object?> map) => jsonEncode(map);

// ==================== 消息（MessageInfo） ====================

MessageInfo _message({
  required String id,
  required int contentType,
  required String content,
  String sender = '李四',
  String sendId = 'user_2',
  String recvId = 'user_1',
  String groupId = '',
  int sessionType = 1,
  int status = 2,
  int sendTime = 0,
  String senderFaceUrl = '',
}) {
  return MessageInfo(
    clientMsgId: id,
    serverMsgId: 'srv_$id',
    sendId: sendId,
    recvId: recvId,
    groupId: groupId,
    senderPlatformId: 0,
    senderNickname: sender,
    senderFaceUrl: senderFaceUrl,
    sessionType: sessionType,
    msgFrom: 0,
    contentType: contentType,
    content: content,
    seq: 0,
    sendTime: sendTime,
    createTime: sendTime,
    status: status,
    isRead: false,
    attachedInfo: '',
    ex: '',
  );
}

/// 当前用户（发送方）ID，与 [User.mockUsers] 的「张三」对应。
const String kPreviewMyUserId = 'user_1';
const String kPreviewMyNickname = '张三';

/// 文本消息（contentType=101）
MessageInfo fakeTextMessage({
  String text = '你好，这是一条文本消息',
  bool fromMe = false,
  String sender = '李四',
  int sendTime = 0,
  int status = 2,
}) {
  return _message(
    id: 'text_${fromMe ? 'me' : 'other'}',
    contentType: 101,
    content: _json({'content': text}),
    sender: fromMe ? kPreviewMyNickname : sender,
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
    sendTime: sendTime,
    status: status,
  );
}

/// 图片消息（contentType=102，地址为空走占位分支）
MessageInfo fakeImageMessage({bool fromMe = false}) {
  return _message(
    id: 'image_${fromMe ? 'me' : 'other'}',
    contentType: 102,
    content: _json({
      'sourcePicture': {'url': '', 'width': 300, 'height': 300},
    }),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 视频消息（contentType=103，无快照走占位）
MessageInfo fakeVideoMessage({bool fromMe = false}) {
  return _message(
    id: 'video_${fromMe ? 'me' : 'other'}',
    contentType: 103,
    content: _json({'videoPath': '', 'duration': 12, 'size': 2048}),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 语音消息（contentType=104）
MessageInfo fakeAudioMessage({bool fromMe = false, int duration = 8}) {
  return _message(
    id: 'audio_${fromMe ? 'me' : 'other'}',
    contentType: 104,
    content: _json({'soundPath': '', 'duration': duration, 'dataSize': 1000}),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 文件消息（contentType=105）
MessageInfo fakeFileMessage({bool fromMe = false, String name = '需求文档.pdf'}) {
  return _message(
    id: 'file_${fromMe ? 'me' : 'other'}',
    contentType: 105,
    content: _json({
      'fileName': name,
      'fileSize': 2048 * 1024,
      'filePath': '',
      'fileType': 'pdf',
    }),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 引用消息（contentType=114）
MessageInfo fakeQuoteMessage({
  bool fromMe = false,
  String replyContent = '被引用的原文内容',
  String replySender = '王五',
}) {
  return _message(
    id: 'quote_${fromMe ? 'me' : 'other'}',
    contentType: 114,
    content: _json({
      'text': '这是一条引用消息的回复',
      'replyMessageId': 'quote_target',
      'senderNickname': replySender,
      'replyMessageContentType': 101,
      'replyMessageContent': replyContent,
    }),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 合并转发消息（contentType=107）
MessageInfo fakeMergeMessage({bool fromMe = false}) {
  return _message(
    id: 'merge_${fromMe ? 'me' : 'other'}',
    contentType: 107,
    content: _json({
      'title': '群聊记录',
      'abstractList': ['张三: 明天开会', '李四: 收到', '王五: 地点在哪？', '张三: 3 楼会议室'],
      'multiMessage': [
        {'clientMsgID': 'm1'},
        {'clientMsgID': 'm2'},
        {'clientMsgID': 'm3'},
        {'clientMsgID': 'm4'},
      ],
    }),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 名片消息（contentType=108）
MessageInfo fakeCardMessage({bool fromMe = false}) {
  return _message(
    id: 'card_${fromMe ? 'me' : 'other'}',
    contentType: 108,
    content: _json({'userID': 'user_5', 'nickname': '赵六', 'faceUrl': ''}),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 位置消息（contentType=106）
MessageInfo fakeLocationMessage({bool fromMe = false}) {
  return _message(
    id: 'location_${fromMe ? 'me' : 'other'}',
    contentType: 106,
    content: _json({
      'name': '杭州西溪湿地',
      'desc': '浙江省杭州市西湖区天目山路 518 号',
      'latitude': 30.27,
      'longitude': 120.04,
    }),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 系统消息（contentType=2101 撤回通知）
MessageInfo fakeSystemMessage({String text = '李四 撤回了一条消息'}) {
  return _message(
    id: 'system_1',
    contentType: 2101,
    content: _json({'content': text, 'revokerNickname': '李四'}),
    sender: '系统',
    sendId: '',
    recvId: kPreviewMyUserId,
  );
}

/// @ 消息（contentType=116）
MessageInfo fakeAtMessage({bool fromMe = false}) {
  return _message(
    id: 'at_${fromMe ? 'me' : 'other'}',
    contentType: 116,
    content: _json({
      'text': '@张三 晚上一起吃饭吗？',
      'atUsers': [
        {'atUserID': kPreviewMyUserId, 'nickname': kPreviewMyNickname},
      ],
    }),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// Markdown 消息（contentType=118）
MessageInfo fakeMarkdownMessage({bool fromMe = false}) {
  return _message(
    id: 'md_${fromMe ? 'me' : 'other'}',
    contentType: 118,
    content: _json({
      'content':
          '# 会议纪要\n\n- 确认 **Q3 目标**\n- [链接](https://example.com)\n\n```dart\nprint("hello");\n```',
    }),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 自定义消息（contentType=110）
MessageInfo fakeCustomMessage({bool fromMe = false}) {
  return _message(
    id: 'custom_${fromMe ? 'me' : 'other'}',
    contentType: 110,
    content: _json({'data': '{"type":"todo"}'}),
    sender: fromMe ? kPreviewMyNickname : '李四',
    sendId: fromMe ? kPreviewMyUserId : 'user_2',
    recvId: fromMe ? 'user_2' : kPreviewMyUserId,
  );
}

/// 一组混合消息（按时间升序），用于消息列表类预览。
List<MessageInfo> fakeMessageList() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    fakeSystemMessage(text: '你已加入群聊，开始畅聊吧'),
    fakeTextMessage(
      text: '大家好，我是新来的运营同学',
      sender: '王五',
      sendTime: now - 3600 * 1000,
    ),
    fakeImageMessage(),
    fakeTextMessage(text: '这张图拍得不错', sender: '李四', sendTime: now - 1800 * 1000),
    fakeQuoteMessage(replyContent: '这张图拍得不错', replySender: '李四'),
    fakeTextMessage(
      text: '好的，收到！',
      fromMe: true,
      sendTime: now - 600 * 1000,
      status: 2,
    ),
    fakeAudioMessage(duration: 6),
    fakeTextMessage(text: '语音已经收到', sender: '李四', sendTime: now - 300 * 1000),
    fakeTextMessage(
      text: '晚上 8 点会议室碰头，不见不散',
      fromMe: true,
      sendTime: now - 60 * 1000,
      status: 2,
    ),
  ];
}

// ==================== 会话（Conversation） ====================

Conversation fakeConversation({
  String conversationId = 'si_user_1_user_2',
  int conversationType = 1,
  String userId = 'user_2',
  String groupId = '',
  String showName = '李四',
  String faceUrl = '',
  String latestMsg = '',
  int latestMsgSendTime = 0,
  int unreadCount = 0,
  int recvMsgOpt = 0,
  bool isPinned = false,
  bool isPrivateChat = false,
  bool isNotInGroup = false,
  bool isMsgDestruct = false,
  int burnDuration = 0,
  int groupAtType = 0,
  String ex = '',
  String draftText = '',
  int draftTextTime = 0,
}) {
  return Conversation(
    conversationId: conversationId,
    conversationType: conversationType,
    userId: userId,
    groupId: groupId,
    showName: showName,
    faceUrl: faceUrl,
    latestMsg: latestMsg,
    latestMsgSendTime: latestMsgSendTime,
    unreadCount: unreadCount,
    recvMsgOpt: recvMsgOpt,
    isPinned: isPinned,
    isPrivateChat: isPrivateChat,
    burnDuration: burnDuration,
    groupAtType: groupAtType,
    isNotInGroup: isNotInGroup,
    updateUnreadCountTime: 0,
    attachedInfo: '',
    ex: ex,
    draftText: draftText,
    draftTextTime: draftTextTime,
    maxSeq: 0,
    minSeq: 0,
    isMsgDestruct: isMsgDestruct,
    msgDestructTime: 0,
  );
}

/// 一组会话列表假数据。
List<Conversation> fakeConversationList() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    fakeConversation(
      showName: '产品讨论群',
      conversationId: 'sg_group_1001',
      conversationType: 2,
      groupId: 'group_1001',
      latestMsg:
          '{"contentType":101,"senderNickname":"李四","content":"新版原型已经上传"}',
      latestMsgSendTime: now - 5 * 60 * 1000,
      unreadCount: 12,
    ),
    fakeConversation(
      showName: '李四',
      latestMsg: '{"contentType":102,"senderNickname":"李四","content":""}',
      latestMsgSendTime: now - 30 * 60 * 1000,
      unreadCount: 3,
    ),
    fakeConversation(
      showName: '王五',
      userId: 'user_3',
      conversationId: 'si_user_1_user_3',
      latestMsg: '{"contentType":107,"senderNickname":"王五","content":""}',
      latestMsgSendTime: now - 2 * 3600 * 1000,
      isPinned: true,
    ),
    fakeConversation(
      showName: '测试群',
      conversationId: 'sg_group_1002',
      conversationType: 2,
      groupId: 'group_1002',
      latestMsg: '{"contentType":103,"senderNickname":"赵六","content":""}',
      latestMsgSendTime: now - 24 * 3600 * 1000,
      recvMsgOpt: 1,
      unreadCount: 99,
    ),
    fakeConversation(
      showName: '赵六',
      userId: 'user_5',
      conversationId: 'si_user_1_user_5',
      draftText: '晚上一起吃饭吗？',
      draftTextTime: now - 10 * 60 * 1000,
      latestMsgSendTime: now - 3 * 24 * 3600 * 1000,
    ),
  ];
}

// ==================== 用户 / 群组 / 成员 / 好友 ====================

/// 用户假数据：直接复用 [User.mockUsers]。
List<User> fakeUsers() => User.mockUsers;

Group fakeGroup({
  String groupId = 'group_1001',
  String groupName = '产品讨论群',
  int memberCount = 128,
}) {
  return Group(
    groupId: groupId,
    groupName: groupName,
    faceUrl: '',
    introduction: '日常产品讨论与需求评审',
    notification: '欢迎新成员',
    ownerUserId: 'user_1',
    memberCount: memberCount,
    status: 0,
  );
}

GroupMember fakeGroupMember({
  required String userId,
  required String nickname,
  int roleLevel = 1,
}) {
  return GroupMember(
    groupId: 'group_1001',
    userId: userId,
    nickname: nickname,
    faceUrl: '',
    roleLevel: roleLevel,
    joinSource: '',
  );
}

List<GroupMember> fakeGroupMemberList() {
  return [
    fakeGroupMember(userId: 'user_1', nickname: '张三', roleLevel: 3),
    fakeGroupMember(userId: 'user_2', nickname: '李四', roleLevel: 2),
    fakeGroupMember(userId: 'user_3', nickname: '王五'),
    fakeGroupMember(userId: 'user_4', nickname: '孙七'),
    fakeGroupMember(userId: 'user_5', nickname: '赵六'),
    fakeGroupMember(userId: 'user_6', nickname: '周八'),
  ];
}

Friend fakeFriend({
  required String userId,
  required String nickname,
  String remark = '',
}) {
  return Friend(
    userId: userId,
    nickname: nickname,
    faceUrl: '',
    gender: 0,
    remark: remark,
    addSource: '',
    ex: '',
  );
}

List<Friend> fakeFriendList() {
  return [
    fakeFriend(userId: 'user_2', nickname: '李四', remark: '产品经理'),
    fakeFriend(userId: 'user_3', nickname: '王五'),
    fakeFriend(userId: 'user_4', nickname: '孙七', remark: '后端'),
    fakeFriend(userId: 'user_5', nickname: '赵六', remark: '设计师'),
    fakeFriend(userId: 'user_6', nickname: '周八'),
  ];
}
