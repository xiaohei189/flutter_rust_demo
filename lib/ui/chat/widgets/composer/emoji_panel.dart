import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../data/services/emoji_store.dart';

/// 表情面板 Tab
enum EmojiTab { recent, emoji, favorite, gif }

/// 表情面板：最近使用（真实记录）+ 默认表情 + 收藏 + GIF，底部 Tab 全部可用。
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.onEmojiSelected,
    this.onGifSelected,
    this.onBackspace,
    this.maxHeight = 300,
  });

  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<String>? onGifSelected;

  /// 底部退格：删除输入框光标前一个字符（对齐飞书稿的 ⌫）
  final VoidCallback? onBackspace;

  /// 面板最大高度（默认 300；放进可拖高弹层时传更大值以撑满可用空间）
  final double maxHeight;

  /// 默认表情列表（Unicode Emoji）
  static const List<String> defaultEmojis = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😅',
    '🤣',
    '😂',
    '🙂',
    '🙃',
    '😉',
    '😊',
    '😇',
    '🥰',
    '😍',
    '🤩',
    '😘',
    '😗',
    '😚',
    '😙',
    '🥲',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤗',
    '🤭',
    '🤫',
    '🤔',
    '🤐',
    '🤨',
    '😐',
    '😑',
    '😶',
    '😏',
    '😒',
    '🙄',
    '😬',
    '😮',
    '😯',
    '😲',
    '😳',
    '🥺',
    '😦',
    '😧',
    '😨',
    '😰',
    '😥',
    '😢',
    '😭',
    '😱',
    '😖',
    '😣',
    '😞',
    '😓',
    '😩',
    '😫',
    '🥱',
    '😤',
    '😡',
    '😠',
    '🤬',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '❤️',
    '🔥',
    '⭐',
    '🎉',
    '🎊',
    '💯',
    '✅',
    '❌',
    '⚡',
    '🌟',
    '💫',
  ];

  /// 内置 GIF 列表（GIPHY 公共资源，点击发送为图片消息）
  static const List<String> gifUrls = [
    'https://media.giphy.com/media/26BRuo6sLetdllPAQ/giphy.gif',
    'https://media.giphy.com/media/3o7TKSjRrfIPjeJhde/giphy.gif',
    'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif',
    'https://media.giphy.com/media/26tOZ42r6PsdT2U9G/giphy.gif',
    'https://media.giphy.com/media/l3q2K5jinAlChoCLS/giphy.gif',
    'https://media.giphy.com/media/5GoVLqeAOo6PK/giphy.gif',
    'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif',
    'https://media.giphy.com/media/11sBLVxNs7v6WA/giphy.gif',
    'https://media.giphy.com/media/3oEjHV0z8S7WM4MwnK/giphy.gif',
  ];

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  EmojiTab _activeTab = EmojiTab.emoji;
  List<String> _recent = const [];
  List<String> _favorites = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<String> recent = const [];
    List<String> favorites = const [];
    try {
      recent = await EmojiStore.loadRecent();
      favorites = await EmojiStore.loadFavorites();
    } catch (_) {
      // 插件不可用（如 Widget Preview 环境）时降级为空列表
    }
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _favorites = favorites;
    });
  }

  Future<void> _handleEmojiTap(String emoji) async {
    widget.onEmojiSelected(emoji);
    final recent = await EmojiStore.recordUse(emoji);
    if (mounted) setState(() => _recent = recent);
  }

  Future<void> _handleEmojiLongPress(String emoji) async {
    final favorites = await EmojiStore.toggleFavorite(emoji);
    if (!mounted) return;
    setState(() => _favorites = favorites);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(favorites.contains(emoji) ? '已收藏' : '已取消收藏'),
        duration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: colors.attachmentBackground,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _buildContent(context)),
          // 底部 Tab 栏（飞书稿：左侧新建、中间表情/收藏/GIF、右侧退格）
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_activeTab) {
      case EmojiTab.emoji:
        // 「最常使用」置顶 + 「默认表情」常驻（对齐飞书稿的分区）
        return _buildEmojiSections(context);
      case EmojiTab.recent:
        return _buildEmojiGrid(
          context,
          _recent.isNotEmpty ? _recent : EmojiPanel.defaultEmojis,
          header: _recent.isEmpty ? '默认表情' : '最常使用',
        );
      case EmojiTab.favorite:
        return _buildEmojiGrid(
          context,
          _favorites,
          header: '我的收藏',
          empty: true,
        );
      case EmojiTab.gif:
        return _buildGifGrid(context);
    }
  }

  Widget _buildEmojiGrid(
    BuildContext context,
    List<String> emojis, {
    String? header,
    bool empty = false,
  }) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null) ...[
            Text(
              header,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 4),
          ],
          if (empty && emojis.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '暂无收藏，长按表情可收藏',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            _emojiGrid(context, emojis),
        ],
      ),
    );
  }

  /// 表情九宫格（7 列，不滚动，交给外层滚动容器）
  Widget _emojiGrid(BuildContext context, List<String> emojis) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: emojis.length,
      itemBuilder: (_, i) {
        final emoji = emojis[i];
        return GestureDetector(
          onTap: () => _handleEmojiTap(emoji),
          onLongPress: () => _handleEmojiLongPress(emoji),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
        );
      },
    );
  }

  Widget _buildGifGrid(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: EmojiPanel.gifUrls.length,
      itemBuilder: (_, i) {
        final url = EmojiPanel.gifUrls[i];
        return GestureDetector(
          onTap: () => widget.onGifSelected?.call(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: context.appColors.surfaceMuted,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: context.appColors.surfaceMuted,
                child: Icon(
                  Icons.broken_image,
                  color: context.appColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 「最常使用 + 默认表情」分区（同一滚动视图，对齐飞书稿）
  Widget _buildEmojiSections(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_recent.isNotEmpty) ...[
            _sectionHeader(colors, '最常使用'),
            _emojiGrid(context, _recent),
            const SizedBox(height: 12),
          ],
          _sectionHeader(colors, '默认表情'),
          _emojiGrid(context, EmojiPanel.defaultEmojis),
        ],
      ),
    );
  }

  Widget _sectionHeader(AppColors colors, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: colors.textSecondary),
    ),
  );

  /// 底部 Tab 栏：新建（稿子里的 +，暂不支持自定义表情，置灰）、表情、收藏、GIF、退格
  Widget _buildBottomBar(BuildContext context) {
    final colors = context.appColors;
    final tabs = <(EmojiTab, IconData, String)>[
      (EmojiTab.emoji, Icons.emoji_emotions_outlined, '表情'),
      (EmojiTab.favorite, Icons.favorite_border, '收藏'),
      (EmojiTab.gif, Icons.gif, 'GIF'),
    ];
    Widget tabButton((EmojiTab, IconData, String) t) {
      final selected = _activeTab == t.$1;
      return Tooltip(
        message: t.$3,
        child: Semantics(
          label: t.$3,
          button: true,
          selected: selected,
          child: InkResponse(
            onTap: () => setState(() => _activeTab = t.$1),
            radius: 22,
            child: Container(
              width: 40,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? colors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                t.$2,
                size: 22,
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: null,
            tooltip: '添加表情（暂不支持自定义表情）',
            icon: Icon(Icons.add, size: 24, color: colors.textSecondary),
          ),
          const SizedBox(width: 4),
          for (final t in tabs) ...[tabButton(t), const SizedBox(width: 6)],
          const Spacer(),
          if (widget.onBackspace != null)
            Tooltip(
              message: '删除',
              child: Semantics(
                label: '删除',
                button: true,
                child: InkResponse(
                  onTap: widget.onBackspace,
                  radius: 22,
                  child: Container(
                    width: 44,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.attachmentBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.backspace_outlined,
                      size: 20,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '表情面板（默认表情页）', group: 'EmojiPanel')
Widget emojiPanelPreview() {
  return const Padding(
    padding: EdgeInsets.all(16),
    child: EmojiPanel(onEmojiSelected: _noopString),
  );
}

void _noopString(String value) {}
