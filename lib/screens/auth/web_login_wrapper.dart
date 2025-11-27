import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:url_launcher/url_launcher.dart';

/// 웹 전용 로그인 래퍼 - 모바일 폰 프레임과 소개 섹션
class WebLoginWrapper extends StatelessWidget {
  final Widget child;

  const WebLoginWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 모바일 화면: 기존 LoginScreen 그대로
    if (screenWidth < 768) {
      return child;
    }

    // 데스크톱/태블릿: 3단 레이아웃
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A0E27),
                    const Color(0xFF1A1F3A),
                    const Color(0xFF0A0E27),
                  ]
                : [
                    const Color(0xFFE3F2FD),
                    const Color(0xFFBBDEFB),
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: Column(
          children: [
            // 메인 컨텐츠
            Expanded(
              child: Row(
                children: [
                  // 왼쪽 소개 섹션
                  if (screenWidth >= 1024)
                    Expanded(
                      child: _LeftIntroSection(isDark: isDark),
                    ),

                  // 중앙 폰 프레임
                  Center(
                    child: _PhoneFrame(
                      isDark: isDark,
                      child: child,
                    ),
                  ),

                  // 오른쪽 기능 섹션
                  if (screenWidth >= 1024)
                    Expanded(
                      child: _RightFeaturesSection(isDark: isDark),
                    ),
                ],
              ),
            ),
            
            // 푸터
            _FooterSection(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

/// 왼쪽 소개 섹션
class _LeftIntroSection extends StatelessWidget {
  final bool isDark;

  const _LeftIntroSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 앱 로고와 글로우 효과
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: isDark ? 0.5 : 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/app_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 앱 이름 - 네온 효과
          Text(
            'MAKECALL',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..shader = LinearGradient(
                  colors: isDark
                      ? [Colors.blue[300]!, Colors.purple[300]!]
                      : [Colors.blue[700]!, Colors.blue[900]!],
                ).createShader(const Rect.fromLTWH(0, 0, 400, 100)),
              shadows: isDark
                  ? [
                      Shadow(
                        color: Colors.blue.withValues(alpha: 0.5),
                        blurRadius: 20,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // 짧은 설명
          Text(
            '모바일로 스마트한 통화 확장',
            style: TextStyle(
              fontSize: 22,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 48),

          // 주요 특징
          _buildFeature(
            icon: Icons.phone_forwarded,
            title: '원터치 발신',
            description: '콜서버 기반 즉시 발신',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildFeature(
            icon: Icons.swap_calls,
            title: '스마트 착신전환',
            description: '언제 어디서나 번호 관리 및 모바일 앱/웹  수신알림',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildFeature(
            icon: Icons.history,
            title: '통화 녹음 청취',
            description: '콜 서버의 통화 녹음 청취',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.blue[900]!.withValues(alpha: 0.3)
                : Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isDark ? Colors.blue[300] : Colors.blue[700],
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 오른쪽 기능 섹션
class _RightFeaturesSection extends StatelessWidget {
  final bool isDark;

  const _RightFeaturesSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildInfoCard(
            icon: Icons.devices,
            title: '다양한 플랫폼 및 동시 사용 지원',
            description: '모바일, 웹, 데스크톱 어디서나\n한 사용자가 여러 기기 동시 사용 가능',
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.blue[700]!, Colors.blue[900]!]
                  : [Colors.blue[400]!, Colors.blue[600]!],
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            icon: Icons.grid_view,
            title: '빠른 발신 - 그리드뷰 전체화면',
            description: '다수의 전화번호를 한눈에\n전체화면으로 효율적 발신',
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.purple[700]!, Colors.purple[900]!]
                  : [Colors.purple[400]!, Colors.purple[600]!],
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildInfoCard(
            icon: Icons.home_work,
            title: '재택근무·이동근무로 업무 효율성 증가',
            description: '어디서나 업무 가능\n유연한 근무 환경 지원',
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.teal[700]!, Colors.teal[900]!]
                  : [Colors.teal[400]!, Colors.teal[600]!],
            ),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required LinearGradient gradient,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.colors[0].withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 폰 프레임 - 3D 효과와 글로우
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _PhoneFrame({
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      height: 980,
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          // 외부 글로우 효과
          BoxShadow(
            color: isDark
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.blue.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 10,
          ),
          // 그림자
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 폰 외곽 (메탈 프레임)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.grey[900]!,
                        Colors.grey[800]!,
                        Colors.grey[900]!,
                      ]
                    : [
                        Colors.grey[300]!,
                        Colors.grey[200]!,
                        Colors.grey[300]!,
                      ],
              ),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(38),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: child,
              ),
            ),
          ),

          // 상단 노치/다이나믹 아일랜드 효과
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 150,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[700]!,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // 카메라 렌즈
          Positioned(
            top: 22,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 푸터 섹션
class _FooterSection extends StatelessWidget {
  final bool isDark;

  const _FooterSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 스토어 아이콘 섹션
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google Play Store Badge
              _buildStoreIcon(
                imagePath: 'assets/images/stores/google_play.png',
                label: 'Google Play',
                url: '', // TODO: Google Play Store URL 추가
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              // Apple App Store Badge
              _buildStoreIcon(
                imagePath: 'assets/images/stores/app_store.png',
                label: 'App Store',
                url: 'https://apps.apple.com/kr/app/makecall/id6475055702',
                isDark: isDark,
              ),
            ],
          ),
        ),
        
        // 푸터 링크 섹션
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.3),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 0,
            runSpacing: 8,
            children: [
              _buildFooterLink(
                text: '개인정보 처리방침',
                url: 'https://app.makecall.io/privacy_policy.html',
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildFooterLink(
                text: '서비스 이용 약관',
                url: 'https://app.makecall.io/terms_of_service.html',
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildFooterLink(
                text: '주식회사 얼쑤팩토리',
                url: 'https://olssoo.com',
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildFooterLink(
                text: 'MAKECALL',
                url: 'https://makecall.io',
                isDark: isDark,
              ),
              _buildDivider(isDark),
              _buildFooterText(
                text: '고객센터: 1668-2471',
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreIcon({
    required String imagePath,
    required String label,
    required String url,
    required bool isDark,
  }) {
    final bool hasUrl = url.isNotEmpty;
    
    return MouseRegion(
      cursor: hasUrl ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: hasUrl
            ? () async {
                try {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('Failed to open URL: $url');
                  }
                }
              }
            : null,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[900]!.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Image.asset(
            imagePath,
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink({
    required String text,
    required String url,
    required bool isDark,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          // URL 링크 열기
          try {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to open URL: $url');
            }
          }
        },
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '|',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildFooterText({
    required String text,
    required bool isDark,
  }) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
