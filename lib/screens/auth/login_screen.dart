import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/account_manager_service.dart';
import '../../services/social_login_service.dart';
import '../../utils/dialog_utils.dart';
import '../../widgets/social_login_buttons.dart';
import '../../widgets/social_login_progress_overlay.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? prefilledEmail; // 계정 전환 시 자동으로 채울 이메일
  
  const LoginScreen({super.key, this.prefilledEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true; // 초기값을 true로 변경 (자동 로그인 체크 중)
  bool _obscurePassword = true;
  bool _rememberEmail = false;
  bool _autoLogin = false;
  bool _isAutoLoginAttempting = false; // 자동 로그인 시도 중 플래그
  bool _isSocialLoginLoading = false; // 소셜 로그인 진행 중 플래그
  
  final _socialLoginService = SocialLoginService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  static const String _keyRememberEmail = 'remember_email';
  static const String _keySavedEmail = 'saved_email';
  static const String _keyAutoLogin = 'auto_login';

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
    
    // 즉시 자동 로그인 체크 및 시도
    _checkAndAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  // 플랫폼 감지 (웹 플랫폼 안전 처리)
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
  
  // 자동 로그인 체크 및 시도 (LoginScreen 표시 전)
  Future<void> _checkAndAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberEmail = prefs.getBool(_keyRememberEmail) ?? false;
      final savedEmail = prefs.getString(_keySavedEmail) ?? '';
      final autoLogin = prefs.getBool(_keyAutoLogin) ?? false;
      
      // 계정 전환 대상 이메일 확인
      // 🚫 멀티 계정 기능 비활성화
      final switchTargetEmail = await AccountManagerService().getSwitchTargetEmail();
      
      if (kDebugMode) {
        debugPrint('🔍 Auto-login check:');
        debugPrint('   - Switch target: $switchTargetEmail');
        debugPrint('   - Auto login enabled: $autoLogin');
      }
      
      // 자동 로그인 실패 또는 시도하지 않음 - LoginScreen 표시
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAutoLoginAttempting = false;
          _rememberEmail = rememberEmail;
          _autoLogin = autoLogin;
          
          // 우선순위: 1. 계정 전환 이메일 2. prefilledEmail 3. 저장된 이메일
          if (switchTargetEmail != null && switchTargetEmail.isNotEmpty) {
            _emailController.text = switchTargetEmail;
          } else if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
            _emailController.text = widget.prefilledEmail!;
          } else if (rememberEmail && savedEmail.isNotEmpty) {
            _emailController.text = savedEmail;
          }
        });
        
        // 애니메이션 시작
        _animationController.forward();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Auto-login check error: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAutoLoginAttempting = false;
        });
        _animationController.forward();
      }
    }
  }
  
  // 이메일 저장 설정
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberEmail, _rememberEmail);
    await prefs.setBool(_keyAutoLogin, _autoLogin);
    
    if (_rememberEmail) {
      await prefs.setString(_keySavedEmail, _emailController.text.trim());
    } else {
      await prefs.remove(_keySavedEmail);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      
      if (kDebugMode) {
        debugPrint('🔐 [LOGIN] 로그인 시도 시작 (승인 대기 포함)');
      }
      
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (kDebugMode) {
        debugPrint('✅ [LOGIN] 로그인 및 승인 완료');
      }
      
      // 로그인 성공 시 이메일 저장 설정 적용
      await _saveCredentials();
      
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          context.read<AuthService>().getErrorMessage(e.code),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Device approval denied')) {
          await DialogUtils.showError(
            context,
            '기기 승인이 거부되었습니다.\n다시 시도하려면 기존 기기에서 승인해주세요.',
          );
        } else if (e.toString().contains('timeout')) {
          await DialogUtils.showError(
            context,
            '기기 승인 시간이 초과되었습니다.\n다시 시도해주세요.',
          );
        } else {
          await DialogUtils.showError(
            context,
            '로그인 중 오류가 발생했습니다: ${e.toString()}',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // 비밀번호 재설정 - 전용 화면으로 이동
  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordScreen(),
      ),
    );
  }
  
  // 소셜 로그인 성공 처리
  Future<void> _handleSocialLoginSuccess(SocialLoginResult result) async {
    try {
      // 🔒 CRITICAL: mounted 체크 - 비동기 작업 전 위젯이 마운트되어 있는지 확인
      if (!mounted) {
        if (kDebugMode) {
          debugPrint('⚠️ [SOCIAL LOGIN] Widget unmounted - 후처리 중단');
        }
        return;
      }
      
      final authService = context.read<AuthService>();
      
      if (kDebugMode) {
        debugPrint('✅ [SOCIAL LOGIN] ${result.provider.name} 로그인 성공');
        debugPrint('   - User ID: ${result.userId}');
        debugPrint('   - Email: ${result.email}');
        debugPrint('   - Name: ${result.displayName}');
        debugPrint('   - Photo URL: ${result.photoUrl}');
      }
      
      // 🔐 CRITICAL: Firestore 사용자 정보 업데이트 완료 대기
      // 소셜 로그인 성공 시 Firestore 사용자 정보를 먼저 업데이트하고
      // 업데이트가 완전히 완료된 후에야 AuthService가 userModel을 로드하도록 함
      if (result.success && result.userId != null) {
        // 🔄 기존 오버레이 명시적 제거 (카카오톡 로그인 중... 오버레이)
        if (kDebugMode) {
          debugPrint('🔄 [OVERLAY] 기존 로그인 오버레이 제거 중...');
        }
        SocialLoginProgressHelper.hide();
        
        // 짧은 지연 후 새 오버레이 표시 (UI 업데이트 보장)
        await Future.delayed(const Duration(milliseconds: 50));
        
        // 🔒 mounted 재확인 (비동기 지연 후)
        if (!mounted) {
          if (kDebugMode) {
            debugPrint('⚠️ [SOCIAL LOGIN] Widget unmounted after delay - 후처리 중단');
          }
          return;
        }
        
        // 1️⃣ 사용자 정보 업데이트 중
        if (kDebugMode) {
          debugPrint('🔄 [OVERLAY] 새 오버레이 표시: 사용자 정보 업데이트 중...');
        }
        SocialLoginProgressHelper.show(
          context,
          message: '사용자 정보 업데이트 중...',
          subMessage: 'Firebase에 프로필 정보를 저장하고 있습니다',
        );
        
        if (kDebugMode) {
          debugPrint('🔄 [SOCIAL LOGIN] 사용자 문서 확인 중...');
        }
        
        // 🔍 CRITICAL: 기존 사용자인지 신규 사용자인지 확인
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(result.userId!)
            .get();
        
        if (!userDoc.exists) {
          // 🆕 신규 사용자 - 회원가입 필요
          if (kDebugMode) {
            debugPrint('🆕 [SOCIAL LOGIN] 신규 사용자 - 회원가입 필요');
          }
          
          // 오버레이 제거
          SocialLoginProgressHelper.hide();
          
          // 로그아웃 처리
          await FirebaseAuth.instance.signOut();
          
          if (!mounted) return;
          
          // 회원가입 안내
          await DialogUtils.showInfo(
            context,
            '아직 가입되지 않은 계정입니다.\n\n회원가입 페이지에서 먼저 가입해주세요.',
            title: '회원가입 필요',
          );
          
          return;
        }
        
        // ♻️ 기존 사용자 - 프로필 정보 업데이트
        if (kDebugMode) {
          debugPrint('♻️ [SOCIAL LOGIN] 기존 사용자 - 프로필 업데이트');
        }
        
        await _updateFirestoreUserProfile(
          userId: result.userId!,
          displayName: result.displayName,
          photoUrl: result.photoUrl,
          provider: result.provider,
        );
        
        if (kDebugMode) {
          debugPrint('✅ [SOCIAL LOGIN] 프로필 업데이트 완료');
        }
        
        // 기존 사용자 모델 새로고침
        try {
          await authService.refreshUserModel();
          
          if (kDebugMode) {
            debugPrint('✅ [SOCIAL LOGIN] 기존 사용자 모델 재로드 완료');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [SOCIAL LOGIN] 기존 사용자 모델 재로드 실패: $e');
          }
        }
        
        // 🔒 mounted 재확인
        if (!mounted) {
          if (kDebugMode) {
            debugPrint('⚠️ [SOCIAL LOGIN] Widget unmounted after user check');
          }
          return;
        }
        
        // 🔄 CRITICAL: 오버레이 제거
        // AuthService의 user stream이 업데이트되면 화면이 자동 전환되므로
        // 오버레이는 최대한 빨리 제거해야 함
        if (mounted) {
          if (kDebugMode) {
            debugPrint('🔄 [OVERLAY] 로그인 완료 - 오버레이 제거');
          }
          SocialLoginProgressHelper.hide();
        }
      }
      
      // 🎯 모든 비동기 처리 완료 후 홈 화면으로 이동
      // AuthService의 user stream이 자동으로 업데이트되어 홈 화면으로 이동
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SOCIAL LOGIN] 후처리 오류: $e');
      }
      
      // 에러 시 오버레이 제거 (mounted 체크)
      if (mounted) {
        SocialLoginProgressHelper.hide();
        
        // 에러 다이얼로그 표시 (mounted 재확인)
        if (mounted) {
          await DialogUtils.showError(
            context,
            '소셜 로그인 후 처리 중 오류가 발생했습니다: ${e.toString()}',
          );
        }
      }
    }
  }
  
  // Firestore 기존 사용자 프로필 업데이트 (lastLoginAt, 프로필 정보)
  Future<void> _updateFirestoreUserProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
    required SocialLoginProvider provider,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [PROFILE UPDATE] 기존 사용자 프로필 업데이트 시작');
        debugPrint('   - User ID: $userId');
        debugPrint('   - Provider: ${provider.name}');
      }
      
      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      final docSnapshot = await userDoc.get();
      
      if (!docSnapshot.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ [PROFILE UPDATE] 사용자 문서 없음 - 업데이트 생략');
        }
        return;
      }
      
      final Map<String, dynamic> updateData = {
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // 소셜 로그인 제공자 정보 추가 (없으면)
      if (docSnapshot.data()?['loginProvider'] == null) {
        updateData['loginProvider'] = provider.name;
      }
      
      // 조직명 업데이트 (비어있을 때만)
      if (displayName != null && displayName.isNotEmpty) {
        if (docSnapshot.data()?['organizationName'] == null || 
            docSnapshot.data()?['organizationName'] == '') {
          updateData['organizationName'] = displayName;
        }
      }
      
      // 프로필 이미지 업데이트 (비어있을 때만)
      if (photoUrl != null && photoUrl.isNotEmpty) {
        if (docSnapshot.data()?['profileImageUrl'] == null || 
            docSnapshot.data()?['profileImageUrl'] == '') {
          updateData['profileImageUrl'] = photoUrl;
        }
      }
      
      await userDoc.update(updateData);
      
      if (kDebugMode) {
        debugPrint('✅ [PROFILE UPDATE] 기존 사용자 업데이트 완료');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [PROFILE UPDATE] Firestore 업데이트 실패: $e');
      }
      // 기존 사용자 업데이트 실패는 치명적이지 않으므로 에러를 throw하지 않음
    }
  }
  
  // 구글 로그인
  Future<void> _handleGoogleLogin() async {
    // 웹 플랫폼에서는 소셜 로그인 비활성화
    if (_isWeb) {
      await DialogUtils.showInfo(
        context,
        '소셜 로그인은 웹에서는 제공하지 않습니다.',
        title: 'Google 로그인',
      );
      return;
    }
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      // 🎯 구글 로그인 진행 중 오버레이 표시
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '구글로 로그인 중입니다',
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
          // 사용자 취소는 안내 메시지로 표시
          if (result.errorMessage?.contains('취소') ?? false) {
            await DialogUtils.showInfo(
              context,
              'Google 로그인이 취소되었습니다.',
              title: 'Google 로그인',
            );
          } else {
            await DialogUtils.showError(
              context,
              result.errorMessage ?? 'Google 로그인에 실패했습니다.',
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
          'Google 로그인 중 오류가 발생했습니다: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSocialLoginLoading = false);
      }
    }
  }
  
  // 카카오 로그인
  Future<void> _handleKakaoLogin() async {
    // 웹 플랫폼에서는 소셜 로그인 비활성화
    if (_isWeb) {
      await DialogUtils.showInfo(
        context,
        '소셜 로그인은 웹에서는 제공하지 않습니다.',
        title: 'Kakao 로그인',
      );
      return;
    }
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      // 🎯 카카오톡 로그인 진행 중 오버레이 표시
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '카카오톡으로 로그인 중입니다',
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
          // 사용자 취소는 안내 메시지로 표시
          if (result.errorMessage?.contains('취소') ?? false) {
            await DialogUtils.showInfo(
              context,
              'Kakao 로그인이 취소되었습니다.',
              title: 'Kakao 로그인',
            );
          } else {
            await DialogUtils.showError(
              context,
              result.errorMessage ?? 'Kakao 로그인에 실패했습니다.',
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
          'Kakao 로그인 중 오류가 발생했습니다: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSocialLoginLoading = false);
      }
    }
  }
  
  // 📧 애플 로그인 이메일 안내 다이얼로그
  // 📧 애플 로그인 이메일 확인 및 안내
  Future<bool> _checkAndShowAppleEmailNotice() async {
    if (!mounted) return false;
    
    try {
      // 🔍 방법 1: 입력된 이메일로 조회
      final inputEmail = _emailController.text.trim();
      
      if (inputEmail.isNotEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: inputEmail)
            .where('loginProvider', isEqualTo: 'apple')
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          final userData = querySnapshot.docs.first.data();
          final userEmail = userData['email'] as String?;
          
          if (userEmail != null && userEmail.isNotEmpty) {
            // 이메일이 이미 있는 사용자 - 안내 스킵
            if (kDebugMode) {
              debugPrint('✅ [Apple] 이메일 확인됨 - 안내 스킵: $userEmail');
            }
            return true;
          }
        }
      }
      
      // 🔍 방법 2: AuthService에서 현재 사용자 모델 확인
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUserModel;
      
      if (currentUser != null && 
          currentUser.loginProvider == 'apple' && 
          currentUser.email.isNotEmpty) {
        // 이메일이 이미 있는 사용자 - 안내 스킵
        if (kDebugMode) {
          debugPrint('✅ [Apple] AuthService에서 이메일 확인됨 - 안내 스킵: ${currentUser.email}');
        }
        return true;
      }
      
      // 이메일이 없거나 신규 사용자 - 안내 표시
      if (kDebugMode) {
        debugPrint('⚠️ [Apple] 이메일 없음 - 안내 표시');
      }
      return await _showAppleEmailNotice();
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Apple] 이메일 확인 오류: $e');
      }
      // 오류 발생 시에도 안내 표시
      return await _showAppleEmailNotice();
    }
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
                    '이메일을 숨기셔도 로그인은 가능합니다',
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
  
  // 애플 로그인 (모든 플랫폼)
  Future<void> _handleAppleLogin() async {
    // 웹 플랫폼에서는 소셜 로그인 비활성화
    if (_isWeb) {
      await DialogUtils.showInfo(
        context,
        '소셜 로그인은 웹에서는 제공하지 않습니다.',
        title: 'Apple 로그인',
      );
      return;
    }
    
    // 📧 애플 로그인 이메일 안내 (이메일 없는 사용자만)
    final shouldContinue = await _checkAndShowAppleEmailNotice();
    if (!shouldContinue) return;
    
    if (_isSocialLoginLoading) return;
    
    setState(() => _isSocialLoginLoading = true);
    
    try {
      // 🎯 애플 로그인 진행 중 오버레이 표시
      if (mounted) {
        SocialLoginProgressHelper.show(
          context,
          message: '애플로 로그인 중입니다',
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
              result.errorMessage ?? 'Apple 로그인이 취소되었습니다.',
              title: 'Apple 로그인',
            );
          } else {
            await DialogUtils.showError(
              context,
              result.errorMessage ?? 'Apple 로그인에 실패했습니다.\n\niOS 설정 > Apple ID > 암호 및 보안에서\nApple로 로그인 설정을 확인해주세요.',
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
          'Apple 로그인 중 오류가 발생했습니다.\n\n${e.toString()}',
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
    
    // 자동 로그인 시도 중일 때는 로딩 화면만 표시
    if (_isAutoLoginAttempting) {
      return Scaffold(
        backgroundColor: _isWeb ? Colors.grey[50] : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF2196F3),
              ),
              const SizedBox(height: 24),
              Text(
                '자동 로그인 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark 
          ? Theme.of(context).scaffoldBackgroundColor
          : (_isWeb ? Colors.grey[50] : Colors.white),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: _isMobile ? 24.0 : 48.0,
                vertical: 32.0,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 로고 섹션 - 모던하고 깔끔한 디자인
                        Center(
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(28),
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
                              borderRadius: BorderRadius.circular(28),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.phone_in_talk_rounded,
                                      size: 60,
                                      color: Color(0xFF2196F3),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // 앱 이름
                        const Text(
                          'MAKECALL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                            letterSpacing: 1,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // 부제목
                        Text(
                          '당신의 더 나은 커뮤니케이션',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            letterSpacing: 0.3,
                          ),
                        ),
                        
                        SizedBox(height: _isMobile ? 48 : 56),
                        
                        // 이메일 입력 - 모던한 스타일
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
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
                        
                        // 비밀번호 입력 - 모던한 스타일
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onFieldSubmitted: (_) => _handleLogin(),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                            hintText: '6자 이상 입력',
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
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
                        
                        const SizedBox(height: 12),
                        
                        // 옵션 및 비밀번호 재설정
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 이메일 저장 체크박스
                            Expanded(
                              child: Row(
                                children: [
                                  Transform.scale(
                                    scale: 0.9,
                                    child: Checkbox(
                                      value: _rememberEmail,
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberEmail = value ?? false;
                                          if (!_rememberEmail) {
                                            _autoLogin = false;
                                          }
                                        });
                                      },
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '이메일 저장',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 비밀번호 재설정
                            TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: Text(
                                '비밀번호 재설정',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: _isMobile ? 32 : 40),
                        
                        // 로그인 버튼 - 모던한 그라데이션
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF2196F3),
                                Color(0xFF1976D2),
                              ],
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
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
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
                                    '로그인',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // 회원가입 버튼 - 깔끔한 아웃라인
                        SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: isDark ? Colors.grey[850] : Colors.transparent,
                            ),
                            child: Text(
                              '회원가입',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.grey[800],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: _isMobile ? 40 : 48),
                        
                        // 소셜 로그인 버튼들 (Google, Kakao, Apple)
                        SocialLoginButtons(
                          onGooglePressed: _isSocialLoginLoading ? null : _handleGoogleLogin,
                          onKakaoPressed: _isSocialLoginLoading ? null : _handleKakaoLogin,
                          onApplePressed: _isSocialLoginLoading ? null : _handleAppleLogin,
                          isLoading: _isSocialLoginLoading,
                        ),
                        
                        SizedBox(height: _isMobile ? 24 : 32),
                        
                        // 하단 정보
                        Center(
                          child: Text(
                            'MAKECALL © ${DateTime.now().year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[600] : Colors.grey[500],
                              letterSpacing: 0.5,
                            ),
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
