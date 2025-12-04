import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('🔍 [MaxDeviceLimitDialog] 활성 기기 목록 로드 시작');
      debugPrint('   userId: ${widget.userId}');
      
      // ✅ Exception에 기기 목록이 포함되어 있으면 바로 사용 (권한 오류 방지)
      if (widget.exception.activeDevices != null && widget.exception.activeDevices!.isNotEmpty) {
        debugPrint('✅ [MaxDeviceLimitDialog] Exception에서 기기 목록 사용 (권한 오류 방지)');
        debugPrint('   기기 수: ${widget.exception.activeDevices!.length}개');
        
        if (mounted) {
          setState(() {
            _activeDevices = widget.exception.activeDevices!;
            _isLoading = false;
          });
        }
        return;
      }
      
      // ⚠️ Fallback: Exception에 기기 목록이 없으면 Firestore 조회 시도
      // (로그아웃 전이라면 조회 가능)
      debugPrint('⚠️  [MaxDeviceLimitDialog] Exception에 기기 목록 없음 - Firestore 조회 시도');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('fcm_tokens')
          .where('userId', isEqualTo: widget.userId)  // ← 카멜케이스로 수정
          .where('isActive', isEqualTo: true)         // ← 카멜케이스로 수정
          .get();

      debugPrint('📊 [MaxDeviceLimitDialog] 조회 결과: ${querySnapshot.docs.length}개');

      if (mounted) {
        setState(() {
          _activeDevices = querySnapshot.docs.map((doc) {
            final data = doc.data();
            debugPrint('   - ${data['deviceName']} (${data['platform']})');
            return {
              'device_name': data['deviceName'] ?? 'Unknown Device',  // ← 카멜케이스
              'platform': data['platform'] ?? 'Unknown',
              'last_updated': data['lastActiveAt'] as Timestamp?,      // ← 실제 Firestore 필드명 (lastActiveAt)
            };
          }).toList();
          _isLoading = false;
        });
      }
      
      debugPrint('✅ [MaxDeviceLimitDialog] 활성 기기 목록 로드 완료');
    } catch (e) {
      debugPrint('⚠️  [MaxDeviceLimitDialog] 활성 기기 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  String _formatLastUpdatedFromDateTime(DateTime? dateTime) {
    if (dateTime == null) return '알 수 없음';
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
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
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
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
                // ✅ 플랫폼 호환성: Timestamp/DateTime 타입 안전 처리
                final lastUpdatedRaw = device['last_updated'];
                
                // 🔍 디버그: 받은 데이터 타입 확인
                if (kDebugMode) {
                  print('🔍 [MaxDeviceLimit Dialog] 기기: $deviceName');
                  print('   - last_updated 타입: ${lastUpdatedRaw.runtimeType}');
                  print('   - last_updated 값: $lastUpdatedRaw');
                }
                
                final DateTime? lastUpdatedDateTime;
                if (lastUpdatedRaw is Timestamp) {
                  lastUpdatedDateTime = lastUpdatedRaw.toDate();
                } else if (lastUpdatedRaw is DateTime) {
                  lastUpdatedDateTime = lastUpdatedRaw;
                } else {
                  lastUpdatedDateTime = null;
                  if (kDebugMode) {
                    print('   ⚠️ last_updated가 null이거나 지원되지 않는 타입입니다');
                  }
                }
                
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
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
                              '마지막 활동: ${_formatLastUpdatedFromDateTime(lastUpdatedDateTime)}',
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
