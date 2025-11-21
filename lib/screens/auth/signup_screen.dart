import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/social_login_service.dart';
import '../../utils/dialog_utils.dart';
import '../../widgets/social_login_buttons.dart';
import '../../widgets/social_login_progress_overlay.dart';
import '../home/main_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _isSocialLoginLoading = false;
  
  final _socialLoginService = SocialLoginService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Platform detection (웹 플랫폼 안전 처리)
  bool get _isMobile {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }
  bool get _isWeb => kIsWeb;
  
  bool get _isIOS {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    
    // 애니메이션 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    // 애니메이션 시작
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_agreedToTerms) {
      await DialogUtils.showWarning(
        context,
        '이용약관에 동의해주세요',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (mounted) {
        Navigator.pop(context);
        await DialogUtils.showSuccess(
          context,
          '회원가입이 완료되었습니다',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          context.read<AuthService>().getErrorMessage(e.code),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 소셜 로그인 성공 처리
  Future<void> _handleSocialLoginSuccess(SocialLoginResult result) async {
    try {
      if (!result.success || result.userId == null) return;
      
      // 1️⃣ 사용자 정보 확인 중
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '사용자 정보 확인 중...',
          subMessage: '잠시만 기다려주세요',
        );
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 🔍 기존 계정 확인
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(result.userId!)
          .get();
      
      // 진행 상황 오버레이 제거
      if (mounted) {
        SocialLoginProgressHelper.hide();
      }
      
      if (userDoc.exists) {
        // ✅ 기존 계정이 있음 - 안내 다이얼로그 표시
        if (mounted) {
          await _showExistingAccountDialog(
            email: result.email ?? 'Unknown',
            provider: result.provider,
          );
        }
        return;
      }
      
      // 2️⃣ 신규 가입 - 프로필 생성 중
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '계정 생성 중...',
          subMessage: 'Firebase 프로필을 생성하고 있습니다',
        );
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 🆕 신규 가입 - Firestore 프로필 업데이트
      await _updateFirestoreUserProfile(
        userId: result.userId!,
        displayName: result.displayName,
        photoUrl: result.photoUrl,
        provider: result.provider,
      );
      
      // 진행 상황 오버레이 제거
      if (mounted) {
        SocialLoginProgressHelper.hide();
      }
      
      if (mounted) {
        Navigator.pop(context);
        await DialogUtils.showSuccess(
          context,
          '${result.provider.name.toUpperCase()} 계정으로 가입되었습니다',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 소셜 로그인 성공 처리 오류: $e');
      }
      // 에러 시 오버레이 제거
      if (mounted) {
        SocialLoginProgressHelper.hide();
      }
    }
  }
  
  // REST API 설정 필요 안내 다이얼로그
  Future<void> _showApiSettingsRequiredDialog() async {
    if (!mounted) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.orange[300] : Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('REST API 설정 필요'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '통화 기능을 사용하기 위해서는\nREST API 서버 설정이 필요합니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange[900]!.withAlpha(77)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.orange[700]!
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 20,
                    color: isDark ? Colors.orange[300] : Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '왼쪽 상단 프로필 아이콘을 눌러\nREST API 서버 정보를 입력해주세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.orange[300] : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '※ WebSocket 설정은 선택사항입니다',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.orange[700] : Colors.orange[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  // 기존 계정 안내 다이얼로그
  Future<void> _showExistingAccountDialog({
    required String email,
    required SocialLoginProvider provider,
  }) async {
    if (!mounted) return;
    
    // 🎯 소셜 로그인 진행 중 플래그 설정 (이벤트 기반)
    // "기존 계정 확인" 다이얼로그가 표시되는 동안 초기 설정 팝업 표시 안 함
    final authService = context.read<AuthService>();
    authService.setInSocialLoginFlow(true);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('기존 계정 확인'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '기존에 가입한 계정이 있습니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.grey[800] 
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '가입한 계정:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 소셜 로그인 진행 취소 (이벤트 기반)
              if (context.mounted) {
                final authService = context.read<AuthService>();
                authService.setInSocialLoginFlow(false);
              }
              
              // Firebase 로그아웃 (기존 계정 세션 제거)
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              }
            },
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (context.mounted) {
                final authService = context.read<AuthService>();
                
                // 1️⃣ 소셜 로그인 진행 완료 (이벤트 기반)
                authService.setInSocialLoginFlow(false);
                
                // 2️⃣ REST API 설정 확인 (기존 계정 로그인 시에만 체크)
                final userModel = authService.currentUserModel;
                
                // 🔍 REST API 설정이 없는 경우 안내 다이얼로그 표시
                if (userModel != null) {
                  final hasApiSettings = (userModel.apiBaseUrl?.isNotEmpty ?? false) &&
                                        (userModel.companyId?.isNotEmpty ?? false) &&
                                        (userModel.appKey?.isNotEmpty ?? false);
                  
                  if (!hasApiSettings && context.mounted) {
                    // 다이얼로그 닫기
                    Navigator.of(context).pop();
                    
                    // 약간의 지연 후 REST API 설정 안내 다이얼로그 표시
                    await Future.delayed(const Duration(milliseconds: 300));
                    
                    if (context.mounted) {
                      await _showApiSettingsRequiredDialog();
                    }
                    
                    // 3️⃣ 모든 navigation stack 제거하고 root로 돌아가기
                    if (context.mounted && Navigator.of(context).canPop()) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                    
                    return;
                  }
                }
                
                // 3️⃣ 모든 navigation stack 제거하고 root로 돌아가기
                // main.dart의 Consumer<AuthService>가 자동으로 적절한 화면 표시:
                // - isWaitingForApproval == true → ApprovalWaitingScreen
                // - 아니면 → MainScreen
                if (context.mounted) {
                  // 🔒 안전성 체크: navigation history가 있는지 확인
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[700] : Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }
  
  // Firestore 사용자 프로필 업데이트 (카카오 닉네임 → 조직명, 프로필사진 → 썸네일)
  Future<void> _updateFirestoreUserProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
    required SocialLoginProvider provider,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [PROFILE UPDATE] Firestore 사용자 정보 업데이트 시작');
        debugPrint('   - Provider: ${provider.name}');
        debugPrint('   - DisplayName: ${displayName ?? "null"}');
        debugPrint('   - PhotoUrl: ${photoUrl ?? "null"}');
      }
      
      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      final docSnapshot = await userDoc.get();
      
      // 업데이트할 필드 준비
      final Map<String, dynamic> updateData = {};
      
      // 카카오 닉네임 → organizationName (조직명이 비어있을 때만)
      if (displayName != null && displayName.isNotEmpty) {
        if (!docSnapshot.exists || docSnapshot.data()?['organizationName'] == null) {
          updateData['organizationName'] = displayName;
          if (kDebugMode) {
            debugPrint('   ✅ organizationName 설정: $displayName');
          }
        }
      }
      
      // 카카오 프로필사진 → profileImageUrl (썸네일, 비어있을 때만)
      if (photoUrl != null && photoUrl.isNotEmpty) {
        if (!docSnapshot.exists || docSnapshot.data()?['profileImageUrl'] == null) {
          updateData['profileImageUrl'] = photoUrl;
          if (kDebugMode) {
            debugPrint('   ✅ profileImageUrl 설정: $photoUrl');
          }
        }
      }
      
      // 업데이트 실행
      if (updateData.isNotEmpty) {
        await userDoc.set(updateData, SetOptions(merge: true));
        if (kDebugMode) {
          debugPrint('✅ [PROFILE UPDATE] Firestore 업데이트 완료');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ [PROFILE UPDATE] 업데이트할 필드 없음 (이미 설정됨)');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [PROFILE UPDATE] Firestore 업데이트 실패: $e');
      }
      // 프로필 업데이트 실패는 치명적이지 않으므로 에러를 throw하지 않음
    }
  }

  // Google 회원가입
  Future<void> _handleGoogleSignUp() async {
    // 웹 플랫폼에서는 소셜 로그인 비활성화
    if (_isWeb) {
      await DialogUtils.showInfo(
        context,
        '소셜 로그인은 웹에서는 제공하지 않습니다.',
        title: 'Google 회원가입',
      );
      return;
    }
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      final result = await _socialLoginService.signInWithGoogle();
      
      if (result.success) {
        await _handleSocialLoginSuccess(result);
      } else {
        if (mounted) {
          if (result.errorMessage?.contains('취소') ?? false) {
            await DialogUtils.showInfo(
              context,
              'Google 회원가입이 취소되었습니다.',
              title: 'Google 회원가입',
            );
          } else {
            await DialogUtils.showError(
              context,
              result.errorMessage ?? 'Google 회원가입에 실패했습니다.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          'Google 회원가입 중 오류가 발생했습니다: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSocialLoginLoading = false);
      }
    }
  }

  // Kakao 회원가입
  Future<void> _handleKakaoSignUp() async {
    // 웹 플랫폼에서는 소셜 로그인 비활성화
    if (_isWeb) {
      await DialogUtils.showInfo(
        context,
        '소셜 로그인은 웹에서는 제공하지 않습니다.',
        title: 'Kakao 회원가입',
      );
      return;
    }
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      final result = await _socialLoginService.signInWithKakao();
      
      if (result.success) {
        await _handleSocialLoginSuccess(result);
      } else {
        if (mounted) {
          if (result.errorMessage?.contains('취소') ?? false) {
            await DialogUtils.showInfo(
              context,
              'Kakao 회원가입이 취소되었습니다.',
              title: 'Kakao 회원가입',
            );
          } else {
            await DialogUtils.showError(
              context,
              result.errorMessage ?? 'Kakao 회원가입에 실패했습니다.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          'Kakao 회원가입 중 오류가 발생했습니다: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSocialLoginLoading = false);
      }
    }
  }

  // Apple 회원가입 (모든 플랫폼)
  Future<void> _handleAppleSignUp() async {
    // 웹 플랫폼에서는 소셜 로그인 비활성화
    if (_isWeb) {
      await DialogUtils.showInfo(
        context,
        '소셜 로그인은 웹에서는 제공하지 않습니다.',
        title: 'Apple 회원가입',
      );
      return;
    }
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      final result = await _socialLoginService.signInWithApple();
      
      if (result.success) {
        await _handleSocialLoginSuccess(result);
      } else {
        if (mounted) {
          // 사용자 취소는 안내 메시지로 표시 (info), 나머지는 에러로 표시
          final isCanceled = result.errorMessage?.contains('취소') ?? false;
          
          if (isCanceled) {
            await DialogUtils.showInfo(
              context,
              result.errorMessage ?? 'Apple 회원가입이 취소되었습니다.',
              title: 'Apple 회원가입',
            );
          } else {
            await DialogUtils.showError(
              context,
              result.errorMessage ?? 'Apple 회원가입에 실패했습니다.\n\niOS 설정 > Apple ID > 암호 및 보안에서\nApple로 로그인 설정을 확인해주세요.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          'Apple 회원가입 중 오류가 발생했습니다.\n\n${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSocialLoginLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = _isMobile ? double.infinity : 480.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : (_isWeb ? Colors.grey[50] : Colors.white),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.grey[300] : (_isWeb ? Colors.grey[800] : Colors.black87),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: _isMobile ? 24.0 : 48.0,
                vertical: 16.0,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo Section
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                  blurRadius: 20,
                                  spreadRadius: -5,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.phone_in_talk_rounded,
                                      size: 50,
                                      color: Color(0xFF2196F3),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Title
                        Text(
                          '회원가입',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : (_isWeb ? Colors.grey[900] : Colors.black87),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MAKECALL과 함께 시작하세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 40),
                        
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: '이메일',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                            hintText: 'example@email.com',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[850]
                                : (_isWeb ? Colors.white : Colors.grey[50]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2196F3),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '이메일을 입력해주세요';
                            }
                            if (!value.contains('@')) {
                              return '올바른 이메일 형식이 아닙니다';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                            hintText: '최소 6자 이상',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[850]
                                : (_isWeb ? Colors.white : Colors.grey[50]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2196F3),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 입력해주세요';
                            }
                            if (value.length < 6) {
                              return '비밀번호는 최소 6자 이상이어야 합니다';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: '비밀번호 확인',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                            hintText: '비밀번호를 다시 입력하세요',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[850]
                                : (_isWeb ? Colors.white : Colors.grey[50]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF2196F3),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호 확인을 입력해주세요';
                            }
                            if (value != _passwordController.text) {
                              return '비밀번호가 일치하지 않습니다';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Terms Checkbox
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[850]
                                : (_isWeb 
                                    ? Colors.blue.withValues(alpha: 0.05)
                                    : Colors.grey.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            value: _agreedToTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreedToTerms = value ?? false;
                              });
                            },
                            title: Text(
                              '이용약관 및 개인정보처리방침에 동의합니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            activeColor: const Color(0xFF2196F3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Sign Up Button (Gradient)
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    '가입하기',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Divider with "또는"
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '또는',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Social Login Buttons
                        SocialLoginButtons(
                          onGooglePressed: _handleGoogleSignUp,
                          onKakaoPressed: _handleKakaoSignUp,
                          onApplePressed: _handleAppleSignUp,
                          isLoading: _isSocialLoginLoading,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Already have account
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '이미 계정이 있으신가요?',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2196F3),
                              ),
                              child: const Text(
                                '로그인',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // 웹 플랫폼: 개인정보 보호정책 및 서비스 이용 약관 링크
                        if (_isWeb) ...[
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    final uri = Uri.parse('https://app.makecall.io/privacy_policy.html');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Text(
                                    '개인정보 보호정책',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                                      decoration: TextDecoration.underline,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                Text(
                                  '|',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                                  ),
                                ),
                                InkWell(
                                  onTap: () async {
                                    final uri = Uri.parse('https://app.makecall.io/terms_of_service.html');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Text(
                                    '서비스 이용 약관',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                                      decoration: TextDecoration.underline,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        // Copyright
                        Text(
                          '© 2024 MAKECALL. All rights reserved.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
