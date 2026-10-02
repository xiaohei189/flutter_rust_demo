import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/group_member.dart';
import '../../../core/theme/app_theme.dart';
import '../message_content_type.dart';
import 'at_member_suggestions.dart';
import 'attachment_panel.dart';
import 'chat_composer_controller.dart';
import 'chat_input_field.dart';
import 'emoji_panel.dart';
import 'format_toolbar.dart' show MarkdownFormat;
import 'input_toolbar_icon.dart';
import 'markdown_format_bar.dart';
import 'message_composer_sheet.dart';
import 'recording_overlay.dart';
import 'voice_recorder_controller.dart';

/// 底部输入区：
/// - 按钮变形（mic ↔ 发送）
/// - 内嵌表情面板
/// - 附件 Grid 面板
/// - Markdown 格式工具栏（长按发送切换）
/// - 输入框自适应扩展
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String text, MessageContentType type) onSend;
  final VoidCallback? onImagePick;
  final VoidCallback? onImagesPick;
  final VoidCallback? onCameraPick;
  final VoidCallback? onFilePick;
  final VoidCallback? onLocationPick;
  final VoidCallback? onVideoPick;
  final Function(int duration, String filePath)? onVoiceRecord;
  final VoidCallback? onCardSend;
  final VoidCallback? onAtMention;
  final ValueChanged<String>? onGifSelected;
  final List<GroupMember>? atMembers;
  final ValueChanged<String>? onAtMemberSelected;
  final bool isGroupChat;

  /// 展开编辑抽屉的占位文案（如「发送给 张三」）
  final String? sendToLabel;

  /// 输入区高度上报（输入行 + 已展开的面板）。
  ///
  /// 注意：上报的是**布局占位高度**（输入行 + 面板），**不含键盘让位的那部分**。
  /// 外层据此给消息列表留底部空间；键盘高度变化不会改变这个值，
  /// 因此键盘开合不会让列表内容重新留白/位移 —— 对齐飞书实机录屏测得的行为：
  /// 键盘直接盖在列表之上，列表本身不反应。
  final ValueNotifier<double>? heightNotifier;

  /// 键盘高度（`MediaQuery.viewInsets.bottom`），0 表示键盘收起。
  ///
  /// 由外层传入：外层已设 resizeToAvoidBottomInset: false，键盘高度是布局的**输入**
  /// 而非结果，显式传入可避免重复依赖 MediaQuery。取实际值而非写死，
  /// 因此不同机型的键盘高度都成立。
  final double keyboardInset;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onImagePick,
    this.onImagesPick,
    this.onCameraPick,
    this.onFilePick,
    this.onLocationPick,
    this.onVideoPick,
    this.onVoiceRecord,
    this.onCardSend,
    this.onAtMention,
    this.onGifSelected,
    this.atMembers,
    this.onAtMemberSelected,
    this.isGroupChat = false,
    this.sendToLabel,
    this.heightNotifier,
    // 必传：漏传会让输入行停在屏幕底部被键盘挡住（真机出过这个事故）。
    // 做成必传参数后，「忘记接线」会在编译期直接失败，而不是运行时静默失效。
    required this.keyboardInset,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  /// 输入行高度（实测）。用于把差额占位限制在可用空间内，避免小屏溢出。
  double _inputRowHeight = 0;

  /// 上一次实测到的键盘高度（进程内跨会话页共享）。
  ///
  /// 面板与键盘是「同一块底部空间」的两种形态，面板按记忆的键盘高度对齐占位，
  /// 两者互相切换时占位高度不变 → 列表零位移（业界 IM 的通行做法）。
  ///
  /// 用 static：同一台设备键盘高度稳定，换一个会话/重进页面也能立刻按已知高度
  /// 给面板占位；否则新页面第一次开面板会低二十几像素，之后弹一次键盘才对齐。
  ///
  /// 只在键盘「稳定弹出后完全收起」时提交（见 [_learnKeyboardHeight]），
  /// 弹出/收起动画途中的中间值一律不写入，免得面板占位跟着动画忽大忽小。
  static double _lastKeyboardHeight = 0;

  /// 本次 build 算出的「底部占位块」高度 = max(面板高度, 键盘高度)，供上报列表留白。
  double _sheetExtent = 0;

  /// 本次键盘弹出期间见过的最大 inset（键盘完全收起时清 0 并提交为长期记忆）。
  ///
  /// 用途：剔除键盘收起动画里的中间值与尾巴，同时让「记忆键盘高度」只在键盘
  /// 稳定弹出结束后才更新，见 [_learnKeyboardHeight]。
  double _keyboardSessionPeak = 0;

  late FocusNode _focusNode;
  late final ChatComposerController _composer;

  /// 语音录制状态（权限、临时文件、上滑取消、60s 上限）
  late final VoiceRecorderController _voiceRecorder;

  /// 缓存的附件列表，避免每次 build 创建新对象
  late List<AttachmentItem> _cachedAttachmentItems;

  /// 两个面板按需构建：从未打开过就不创建（进入会话不付面板的 build/layout 成本）；
  /// 打开过一次后常驻树中（Offstage 保状态），并且缓存 widget 实例——Flutter 在
  /// `child.widget == newWidget` 时直接复用 Element 不重建子树（Element.updateChild 快路径），
  /// 约束未变时 layout 也提前返回。因此「首次进入零成本 + 之后重建零成本 + 状态保留」。
  late final Widget _emojiPanel = EmojiPanel(
    onEmojiSelected: _insertEmoji,
    onGifSelected: widget.onGifSelected,
    onBackspace: _handleBackspace,
  );
  late final Widget _attachmentPanel = AttachmentPanel(
    items: _cachedAttachmentItems,
    onItemTap: () => _composer.closePanels(),
  );
  bool _emojiPanelOpened = false;
  bool _attachmentPanelOpened = false;

  @override
  void initState() {
    super.initState();
    // 页面可能在键盘已经弹起时才被创建（切会话、热更新）：先把当前高度收进记忆，
    // 否则面板占位会按设计高度算，输入行落到键盘下面。
    if (widget.keyboardInset > 0) {
      _lastKeyboardHeight = widget.keyboardInset;
      _keyboardSessionPeak = widget.keyboardInset;
    }
    _focusNode = FocusNode();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
    _composer = ChatComposerController(
      onAtMemberSelected: widget.onAtMemberSelected,
    )..addListener(_onComposerChanged);
    _composer.updateText(
      widget.controller.text,
      widget.controller.selection,
      isGroupChat: widget.isGroupChat,
      atMembers: widget.atMembers,
    );
    _initAttachmentItems();
    _voiceRecorder = VoiceRecorderController(
      onVoiceRecord: widget.onVoiceRecord,
    )..addListener(_onRecordingChanged);
  }

  void _onFocusChanged() {
    // 飞书式：键盘与面板不是互斥销毁关系，面板始终留在底部，
    // 键盘弹起只是盖在面板之上（面板不关闭、不位移）。
    // 因此聚焦/失焦都不动面板状态，只刷新下面两种布局的切换
    // （默认一行 / 聚焦态完整工具栏）。
    // 焦点变化会切换“默认一行（声音+输入框+表情+更多）”与
    // “聚焦态（输入行+底部完整工具栏）”两种布局，刷新 build
    if (mounted) setState(() {});
  }

  void _initAttachmentItems() {
    // 严格对齐飞书稿：文件 / 云文档 / 日程 / 位置 / 个人名片 / 定时消息 / 任务 / 开启边写边译 / 更多
    const blue = Color(0xFF3370FF);
    const orange = Color(0xFFFF8A00);
    const purple = Color(0xFF7F3BF5);
    const green = Color(0xFF00B42A);
    void notSupported(String label) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 暂未开放'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }

    _cachedAttachmentItems = [
      AttachmentItem(
        icon: Icons.folder_open,
        label: '文件',
        color: orange,
        onTap: widget.onFilePick,
      ),
      AttachmentItem(
        icon: Icons.description_outlined,
        label: '云文档',
        color: blue,
        onTap: () => notSupported('云文档'),
      ),
      AttachmentItem(
        icon: Icons.calendar_today_outlined,
        label: '日程',
        color: orange,
        onTap: () => notSupported('日程'),
      ),
      AttachmentItem(
        icon: Icons.location_on,
        label: '位置',
        color: blue,
        onTap: widget.onLocationPick,
      ),
      AttachmentItem(
        icon: Icons.contact_page_outlined,
        label: '个人名片',
        color: blue,
        onTap: widget.onCardSend != null ? () => widget.onCardSend!() : null,
      ),
      AttachmentItem(
        icon: Icons.schedule_send_outlined,
        label: '定时消息',
        color: blue,
        onTap: () => notSupported('定时消息'),
      ),
      AttachmentItem(
        icon: Icons.task_alt,
        label: '任务',
        color: purple,
        onTap: () => notSupported('任务'),
      ),
      AttachmentItem(
        icon: Icons.translate,
        label: '开启边写边译',
        color: green,
        onTap: () => notSupported('边写边译'),
      ),
      AttachmentItem(
        icon: Icons.more_horiz,
        label: '更多',
        color: const Color(0xFF646A73),
        onTap: () => notSupported('更多'),
      ),
    ];
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // @ 成员列表激活时：↑/↓ 切换高亮、Enter 确认、Esc 关闭
    if (_composer.atKeyword != null && _filteredAtMembers.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _composer.moveAtSelection(1, _filteredAtMembers.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _composer.moveAtSelection(-1, _filteredAtMembers.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _composer.setAtKeyword(null);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter) {
        if (!HardwareKeyboard.instance.isShiftPressed) {
          final members = _filteredAtMembers;
          final index = _composer.atMemberQuery.normalizedIndex(
            _composer.atSelectionIndex,
            members.length,
          );
          _composer.selectAtMember(widget.controller, members[index]);
          _focusNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
    }

    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _doSend();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _voiceRecorder.removeListener(_onRecordingChanged);
    _voiceRecorder.dispose();
    _composer.removeListener(_onComposerChanged);
    _composer.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _learnKeyboardHeight(widget.keyboardInset);
  }

  /// 学习键盘高度：会话期间只记峰值，键盘完全收起时才提交为长期记忆。
  ///
  /// 绝不能在键盘升起途中用中间值改写 `_lastKeyboardHeight`：面板开着时占位块取
  /// `max(面板高度, 键盘高度)`，记忆值一旦被 62.5 这种中间值改小，占位块会在
  /// 键盘升到一半时先塌下去、再被顶回来 —— 真机逐帧量到输入行与整个消息列表
  /// 上下抖一次（inset 0→62.5→237.8→312.7→321.8 时占位 321.8→300→300→312.7→321.8）。
  ///
  /// 收起动画同理：inset 会一路衰减并留一个手势条高度的尾巴，所以只在
  /// `inset <= 0` 时才把本次峰值提交为记忆值。
  void _learnKeyboardHeight(double inset) {
    if (inset <= 0) {
      if (_keyboardSessionPeak > 0) {
        _lastKeyboardHeight = _keyboardSessionPeak;
      }
      _keyboardSessionPeak = 0;
      return;
    }
    if (inset > _keyboardSessionPeak) {
      _keyboardSessionPeak = inset;
    }
  }

  void _onTextChanged() {
    _composer.updateText(
      widget.controller.text,
      widget.controller.selection,
      isGroupChat: widget.isGroupChat,
      atMembers: widget.atMembers,
    );
  }

  void _onComposerChanged() {
    // 面板第一次被激活时才标记：build 里据此决定是否把面板放进树（按需构建）
    switch (_composer.activePanel) {
      case ComposerPanel.emoji:
        _emojiPanelOpened = true;
      case ComposerPanel.attachment:
        _attachmentPanelOpened = true;
      case ComposerPanel.none:
        break;
    }
    if (mounted) setState(() {});
  }

  void _onRecordingChanged() {
    if (mounted) setState(() {});
  }

  void _doSend() {
    _composer.sendText(widget.controller, onSend: widget.onSend);
  }

  // ==================== 面板管理 ====================

  /// 面板按钮：切换「底部露出的是谁」。
  ///
  /// - 点到另一个面板 / 从无面板点开 → 展开该面板并收键盘（面板直接顶上来）
  /// - 面板被键盘盖着时再点同一按钮 → 只收键盘，面板留在原地露出来
  /// - 面板可见、键盘未弹时再点同一按钮 → 收起面板（既有交互）
  ///
  /// 注意：键盘弹起本身（点输入框）不会关闭面板，见 [_onFocusChanged]。
  void _togglePanel(ComposerPanel panel) {
    final samePanel = _composer.activePanel == panel;
    if (!samePanel) {
      _composer.togglePanel(panel);
      FocusScope.of(context).unfocus();
      return;
    }
    if (_focusNode.hasFocus) {
      // 键盘正盖着面板：收键盘即可，面板不需要重建/关闭。
      FocusScope.of(context).unfocus();
      return;
    }
    _composer.closePanels();
  }

  void _closeAllPanels() {
    _composer.closePanels();
  }

  /// 表情面板的退格：删除光标前一个字符（有选区则删选区）
  void _handleBackspace() {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final end = selection.end >= 0 ? selection.end : text.length;
    if (end <= 0) return;
    final start = selection.start >= 0 ? selection.start : end;
    var removeStart = start == end ? end - 1 : start;
    // 避免把代理对（emoji）拆成半个字符
    if (removeStart > 0 &&
        text.codeUnitAt(removeStart) >= 0xDC00 &&
        text.codeUnitAt(removeStart) <= 0xDFFF) {
      removeStart -= 1;
    }
    controller.value = TextEditingValue(
      text: text.replaceRange(removeStart, end, ''),
      selection: TextSelection.collapsed(offset: removeStart),
    );
  }

  /// 打开"展开编辑"抽屉（飞书式半屏大编辑区）。
  /// 与输入框共享同一个 controller，草稿天然同步；只编辑不发送，关闭后回主界面发送。
  void _openComposerSheet() {
    _closeAllPanels();
    // 不主动收键盘：抽屉内输入框 autofocus 会接管焦点，键盘保持连续，
    // 避免“先收起键盘、抽屉弹出后再弹键盘”导致的键盘翻动。
    final wasFocused = _focusNode.hasFocus;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // 高度由抽屉内拖拽把手自管理：enableDrag 会让整体拖动（工具栏被拖到键盘下）且松手自动回弹，
      // 改为把手拖动调整高度并保持，底部工具栏固定
      // 覆盖 M3 BottomSheet 默认 maxWidth 640，抽屉全宽
      constraints: const BoxConstraints(maxWidth: double.infinity),
      // surface 随深浅色主题变化（onPrimary 恒为白，不能当背景用）
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MessageComposerSheet(
        controller: widget.controller,
        hasText: _composer.hasText,
        onSend: widget.onSend,
        onImagePick: widget.onImagePick,
        onAtMention: widget.onAtMention,
        onGifSelected: widget.onGifSelected,
        attachmentItems: _attachmentItems,
        sendToLabel: widget.sendToLabel ?? '发送消息',
      ),
    ).then((_) {
      // 缩回后恢复打开前的输入区状态：若打开前未聚焦（工具栏收起），
      // 则取消主输入框焦点，避免抽屉关闭后焦点回弹导致底部工具栏意外展开。
      if (mounted && !wasFocused && _focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    });
  }

  // ==================== Markdown 格式插入 ====================

  void _handleFormat(MarkdownFormat format) {
    _composer.handleFormat(
      widget.controller,
      format,
      onRequestFocus: () => _focusNode.requestFocus(),
    );
  }

  // ==================== Emoji 插入 ====================

  void _insertEmoji(String emoji) {
    _composer.insertEmoji(widget.controller, emoji);
    // 面板态插入不弹键盘，保持连续选择；切回键盘用面板内"键盘"按钮
  }

  // ==================== 附件列表 ====================

  List<AttachmentItem> get _attachmentItems => _cachedAttachmentItems;

  // ==================== 实时 @（Telegram 式） ====================

  /// 按关键字过滤群成员（昵称 / ID 模糊匹配）
  List<GroupMember> get _filteredAtMembers => _composer.atMemberQuery.filter(
    _composer.atKeyword,
    widget.atMembers ?? const [],
  );

  /// 成员选择列表（输入框上方，随关键字过滤）
  Widget _buildAtMemberList() => AtMemberSuggestions(
    members: _filteredAtMembers,
    selectedIndex: _composer.atSelectionIndex,
    onSelect: (member) {
      _composer.selectAtMember(widget.controller, member);
      _focusNode.requestFocus();
    },
  );

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    // 手势条高度（键盘弹起时系统会把它置 0）。必须在 SafeArea 之外取：
    // 进了 SafeArea 之后 MediaQuery.padding.bottom 已被清零。
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // 按钮高亮表示「现在露出的是这个面板」。键盘盖在面板上时露出的是键盘，
    // 按钮回到未激活态，点击含义变成「收键盘、露出面板」（对齐飞书）。
    final keyboardOnTop = _focusNode.hasFocus || widget.keyboardInset > 0;
    final emojiActive =
        _composer.activePanel == ComposerPanel.emoji && !keyboardOnTop;
    final moreActive =
        _composer.activePanel == ComposerPanel.attachment && !keyboardOnTop;
    // 面板的「设计高度」：占位块的下限（表情 300 / 附件 320）。
    // 面板渲染时会被撑到占位块高度，所以这里用设计常量即可，不必等实测。
    final panelPreferred = switch (_composer.activePanel) {
      ComposerPanel.emoji => kEmojiPanelHeight,
      ComposerPanel.attachment => kAttachmentPanelHeight,
      ComposerPanel.none => 0.0,
    };
    // 底部占位块 = max(面板设计高度, 键盘高度)：面板与键盘争的是同一块空间。
    //
    // 面板开着时**只用记忆的键盘高度**、不掺逐帧变化的当前 inset：
    // 这样键盘升降动画期间占位恒定 → 输入行一动不动，键盘只是滑上来盖住面板，
    // 就是飞书那种「底部在换、其它不动」的观感。首次遇到更高的键盘时会随
    // 峰值抬高一次，之后不再变化。
    //
    // 无面板时用当前 inset：键盘把列表顶起来，最新消息不会被键盘盖住。
    // 面板态只用「记忆的键盘高度」，**不掺当前逐帧 inset**：键盘收起动画期间
    // 逐帧 inset 会一路衰减到 0，掺进来会让占位块先塌到面板高度、动画结束再被
    // 记忆值顶回去 —— 真机逐帧量到输入行会先掉 60px 再弹回来（就是"上下动一下"）。
    // 键盘高度在 initState（进页面时键盘已弹起）和 didUpdateWidget（弹出峰值）里学习。
    //
    // 取「长期记忆」与「本次会话峰值」的较大者：两者都只增不减，因此键盘升到
    // 一半时占位块也不会被压小 —— 否则真机逐帧量到占位先塌 22px 再顶回来
    // （面板态点输入框带出键盘时，输入行和整个消息列表会抖一下）。
    final panelKeyboardHeight = math.max(
      _lastKeyboardHeight,
      _keyboardSessionPeak,
    );
    final sheetExtent = _composer.hasActivePanel
        ? math.max(panelPreferred, panelKeyboardHeight)
        : widget.keyboardInset;
    _sheetExtent = sheetExtent;
    // 占位块的目标高度（从输入行下沿到屏幕底部，扣掉手势条）。
    // 无面板时它就是键盘高度（把输入行顶到键盘上沿）；
    // 有面板时面板撑满它，面板顶边正好接住输入行。
    final desiredBlock = math.max(0.0, sheetExtent - safeBottom);
    // SafeArea 只在外层与屏幕边缘之间留间隙，内部组件无缝紧贴
    return SafeArea(
      top: false,
      bottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 可用空间不足（小屏/横屏/大字体/高键盘）时收敛面板占位：优先保证
          // 输入行完整可见，收敛掉的部分转到「输入行与面板之间」的差额里，
          // 占位块高度：目标值由外层 Flexible 自动收敛到可用空间（Column 布局时
          // 先量非 flex 的输入行，再给 Flexible 剩余空间），因此这里直接给目标值即可，
          // 不会出现 RenderFlex 溢出，也不必依赖尚未来得及实测的输入行高度。
          final block = desiredBlock;
          return _MeasureSize(
            onChange: _reportHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_voiceRecorder.isRecording)
                  RecordingOverlay(cancel: _voiceRecorder.recordingCancel),
                _MeasureSize(
                  onChange: _onInputRowSized,
                  child: Container(
                    // 供测试精确测量输入行区域（下沿应贴住键盘上沿）。
                    key: const ValueKey('chat_input_row_area'),
                    color: context.appColors.inputBackground,
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      // 子项撑满宽度，避免工具栏/面板被默认居中
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // @ 成员候选：贴在胶囊上方
                        if (_composer.atKeyword != null) _buildAtMemberList(),
                        // 输入胶囊：白底圆角，右侧内嵌「展开编辑」
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _buildInputRow(),
                        ),
                        const SizedBox(height: 4),
                        // Markdown 模式用格式栏替换操作行（避免出现两个发送按钮）
                        if (_composer.isMarkdownMode)
                          _buildFormatBar()
                        else
                          // 常驻操作行：😊 @ 🎤 🖼 Aa ⊕ ——右侧固定发送
                          _buildActionRow(emojiActive, moreActive),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
                // 底部占位块：高度 = max(面板设计高度, 记忆的键盘高度) − 手势条，
                // **与键盘动画无关**（面板态下不掺当前 inset），所以键盘滑上来时
                // 面板与输入行都不位移，只有键盘盖在面板上 —— 飞书那种观感。
                // 面板贴在块底部，块内剩余部分填面板同色，视觉上等于面板顶到输入行；
                // 没有面板时整块就是让位空间（被键盘盖住，看不到）。
                // 两个面板常驻树中（Offstage 保状态），切换不重建、不重读磁盘。
                Flexible(
                  fit: FlexFit.loose,
                  child: SizedBox(
                    height: block,
                    width: double.infinity,
                    child: ColoredBox(
                      color: _composer.hasActivePanel
                          ? context.appColors.attachmentBackground
                          : context.appColors.inputBackground,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 面板必须包在 Flexible 里：Column 给非 flex 子项的
                            // 主轴约束是**无界**的，面板会按自身（内容 + 内边距）
                            // 高度铺开并溢出占位块（真机上报过面板下沿超出屏幕 36px）。
                            if (_emojiPanelOpened)
                              Flexible(
                                child: Offstage(
                                  offstage:
                                      _composer.activePanel !=
                                      ComposerPanel.emoji,
                                  child: _emojiPanel,
                                ),
                              ),
                            if (_attachmentPanelOpened)
                              Flexible(
                                child: Offstage(
                                  offstage:
                                      _composer.activePanel !=
                                      ComposerPanel.attachment,
                                  child: _attachmentPanel,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 上报「输入行 + 底部占位块」的总高度（业界公式：`输入行 + max(面板, 键盘)`）。
  ///
  /// 外层据此给消息列表留底部空间：占位块多高，列表就让多少，
  /// 最新消息始终停在输入行上方。面板与键盘等高时该值恒定，
  /// 因此两者互相切换不会让列表重新留白（不依赖具体机型/键盘高度）。
  void _reportHeight(Size size) {
    final notifier = widget.heightNotifier;
    if (notifier == null) return;
    // 实测总高（输入行 + 占位块）与让位公式取较大者：既保证列表留白不小于
    // 实际渲染高度（不遮挡），也不小于占位块高度（面板与键盘切换零位移）。
    final height = math.max(size.height, _inputRowHeight + _sheetExtent);
    if (height <= 0 || height == notifier.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifier.value = height;
    });
  }

  /// 输入行高度回报：用于把差额占位限制在可用空间内。
  void _onInputRowSized(Size size) {
    final height = size.height;
    if (height <= 0 || height == _inputRowHeight) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _inputRowHeight = height);
    });
  }

  /// 第二层：输入框行（全宽圆角、自适应高度）
  Widget _buildInputRow() {
    return ChatInputField(
      controller: widget.controller,
      focusNode: _focusNode,
      isMarkdownMode: _composer.isMarkdownMode,
      onOpenComposer: _openComposerSheet,
      onSubmitted: _doSend,
    );
  }

  /// 常驻操作行（飞书稿）：😊 @ 🎤 🖼 Aa ⊕ 均匀分布，最右固定发送。
  /// 开关面板只改图标形态（蓝色/实心），行结构与输入框 Element 始终不变，
  /// 因此聚焦、切面板都不会替换 TextField（键盘不会闪）。
  Widget _buildActionRow(bool emojiActive, bool moreActive) {
    final colors = context.appColors;
    final imagePicker = widget.onImagesPick ?? widget.onImagePick;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final icon in <Widget>[
            InputToolbarIcon(
              icon: emojiActive
                  ? Icons.emoji_emotions
                  : Icons.emoji_emotions_outlined,
              tooltip: '表情',
              active: emojiActive,
              onTap: () => _togglePanel(ComposerPanel.emoji),
            ),
            InputToolbarIcon(
              icon: Icons.alternate_email,
              tooltip: '@ 提及',
              onTap: () => widget.onAtMention?.call(),
            ),
            InputToolbarIcon(
              icon: Icons.mic_none,
              tooltip: '语音（长按录音，上滑取消）',
              onTap: () => _focusNode.requestFocus(),
              onLongPressStart: (details) =>
                  _voiceRecorder.start(context, details),
              onLongPressMoveUpdate: _voiceRecorder.onMove,
              onLongPressEnd: (details) =>
                  _voiceRecorder.stop(context, details),
            ),
            InputToolbarIcon(
              icon: Icons.image_outlined,
              tooltip: '相册',
              enabled: imagePicker != null,
              onTap: () => imagePicker?.call(),
            ),
            _buildMarkdownToggle(colors),
            InputToolbarIcon(
              icon: moreActive ? Icons.cancel : Icons.add_circle_outline,
              tooltip: moreActive ? '收起' : '更多',
              active: moreActive,
              onTap: () => _togglePanel(ComposerPanel.attachment),
            ),
          ])
            Expanded(child: Center(child: icon)),
          const SizedBox(width: 4),
          _buildSendButton(colors),
        ],
      ),
    );
  }

  /// Aa：Markdown 模式开关（激活时蓝色）
  Widget _buildMarkdownToggle(AppColors colors) {
    final active = _composer.isMarkdownMode;
    return Tooltip(
      message: active ? '关闭 Markdown' : 'Markdown 格式',
      child: Semantics(
        label: 'Aa',
        button: true,
        child: InkResponse(
          onTap: _toggleMarkdown,
          radius: 20,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: Text(
                'Aa',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? colors.primary
                      : colors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 发送：纸飞机图标，无文字时置灰不可点
  Widget _buildSendButton(AppColors colors) {
    return ValueListenableBuilder<bool>(
      valueListenable: _composer.hasText,
      builder: (_, hasText, __) => Tooltip(
        message: '发送',
        child: Semantics(
          label: '发送',
          button: true,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 36),
            onPressed: hasText ? _doSend : null,
            icon: Icon(
              Icons.send_outlined,
              size: 26,
              color: hasText
                  ? colors.primary
                  : colors.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  /// Aa 点击：切换 Markdown 模式（进入时收起面板并聚焦）
  void _toggleMarkdown() {
    HapticFeedback.lightImpact();
    final enteringMarkdown = !_composer.isMarkdownMode;
    _composer.setMarkdownMode(enteringMarkdown);
    if (enteringMarkdown) {
      // 进入 Markdown 模式时收起面板，避免面板+格式栏同屏
      _composer.closePanels();
      _focusNode.requestFocus();
    }
  }

  /// 第二层（Markdown 模式）：格式按钮栏，替换普通工具栏。
  /// 发送统一走普通工具栏：先点 ↩ 退出 Markdown，再点发送（右侧只留返回按钮）。
  /// 退出后聚焦输入框继续输入（与进入时对称）。
  Widget _buildFormatBar() {
    return MarkdownFormatBar(
      onFormat: _handleFormat,
      onClose: () {
        _composer.setMarkdownMode(false);
        _focusNode.requestFocus();
      },
      trailing: ValueListenableBuilder<bool>(
        valueListenable: _composer.hasText,
        builder: (_, __, ___) => _buildSendButton(context.appColors),
      ),
    );
  }

  // ==================== 辅助 ====================
}

/// 布局结束后回调子树实际尺寸（回调发生在布局阶段，调用方需把写值推迟到帧末）。
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required Widget super.child, this.onChange});

  final ValueChanged<Size>? onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size>? onChange;

  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (newSize == _lastSize) return;
    _lastSize = newSize;
    onChange?.call(newSize);
  }
}
