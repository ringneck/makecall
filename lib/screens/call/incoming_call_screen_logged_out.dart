import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/cached_network_image_widget.dart';

/// 📞 로그아웃 전용 수신전화 화면
/// 
/// 기존 IncomingCallScreen과 완전 동일한 디자인이지만, 로그인하지 않은 사용자를 위한 버전:
/// - ✅ 동일한 UI/애니메이션 (그라데이션, 파동 효과, 글로우 효과)
/// - ❌ Firestore 리스너 없음 (실시간 업데이트 불필요)
/// - ❌ 벨소리/진동 없음 (시스템 알림에서 이미 처리)
/// - ➕ 닫기 버튼 (우측 상단 ✕)
/// - ✅ 통화 확인 버튼 (Firestore 업데이트)
class IncomingCallScreenLoggedOut extends StatefulWidget {
  final String callerName;
  final String callerNumber;
  final String? callerAvatar;
  final Uint8List? contactPhoto;
  final String channel;
  final String linkedid;
  final String receiverNumber;
  final String callType;
  final String? myExtension;
  final String? myCompanyName;
  final String? myOutboundCid;
  final String? myExternalCidName;
  final String? myExternalCidNumber;
  final bool? isCallForwardEnabled;
  final String? callForwardDestination;

  const IncomingCallScreenLoggedOut({
    super.key,
    required this.callerName,
    required this.callerNumber,
    this.callerAvatar,
    this.contactPhoto,
    required this.channel,
    required this.linkedid,
    required this.receiverNumber,
    this.callType = 'unknown',
    this.myExtension,
    this.myCompanyName,
    this.myOutboundCid,
    this.myExternalCidName,
    this.myExternalCidNumber,
    this.isCallForwardEnabled,
    this.callForwardDestination,
  });

  @override
  State<IncomingCallScreenLoggedOut> createState() => _IncomingCallScreenLoggedOutState();
}

class _IncomingCallScreenLoggedOutState extends State<IncomingCallScreenLoggedOut>
    with TickerProviderStateMixin {
  // 애니메이션 컨트롤러 (기존과 동일)
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;

  // 애니메이션
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// 🎬 애니메이션 초기화 (기존과 동일)
  void _initAnimations() {
    // 파동 효과 (3초, 무한 반복)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 글로우 효과 (2초, 무한 반복)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 페이드 인 효과 (500ms)
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // 스케일 효과 (300ms)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    // 애니메이션 시작
    _fadeController.forward();
    _scaleController.forward();
  }

  /// ✅ 통화 확인 (Firestore 업데이트)
  Future<void> _confirmCall() async {
    if (kDebugMode) {
      debugPrint('🔄 로그아웃 상태에서 통화 확인 시도: ${widget.linkedid}');
      debugPrint('⚠️  로그아웃 상태에서는 Firestore 업데이트 불가 - 화면만 닫기');
    }

    // ✅ 로그아웃 상태에서는 Firestore 접근 권한이 없으므로
    // 화면만 닫고 실제 통화 확인은 로그인 후에 처리
    try {
      if (kDebugMode) {
        debugPrint('✅ 로그아웃 상태 통화 확인: 화면 닫기만 수행');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 로그아웃 상태 통화 확인 실패: $e');
        debugPrint('❌ 에러 타입: ${e.runtimeType}');
        debugPrint('❌ 에러 상세: ${e.toString()}');
      }
      
      // ⚠️ 로그아웃 상태에서는 에러가 예상되므로 사용자에게 표시하지 않음
      // (화면은 정상적으로 닫힘)
    }

    // 화면 닫기
    _closeScreen();
  }

  /// ❌ 화면 닫기
  void _closeScreen() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔝 AppBar with close button (투명 배경)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // ✕ 닫기 버튼 (우측 상단)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: _closeScreen,
            tooltip: '닫기',
          ),
          const SizedBox(width: 8),
        ],
      ),
      extendBodyBehindAppBar: true, // AppBar 뒤로 배경 확장
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),

                              // 🏢 내 단말번호 정보 (상단)
                              _buildMyExtensionInfo(),

                              const SizedBox(height: 16),

                              // 📞 "수신 전화" 텍스트
                              _buildHeaderText(),

                              const Spacer(flex: 2),

                              // 👤 발신자 정보 (아바타 + 이름 + 번호)
                              ScaleTransition(
                                scale: _scaleAnimation,
                                child: _buildCallerInfo(),
                              ),

                              const Spacer(flex: 3),

                              // ✅ 통화 확인 버튼
                              _buildConfirmButton(),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🎨 동적 그라데이션 배경 (통화 타입별 색상)
  BoxDecoration _buildGradientBackground() {
    // 통화 타입에 따른 색상 테마
    List<Color> gradientColors;
    
    if (widget.callType == 'external') {
      // 외부 수신: 따뜻한 오렌지-레드 그라데이션
      gradientColors = [
        const Color(0xFF1a1a2e), // 다크 네이비
        const Color(0xFF16213e), // 미디엄 네이비
        const Color(0xFF0f3460), // 딥 블루-퍼플
      ];
    } else if (widget.callType == 'internal') {
      // 내부 수신: 차분한 그린-블루 그라데이션
      gradientColors = [
        const Color(0xFF0d1b2a), // 다크 블루
        const Color(0xFF1b263b), // 미디엄 블루
        const Color(0xFF415a77), // 라이트 블루-그레이
      ];
    } else {
      // 기본: 기존 블루 그라데이션
      gradientColors = [
        const Color(0xFF0F2027), // 다크 블루
        const Color(0xFF203A43), // 미디엄 블루
        const Color(0xFF2C5364), // 라이트 블루
      ];
    }
    
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
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

  /// 🏢 내 단말번호 정보 (상단) - 통화 타입별 색상
  Widget _buildMyExtensionInfo() {
    // receiverNumber와 착신전환 정보가 모두 없으면 표시하지 않음
    final hasReceiverNumber = widget.receiverNumber.isNotEmpty;
    final hasCompanyName = widget.myCompanyName != null && widget.myCompanyName!.isNotEmpty;
    final hasCallForward = widget.isCallForwardEnabled == true && 
                           widget.callForwardDestination != null && 
                           widget.callForwardDestination!.isNotEmpty &&
                           widget.callForwardDestination != '00000000000';
    
    if (!hasReceiverNumber && !hasCompanyName) {
      return const SizedBox.shrink();
    }

    // 통화 타입별 색상
    Color borderColor;
    if (widget.callType == 'external') {
      borderColor = const Color(0xFFe76f51).withValues(alpha: 0.4);
    } else if (widget.callType == 'internal') {
      borderColor = const Color(0xFF06d6a0).withValues(alpha: 0.4);
    } else {
      borderColor = Colors.white.withValues(alpha: 0.3);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // 조직명 (첫 번째 줄)
          if (hasCompanyName)
            Text(
              widget.myCompanyName!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          
          // 간격 (조직명이 있을 때만)
          if (hasCompanyName && hasReceiverNumber)
            const SizedBox(height: 6),
          
          // 수신 단말번호 표시 (착신전환 상태에 따라 다르게 표시)
          if (hasReceiverNumber)
            _buildReceiverNumberDisplay(hasCallForward),
        ],
      ),
    );
  }

  /// 수신 단말번호 표시 (착신전환 상태에 따라 다르게 표시)
  Widget _buildReceiverNumberDisplay(bool hasCallForward) {
    if (hasCallForward) {
      // 착신전환 활성화: 단말번호 → 착신번호 (주황색)
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 단말번호
          Text(
            widget.receiverNumber,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          // 화살표 아이콘
          const Icon(
            Icons.arrow_forward,
            color: Color(0xFFFF9800),
            size: 16,
          ),
          const SizedBox(width: 8),
          // 착신전환 번호 (주황색)
          Text(
            widget.callForwardDestination!,
            style: const TextStyle(
              color: Color(0xFFFF9800),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      );
    } else {
      // 착신전환 비활성화: 단말번호만 표시
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_in_talk,
            color: Colors.white.withValues(alpha: 0.8),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            widget.receiverNumber,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ],
      );
    }
  }

  /// 📞 헤더 텍스트 (통화 타입에 따라 변경 + 색상 구분)
  Widget _buildHeaderText() {
    // 통화 타입에 따른 헤더 텍스트 및 색상 결정
    String headerText;
    Color accentColor;
    IconData headerIcon;
    
    if (widget.callType == 'external') {
      headerText = '외부 수신 통화';
      accentColor = const Color(0xFFe76f51); // 따뜻한 오렌지
      headerIcon = Icons.call_received;
    } else if (widget.callType == 'internal') {
      headerText = '내부 수신 통화';
      accentColor = const Color(0xFF06d6a0); // 민트 그린
      headerIcon = Icons.phone_in_talk_rounded;
    } else {
      headerText = '수신 전화';
      accentColor = Colors.white;
      headerIcon = Icons.phone_in_talk_rounded;
    }
    
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                headerIcon,
                color: accentColor.withValues(alpha: 0.95),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                headerText,
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 👤 발신자 정보 (통화 타입에 따라 순서 변경)
  Widget _buildCallerInfo() {
    // 외부 수신 통화: 외부발신 정보 먼저 표시 → 실제 발신자 정보
    // 내부 수신 통화: 실제 발신자 정보만 표시
    
    if (widget.callType == 'external') {
      return _buildExternalCallInfo();
    } else {
      return _buildInternalCallInfo();
    }
  }
  
  /// 외부 수신 통화 정보 (외부CID → 발신자)
  Widget _buildExternalCallInfo() {
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

        // 📋 외부발신 정보 (externalCidName, externalCidNumber) - 먼저 표시
        if (widget.myExternalCidName != null && widget.myExternalCidName!.isNotEmpty ||
            widget.myExternalCidNumber != null && widget.myExternalCidNumber!.isNotEmpty) ...[
          
          // 외부발신 이름 (첫 번째 줄) - 발신자 이름과 동일한 크기 및 스타일
          if (widget.myExternalCidName != null && widget.myExternalCidName!.isNotEmpty)
            Text(
              widget.myExternalCidName!,
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
          
          // 간격 (이름과 번호 사이)
          if (widget.myExternalCidName != null && 
              widget.myExternalCidName!.isNotEmpty &&
              widget.myExternalCidNumber != null &&
              widget.myExternalCidNumber!.isNotEmpty)
            const SizedBox(height: 12),
          
          // 외부발신 번호 (두 번째 줄)
          if (widget.myExternalCidNumber != null && widget.myExternalCidNumber!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.call_made,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.myExternalCidNumber!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 32), // 외부발신 정보와 발신자 정보 간격
        ],
        
        // 📝 실제 발신자 이름 (두 번째 표시)
        Text(
          widget.callerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
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

        // 📞 전화번호 (세 번째 표시)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.callerNumber,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
  
  /// 내부 수신 통화 정보 (발신자만)
  Widget _buildInternalCallInfo() {
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
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.callerNumber,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
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
      return CachedNetworkImageWidget(
        imageUrl: widget.callerAvatar!,
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

  /// ✅ 통화 확인 버튼 (로그아웃 상태)
  Widget _buildConfirmButton() {
    return Center(
      child: GestureDetector(
        onTap: _confirmCall,
        child: Column(
          children: [
            // 확인 버튼 (녹색 글로우 효과)
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.6 * _glowController.value),
                        blurRadius: 35 * _glowController.value,
                        spreadRadius: 8 * _glowController.value,
                      ),
                    ],
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // 레이블
            Text(
              '통화 확인',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
