import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// CORS 문제를 우아하게 처리하는 안전한 CircleAvatar
/// 
/// Firebase Storage 이미지가 CORS 에러로 로드 실패 시 자동으로 기본 아이콘을 표시합니다.
class SafeCircleAvatar extends StatefulWidget {
  final double radius;
  final String? imageUrl;
  final Color? backgroundColor;
  final Widget? child;

  const SafeCircleAvatar({
    super.key,
    required this.radius,
    this.imageUrl,
    this.backgroundColor,
    this.child,
  });

  @override
  State<SafeCircleAvatar> createState() => _SafeCircleAvatarState();
}

class _SafeCircleAvatarState extends State<SafeCircleAvatar> {
  bool _imageLoadFailed = false;

  @override
  void didUpdateWidget(SafeCircleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // URL이 변경되면 에러 상태 리셋
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageLoadFailed = false;
    }
  }

  Widget _buildFallbackAvatar() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? Colors.grey[300],
      child: widget.child ?? Icon(
        Icons.person,
        size: widget.radius * 0.8,
        color: Colors.grey[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 이미지 URL이 없거나 로드 실패한 경우
    if (widget.imageUrl == null || _imageLoadFailed) {
      return _buildFallbackAvatar();
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? Colors.transparent,
      child: ClipOval(
        child: Image.network(
          widget.imageUrl!,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              debugPrint('⚠️ CircleAvatar 이미지 로드 실패 (CORS): ${widget.imageUrl}');
              debugPrint('   에러: $error');
            }
            // 에러 발생 시 상태 업데이트하여 기본 아이콘 표시
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_imageLoadFailed) {
                setState(() {
                  _imageLoadFailed = true;
                });
              }
            });
            // 즉시 기본 아이콘 표시
            return Icon(
              Icons.person,
              size: widget.radius * 0.8,
              color: Colors.grey[600],
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: widget.radius * 0.6,
                height: widget.radius * 0.6,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
