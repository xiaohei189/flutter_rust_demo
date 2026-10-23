/// 自动登录失败时，是否应该清除本地凭证。
///
/// 只有明确的 token 失效/认证失败才清；网络断开、连接被拒、超时等
/// 临时错误必须保留凭证，等服务恢复后下次启动可以直接重试。
bool shouldClearCredentialsOnAutoLoginFailure(Object error) {
  final text = error.toString().toLowerCase();

  const networkHints = <String>[
    'connection refused',
    'websocket connect failed',
    'io error',
    'socketexception',
    'socket',
    'timeout',
    'timed out',
    '超时',
    '连接错误',
    '连接失败',
    '网络',
    'network',
  ];
  if (networkHints.any(text.contains)) return false;

  const authHints = <String>[
    '401',
    'unauthorized',
    'invalid token',
    'token expired',
    'token is expired',
    'token 无效',
    'token无效',
    '认证失败',
    '登录已过期',
  ];
  return authHints.any(text.contains);
}
