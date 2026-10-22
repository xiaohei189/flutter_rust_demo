/// 群模式：决定群内内容按什么维度组织（对齐飞书「群模式」）。
///
/// - [chat]：对话群，消息按发送先后顺序排列（默认）；
/// - [topic]：话题群，内容按话题聚合（需要服务端支持，见 docs/create-group-plan.md）。
enum GroupMode {
  chat,
  topic;

  bool get isTopic => this == GroupMode.topic;
}
