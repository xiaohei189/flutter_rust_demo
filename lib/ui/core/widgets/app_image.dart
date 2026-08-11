import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 统一图片组件：支持网络/本地文件/asset，带加载占位、失败占位和 cacheWidth。
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.errorWidget,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double? cacheWidth;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return _fallback(context);
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: source,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth?.round(),
        placeholder: (_, _) => _loading(context),
        errorWidget: (_, _, _) => _fallback(context),
      );
    }

    final file = File(source);
    if (file.existsSync()) {
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth?.round(),
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }

    return Image.asset(
      source,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth?.round(),
      errorBuilder: (_, _, _) => _fallback(context),
    );
  }

  Widget _loading(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: width,
      height: height,
      color: colors.surfaceMuted,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final colors = context.appColors;
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: colors.surfaceMuted,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image, color: colors.textSecondary),
        );
  }
}
