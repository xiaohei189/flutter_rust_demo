import 'package:flutter/material.dart';

/// 聊天输入框组件
class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSend;

  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 语音按钮
            IconButton(
              icon: const Icon(Icons.mic_none),
              onPressed: () {
                // TODO: 语音输入
              },
            ),
            
            // 文本输入框
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (text) {
                  onSend(text);
                },
              ),
            ),
            
            // 更多功能按钮
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                _showMoreOptions(context);
              },
            ),
            
            // 发送按钮
            IconButton(
              icon: const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
              onPressed: () {
                onSend(controller.text);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          children: [
            _buildOptionItem(Icons.photo, '相册', () {}),
            _buildOptionItem(Icons.camera_alt, '拍照', () {}),
            _buildOptionItem(Icons.videocam, '视频', () {}),
            _buildOptionItem(Icons.insert_drive_file, '文件', () {}),
            _buildOptionItem(Icons.location_on, '位置', () {}),
            _buildOptionItem(Icons.contact_page, '名片', () {}),
            _buildOptionItem(Icons.calendar_today, '日程', () {}),
            _buildOptionItem(Icons.payment, '转账', () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}



