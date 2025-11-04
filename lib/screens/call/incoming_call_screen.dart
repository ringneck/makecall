import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';

/// 수신 전화 풀스크린 (미래지향적 디자인 + 고급 애니메이션)
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerNumber;
  final String? callerAvatar;
  final Uint8List? contactPhoto;
  final String channel;
  final String linkedid;
  final String receiverNumber;
  final String? myCompanyName;
  final String? myOutboundCid;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerNumber,
    this.callerAvatar,
    this.contactPhoto,
    required this.channel,
    required this.linkedid,
    required this.receiverNumber,
    this.myCompanyName,
    this.myOutboundCid,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 🌊 파동 애니메이션 (연속 반복)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // ✨ 글로우 애니메이션 (펄스 효과)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // 🎭 페이드 인 애니메이션
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // 🔍 스케일 애니메이션
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    // 시작 애니메이션 실행
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// 전화 수락 애니메이션
  Future<void> _acceptCall() async {
    await _scaleController.reverse();
    widget.onAccept();
  }

  /// 전화 거절 애니메이션
  Future<void> _rejectCall() async {
    await _fadeController.reverse();
    widget.onReject();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: _buildGradientBackground(),
          child: SafeArea(
            child: Stack(
              children: [
                // 🌊 배경 파동 효과 (3개 레이어)
                _buildRippleEffect(),

                // 📱 메인 콘텐츠
                Column(
                  children: [
                    const SizedBox(height: 40),

                    // 🏢 내 단말번호 정보 (상단)
                    _buildMyExtensionInfo(),

                    const SizedBox(height: 30),

                    // 📞 "수신 전화" 텍스트
                    _buildHeaderText(),

                    const Spacer(flex: 2),

                    // 👤 발신자 정보 (아바타 + 이름 + 번호)
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildCallerInfo(),
                    ),

                    const Spacer(flex: 3),

                    // ✅ 확인 버튼 (아이콘+레이블)
                    _buildConfirmButtonWithIcon(),

                    const SizedBox(height: 80),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🎨 동적 그라데이션 배경
  BoxDecoration _buildGradientBackground() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF0F2027), // 다크 블루
          const Color(0xFF203A43), // 미디엄 블루
          const Color(0xFF2C5364), // 라이트 블루
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }

  /// 🌊 파동 효과 (3개 레이어)
  Widget _buildRippleEffect() {
    return Positioned.fill(
      child: Center(
        child: AnimatedBuilder(
          animation: _rippleController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildRippleLayer(0.0, 0.3, 1.0),
                _buildRippleLayer(0.33, 0.25, 0.7),
                _buildRippleLayer(0.66, 0.20, 0.4),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 단일 파동 레이어
  Widget _buildRippleLayer(double delay, double baseOpacity, double maxScale) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = 1.0 + (animation.value * maxScale);
        final opacity = baseOpacity * (1.0 - animation.value);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🏢 내 단말번호 정보 (상단)
  Widget _buildMyExtensionInfo() {
    // companyName과 myOutboundCid가 모두 없으면 표시하지 않음
    if ((widget.myCompanyName == null || widget.myCompanyName!.isEmpty) &&
        (widget.myOutboundCid == null || widget.myOutboundCid!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 조직명 (첫 번째 줄)
          if (widget.myCompanyName != null && widget.myCompanyName!.isNotEmpty)
            Text(
              widget.myCompanyName!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          
          // 간격 (조직명이 있을 때만)
          if (widget.myCompanyName != null && 
              widget.myCompanyName!.isNotEmpty &&
              widget.myOutboundCid != null &&
              widget.myOutboundCid!.isNotEmpty)
            const SizedBox(height: 6),
          
          // 외부발신 표시번호 (두 번째 줄)
          if (widget.myOutboundCid != null && widget.myOutboundCid!.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_forwarded,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.myOutboundCid!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 📞 헤더 텍스트
  Widget _buildHeaderText() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '수신 전화',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 👤 발신자 정보
  Widget _buildCallerInfo() {
    return Column(
      children: [
        // 👤 아바타 (글로우 효과)
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3 * _glowController.value),
                    blurRadius: 40 * _glowController.value,
                    spreadRadius: 10 * _glowController.value,
                  ),
                ],
              ),
              child: _buildAvatar(),
            );
          },
        ),

        const SizedBox(height: 40),

        // 📝 발신자 이름
        Text(
          widget.callerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // 📞 전화번호
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.callerNumber,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  /// 👤 아바타 위젯
  Widget _buildAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: widget.contactPhoto == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade400,
                  Colors.purple.shade400,
                ],
              )
            : null,
        color: widget.contactPhoto != null ? Colors.white : null,
        border: Border.all(
          color: Colors.white,
          width: 4,
        ),
      ),
      child: ClipOval(
        child: _buildAvatarContent(),
      ),
    );
  }

  /// 아바타 콘텐츠 (우선순위: 연락처 사진 > callerAvatar > app_logo)
  Widget _buildAvatarContent() {
    // 1순위: 연락처 사진
    if (widget.contactPhoto != null) {
      return Image.memory(
        widget.contactPhoto!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAppLogo(),
      );
    }
    
    // 2순위: callerAvatar (URL)
    if (widget.callerAvatar != null && widget.callerAvatar!.isNotEmpty) {
      return Image.network(
        widget.callerAvatar!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAppLogo(),
      );
    }
    
    // 3순위: app_logo (기본 이미지)
    return _buildAppLogo();
  }

  /// 기본 app_logo 아이콘
  Widget _buildAppLogo() {
    return Image.asset(
      'assets/icons/app_icon.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
    );
  }

  /// 최후 대안: 이니셜 아바타
  Widget _buildDefaultAvatar() {
    final initial = widget.callerName.isNotEmpty
        ? widget.callerName[0].toUpperCase()
        : '?';

    return Container(
      color: Colors.blue.shade400,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// ✅ 확인 버튼 (아이콘+레이블)
  Widget _buildConfirmButtonWithIcon() {
    return Center(
      child: GestureDetector(
        onTap: () {
          // TODO: 확인 버튼 동작 정의 (현재는 화면 닫기)
          Navigator.of(context).pop();
        },
        child: Column(
          children: [
            // 버튼 (글로우 효과)
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5 * _glowController.value),
                        blurRadius: 30 * _glowController.value,
                        spreadRadius: 5 * _glowController.value,
                      ),
                    ],
                  ),
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade600,
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // 레이블
            Text(
              '확인',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 수락/거절 버튼 (기존 아이콘 버전 - 유지)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ❌ 거절 버튼
          _buildActionButton(
            icon: Icons.call_end_rounded,
            color: Colors.red,
            label: '거절',
            onTap: _rejectCall,
          ),

          // ✅ 수락 버튼
          _buildActionButton(
            icon: Icons.call_rounded,
            color: Colors.green,
            label: '수락',
            onTap: _acceptCall,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  /// 단일 액션 버튼
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // 버튼 (글로우 효과)
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isPrimary
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5 * _glowController.value),
                            blurRadius: 30 * _glowController.value,
                            spreadRadius: 5 * _glowController.value,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withOpacity(0.8),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 레이블
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
