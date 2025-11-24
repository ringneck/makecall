import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/social_login_service.dart';

/// 소셜 로그인 사용자 동의 화면
/// 
/// 신규 소셜 로그인 사용자가 이용약관, 개인정보처리방침, 마케팅 수신 동의를 진행하는 화면
class SocialLoginConsentScreen extends StatefulWidget {
  final String userId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final SocialLoginProvider provider;

  const SocialLoginConsentScreen({
    super.key,
    required this.userId,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.provider,
  });

  @override
  State<SocialLoginConsentScreen> createState() => _SocialLoginConsentScreenState();
}

class _SocialLoginConsentScreenState extends State<SocialLoginConsentScreen> {
  bool _allAgreed = false;
  bool _termsAgreed = false;
  bool _privacyPolicyAgreed = false;
  bool _marketingConsent = false;
  bool _isProcessing = false;

  void _handleAllAgreedChanged(bool? value) {
    setState(() {
      _allAgreed = value ?? false;
      _termsAgreed = _allAgreed;
      _privacyPolicyAgreed = _allAgreed;
      _marketingConsent = _allAgreed;
    });
  }

  void _handleIndividualAgreementChanged() {
    setState(() {
      _allAgreed = _termsAgreed && _privacyPolicyAgreed && _marketingConsent;
    });
  }

  Future<void> _handleComplete() async {
    // 필수 동의 확인
    if (!_termsAgreed || !_privacyPolicyAgreed) {
      _showErrorDialog('이용약관 및 개인정보처리방침에 동의해주세요.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Firestore 사용자 문서 생성
      final now = FieldValue.serverTimestamp();
      final nowDateTime = DateTime.now(); // 배열에 사용할 DateTime
      final twoYearsLater = nowDateTime.add(const Duration(days: 730));

      final userData = {
        'uid': widget.userId,
        'email': widget.email ?? '',
        'organizationName': widget.displayName ?? '소셜 로그인 사용자',
        'profileImageUrl': widget.photoUrl,
        'role': 'user',
        'loginProvider': widget.provider.name,
        'createdAt': now,
        'updatedAt': now,
        'lastLoginAt': now,
        'isActive': true,
        'accountStatus': 'approved', // 소셜 로그인은 자동 승인
        // 동의 정보
        'consentVersion': '1.0',
        'termsAgreed': _termsAgreed,
        'termsAgreedAt': _termsAgreed ? now : null,
        'privacyPolicyAgreed': _privacyPolicyAgreed,
        'privacyPolicyAgreedAt': _privacyPolicyAgreed ? now : null,
        'marketingConsent': _marketingConsent,
        'marketingConsentAt': _marketingConsent ? now : null,
        'lastConsentCheckAt': now,
        'nextConsentCheckDue': Timestamp.fromDate(twoYearsLater),
        // 🔧 FIX: 배열 안에는 serverTimestamp 사용 불가 - DateTime.now() 사용
        'consentHistory': [
          {
            'version': '1.0',
            'agreedAt': Timestamp.fromDate(nowDateTime), // DateTime → Timestamp 변환
            'type': 'initial',
            'termsAgreed': _termsAgreed,
            'privacyPolicyAgreed': _privacyPolicyAgreed,
            'marketingConsent': _marketingConsent,
          }
        ],
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(userData);

      // 성공 - 화면 닫기 (true 반환)
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('동의 처리 중 오류가 발생했습니다.\n\n$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이용약관'),
        content: const SingleChildScrollView(
          child: Text(
            '제1조 (목적)\n'
            '이 약관은 MAKECALL 서비스 이용과 관련하여 회사와 회원 간의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
            '제2조 (정의)\n'
            '1. "서비스"란 회사가 제공하는 통화 관리 서비스를 의미합니다.\n'
            '2. "회원"이란 이 약관에 동의하고 회사와 이용계약을 체결한 자를 말합니다.\n\n'
            '제3조 (약관의 효력 및 변경)\n'
            '1. 이 약관은 서비스를 이용하고자 하는 모든 회원에게 그 효력이 발생합니다.\n'
            '2. 회사는 필요시 약관을 변경할 수 있으며, 변경된 약관은 공지 후 7일이 경과한 시점부터 효력이 발생합니다.\n\n'
            '제4조 (회원가입)\n'
            '1. 회원가입은 이용자가 약관에 동의하고 회사가 정한 절차에 따라 신청함으로써 이루어집니다.\n'
            '2. 회사는 관련 법령에 위배되거나 사회의 안녕질서 또는 미풍양속을 저해할 수 있는 경우 회원가입을 거부할 수 있습니다.\n\n'
            '제5조 (서비스의 제공 및 변경)\n'
            '회사는 다음과 같은 서비스를 제공합니다:\n'
            '- 통화 관리 서비스\n'
            '- 연락처 관리 서비스\n'
            '- 통화 기록 조회 서비스\n\n'
            '제6조 (서비스 이용의 제한)\n'
            '회사는 회원이 이 약관의 의무를 위반하거나 서비스의 정상적인 운영을 방해한 경우 서비스 이용을 제한할 수 있습니다.\n\n'
            '제7조 (개인정보보호)\n'
            '회사는 관련 법령이 정하는 바에 따라 회원의 개인정보를 보호하기 위해 노력합니다.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개인정보처리방침'),
        content: const SingleChildScrollView(
          child: Text(
            '제1조 (개인정보의 수집 및 이용 목적)\n'
            'MAKECALL은 다음의 목적을 위하여 개인정보를 수집 및 이용합니다:\n'
            '1. 회원 가입 및 관리\n'
            '2. 서비스 제공 및 통화 기록 관리\n'
            '3. 고객 문의 응대 및 불만 처리\n\n'
            '제2조 (수집하는 개인정보 항목)\n'
            '1. 필수항목: 이메일, 비밀번호, 조직명\n'
            '2. 소셜 로그인 시: 소셜 계정 정보, 프로필 사진\n'
            '3. 서비스 이용 과정에서 수집되는 정보: 통화 기록, IP 주소, 접속 기록\n\n'
            '제3조 (개인정보의 보유 및 이용기간)\n'
            '1. 회원 탈퇴 시까지 보유 및 이용\n'
            '2. 관계 법령에 따라 일정 기간 보존이 필요한 경우 해당 기간 동안 보관\n\n'
            '제4조 (개인정보의 제3자 제공)\n'
            '회사는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.\n\n'
            '제5조 (개인정보의 파기)\n'
            '회사는 개인정보 보유기간의 경과, 처리목적 달성 등 개인정보가 불필요하게 되었을 때에는 지체없이 해당 개인정보를 파기합니다.\n\n'
            '제6조 (이용자의 권리)\n'
            '이용자는 언제든지 자신의 개인정보를 조회하거나 수정할 수 있으며, 가입 해지를 요청할 수 있습니다.\n\n'
            '제7조 (개인정보 보호책임자)\n'
            '회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리를 위하여 개인정보 보호책임자를 지정하고 있습니다.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => false, // 뒤로가기 방지 (동의 필수)
      child: Scaffold(
        backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
        appBar: AppBar(
          title: const Text('서비스 이용 동의'),
          automaticallyImplyLeading: false, // 뒤로가기 버튼 숨김
          backgroundColor: isDark ? Theme.of(context).appBarTheme.backgroundColor : Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 환영 메시지
                      Text(
                        'MAKECALL에 오신 것을 환영합니다!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '서비스 이용을 위해 아래 약관에 동의해주세요.',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 전체 동의
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            '전체 동의',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            '이용약관, 개인정보처리방침, 마케팅 수신 동의 모두에 동의합니다.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          value: _allAgreed,
                          onChanged: _isProcessing ? null : _handleAllAgreedChanged,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 이용약관 동의 (필수)
                      _buildAgreementItem(
                        title: '이용약관 동의',
                        isRequired: true,
                        value: _termsAgreed,
                        onChanged: (value) {
                          setState(() {
                            _termsAgreed = value ?? false;
                            _handleIndividualAgreementChanged();
                          });
                        },
                        onViewDetails: _showTermsDialog,
                      ),

                      const SizedBox(height: 16),

                      // 개인정보처리방침 동의 (필수)
                      _buildAgreementItem(
                        title: '개인정보처리방침 동의',
                        isRequired: true,
                        value: _privacyPolicyAgreed,
                        onChanged: (value) {
                          setState(() {
                            _privacyPolicyAgreed = value ?? false;
                            _handleIndividualAgreementChanged();
                          });
                        },
                        onViewDetails: _showPrivacyPolicyDialog,
                      ),

                      const SizedBox(height: 16),

                      // 마케팅 수신 동의 (선택)
                      _buildAgreementItem(
                        title: '마케팅 수신 동의',
                        isRequired: false,
                        value: _marketingConsent,
                        onChanged: (value) {
                          setState(() {
                            _marketingConsent = value ?? false;
                            _handleIndividualAgreementChanged();
                          });
                        },
                        description: '이벤트, 프로모션 등의 마케팅 정보를 수신합니다.',
                      ),
                    ],
                  ),
                ),
              ),

              // 하단 버튼
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing || !_termsAgreed || !_privacyPolicyAgreed
                        ? null
                        : _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            '동의하고 시작하기',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementItem({
    required String title,
    required bool isRequired,
    required bool value,
    required ValueChanged<bool?> onChanged,
    VoidCallback? onViewDetails,
    String? description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: value,
                onChanged: _isProcessing ? null : onChanged,
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(
                        text: isRequired ? ' (필수)' : ' (선택)',
                        style: TextStyle(
                          color: isRequired
                              ? const Color(0xFF2196F3)
                              : (isDark ? Colors.grey[500] : Colors.grey[600]),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onViewDetails != null)
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text(
                    '보기',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
