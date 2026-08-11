/// 将 sendTime 规范化为毫秒（自动检测秒/毫秒）
int normalizeMessageSendTime(int t) {
  if (t <= 0) return DateTime.now().millisecondsSinceEpoch;
  if (t < 946684800000) return t * 1000;
  return t;
}
