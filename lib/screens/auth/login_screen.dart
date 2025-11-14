import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/account_manager_service.dart';
import '../../utils/dialog_utils.dart';
import 'signup_screen.dart';

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
  
  // 플랫폼 감지
  bool get _isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  bool get _isWeb => kIsWeb;
  
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
  
  // 비밀번호 찾기
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      await DialogUtils.showWarning(
        context,
        '이메일을 입력해주세요',
      );
      return;
    }
    
    if (!email.contains('@')) {
      await DialogUtils.showWarning(
        context,
        '올바른 이메일 형식이 아닙니다',
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('비밀번호 재설정'),
        content: Text('$email\n\n위 이메일로 비밀번호 재설정 링크를 보내시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('전송'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final authService = context.read<AuthService>();
      await authService.resetPassword(email);
      
      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          '비밀번호 재설정 이메일을 전송했습니다. 이메일을 확인해주세요.',
          duration: const Duration(seconds: 5),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          context.read<AuthService>().getErrorMessage(e.code),
        );
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
    
    return Scaffold(
      backgroundColor: _isWeb ? Colors.grey[50] : Colors.white,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                                  blurRadius: 40,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
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
                            color: Colors.grey[600],
                            letterSpacing: 0.3,
                          ),
                        ),
                        
                        SizedBox(height: _isMobile ? 48 : 56),
                        
                        // 이메일 입력 - 모던한 스타일
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: '이메일',
                            hintText: 'example@email.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: _isWeb ? Colors.white : Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: '비밀번호',
                            hintText: '6자 이상 입력',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: _isWeb ? Colors.white : Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
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
                        
                        // 옵션 및 비밀번호 찾기
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
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 비밀번호 찾기
                            TextButton(
                              onPressed: _handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: Text(
                                '비밀번호 찾기',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
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
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              '회원가입',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(height: _isMobile ? 24 : 32),
                        
                        // 하단 정보
                        Center(
                          child: Text(
                            'MAKECALL © ${DateTime.now().year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
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
