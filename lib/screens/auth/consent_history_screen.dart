import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/consent_record.dart';

/// 📜 동의 이력 뷰어 화면
class ConsentHistoryScreen extends StatelessWidget {
  const ConsentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final userModel = authService.currentUserModel;

    if (userModel == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('동의 이력'),
        ),
        body: const Center(
          child: Text('사용자 정보를 찾을 수 없습니다.'),
        ),
      );
    }

    final consentHistory = userModel.consentHistory ?? [];
    final dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm');

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFF2196F3),
        title: const Text('동의 이력'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 현재 동의 상태 요약
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: userModel.hasValidConsent
                            ? Colors.green
                            : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '현재 동의 상태',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildStatusRow(
                    '이용약관',
                    userModel.termsAgreed,
                    userModel.termsAgreedAt,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  
                  _buildStatusRow(
                    '개인정보처리방침',
                    userModel.privacyPolicyAgreed,
                    userModel.privacyPolicyAgreedAt,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  
                  _buildStatusRow(
                    '마케팅 수신 동의',
                    userModel.marketingConsent ?? false,
                    userModel.marketingConsentAt,
                    isDark,
                    isOptional: true,
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '다음 동의 갱신일',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userModel.nextConsentCheckDue != null
                        ? dateFormat.format(userModel.nextConsentCheckDue!.toDate())
                        : '정보 없음',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: userModel.needsConsentRenewal
                          ? Colors.red
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  
                  if (userModel.needsConsentRenewal) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '동의 갱신이 필요합니다',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 이력 목록 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '동의 이력 (${consentHistory.length}건)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            // 이력 목록
            Expanded(
              child: consentHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 64,
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '동의 이력이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: consentHistory.length,
                      itemBuilder: (context, index) {
                        // 최신 이력이 위로 오도록 역순 정렬
                        final record = consentHistory[consentHistory.length - 1 - index];
                        return _buildHistoryItem(record, isDark, dateFormat);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상태 행 빌더
  Widget _buildStatusRow(
    String label,
    bool agreed,
    DateTime? agreedAt,
    bool isDark, {
    bool isOptional = false,
  }) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    
    return Row(
      children: [
        Icon(
          agreed ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: agreed
              ? Colors.green
              : (isOptional ? Colors.grey : Colors.red),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              if (agreedAt != null)
                Text(
                  dateFormat.format(agreedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
        Text(
          agreed ? '동의' : '미동의',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: agreed
                ? Colors.green
                : (isOptional ? (isDark ? Colors.grey[500] : Colors.grey[600]) : Colors.red),
          ),
        ),
      ],
    );
  }

  /// 이력 아이템 빌더
  Widget _buildHistoryItem(
    ConsentRecord record,
    bool isDark,
    DateFormat dateFormat,
  ) {
    String typeLabel;
    Color typeColor;
    IconData typeIcon;

    switch (record.type) {
      case 'initial':
        typeLabel = '최초 동의';
        typeColor = Colors.blue;
        typeIcon = Icons.new_releases;
        break;
      case 'renewal':
        typeLabel = '갱신';
        typeColor = Colors.green;
        typeIcon = Icons.refresh;
        break;
      case 'update':
        typeLabel = '수정';
        typeColor = Colors.orange;
        typeIcon = Icons.edit;
        break;
      default:
        typeLabel = '기타';
        typeColor = Colors.grey;
        typeIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              typeIcon,
              color: typeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(record.agreedAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '버전 ${record.version}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
