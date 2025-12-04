import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../utils/dialog_utils.dart';

/// 🔄 동의 갱신 화면 (2년 주기 재동의)
class ConsentRenewalScreen extends StatefulWidget {
  const ConsentRenewalScreen({super.key});

  @override
  State<ConsentRenewalScreen> createState() => _ConsentRenewalScreenState();
}

class _ConsentRenewalScreenState extends State<ConsentRenewalScreen> {
  bool _isLoading = false;
  
  // 동의 항목 상태
  bool _allAgreed = false;
  bool _termsAgreed = false;
  bool _privacyPolicyAgreed = false;
  bool _marketingConsent = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      // 뒤로가기 비활성화 (반드시 동의해야 함)
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : const Color(0xFF2196F3),
          automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
          title: const Text('약관 재동의'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 안내 메시지
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.orange[900]!.withAlpha(77)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.orange[700]!
                              : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: isDark ? Colors.orange[300] : Colors.orange[700],
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '약관 재동의 필요',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.orange[300] : Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '개인정보보호법에 따라 2년마다 약관 동의가 필요합니다.\n'
                            '계속 서비스를 이용하시려면 아래 약관에 다시 동의해주세요.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.orange[200] : Colors.orange[900],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // 동의 항목
                    _buildConsentSection(isDark),
                    const SizedBox(height: 32),
                    
                    // 동의 버튼
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
                            : _handleRenewal,
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
                                '동의하고 계속하기',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 로그아웃 버튼
                    TextButton(
                      onPressed: _isLoading ? null : _handleLogout,
                      child: Text(
                        '로그아웃',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
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
    );
  }

  /// 동의 섹션 UI
  Widget _buildConsentSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey.withValues(alpha: 0.05),
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

  /// 전체 동의 상태 업데이트
  void _updateAllAgreed() {
    setState(() {
      _allAgreed = _termsAgreed && _privacyPolicyAgreed && _marketingConsent;
    });
  }

  /// 이용약관 보기
  Future<void> _showTermsDialog(BuildContext context) async {
    final Uri url = Uri.parse('https://app.makecall.io/terms_of_service.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    } else {
      if (mounted) {
        await DialogUtils.showError(context, '이용약관을 열 수 없습니다.');
      }
    }
  }

  /// 개인정보처리방침 보기
  Future<void> _showPrivacyPolicyDialog(BuildContext context) async {
    final Uri url = Uri.parse('https://app.makecall.io/privacy_policy.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    } else {
      if (mounted) {
        await DialogUtils.showError(context, '개인정보처리방침을 열 수 없습니다.');
      }
    }
  }

  /// 동의 갱신 처리
  Future<void> _handleRenewal() async {
    if (!_termsAgreed || !_privacyPolicyAgreed) {
      await DialogUtils.showWarning(
        context,
        '필수 항목에 모두 동의해주세요\n\n- 이용약관\n- 개인정보처리방침',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다.');
      }

      // Firestore 업데이트
      final now = Timestamp.now();
      final twoYearsLater = DateTime.now().add(const Duration(days: 730));

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'consentVersion': '1.0',
        'termsAgreed': _termsAgreed,
        'termsAgreedAt': now,
        'privacyPolicyAgreed': _privacyPolicyAgreed,
        'privacyPolicyAgreedAt': now,
        'marketingConsent': _marketingConsent,
        'marketingConsentAt': _marketingConsent ? now : null,
        'lastConsentCheckAt': now,
        'nextConsentCheckDue': Timestamp.fromDate(twoYearsLater),
        'consentHistory': FieldValue.arrayUnion([
          {
            'version': '1.0',
            'agreedAt': now,
            'type': 'renewal',
          }
        ]),
      });

      // AuthService의 사용자 정보 갱신
      await authService.reloadCurrentUser();

      // ✅ 메시지 없이 자동 화면 전환
      // AuthService.notifyListeners()가 호출되면
      // main.dart의 Consumer<AuthService>가 rebuild되면서 자동으로 MainScreen으로 이동
    } catch (e) {
      if (mounted) {
        await DialogUtils.showError(
          context,
          '동의 처리 중 오류가 발생했습니다: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 로그아웃 처리
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('약관에 동의하지 않으면 서비스를 이용할 수 없습니다.\n로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = context.read<AuthService>();
      await authService.signOut();
    }
  }
}
