import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 미래지향적 스플래시 스크린
/// 
/// 앱 초기화 중 표시되는 로딩 화면
/// - 시스템 다크모드 자동 감지 및 적용
/// - 미래지향적 애니메이션 효과
/// - 그라디언트 배경 + 파티클 효과
/// - 펄스 애니메이션 + 회전 효과
/// - 부드러운 Fade Out 전환
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFadeOutStart;
  
  const SplashScreen({super.key, this.onFadeOutStart});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _fadeInController;
  late AnimationController _fadeOutController;
  late AnimationController _particleController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();
    
    // 펄스 애니메이션 (아이콘 크기 변화)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // 회전 애니메이션 (로딩 링)
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      _rotationController,
    );
    
    // 페이드 인 애니메이션 (시작 시)
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeInController, curve: Curves.easeIn),
    );
    
    // 페이드 아웃 애니메이션 (종료 시)
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeOut),
    );
    
    // 파티클 애니메이션
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();
    
    _fadeInController.forward();
  }
  
  /// Fade Out 시작 (외부에서 호출 가능)
  Future<void> startFadeOut() async {
    widget.onFadeOutStart?.call();
    await _fadeOutController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _fadeInController.dispose();
    _fadeOutController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 다크모드에 따른 그라디언트 색상
    final gradientColors = isDark
        ? [
            const Color(0xFF0D47A1), // 다크 블루
            const Color(0xFF1565C0), // 미드 블루
            const Color(0xFF1976D2), // 라이트 블루
          ]
        : [
            const Color(0xFF1976D2), // 라이트 블루
            const Color(0xFF2196F3), // 브라이트 블루
            const Color(0xFF42A5F5), // 스카이 블루
          ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            // 배경 파티클 효과 (반응형)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ParticlePainter(
                      animation: _particleController.value,
                      isDark: isDark,
                    ),
                  );
                },
              ),
            ),
            
            // 메인 컨텐츠
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 반응형 크기 계산
                  final screenWidth = constraints.maxWidth;
                  final screenHeight = constraints.maxHeight;
                  final iconSize = (screenWidth * 0.3).clamp(100.0, 140.0);
                  final ringSize = iconSize * 1.33;
                  
                  return Center(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_fadeInAnimation, _fadeOutAnimation]),
                      builder: (context, child) {
                        // Fade In 후 Fade Out 적용
                        final opacity = _fadeInAnimation.value * _fadeOutAnimation.value;
                        return Opacity(
                          opacity: opacity,
                          child: child,
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 앱 아이콘 + 펄스 효과
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 외부 회전 링
                                    AnimatedBuilder(
                                      animation: _rotationAnimation,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle: _rotationAnimation.value,
                                          child: Container(
                                            width: ringSize,
                                            height: ringSize,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.3),
                                                width: 2,
                                              ),
                                            ),
                                            child: CustomPaint(
                                              painter: ArcPainter(
                                                color: Colors.white,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    
                                    // 앱 아이콘
                                    Container(
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(iconSize * 0.23),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withOpacity(0.5)
                                            : Colors.black.withOpacity(0.3),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                        offset: const Offset(0, 10),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.1),
                                        blurRadius: 20,
                                        spreadRadius: -5,
                                        offset: const Offset(0, -5),
                                      ),
                                    ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(iconSize * 0.23),
                                        child: Image.asset(
                                          'assets/icons/app_icon.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            // 이미지 로드 실패 시 대체 아이콘 표시
                                            return Container(
                                              color: Colors.white,
                                              child: Icon(
                                                Icons.phone_enabled,
                                                size: iconSize * 0.6,
                                                color: const Color(0xFF2196F3),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          SizedBox(height: screenHeight * 0.06),
                          
                          // 앱 이름 (글로우 효과)
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withOpacity(0.8),
                                Colors.white,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: Text(
                              'MAKECALL',
                              style: TextStyle(
                                fontSize: (screenWidth * 0.09).clamp(28.0, 40.0),
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Colors.white,
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * 0.015),
                          
                          // 부제목
                          Text(
                            '당신의 더 나은 커뮤니케이션',
                            style: TextStyle(
                              fontSize: (screenWidth * 0.038).clamp(13.0, 16.0),
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * 0.08),
                          
                          // 미래지향적 로딩 인디케이터
                          SizedBox(
                            width: (screenWidth * 0.15).clamp(50.0, 70.0),
                            height: (screenWidth * 0.15).clamp(50.0, 70.0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 외부 회전 링
                                AnimatedBuilder(
                                  animation: _rotationController,
                                  builder: (context, child) {
                                    final loadingSize = (screenWidth * 0.15).clamp(50.0, 70.0);
                                    return Transform.rotate(
                                      angle: _rotationAnimation.value,
                                      child: SizedBox(
                                        width: loadingSize,
                                        height: loadingSize,
                                        child: CustomPaint(
                                          painter: LoadingRingPainter(
                                            color: Colors.white,
                                            isDark: isDark,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                // 내부 펄스 점
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final dotSize = (screenWidth * 0.03).clamp(10.0, 14.0);
                                    return Container(
                                      width: dotSize * _pulseAnimation.value,
                                      height: dotSize * _pulseAnimation.value,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(0.5),
                                            blurRadius: 10 * _pulseAnimation.value,
                                            spreadRadius: 2 * _pulseAnimation.value,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: screenHeight * 0.03),
                          
                          // 로딩 메시지
                          Text(
                            '초기화 중...',
                            style: TextStyle(
                              fontSize: (screenWidth * 0.038).clamp(13.0, 16.0),
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 회전하는 아크 페인터 (앱 아이콘 주변)
class ArcPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  ArcPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.6 : 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 3개의 아크 그리기
    for (int i = 0; i < 3; i++) {
      final startAngle = (i * 2 * math.pi / 3);
      final sweepAngle = math.pi / 3;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 로딩 링 페인터
class LoadingRingPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  LoadingRingPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(isDark ? 0.7 : 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 2개의 아크 그리기 (로딩 효과)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 배경 파티클 효과 페인터
class ParticlePainter extends CustomPainter {
  final double animation;
  final bool isDark;

  ParticlePainter({required this.animation, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(isDark ? 0.1 : 0.15)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // 고정 시드로 일관된 파티클 위치

    // 20개의 파티클 그리기
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      
      // 파티클이 위로 올라가는 애니메이션
      final y = (baseY + (animation * size.height * 0.5)) % size.height;
      
      final particleSize = 2 + random.nextDouble() * 3;
      
      // 파티클 페이드 효과
      final opacity = (1 - (y / size.height)) * (isDark ? 0.3 : 0.4);
      paint.color = Colors.white.withOpacity(opacity);
      
      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return animation != oldDelegate.animation;
  }
}
