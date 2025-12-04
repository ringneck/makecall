import 'package:flutter/material.dart';
import '../../utils/dialog_utils.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/fcm_token_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';

/// 활성 세션 관리 화면
/// 
/// 사용자의 모든 로그인된 기기를 표시하고 원격 로그아웃 기능을 제공합니다.
class ActiveSessionsScreen extends StatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  State<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends State<ActiveSessionsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;
  List<FcmTokenModel> _sessions = [];
  String? _error;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  /// 세션 목록 로드
  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        throw Exception('로그인 정보가 없습니다');
      }

      // 모든 FCM 토큰 조회
      final sessions = await _databaseService.getAllFcmTokens(userId);

      // 현재 기기 ID 조회 (활성 세션 표시용)
      final activeSess = await _databaseService.getActiveFcmToken(userId);
      _currentDeviceId = activeSess?.deviceId;

      setState(() {
        _sessions = sessions;
        _sessions.sort((a, b) {
          // 활성 세션을 맨 위로
          if (a.isActive && !b.isActive) return -1;
          if (!a.isActive && b.isActive) return 1;
          // 마지막 활동 시간 순으로 정렬
          return b.lastActiveAt.compareTo(a.lastActiveAt);
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 원격 로그아웃 실행
  Future<void> _remoteLogout(FcmTokenModel session) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('원격 로그아웃'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('다음 기기를 로그아웃하시겠습니까?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getPlatformIcon(session.platform),
                        size: 20,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPlatformName(session.platform),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '해당 기기에서 앱이 자동으로 로그아웃됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('원격 로그아웃 처리 중...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        throw Exception('로그인 정보가 없습니다');
      }

      // Cloud Functions 호출 (서울 리전)
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3').httpsCallable('remoteLogout');
      final result = await callable.call({
        'targetDeviceId': session.deviceId,
        'targetUserId': userId,
      });

      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      // 성공 메시지
      await DialogUtils.showSuccess(
        context,
        result.data['message'] ?? '원격 로그아웃이 완료되었습니다.',
      );

      // 세션 목록 새로고침
      _loadSessions();
    } catch (e) {
      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      // 에러 메시지
      await DialogUtils.showError(
        context,
        '원격 로그아웃 실패: $e',
      );
    }
  }

  /// 플랫폼 아이콘 가져오기
  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      case 'web':
        return Icons.web;
      default:
        return Icons.devices;
    }
  }

  /// 플랫폼 이름 가져오기
  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'ios':
        return 'iOS';
      case 'android':
        return 'Android';
      case 'web':
        return 'Web';
      default:
        return '알 수 없음';
    }
  }

  /// 시간 포맷팅
  String _formatDateTime(DateTime dateTime) {
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
      // Flutter 기본 기능으로 날짜 포맷팅 (intl 패키지 불필요)
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('활성 세션 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('오류: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSessions,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices_other, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            '활성 세션이 없습니다',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final isCurrentDevice = session.deviceId == _currentDeviceId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isCurrentDevice
                                  ? BorderSide(color: Colors.green, width: 2)
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: session.isActive
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                child: Icon(
                                  _getPlatformIcon(session.platform),
                                  color: session.isActive ? Colors.green[700] : Colors.grey[600],
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.deviceName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (isCurrentDevice)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        '현재 기기',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: session.isActive ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        session.isActive ? '활성' : '비활성',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: session.isActive ? Colors.green[700] : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getPlatformName(session.platform),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '마지막 활동: ${_formatDateTime(session.lastActiveAt)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    '로그인: ${_formatDateTime(session.createdAt)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: !isCurrentDevice
                                  ? IconButton(
                                      icon: const Icon(Icons.logout, color: Colors.red),
                                      onPressed: () => _remoteLogout(session),
                                      tooltip: '로그아웃',
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
