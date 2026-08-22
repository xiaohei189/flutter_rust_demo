import 'package:flutter/material.dart';

/// 单条左滑操作（右侧起排列）。
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.width = 72,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double width;
  final VoidCallback onPressed;
}

/// 可左滑露出操作按钮的容器（仿钉钉/飞书）。
///
/// - 左滑露出右侧操作按钮，超过阈值自动展开；
/// - 展开时点击内容区收起，点击操作按钮直接执行；
/// - 不拦截列表纵向滚动。
class SwipeActionItem extends StatefulWidget {
  const SwipeActionItem({
    super.key,
    required this.actions,
    required this.child,
  });

  final List<SwipeAction> actions;
  final Widget child;

  @override
  State<SwipeActionItem> createState() => _SwipeActionItemState();
}

class _SwipeActionItemState extends State<SwipeActionItem> {
  double _offset = 0;
  bool _open = false;

  double get _actionsWidth =>
      widget.actions.fold(0.0, (sum, a) => sum + a.width);

  void _close() {
    if (!_open) return;
    setState(() {
      _open = false;
      _offset = 0;
    });
  }

  void _runAction(SwipeAction action) {
    setState(() {
      _open = false;
      _offset = 0;
    });
    action.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        // 已展开时允许继续右滑收起；未展开时只响应左滑。
        if (!_open && details.delta.dx > 0) return;
        setState(() {
          _offset = (_offset + details.delta.dx).clamp(-_actionsWidth, 0.0);
        });
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          if (_offset < -_actionsWidth * 0.35) {
            _open = true;
            _offset = -_actionsWidth;
          } else {
            _open = false;
            _offset = 0;
          }
        });
      },
      child: Stack(
        children: [
          // 背景操作按钮（右侧）
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in widget.actions)
                    SizedBox(
                      width: action.width,
                      height: double.infinity,
                      child: Material(
                        color: action.color,
                        child: InkWell(
                          onTap: () => _runAction(action),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (action.icon != null) ...[
                                Icon(
                                  action.icon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                action.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 前景内容
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
          // 展开时：点击内容区收起（不遮挡右侧操作按钮）
          if (_open)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: _actionsWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
              ),
            ),
        ],
      ),
    );
  }
}
