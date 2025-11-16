import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import '../../utils/dialog_utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Platform detection
  bool get _isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  bool get _isWeb => kIsWeb;

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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (kDebugMode) {
        print('✅ 비밀번호 재설정 이메일 전송 성공: ${_emailController.text.trim()}');
      }

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });

      if (mounted) {
        await DialogUtils.showSuccess(
          context,
          '비밀번호 재설정 이메일이 발송되었습니다.\n이메일을 확인해주세요.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('❌ 비밀번호 재설정 이메일 전송 실패: ${e.code} - ${e.message}');
      }
      
      String message = '비밀번호 재설정 이메일 발송에 실패했습니다.';
      
      switch (e.code) {
        case 'user-not-found':
          message = '등록되지 않은 이메일입니다.';
          break;
        case 'invalid-email':
          message = '올바르지 않은 이메일 형식입니다.';
          break;
        case 'too-many-requests':
          message = '너무 많은 요청이 발생했습니다.\n잠시 후 다시 시도해주세요.';
          break;
      }

      if (mounted) {
        await DialogUtils.showError(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
                vertical: 32.0,
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
                                  color: const Color(0xFF2196F3)
                                      .withValues(alpha: 0.15),
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

                        // Icon & Title
                        if (!_emailSent) ...[
                          Icon(
                            Icons.lock_reset_rounded,
                            size: 64,
                            color: const Color(0xFF2196F3).withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '비밀번호 재설정',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : (_isWeb ? Colors.grey[900] : Colors.black87),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '가입하신 이메일 주소를 입력하시면\n비밀번호 재설정 링크를 보내드립니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.mark_email_read_rounded,
                            size: 80,
                            color: Colors.green[600],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '이메일 발송 완료',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_emailController.text.trim()}\n위 이메일로 비밀번호 재설정 링크를 발송했습니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              height: 1.6,
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),

                        if (!_emailSent) ...[
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
                          const SizedBox(height: 24),

                          // Submit Button (Gradient)
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
                                  color: const Color(0xFF2196F3)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleResetPassword,
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
                                      '재설정 이메일 보내기',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ] else ...[
                          // Success - Instructions
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : Colors.green.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.green[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '다음 단계',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildInstructionStep(context, '1', '이메일을 확인하세요'),
                                const SizedBox(height: 8),
                                _buildInstructionStep(context, '2', '비밀번호 재설정 링크를 클릭하세요'),
                                const SizedBox(height: 8),
                                _buildInstructionStep(context, '3', '새로운 비밀번호를 설정하세요'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Back to Login Button
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: Color(0xFF2196F3),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              '로그인 화면으로 돌아가기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Back to Login Link
                        if (!_emailSent)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '비밀번호가 기억나셨나요?',
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

  Widget _buildInstructionStep(BuildContext context, String number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.green[600],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
