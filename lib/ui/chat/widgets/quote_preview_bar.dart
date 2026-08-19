import 'package:flutter/material.dart';

import '../../../domain/models/chat_message.dart' show ChatMessage;
import '../../previews/app_theme_preview.dart';
import '../../previews/fake_data.dart';
import '../../core/theme/app_theme.dart';

/// 引用消息预览栏
class QuotePreviewBar extends StatelessWidget {
  const QuotePreviewBar({
    super.key,
    required this.message,
    required this.onClose,
  });

  final ChatMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          top: BorderSide(color: colors.divider.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '引用 ${message.senderNickname}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ==================== 预览 ====================

@AppThemePreview(name: '引用预览栏', group: 'QuotePreviewBar')
Widget quotePreviewBarPreview() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: QuotePreviewBar(message: fakeQuoteMessage(), onClose: _noop),
  );
}

void _noop() {}
