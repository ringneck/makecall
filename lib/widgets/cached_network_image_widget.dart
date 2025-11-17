import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 웹 플랫폼에서 안전하게 네트워크 이미지를 표시하는 위젯
/// 
/// Firebase Storage 이미지 로드 시 CORS 에러를 우아하게 처리합니다.
class CachedNetworkImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final double? width;
  final double? height;

  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.width,
    this.height,
  });

  Widget _buildDefaultError(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: width == height ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Icon(
        Icons.person,
        color: Colors.grey[600],
        size: width != null ? width! * 0.6 : 40,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder ?? (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint('⚠️ 이미지 로드 실패: $imageUrl');
          debugPrint('   에러: $error');
        }
        return _buildDefaultError(context);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: width == height ? BoxShape.circle : BoxShape.rectangle,
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// CircleAvatar 등에서 사용할 수 있는 안전한 NetworkImage 래퍼
/// 
/// 기본 NetworkImage를 그대로 사용하되, 에러 처리를 개선합니다.
class SafeNetworkImage extends ImageProvider<NetworkImage> {
  final String url;
  final double scale;

  const SafeNetworkImage(this.url, {this.scale = 1.0});

  @override
  Future<NetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NetworkImage>(NetworkImage(url, scale: scale));
  }

  @override
  ImageStreamCompleter loadImage(NetworkImage key, ImageDecoderCallback decode) {
    return key.loadImage(key, decode);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is SafeNetworkImage && other.url == url && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => 'SafeNetworkImage("$url", scale: $scale)';
}
