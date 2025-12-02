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
import '../../utils/common_utils.dart';
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
  
  // 🆕 개인정보보호법 준수 - 동의 관리
  bool _agreedToTerms = false;  // 하위 호환성 유지
  bool _allAgreed = false;                 // 전체 동의
  bool _termsAgreed = false;               // 이용약관 동의 (필수)
  bool _privacyPolicyAgreed = false;       // 개인정보처리방침 동의 (필수)
  bool _marketingConsent = false;          // 마케팅 수신 동의 (선택)
  
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
    
    // 🆕 필수 동의 항목 확인
    if (!_termsAgreed || !_privacyPolicyAgreed) {
      await DialogUtils.showWarning(
        context,
        '필수 항목에 모두 동의해주세요\n\n- 이용약관\n- 개인정보처리방칈',
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
      
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        // Navigator.pop 후 약간의 딜레이를 주어 안전하게 새 다이얼로그 표시
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (mounted) {
          await DialogUtils.showSuccess(
            context,
            '회원가입이 완료되었습니다',
          );
        }
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
      
      // ⌨️ CRITICAL: 키보드 내리기 (소셜 회원가입 성공 시)
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
      
      // 🎯 즉시 소셜 로그인 플래그 설정 (main.dart의 자동 화면 전환 차단)
      if (mounted) {
        final authService = context.read<AuthService>();
        authService.setInSocialLoginFlow(true);
      }
      
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
        if (kDebugMode) {
          debugPrint('⚠️ [SIGNUP] 기존 계정 발견 - 다이얼로그 표시');
          debugPrint('   - Email: ${result.email ?? 'Unknown'}');
        }
        
        if (mounted) {
          await _showExistingAccountDialog(
            email: result.email,
            userId: result.userId!,
            provider: result.provider,
          );
        }
        
        // 🚨 CRITICAL: 기존 사용자는 프로필 업데이트하지 않음
        // (동의 정보를 덮어쓰지 않기 위해)
        return;
      }
      
      // 🆕 신규 사용자 - Firestore 문서 생성 (동의는 이미 완료됨)
      
      // Firestore 사용자 문서 생성
      final nowDateTime = DateTime.now();
      final now = FieldValue.serverTimestamp();
      final twoYearsLater = nowDateTime.add(const Duration(days: 730));
      
      final userData = {
        'uid': result.userId,
        'email': result.email ?? '',
        'organizationName': result.displayName ?? '소셜 로그인 사용자',
        'profileImageUrl': result.photoUrl,
        'role': 'user',
        'loginProvider': result.provider.name,
        'createdAt': now,
        'updatedAt': now,
        'lastLoginAt': now,
        'isActive': true,
        'accountStatus': 'approved', // 소셜 로그인은 자동 승인
        'maxDevices': 1, // 최대 사용 기기 수 (기본값: 1)
        // 동의 정보 (SignupScreen에서 이미 수집됨)
        'consentVersion': '1.0',
        'termsAgreed': _termsAgreed,
        'termsAgreedAt': _termsAgreed ? now : null,
        'privacyPolicyAgreed': _privacyPolicyAgreed,
        'privacyPolicyAgreedAt': _privacyPolicyAgreed ? now : null,
        'marketingConsent': _marketingConsent,
        'marketingConsentAt': _marketingConsent ? now : null,
        'lastConsentCheckAt': now,
        'nextConsentCheckDue': Timestamp.fromDate(twoYearsLater),
        'consentHistory': [
          {
            'version': '1.0',
            'agreedAt': Timestamp.fromDate(nowDateTime),
            'type': 'initial',
            'termsAgreed': _termsAgreed,
            'privacyPolicyAgreed': _privacyPolicyAgreed,
            'marketingConsent': _marketingConsent,
          }
        ],
      };
      
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(result.userId!)
            .set(userData);
        
        // Firestore 문서 생성 완료
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [SIGNUP] Firestore 문서 생성 실패: $e');
        }
        
        // 실패 시 Firebase Authentication 로그아웃
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          SocialLoginProgressHelper.hide();
          await DialogUtils.showError(
            context,
            '회원가입 처리 중 오류가 발생했습니다.\n다시 시도해주세요.',
          );
        }
        return;
      }
      
      // 2️⃣ 계정 정보 로드 중
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '계정 정보 로드 중...',
          subMessage: '잠시만 기다려주세요',
        );
      }
      
      // 🔐 CRITICAL: AuthService의 userModel 강제 재로드
      if (mounted) {
        try {
          final authService = context.read<AuthService>();
          await authService.loadNewUserModel(result.userId!);
          
          // 신규 사용자 모델 로드 완료
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [SIGNUP] 신규 사용자 모델 로드 실패: $e');
          }
          
          // 실패 시 오버레이 제거 및 에러 표시
          if (mounted) {
            SocialLoginProgressHelper.hide();
            await DialogUtils.showError(
              context,
              '계정 정보 로드에 실패했습니다.\n다시 시도해주세요.',
            );
          }
          return;
        }
      }
      
      // 진행 상황 오버레이 제거
      if (mounted) {
        SocialLoginProgressHelper.hide();
      }
      
      // 회원가입 완료
      
      // 🔙 CRITICAL: SignupScreen 닫고 LoginScreen으로 복귀
      if (mounted) {
        // 소셜 로그인 진행 중 플래그 해제
        final authService = context.read<AuthService>();
        authService.setInSocialLoginFlow(false);
        
        // SignupScreen 닫기
        Navigator.of(context).pop();
        
        // 짧은 지연 후 성공 메시지 표시 (LoginScreen에서)
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted && Navigator.canPop(context)) {
          // 이미 LoginScreen으로 돌아왔으므로 성공 메시지만 표시
          // (AuthService의 authStateChanges가 자동으로 MainScreen으로 전환)
        }
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
  
  // 📧 애플 로그인 이메일 안내 다이얼로그
  Future<bool> _showAppleEmailNotice() async {
    if (!mounted) return false;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.apple,
                color: isDark ? Colors.white : Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Apple 로그인 안내',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apple 로그인 시 다음 화면에서\n이메일 공유 여부를 선택할 수 있습니다.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.blue[900]!.withValues(alpha: 0.3)
                    : Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue[700]! : Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 20,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '이메일 공유를 권장합니다',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• 계정 복구 및 중요 알림 수신\n• 고객 지원 시 원활한 소통\n• 더 나은 서비스 제공',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '이메일을 숨기셔도 회원가입은 가능합니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '취소',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Apple로 계속하기'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  // 기존 계정 안내 다이얼로그
  Future<void> _showExistingAccountDialog({
    required String? email,
    required String userId,
    required SocialLoginProvider provider,
  }) async {
    if (!mounted) return;
    
    // ℹ️ 소셜 로그인 플래그는 _handleSocialLoginSuccess에서 이미 설정됨
    
    final authService = context.read<AuthService>();
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
                    email != null && email.isNotEmpty 
                        ? Icons.email_outlined 
                        : Icons.fingerprint,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email != null && email.isNotEmpty 
                              ? '가입한 계정:' 
                              : '가입한 계정 UID:',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email != null && email.isNotEmpty 
                              ? email 
                              : userId,
                          style: TextStyle(
                            fontSize: email != null && email.isNotEmpty ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
              if (context.mounted) {
                final authService = context.read<AuthService>();
                
                // 1️⃣ 먼저 Firebase 로그아웃 (기존 계정 사용 거부)
                await FirebaseAuth.instance.signOut();
                
                // 2️⃣ 플래그 해제 (LoginScreen으로 복귀 허용)
                authService.setInSocialLoginFlow(false);
                
                // 3️⃣ 다이얼로그 닫기
                Navigator.of(context).pop();
                
                // 4️⃣ Navigator stack 정리 (LoginScreen으로 돌아가기)
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (context.mounted) {
                final authService = context.read<AuthService>();
                
                // 1️⃣ 다이얼로그 닫기
                Navigator.of(context).pop();
                
                // 2️⃣ 로딩 오버레이 표시
                if (mounted) {
                  SocialLoginProgressHelper.show(
                    context,
                    message: '로그인 처리 중...',
                    subMessage: 'FCM 초기화 및 기기 확인',
                  );
                }
                
                try {
                  // 3️⃣ FCM 초기화 (MaxDeviceLimitException 체크 포함)
                  if (kDebugMode) {
                    debugPrint('🔔 [SIGNUP] 기존 계정 FCM 초기화 시작');
                    debugPrint('   User ID: $userId');
                  }
                  
                  await FCMService().initialize(userId);
                  
                  if (kDebugMode) {
                    debugPrint('✅ [SIGNUP] 기존 계정 FCM 초기화 완료');
                  }
                  
                  // 4️⃣ 플래그 해제 (MainScreen으로 전환 허용)
                  authService.setInSocialLoginFlow(false);
                  
                  // 5️⃣ 로딩 오버레이 제거
                  if (mounted) {
                    SocialLoginProgressHelper.hide();
                  }
                  
                  // 6️⃣ Navigator stack 정리 (root로 돌아가기)
                  // main.dart의 Consumer<AuthService>가 자동으로 MainScreen 표시
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } on MaxDeviceLimitException catch (e) {
                  // 최대 기기 수 초과 예외 처리
                  if (kDebugMode) {
                    debugPrint('🚫 [SIGNUP] MaxDeviceLimitException 발생');
                    debugPrint('   maxDevices: ${e.maxDevices}');
                    debugPrint('   currentDevices: ${e.currentDevices}');
                    debugPrint('   deviceName: ${e.deviceName}');
                  }
                  
                  // 로딩 오버레이 제거
                  if (mounted) {
                    SocialLoginProgressHelper.hide();
                  }
                  
                  // MaxDeviceLimit 다이얼로그 표시
                  if (mounted) {
                    await _showMaxDeviceLimitDialog(e);
                  }
                  
                  // Firebase Auth 로그아웃
                  await FirebaseAuth.instance.signOut();
                  
                  // 플래그 해제
                  authService.setInSocialLoginFlow(false);
                  
                  // LoginScreen으로 돌아가기
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  // 기타 FCM 초기화 오류
                  if (kDebugMode) {
                    debugPrint('❌ [SIGNUP] FCM 초기화 실패: $e');
                  }
                  
                  // 로딩 오버레이 제거
                  if (mounted) {
                    SocialLoginProgressHelper.hide();
                  }
                  
                  // 오류 다이얼로그 표시
                  if (mounted) {
                    await DialogUtils.showError(
                      context,
                      'FCM 초기화에 실패했습니다.\n다시 시도해주세요.',
                    );
                  }
                  
                  // Firebase Auth 로그아웃
                  await FirebaseAuth.instance.signOut();
                  
                  // 플래그 해제
                  authService.setInSocialLoginFlow(false);
                  
                  // LoginScreen으로 돌아가기
                  if (context.mounted && Navigator.of(context).canPop()) {
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
      
      // 🆕 동의 관리 필드 업데이트 (신규 가입 또는 동의 데이터가 없는 경우)
      final data = docSnapshot.data();
      final needsConsentUpdate = !docSnapshot.exists || 
                                   data?['termsAgreed'] == null || 
                                   data?['privacyPolicyAgreed'] == null;
      
      if (needsConsentUpdate) {
        final nowDateTime = DateTime.now();
        final now = Timestamp.fromDate(nowDateTime);
        final twoYearsLater = nowDateTime.add(const Duration(days: 730));
        
        updateData['consentVersion'] = '1.0';
        updateData['termsAgreed'] = _termsAgreed;
        updateData['termsAgreedAt'] = _termsAgreed ? now : null;
        updateData['privacyPolicyAgreed'] = _privacyPolicyAgreed;
        updateData['privacyPolicyAgreedAt'] = _privacyPolicyAgreed ? now : null;
        updateData['marketingConsent'] = _marketingConsent;
        updateData['marketingConsentAt'] = _marketingConsent ? now : null;
        updateData['lastConsentCheckAt'] = now;
        updateData['nextConsentCheckDue'] = Timestamp.fromDate(twoYearsLater);
        // 🔧 FIX: arrayUnion 안에도 Timestamp 사용 (FieldValue.serverTimestamp 사용 불가)
        updateData['consentHistory'] = FieldValue.arrayUnion([
          {
            'version': '1.0',
            'agreedAt': now, // Timestamp (DateTime에서 변환)
            'type': 'initial',
          }
        ]);
        
        if (kDebugMode) {
          debugPrint('   ✅ 동의 정보 저장');
          debugPrint('      - 이용약관: $_termsAgreed');
          debugPrint('      - 개인정보처리방침: $_privacyPolicyAgreed');
          debugPrint('      - 마케팅 수신: $_marketingConsent');
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
    
    // 🔒 CRITICAL: 동의 확인 (필수 항목)
    if (!_termsAgreed || !_privacyPolicyAgreed) {
      await DialogUtils.showWarning(
        context,
        '회원가입을 진행하려면\n필수 항목에 동의해주세요.\n\n✓ 이용약관\n✓ 개인정보처리방침',
      );
      return;
    }
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      // 🎯 구글 회원가입 진행 중 오버레이 표시
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '구글로 회원가입 중입니다',
          subMessage: '잠시만 기다려주세요',
        );
      }
      
      final result = await _socialLoginService.signInWithGoogle();
      
      // 진행 상황 오버레이 제거 (성공 시에는 _handleSocialLoginSuccess에서 제거)
      if (!result.success && mounted) {
        SocialLoginProgressHelper.hide();
      }
      
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
      // 에러 시 오버레이 제거
      if (mounted) {
        SocialLoginProgressHelper.hide();
      }
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
    
    // 🔒 CRITICAL: 동의 확인 (필수 항목)
    if (!_termsAgreed || !_privacyPolicyAgreed) {
      await DialogUtils.showWarning(
        context,
        '회원가입을 진행하려면\n필수 항목에 동의해주세요.\n\n✓ 이용약관\n✓ 개인정보처리방침',
      );
      return;
    }
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      // 🎯 카카오톡 회원가입 진행 중 오버레이 표시
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '카카오톡으로 회원가입 중입니다',
          subMessage: '잠시만 기다려주세요',
        );
      }
      
      final result = await _socialLoginService.signInWithKakao();
      
      // 진행 상황 오버레이 제거 (성공 시에는 _handleSocialLoginSuccess에서 제거)
      if (!result.success && mounted) {
        SocialLoginProgressHelper.hide();
      }
      
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
      // 에러 시 오버레이 제거
      if (mounted) {
        // 이벤트 기반 오버레이 제거 (다음 프레임에서 실행)
        SocialLoginProgressHelper.hide();
      }
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
    
    // 🔒 CRITICAL: 동의 확인 (필수 항목)
    if (!_termsAgreed || !_privacyPolicyAgreed) {
      await DialogUtils.showWarning(
        context,
        '회원가입을 진행하려면\n필수 항목에 동의해주세요.\n\n✓ 이용약관\n✓ 개인정보처리방침',
      );
      return;
    }
    
    // 📧 애플 로그인 이메일 안내 (회원가입은 항상 표시)
    final shouldContinue = await _showAppleEmailNotice();
    if (!shouldContinue) return;
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      // 🎯 애플 회원가입 진행 중 오버레이 표시
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '애플로 회원가입 중입니다',
          subMessage: '잠시만 기다려주세요',
        );
      }
      
      final result = await _socialLoginService.signInWithApple();
      
      // 진행 상황 오버레이 제거 (성공 시에는 _handleSocialLoginSuccess에서 제거)
      if (!result.success && mounted) {
        SocialLoginProgressHelper.hide();
      }
      
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
      // 에러 시 오버레이 제거
      if (mounted) {
        SocialLoginProgressHelper.hide();
      }
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
  
  // 🆕 전체 동의 상태 업데이트
  void _updateAllAgreed() {
    setState(() {
      _allAgreed = _termsAgreed && _privacyPolicyAgreed && _marketingConsent;
    });
  }
  
  // 🆕 이용약관 다이얼로그
  Future<void> _showTermsDialog(BuildContext context) async {
    final Uri url = Uri.parse('https://app.makecall.io/terms_of_service.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    } else {
      if (mounted) {
        await DialogUtils.showError(
          context,
          '이용약관을 열 수 없습니다.',
        );
      }
    }
  }
  
  // 🆕 개인정보처리방침 다이얼로그
  Future<void> _showPrivacyPolicyDialog(BuildContext context) async {
    final Uri url = Uri.parse('https://app.makecall.io/privacy_policy.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    } else {
      if (mounted) {
        await DialogUtils.showError(
          context,
          '개인정보처리방침을 열 수 없습니다.',
        );
      }
    }
  }
  
  // 🆕 동의 섹션 UI 빌더
  Widget _buildConsentSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.grey[850]
            : (_isWeb 
                ? Colors.blue.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 전체 동의
          CheckboxListTile(
            value: _allAgreed,
            onChanged: (value) {
              setState(() {
                _allAgreed = value ?? false;
                _termsAgreed = _allAgreed;
                _privacyPolicyAgreed = _allAgreed;
                _marketingConsent = _allAgreed;
                _agreedToTerms = _termsAgreed && _privacyPolicyAgreed;
              });
            },
            title: Text(
              '전체 동의',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.grey[900],
                fontWeight: FontWeight.bold,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            activeColor: const Color(0xFF2196F3),
          ),
          
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          
          // 필수 1: 이용약관
          CheckboxListTile(
            value: _termsAgreed,
            onChanged: (value) {
              setState(() {
                _termsAgreed = value ?? false;
                _agreedToTerms = _termsAgreed && _privacyPolicyAgreed;
                _updateAllAgreed();
              });
            },
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '[필수] 이용약관 동의',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showTermsDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(40, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            activeColor: const Color(0xFF2196F3),
          ),
          
          // 필수 2: 개인정보처리방침
          CheckboxListTile(
            value: _privacyPolicyAgreed,
            onChanged: (value) {
              setState(() {
                _privacyPolicyAgreed = value ?? false;
                _agreedToTerms = _termsAgreed && _privacyPolicyAgreed;
                _updateAllAgreed();
              });
            },
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '[필수] 개인정보처리방침 동의',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showPrivacyPolicyDialog(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(40, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '보기',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            activeColor: const Color(0xFF2196F3),
          ),
          
          // 선택: 마케팅 수신 동의
          CheckboxListTile(
            value: _marketingConsent,
            onChanged: (value) {
              setState(() {
                _marketingConsent = value ?? false;
                _updateAllAgreed();
              });
            },
            title: Text(
              '[선택] 마케팅 정보 수신 동의',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontWeight: FontWeight.w400,
              ),
            ),
            subtitle: Text(
              '이벤트, 프로모션 등의 마케팅 정보를 받아보실 수 있습니다',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            activeColor: const Color(0xFF2196F3),
            isThreeLine: true,
          ),
        ],
      ),
    );
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
                            hintText: '8자 이상, 영문/숫자/특수문자 포함',
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
                          validator: (value) => CommonUtils.validatePassword(value),
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
                        
                        // 🆕 개선된 동의 UI - 필수/선택 분리
                        _buildConsentSection(isDark),
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
                            onPressed: (_isLoading || !_termsAgreed || !_privacyPolicyAgreed) 
                                ? null 
                                : _handleSignUp,
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
  
  // MaxDeviceLimit 다이얼로그
  void _showMaxDeviceLimitDialog(MaxDeviceLimitException e) {
    if (!mounted) return;
    
    // 소셜 로그인 로딩 오버레이 숨기기
    SocialLoginProgressHelper.hide();
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // ⚡ 즉시 다이얼로그 표시 (await 없음 - 비동기 실행)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.devices_other,
          size: 48,
          color: theme.colorScheme.error,
        ),
        title: Text(
          '최대 사용 기기 수 초과',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 안내 메시지
              Text(
                '최대 사용 기기 수를 초과했습니다.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),
              
              // 구분선
              Divider(
                color: theme.colorScheme.outlineVariant,
                thickness: 1,
              ),
              const SizedBox(height: 16),
              
              // 현재 활성 기기 정보 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Row(
                      children: [
                        Icon(
                          Icons.devices,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '현재 활성 기기',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 활성 기기 수
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${e.currentDevices}개',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '/ ${e.maxDevices}개 (최대)',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // 시도한 기기 정보
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.block,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '시도한 기기: ${e.deviceName}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
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
        ),
        actions: [
          // 큰 확인 버튼 (전체 너비)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '확인',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                    fontSize: 16,
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
