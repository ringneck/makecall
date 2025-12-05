import 'package:flutter/material.dart';

/// 심플한 스플래시 스크린
/// 
/// 앱 초기화 중 표시되는 로딩 화면
/// - 시스템 다크모드 자동 감지 및 적용
/// - 반응형 디자인
/// - 애니메이션 없음 (성능 최적화)
class SplashScreen extends StatefulWidget {
  final VoidCallback? onFadeOutStart;
  
  const SplashScreen({super.key, this.onFadeOutStart});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  
  /// Fade Out 시작 (외부에서 호출 가능)
  Future<void> startFadeOut() async {
    widget.onFadeOutStart?.call();
    // 애니메이션 없이 즉시 완료
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
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 반응형 크기 계산
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;
              final iconSize = (screenWidth * 0.3).clamp(100.0, 140.0);
              
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                                ? Colors.black.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1),
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
                    
                    SizedBox(height: screenHeight * 0.06),
                    
                    // 앱 이름
                    Text(
                      'MAKECALL',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.09).clamp(28.0, 40.0),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.015),
                    
                    // 부제목
                    Text(
                      '당신의 더 나은 커뮤니케이션',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.038).clamp(13.0, 16.0),
                        color: Colors.white.withValues(alpha: 0.95),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.08),
                    
                    // 로딩 인디케이터 (정적)
                    SizedBox(
                      width: (screenWidth * 0.15).clamp(50.0, 70.0),
                      height: (screenWidth * 0.15).clamp(50.0, 70.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.03),
                    
                    // 로딩 메시지
                    Text(
                      '초기화 중...',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.038).clamp(13.0, 16.0),
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
