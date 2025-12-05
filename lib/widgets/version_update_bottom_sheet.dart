import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/version_check_service.dart';

/// 🔄 버전 업데이트 안내 ModalBottomSheet
/// 
/// 기능:
/// - 새 버전 설치 안내
/// - "오늘 하루 보지 않기" 기능
/// - 우측 상단 닫기 버튼
/// - 다크모드 최적화 UI/UX
class VersionUpdateBottomSheet extends StatelessWidget {
  final VersionCheckResult versionResult;
  final String? downloadUrl; // 앱 다운로드 URL (Play Store, App Store 등)

  const VersionUpdateBottomSheet({
    super.key,
    required this.versionResult,
    this.downloadUrl,
  });

  /// BottomSheet 표시 (하루 한 번 체크)
  static Future<void> show(
    BuildContext context,
    VersionCheckResult versionResult, {
    String? downloadUrl,
  }) async {
    // 강제 업데이트가 아니면 "오늘 하루 보지 않기" 체크
    if (!versionResult.isForceUpdate) {
      final prefs = await SharedPreferences.getInstance();
      final lastDismissed = prefs.getString('version_update_dismissed_date');
      final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

      if (lastDismissed == today) {
        // 오늘 이미 닫기 버튼을 누른 경우
        return;
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !versionResult.isForceUpdate, // 강제 업데이트 시 스와이프로 닫기 불가
      enableDrag: !versionResult.isForceUpdate,
      backgroundColor: Colors.transparent,
      builder: (context) => VersionUpdateBottomSheet(
        versionResult: versionResult,
        downloadUrl: downloadUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더: 타이틀 + 닫기 버튼
              _buildHeader(context, isDark),
              
              const SizedBox(height: 24),
              
              // 버전 정보
              _buildVersionInfo(isDark),
              
              const SizedBox(height: 20),
              
              // 업데이트 메시지
              if (versionResult.updateMessage != null) ...[
                _buildUpdateMessage(isDark),
                const SizedBox(height: 24),
              ],
              
              // 버튼들
              _buildActionButtons(context, isDark),
              
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// 헤더 (타이틀 + 닫기 버튼)
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        // 아이콘
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: versionResult.isForceUpdate
                ? const Color(0xFFEF5350).withValues(alpha: 0.1)
                : const Color(0xFF1976D2).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            versionResult.isForceUpdate ? Icons.system_update_alt : Icons.update,
            color: versionResult.isForceUpdate
                ? const Color(0xFFEF5350)
                : const Color(0xFF1976D2),
            size: 24,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // 타이틀
        Expanded(
          child: Text(
            versionResult.isForceUpdate ? '필수 업데이트' : '새 버전 업데이트',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF212121),
            ),
          ),
        ),
        
        // 닫기 버튼 (강제 업데이트가 아닐 때만)
        if (!versionResult.isForceUpdate)
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  /// 버전 정보
  Widget _buildVersionInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 현재 버전
          _buildVersionColumn(
            '현재 버전',
            versionResult.currentVersion,
            isDark,
            isOld: true,
          ),
          
          // 화살표
          Icon(
            Icons.arrow_forward,
            color: isDark ? Colors.white38 : Colors.black38,
            size: 20,
          ),
          
          // 최신 버전
          _buildVersionColumn(
            '최신 버전',
            versionResult.latestVersion,
            isDark,
            isNew: true,
          ),
        ],
      ),
    );
  }

  /// 버전 컬럼
  Widget _buildVersionColumn(
    String label,
    String version,
    bool isDark, {
    bool isOld = false,
    bool isNew = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isNew
                ? const Color(0xFF1976D2).withValues(alpha: 0.1)
                : (isDark ? const Color(0xFF383838) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: isNew
                ? Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.3))
                : null,
          ),
          child: Text(
            version,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isNew ? FontWeight.bold : FontWeight.w600,
              color: isNew
                  ? const Color(0xFF1976D2)
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ),
      ],
    );
  }

  /// 업데이트 메시지
  Widget _buildUpdateMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1976D2).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF1976D2),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              versionResult.updateMessage!,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF424242),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 액션 버튼들
  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 업데이트 버튼
        ElevatedButton(
          onPressed: () => _handleUpdate(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: versionResult.isForceUpdate
                ? const Color(0xFFEF5350)
                : const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.system_update_alt, size: 20),
              const SizedBox(width: 8),
              Text(
                versionResult.isForceUpdate ? '지금 업데이트' : '업데이트',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // "오늘 하루 보지 않기" 버튼 (선택적 업데이트일 때만)
        if (!versionResult.isForceUpdate) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _handleDismissToday(context),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '오늘 하루 보지 않기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 업데이트 버튼 처리
  Future<void> _handleUpdate(BuildContext context) async {
    if (downloadUrl != null && downloadUrl!.isNotEmpty) {
      final uri = Uri.parse(downloadUrl!);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('앱 스토어를 열 수 없습니다.'),
            backgroundColor: Color(0xFFEF5350),
          ),
        );
      }
    } else {
      // 다운로드 URL이 없으면 스낵바로 안내
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('다운로드 링크가 설정되지 않았습니다.'),
          backgroundColor: Color(0xFFFF9800),
        ),
      );
    }
    
    // 강제 업데이트가 아니면 바텀시트 닫기
    if (!versionResult.isForceUpdate && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// "오늘 하루 보지 않기" 처리
  Future<void> _handleDismissToday(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    await prefs.setString('version_update_dismissed_date', today);
    
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}
