// 用于 Android/iOS/桌面：Android 模拟器访问宿主机需用 10.0.2.2
import 'dart:io';

String getHostAddress() => Platform.isAndroid ? '10.0.2.2' : 'localhost';
