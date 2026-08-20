/// 会话类型领域枚举（UI/应用层使用，FFI 层在 Repository 边界转换）
enum ChatSessionType {
  singleChat,
  writeGroupChat,
  readGroupChat,
  notificationChat,
}