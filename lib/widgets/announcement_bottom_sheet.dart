import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/announcement_service.dart';

/// 📢 공지사항 ModalBottomSheet
/// 
/// Firebase Firestore의 공지사항을 표시하는 BottomSheet입니다.
/// 
/// 주요 기능:
/// - Firebase Firestore에서 공지사항 조회
/// - "다시 보지 않기" 체크박스 제공
/// - 오른쪽 상단 닫기 버튼 (X)
/// - 다크모드 최적화
class AnnouncementBottomSheet extends StatefulWidget {
  final AnnouncementData announcement;
  
  const AnnouncementBottomSheet({
    super.key,
    required this.announcement,
  });
  
  /// 공지사항 BottomSheet 표시
  /// 
  /// [context]: BuildContext
  /// [announcement]: 표시할 공지사항 데이터
  static Future<void> show(
    BuildContext context,
    AnnouncementData announcement,
  ) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => AnnouncementBottomSheet(
        announcement: announcement,
      ),
    );
  }

  @override
  State<AnnouncementBottomSheet> createState() => _AnnouncementBottomSheetState();
}

class _AnnouncementBottomSheetState extends State<AnnouncementBottomSheet> {
  bool _dontShowAgain = false;

  /// "다시 보지 않기" 상태를 SharedPreferences에 저장
  Future<void> _saveDontShowAgainState() async {
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'announcement_hidden_${widget.announcement.id}';
      await prefs.setBool(key, true);
      debugPrint('📢 [ANNOUNCEMENT] 다시 보지 않기 설정: ${widget.announcement.id}');
    }
  }

  /// 닫기 버튼 클릭 처리
  Future<void> _handleClose() async {
    await _saveDontShowAgainState();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF212121) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 헤더 (닫기 버튼)
            _buildHeader(isDark),
            
            // 공지사항 내용
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 우선순위 배지 + 제목
                    _buildTitle(isDark),
                    const SizedBox(height: 20),
                    
                    // 공지사항 메시지
                    _buildMessage(isDark),
                    const SizedBox(height: 24),
                    
                    // 날짜 정보
                    _buildDateInfo(isDark),
                  ],
                ),
              ),
            ),
            
            // 하단 액션 영역 ("다시 보지 않기" 체크박스)
            _buildBottomActions(isDark),
          ],
        ),
      ),
    );
  }

  /// 상단 헤더 (닫기 버튼)
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 공지사항 라벨
          Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 20,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                '공지사항',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          
          // 닫기 버튼 (X)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _handleClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 24,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 우선순위 배지 + 제목
  Widget _buildTitle(bool isDark) {
    final priorityColor = _getPriorityColor(widget.announcement.priority);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 우선순위 배지
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: priorityColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: priorityColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.announcement.priorityIcon,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 4),
              Text(
                _getPriorityText(widget.announcement.priority),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: priorityColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        
        // 제목
        Expanded(
          child: Text(
            widget.announcement.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  /// 공지사항 메시지
  Widget _buildMessage(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF383838).withValues(alpha: 0.5)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF424242)
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Text(
        widget.announcement.message,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
        ),
      ),
    );
  }

  /// 날짜 정보
  Widget _buildDateInfo(bool isDark) {
    if (widget.announcement.startDate == null && widget.announcement.endDate == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF383838).withValues(alpha: 0.3)
            : const Color(0xFFF5F5F5).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '공지 기간: ${_formatDate(widget.announcement.startDate)} ~ ${_formatDate(widget.announcement.endDate)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 하단 액션 영역 ("다시 보지 않기" 체크박스)
  Widget _buildBottomActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // "다시 보지 않기" 체크박스
          GestureDetector(
            onTap: () {
              setState(() {
                _dontShowAgain = !_dontShowAgain;
              });
            },
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _dontShowAgain,
                    onChanged: (value) {
                      setState(() {
                        _dontShowAgain = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF1976D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '다시 보지 않기',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // 확인 버튼
          ElevatedButton(
            onPressed: _handleClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              '확인',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 우선순위 색상 변환
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return const Color(0xFFEF5350); // 빨강
      case 'low':
        return const Color(0xFF66BB6A); // 초록
      case 'normal':
      default:
        return const Color(0xFF1976D2); // 파랑
    }
  }

  /// 우선순위 텍스트 변환
  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return '중요';
      case 'low':
        return '일반';
      case 'normal':
      default:
        return '공지';
    }
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
