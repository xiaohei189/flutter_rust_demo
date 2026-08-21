import 'package:flutter/material.dart';

import '../../../../domain/models/group_member.dart';
import '../message_content_type.dart' show MessageContentType;
import 'at_member_query.dart';
import 'format_toolbar.dart' show MarkdownFormat;
import 'markdown_editor.dart';

/// 输入面板展开状态
enum ComposerPanel { none, emoji, attachment }

/// 聊天输入组合状态：面板互斥、Markdown 模式、@ 查询、文本提示。
/// 输入区 State 只负责布局、焦点与录音/附件等设备能力。
class ChatComposerController extends ChangeNotifier {
  ChatComposerController({this.onAtMemberSelected});

  final void Function(String userId)? onAtMemberSelected;

  final AtMemberQuery atMemberQuery = const AtMemberQuery();
  final MarkdownEditor markdownEditor = const MarkdownEditor();
  final ValueNotifier<bool> hasText = ValueNotifier<bool>(false);

  String? _atKeyword;
  int _atSelectionIndex = 0;

  ComposerPanel _activePanel = ComposerPanel.none;
  bool _isMarkdownMode = false;

  ComposerPanel get activePanel => _activePanel;
  bool get isMarkdownMode => _isMarkdownMode;
  String? get atKeyword => _atKeyword;
  int get atSelectionIndex => _atSelectionIndex;
  bool get hasActivePanel => _activePanel != ComposerPanel.none;

  /// 输入内容变化：同步文本提示与 @ 查询关键字。
  void updateText(
    String text,
    TextSelection selection, {
    required bool isGroupChat,
    required List<GroupMember>? atMembers,
  }) {
    hasText.value = text.trim().isNotEmpty;
    final keyword = atMemberQuery.resolve(
      text,
      selection,
      isGroupChat: isGroupChat,
      atMembers: atMembers,
    );
    if (_atKeyword == keyword) return;
    _atKeyword = keyword;
    _atSelectionIndex = 0;
    notifyListeners();
  }

  void setAtKeyword(String? keyword) {
    if (_atKeyword == keyword) return;
    _atKeyword = keyword;
    _atSelectionIndex = 0;
    notifyListeners();
  }

  void moveAtSelection(int delta, int count) {
    if (count == 0) return;
    _atSelectionIndex = atMemberQuery.normalizedIndex(
      _atSelectionIndex + delta,
      count,
    );
    notifyListeners();
  }

  /// 选择成员：替换 "@关键字" 为 "@昵称 "，并回调外部记录 atUserId。
  void selectAtMember(TextEditingController controller, GroupMember member) {
    final text = controller.text;
    final caret = controller.selection.isValid
        ? controller.selection.baseOffset
        : text.length;
    final searchFrom = caret > 0 ? caret - 1 : 0;
    final lastAt = text.lastIndexOf('@', searchFrom);
    if (lastAt < 0) return;
    final displayName = member.nickname.isNotEmpty
        ? member.nickname
        : member.userId;
    final newText = '${text.substring(0, lastAt)}@$displayName ';
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    onAtMemberSelected?.call(member.userId);
    setAtKeyword(null);
  }

  /// 面板与键盘互斥切换（微信式）：点开收键盘，再点同按钮弹键盘。
  void togglePanel(ComposerPanel panel) {
    _activePanel = _activePanel == panel ? ComposerPanel.none : panel;
    notifyListeners();
  }

  void closePanels() {
    if (_activePanel == ComposerPanel.none) return;
    _activePanel = ComposerPanel.none;
    notifyListeners();
  }

  void setMarkdownMode(bool value) {
    if (_isMarkdownMode == value) return;
    _isMarkdownMode = value;
    notifyListeners();
  }

  void insertEmoji(TextEditingController controller, String emoji) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    controller.text = newText;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: start + emoji.length),
    );
  }

  /// Markdown 格式插入；键盘态下由调用方恢复焦点。
  void handleFormat(
    TextEditingController controller,
    MarkdownFormat format, {
    required VoidCallback onRequestFocus,
  }) {
    markdownEditor.handleFormat(controller, format);
    if (_activePanel == ComposerPanel.none) {
      onRequestFocus();
    }
  }

  /// 发送当前输入文本，返回发送内容（空文本不发送）。
  String? sendText(
    TextEditingController controller, {
    required void Function(String text, MessageContentType type) onSend,
  }) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    onSend(
      text,
      _isMarkdownMode ? MessageContentType.markdown : MessageContentType.text,
    );
    return text;
  }

  @override
  void dispose() {
    hasText.dispose();
    super.dispose();
  }
}
