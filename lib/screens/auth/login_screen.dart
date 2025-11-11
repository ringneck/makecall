import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/account_manager_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? prefilledEmail; // 계정 전환 시 자동으로 채울 이메일
  
  const LoginScreen({super.key, this.prefilledEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = true; // 초기값을 true로 변경 (자동 로그인 체크 중)
  bool _obscurePassword = true;
  bool _rememberEmail = false;
  bool _autoLogin = false;
  bool _isAutoLoginAttempting = false; // 자동 로그인 시도 중 플래그
  
  static const String _keyRememberEmail = 'remember_email';
  static const String _keySavedEmail = 'saved_email';
  static const String _keyAutoLogin = 'auto_login';

  @override
  void initState() {
    super.initState();
    // 즉시 자동 로그인 체크 및 시도
    _checkAndAutoLogin();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      
      // 자동 로그인 시도 (계정 전환 시)
      // 🚫 멀티 계정 기능 비활성화
      /* if (switchTargetEmail != null && switchTargetEmail.isNotEmpty) {
        setState(() => _isAutoLoginAttempting = true);
        
        final success = await _tryAutoLogin(switchTargetEmail);
        
        if (success) {
          // 자동 로그인 성공 - LoginScreen을 보여주지 않음
          if (kDebugMode) {
            debugPrint('✅ Auto-login successful, skipping login screen');
          }
          return; // LoginScreen을 표시하지 않고 종료
        }
      } */
      
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
      }
    }
  }
  
  // 자동 로그인 시도 (성공 여부 반환)
  // 🚫 멀티 계정 기능 비활성화
  /* Future<bool> _tryAutoLogin(String email) async {
    try {
      // 자동 로그인 설정 확인
      final autoLoginEnabled = await AccountManagerService().getKeepLoginEnabled();
      if (!autoLoginEnabled) {
        if (kDebugMode) {
          debugPrint('⚠️ Auto login disabled, manual login required');
        }
        return false;
      }
      
      // 저장된 계정 목록에서 해당 계정 찾기
      final accounts = await AccountManagerService().getSavedAccounts();
      final targetAccount = accounts.firstWhere(
        (acc) => acc.email.toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('Account not found'),
      );
      
      // 저장된 비밀번호 확인
      if (targetAccount.encryptedPassword == null) {
        if (kDebugMode) {
          debugPrint('⚠️ No saved password, manual login required');
        }
        return false;
      }
      
      // 비밀번호 복호화
      final password = AccountManagerService().decryptPassword(targetAccount.encryptedPassword);
      if (password == null) {
        if (kDebugMode) {
          debugPrint('❌ Password decryption failed');
        }
        return false;
      }
      
      if (kDebugMode) {
        debugPrint('🔑 Attempting auto-login for: $email');
      }
      
      // 자동 로그인 실행
      final authService = context.read<AuthService>();
      await authService.signIn(
        email: email,
        password: password,
      );
      
      if (kDebugMode) {
        debugPrint('✅ Auto-login successful!');
      }
      
      return true; // 성공
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Auto-login failed: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('자동 로그인 실패: 비밀번호를 입력해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      return false; // 실패
    }
  } */
  
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
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      // 로그인 성공 시 이메일 저장 설정 적용
      await _saveCredentials();
      
      // ✏️ 비밀번호는 AuthService.signIn()에서 자동으로 저장됨
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<AuthService>().getErrorMessage(e.code)),
            backgroundColor: Colors.red,
          ),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일을 입력해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('올바른 이메일 형식이 아닙니다'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('비밀번호 재설정 이메일을 전송했습니다. 이메일을 확인해주세요.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<AuthService>().getErrorMessage(e.code)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 자동 로그인 시도 중일 때는 로딩 화면만 표시
    if (_isAutoLoginAttempting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                '자동 로그인 중...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 로고 이미지 - 고급스러운 스타일
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2196F3).withValues(alpha: 0.1),
                          const Color(0xFF1976D2).withValues(alpha: 0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.network(
                      'https://cdn1.genspark.ai/user-upload-image/rmbg_generated/0_fb40465b-fd3f-4909-83f7-523e4174d3bc',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.phone_in_talk,
                          size: 80,
                          color: Color(0xFF2196F3),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          width: 120,
                          height: 120,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '당신의 더 나은 커뮤니케이션',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
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
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: '비밀번호',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
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
                  const SizedBox(height: 8),
                  // 이메일 저장 및 로그인 유지 체크박스
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          value: _rememberEmail,
                          onChanged: (value) {
                            setState(() {
                              _rememberEmail = value ?? false;
                              if (!_rememberEmail) {
                                _autoLogin = false;
                              }
                            });
                          },
                          title: const Text(
                            '이메일 저장',
                            style: TextStyle(fontSize: 14),
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          value: _autoLogin,
                          onChanged: _rememberEmail
                              ? (value) {
                                  setState(() {
                                    _autoLogin = value ?? false;
                                  });
                                }
                              : null,
                          title: const Text(
                            '로그인 유지',
                            style: TextStyle(fontSize: 14),
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
                  // 비밀번호 찾기 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: const Text(
                        '비밀번호를 잊으셨나요?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '로그인',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF2196F3)),
                    ),
                    child: const Text(
                      '회원가입',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
