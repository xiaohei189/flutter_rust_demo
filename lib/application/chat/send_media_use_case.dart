/// 媒体消息发送编排：校验发送目标、执行发送、失败写错误。
class SendMediaUseCase {
  const SendMediaUseCase();

  Future<bool> send<T>({
    required T? Function() readTarget,
    required Future<bool> Function(T target) run,
    required String? Function() readError,
    required void Function(String message) onError,
  }) async {
    final target = readTarget();
    if (target == null) {
      onError('会话信息异常');
      return false;
    }
    final ok = await run(target);
    if (!ok) {
      onError(readError() ?? '发送失败');
    }
    return ok;
  }
}
