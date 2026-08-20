import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

const List<String> kMessageQuickReplyEmojis = [
  '😀', '😄', '😂', '🤣', '👍', '❤️', '🎉', '😮',
  '😢', '🙏', '😘', '🤝', '💪', '👏', '🥳', '😅',
];

class QuickReplyPanel extends StatefulWidget {
  const QuickReplyPanel({
    super.key,
    required this.onQuickReply,
    required this.onBack,
  });

  final ValueChanged<String> onQuickReply;
  final VoidCallback onBack;

  @override
  State<QuickReplyPanel> createState() => _QuickReplyPanelState();
}

class _QuickReplyPanelState extends State<QuickReplyPanel> {
  static const int _pageSize = 12;
  final PageController _pageController = PageController();
  int _page = 0;

  int get _pageCount =>
      (kMessageQuickReplyEmojis.length / _pageSize).ceil();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '返回工具面板',
              onPressed: widget.onBack,
            ),
            Expanded(
              child: Text(
                '快速回复',
                style: TextStyle(fontSize: 15, color: colors.textPrimary),
              ),
            ),
          ],
        ),
        Divider(height: 1, color: colors.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SizedBox(
            height: 100,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, page) {
                final start = page * _pageSize;
                final end = math.min(start + _pageSize, kMessageQuickReplyEmojis.length);
                return GridView.count(
                  crossAxisCount: 6,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.1,
                  children: kMessageQuickReplyEmojis
                      .sublist(start, end)
                      .map(
                        (emoji) => _QuickReplyEmoji(
                          emoji: emoji,
                          onTap: () => widget.onQuickReply(emoji),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pageCount, (index) {
            final selected = index == _page;
            return GestureDetector(
              key: ValueKey('quick_reply_dot_$index'),
              onTap: () => _pageController.jumpToPage(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _QuickReplyEmoji extends StatelessWidget {
  const _QuickReplyEmoji({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}