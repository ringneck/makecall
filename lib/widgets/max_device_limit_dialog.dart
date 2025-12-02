import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/max_device_limit_exception.dart';

/// 최대 기기 수 초과 다이얼로그 (로그인/회원가입 공통)
class MaxDeviceLimitDialog extends StatefulWidget {
  final MaxDeviceLimitException exception;
  final String userId;
  final VoidCallback? onConfirm; // 확인 버튼 클릭 시 실행할 콜백

  const MaxDeviceLimitDialog({
    super.key,
    required this.exception,
    required this.userId,
    this.onConfirm,
  });

  @override
  State<MaxDeviceLimitDialog> createState() => _MaxDeviceLimitDialogState();
}

class _MaxDeviceLimitDialogState extends State<MaxDeviceLimitDialog> {
  List<Map<String, dynamic>> _activeDevices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveDevices();
  }

  /// Firestore에서 활성 기기 목록 조회
  Future<void> _loadActiveDevices() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .where('user_id', isEqualTo: widget.userId)
          .where('is_active', isEqualTo: true)
          .orderBy('last_updated', descending: true)
          .get();

      setState(() {
        _activeDevices = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'device_name': data['device_name'] ?? 'Unknown Device',
            'platform': data['platform'] ?? 'Unknown',
            'last_updated': data['last_updated'] as Timestamp?,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('⚠️  [MaxDeviceLimitDialog] 활성 기기 목록 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatLastUpdated(Timestamp? timestamp) {
    if (timestamp == null) return '알 수 없음';
    
    final now = DateTime.now();
    final lastUpdated = timestamp.toDate();
    final difference = now.difference(lastUpdated);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${lastUpdated.year}-${lastUpdated.month.toString().padLeft(2, '0')}-${lastUpdated.day.toString().padLeft(2, '0')}';
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.apple;
      case 'web':
        return Icons.language;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
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
            
            // 기기 수 정보 카드
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
                        '기기 사용 현황',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 활성 기기 수 / 최대 허용 기기 수
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.exception.currentDevices}개',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '/ ${widget.exception.maxDevices}개 (최대)',
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
                            '시도한 기기: ${widget.exception.deviceName}',
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
            
            // 활성 기기 목록
            if (_isLoading) ...[
              const SizedBox(height: 20),
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ] else if (_activeDevices.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(
                color: theme.colorScheme.outlineVariant,
                thickness: 1,
              ),
              const SizedBox(height: 16),
              
              // 활성 기기 목록 헤더
              Row(
                children: [
                  Icon(
                    Icons.smartphone,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '현재 활성 기기 목록',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 기기 목록
              ..._activeDevices.asMap().entries.map((entry) {
                final index = entry.key;
                final device = entry.value;
                final deviceName = device['device_name'] as String;
                final platform = device['platform'] as String;
                final lastUpdated = device['last_updated'] as Timestamp?;
                
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index < _activeDevices.length - 1 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHigh
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 플랫폼 아이콘
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getPlatformIcon(platform),
                          size: 20,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 기기 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '마지막 활동: ${_formatLastUpdated(lastUpdated)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
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
                // 확인 버튼 클릭 시 콜백 실행 (LoginScreen으로 이동)
                widget.onConfirm?.call();
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
    );
  }
}
