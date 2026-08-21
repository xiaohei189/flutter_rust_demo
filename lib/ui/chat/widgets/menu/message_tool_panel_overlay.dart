import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../domain/models/chat_message.dart' show ChatMessage;
import 'message_action_menu.dart' show MessageActions;
import 'message_tool_panel.dart';

class MessageToolPanelOverlay extends StatelessWidget {
  const MessageToolPanelOverlay({
    super.key,
    required this.anchor,
    required this.message,
    required this.currentUserId,
    required this.actions,
    required this.reactions,
    required this.rootContext,
    required this.onClose,
  });

  final Rect anchor;
  final ChatMessage message;
  final String currentUserId;
  final MessageActions actions;
  final Set<String> reactions;
  final BuildContext rootContext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
          ),
        ),
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: MessageToolPanelLayoutDelegate(anchor: anchor),
            child: MessageToolPanel(
              message: message,
              currentUserId: currentUserId,
              actions: actions,
              reactions: reactions,
              rootContext: rootContext,
              onClose: onClose,
            ),
          ),
        ),
      ],
    );
  }
}

class MessageToolPanelLayoutDelegate extends SingleChildLayoutDelegate {
  const MessageToolPanelLayoutDelegate({required this.anchor});

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = math.min(360.0, math.max(0.0, constraints.maxWidth - 24));
    return BoxConstraints(
      maxWidth: maxWidth,
      maxHeight: math.max(0.0, constraints.maxHeight - 24),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - childSize.width - 12;
    final left = maxLeft < 12
        ? 12.0
        : ((anchor.left + anchor.right - childSize.width) / 2)
              .clamp(12.0, maxLeft)
              .toDouble();
    final above = anchor.top - childSize.height - 8;
    final below = anchor.bottom + 8;
    final top = above < 8 || below + childSize.height > size.height
        ? math.max(8.0, above)
        : below;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant MessageToolPanelLayoutDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}
