import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../previews/app_theme_preview.dart';
import '../../../core/theme/app_theme.dart';
import '../../../../data/services/emoji_store.dart';

/// 底部 Tab 栏的设计高度（可用空间不足时会按可用高度收敛）。
const double kTabBarHeight = 48;

/// 表情面板的设计高度：输入区按它（与键盘高度取较大者）给面板占位。
const double kEmojiPanelHeight = 300;

/// 表情面板 Tab
enum EmojiTab { recent, emoji, favorite, gif }

/// 表情面板：最近使用（真实记录）+ 默认表情 + 收藏 + GIF，底部 Tab 全部可用。
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.onEmojiSelected,
    this.onGifSelected,
    this.onBackspace,
    this.maxHeight = kEmojiPanelHeight,
    this.showTabBar = true,
    this.backgroundColor,
    this.scrollPhysics,
  });

  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<String>? onGifSelected;

  /// 底部退格：删除输入框光标前一个字符（对齐飞书稿的 ⌫）
  final VoidCallback? onBackspace;

  /// 面板最大高度（默认 300；放进可拖高弹层时传更大值以撑满可用空间）
  final double maxHeight;

  /// 是否显示底部 Tab 栏（表情/收藏/GIF）；长按菜单里的表情面板不显示
  final bool showTabBar;

  /// 面板底色；为空时用默认的附件面板底色
  final Color? backgroundColor;

  /// 内部滚动行为；长按弹层里在抽屉升到顶之前禁用内部滚动（拖动即升抽屉）
  final ScrollPhysics? scrollPhysics;

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
        color: widget.backgroundColor ?? colors.attachmentBackground,
      ),
      // 用 LayoutBuilder 拿到**外层真正给的**可用高度：小屏/横屏/大字体下它可能小于
      // 「正文最小高度 + Tab 栏高度」，此时把 Tab 栏也按可用高度收敛，
      // 使「正文 + Tab 栏 = 可用高度」恒成立，从结构上消除 RenderFlex 溢出。
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = constraints.maxHeight;
          final tabBarHeight = maxHeight.isFinite && maxHeight < kTabBarHeight
              ? maxHeight
              : kTabBarHeight;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 面板高度固定，切 Tab 只换内容不动高度。
              //
              // 三个 Tab 的内容高度本来不同（最常用+默认表情 / 收藏 / GIF），若让面板按内容
              // 自适应，切 Tab 时外层 AnimatedSize 就会播一段高度动画、把输入行一起顶上顶下，
              // 看着就是"底部菜单弹起来"。固定高度后切 Tab 高度不变，不需要任何高度动画。
              _buildBody(context),
              if (widget.showTabBar)
                // 底部 Tab 栏（飞书稿：左侧新建、中间表情/收藏/GIF、右侧退格）
                SizedBox(height: tabBarHeight, child: _buildBottomBar(context)),
            ],
          );
        },
      ),
    );
  }

  /// 正文容器。
  ///
  /// 两种情况都用 [Flexible]，差别只在 fit：
  /// - 有限高度（输入区 300）：`FlexFit.tight` 吃满「上限 - Tab 栏」，
  ///   于是每个 Tab 正文高度一致（切 Tab 不改变面板高度），且恰好等于上限、不会溢出；
  /// - 无限高度（长按工具面板的抽屉）：`FlexFit.loose` 按内容自适应，
  ///   同时给内部滚动视图**有界**约束，避免
  ///   "Vertical viewport was given unbounded height"。
  ///
  /// 不用「上限 - 48」这种算出来的固定高度：它与系统换算出的 Tab 栏真实高度不一定相等，
  /// 多出的部分会直接变成 RenderFlex overflow（真机上报过 74px 溢出）。
  Widget _buildBody(BuildContext context) {
    return Flexible(
      fit: widget.maxHeight.isFinite ? FlexFit.tight : FlexFit.loose,
      child: _buildContent(context),
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

  /// 单个可滚动网格（sliver），标题、分区间距都作为 sliver 放在同一个 CustomScrollView 里。
  ///
  /// 之前是 `SingleChildScrollView + Column + GridView(shrinkWrap: true)`：shrinkWrap 的网格
  /// 必须先按无限高度布局出全部子项才能算出自身高度，外层再重排一次 —— 一次切 Tab 就是
  /// 「全部表情 × 2 遍布局」。改成单层 sliver 后只有一次布局，且默认惰性构建。
  Widget _buildEmojiGrid(
    BuildContext context,
    List<String> emojis, {
    String? header,
    bool empty = false,
  }) {
    final colors = context.appColors;
    return CustomScrollView(
      physics: widget.scrollPhysics,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          sliver: SliverToBoxAdapter(
            child: header == null
                ? const SizedBox.shrink()
                : Text(
                    header,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
          ),
        ),
        if (empty && emojis.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '暂无收藏，长按表情可收藏',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) => _buildEmojiCell(emojis[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildEmojiCell(String emoji) {
    return GestureDetector(
      onTap: () => _handleEmojiTap(emoji),
      onLongPress: () => _handleEmojiLongPress(emoji),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
    );
  }

  Widget _buildGifGrid(BuildContext context) {
    return CustomScrollView(
      physics: widget.scrollPhysics,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: EmojiPanel.gifUrls.length,
            itemBuilder: (_, i) =>
                _buildGifCell(context, EmojiPanel.gifUrls[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildGifCell(BuildContext context, String url) {
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
  }

  /// 「最常使用 + 默认表情」分区（同一滚动视图，对齐飞书稿）。
  ///
  /// 两个分区合并在一个 CustomScrollView 里，避免外层再套一层滚动容器（见 [_buildEmojiGrid]）。
  Widget _buildEmojiSections(BuildContext context) {
    final colors = context.appColors;
    return CustomScrollView(
      physics: widget.scrollPhysics,
      slivers: [
        if (_recent.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            sliver: SliverToBoxAdapter(child: _sectionHeader(colors, '最常使用')),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid.builder(
              gridDelegate: _emojiGridDelegate,
              itemCount: _recent.length,
              itemBuilder: (_, i) => _buildEmojiCell(_recent[i]),
            ),
          ),
        ],
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, _recent.isEmpty ? 12 : 12, 12, 8),
          sliver: SliverToBoxAdapter(child: _sectionHeader(colors, '默认表情')),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          sliver: SliverGrid.builder(
            gridDelegate: _emojiGridDelegate,
            itemCount: EmojiPanel.defaultEmojis.length,
            itemBuilder: (_, i) => _buildEmojiCell(EmojiPanel.defaultEmojis[i]),
          ),
        ),
      ],
    );
  }

  static const SliverGridDelegateWithFixedCrossAxisCount _emojiGridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      );

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
