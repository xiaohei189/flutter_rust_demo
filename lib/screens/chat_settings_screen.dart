import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user.dart';
import '../src/rust/im/model/conversation.dart' as im_conv;
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'group_info_screen.dart';

/// 聊天设置页面：单聊 / 群聊 分别展示不同内容
class ChatSettingsScreen extends StatefulWidget {
  final im_conv.LocalConversation conversation;

  const ChatSettingsScreen({super.key, required this.conversation});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  late bool _muteNotification;
  late bool _pinChat;
  bool _addToMark = false;

  bool get _isGroup =>
      widget.conversation.conversationType == 2 ||
      widget.conversation.conversationType == 3;

  String get _displayName =>
      widget.conversation.showName.isNotEmpty
          ? widget.conversation.showName
          : _isGroup
              ? '群聊'
              : '用户';

  User get _chatUser => User(
        id: widget.conversation.userId.isNotEmpty
            ? widget.conversation.userId
            : widget.conversation.groupId,
        name: _displayName,
        avatar: widget.conversation.faceUrl.isNotEmpty
            ? widget.conversation.faceUrl
            : null,
      );

  @override
  void initState() {
    super.initState();
    _muteNotification = widget.conversation.recvMsgOpt == 1;
    _pinChat = widget.conversation.isPinned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined, size: 22),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ---- 顶部：成员区域 ----
          _buildCard(
            children: [
              if (_isGroup) ..._buildGroupHeader() else ..._buildSingleHeader(),
            ],
          ),

          // ---- 群成员（仅群聊） ----
          if (_isGroup) ...[
            const SizedBox(height: 8),
            _buildCard(children: _buildGroupMembers()),
          ],

          // ---- 应用 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildSectionTitle(_isGroup ? '群应用' : '应用'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  if (_isGroup)
                    _buildAppIcon(Icons.campaign_outlined, '群公告', AppTheme.primaryColor),
                  _buildAppIcon(Icons.edit_outlined, '任务', AppTheme.primaryColor),
                  _buildAppIcon(Icons.push_pin_outlined, 'Pin', const Color(0xFF34C759)),
                  _buildAppIcon(
                    Icons.calendar_month_outlined,
                    _isGroup ? '群成员日历' : '查看日历',
                    const Color(0xFFFF9500),
                  ),
                ],
              ),
            ),
          ]),

          // ---- 搜索会话内容 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('搜索会话内容', onTap: () {}),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  _buildSearchIcon(Icons.chat_bubble_outline, '消息'),
                  _buildSearchIcon(Icons.description_outlined, '云文档'),
                  _buildSearchIcon(Icons.folder_outlined, '文件'),
                  _buildSearchIcon(Icons.image_outlined, '图片/视频'),
                  _buildSearchIcon(Icons.link, '链接'),
                ],
              ),
            ),
          ]),

          // ---- 添加标签页 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('添加标签页', onTap: () {}),
          ]),

          // ---- 群机器人 + 群昵称（仅群聊） ----
          if (_isGroup) ...[
            const SizedBox(height: 8),
            _buildCard(children: [
              _buildNavRow('群机器人', onTap: () {}),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildNavRow('群昵称', onTap: () {}),
            ]),
          ],

          // ---- 开关设置区 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildSwitchRow('消息免打扰', _muteNotification, (v) {
              setState(() => _muteNotification = v);
            }),
            if (_isGroup) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildSwitchRow('@所有人的消息不提示', false, (_) {}),
            ],
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildSwitchRow('置顶会话', _pinChat, (v) {
              setState(() => _pinChat = v);
            }),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildNavRow('标签', onTap: () {}),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildSwitchRow('添加到标记', _addToMark, (v) {
              setState(() => _addToMark = v);
            }),
          ]),

          // ---- 翻译助手 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('翻译助手', onTap: () {}),
          ]),

          // ---- 清空聊天记录 ----
          const SizedBox(height: 8),
          _buildCard(children: [
            _buildNavRow('清空聊天记录', onTap: () {}),
          ]),

          // ---- 退出群组（仅群聊） ----
          if (_isGroup) ...[
            const SizedBox(height: 8),
            _buildCard(children: [
              InkWell(
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Text(
                      '退出群组',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.unreadRed,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],

          // ---- 会话 ID ----
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(
                  ClipboardData(text: widget.conversation.conversationId),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('已复制会话 ID'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '会话 ID: ${widget.conversation.conversationId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy_outlined,
                    size: 12,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),

          // ---- 举报 ----
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {},
              icon: Icon(
                Icons.warning_amber_outlined,
                size: 16,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
              ),
              label: Text(
                '举报',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ==================== 单聊头部 ====================

  List<Widget> _buildSingleHeader() {
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                UserAvatar(user: _chatUser, radius: 24),
                const SizedBox(height: 6),
                SizedBox(
                  width: 56,
                  child: Text(
                    _displayName,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            _buildAddButton(),
          ],
        ),
      ),
    ];
  }

  // ==================== 群聊头部 ====================

  List<Widget> _buildGroupHeader() {
    return [
      InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupInfoScreen(
                conversation: widget.conversation,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatar(user: _chatUser, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.qr_code,
                          size: 18,
                          color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '群描述',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // ==================== 群成员列表 ====================

  List<Widget> _buildGroupMembers() {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '群成员',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            Row(
              children: [
                Text(
                  '0',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [_buildAddButton()]),
      ),
    ];
  }

  // ==================== 通用组件 ====================

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          Icons.add,
          size: 24,
          color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildAppIcon(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchIcon(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppTheme.textSecondaryColor),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow(String title, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimaryColor),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimaryColor),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
