import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'emoji_store.dart';

/// 表情面板 Tab
enum EmojiTab { recent, emoji, favorite, gif }

/// 表情面板：最近使用（真实记录）+ 默认表情 + 收藏 + GIF，底部 Tab 全部可用。
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.onEmojiSelected,
    required this.onClose,
    this.onGifSelected,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onClose;
  final ValueChanged<String>? onGifSelected;

  /// 默认表情列表（Unicode Emoji）
  static const List<String> defaultEmojis = [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
    '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
    '🥲', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫',
    '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬',
    '😮', '😯', '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥',
    '😢', '😭', '😱', '😖', '😣', '😞', '😓', '😩', '😫', '🥱',
    '😤', '😡', '😠', '🤬', '👍', '👎', '👏', '🙏', '💪', '❤️',
    '🔥', '⭐', '🎉', '🎊', '💯', '✅', '❌', '⚡', '🌟', '💫',
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
  EmojiTab _activeTab = EmojiTab.recent;
  List<String> _recent = const [];
  List<String> _favorites = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recent = await EmojiStore.loadRecent();
    final favorites = await EmojiStore.loadFavorites();
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
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _buildContent(context)),
          const Divider(height: 1),
          _buildTabBar(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_activeTab) {
      case EmojiTab.recent:
        final emojis = _recent.isNotEmpty ? _recent : EmojiPanel.defaultEmojis;
        return _buildEmojiGrid(
          context,
          emojis,
          header: _recent.isEmpty ? '默认表情（使用后会出现在这里）' : '最近使用',
        );
      case EmojiTab.emoji:
        return _buildEmojiGrid(context, EmojiPanel.defaultEmojis);
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
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) {
                final emoji = emojis[i];
                return GestureDetector(
                  onTap: () => _handleEmojiTap(emoji),
                  onLongPress: () => _handleEmojiLongPress(emoji),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                );
              },
            ),
        ],
      ),
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

  Widget _buildTabBar(BuildContext context) {
    final colors = context.appColors;
    final tabs = <(EmojiTab, IconData, String)>[
      (EmojiTab.recent, Icons.history, '最近'),
      (EmojiTab.emoji, Icons.emoji_emotions_outlined, '表情'),
      (EmojiTab.favorite, Icons.favorite_border, '收藏'),
      (EmojiTab.gif, Icons.gif, 'GIF'),
    ];
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ...tabs.map(
            (t) => IconButton(
              icon: Icon(
                t.$2,
                size: 20,
                color: _activeTab == t.$1
                    ? colors.primary
                    : colors.textSecondary,
              ),
              tooltip: t.$3,
              onPressed: () => setState(() => _activeTab = t.$1),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          IconButton(
            icon: Icon(Icons.keyboard, size: 20, color: colors.textSecondary),
            tooltip: '键盘',
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
