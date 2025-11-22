import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../services/database_service.dart';
import '../../../services/mobile_contacts_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/contact_model.dart';
import '../../../utils/dialog_utils.dart';
import 'permission_handler.dart';

/// 🔧 ContactManager Service
/// 
/// **책임 (Single Responsibility)**:
/// - 연락처 상태 관리 (장치 연락처, 로딩 상태)
/// - 장치 연락처 불러오기/숨기기 토글
/// - 즐겨찾기 추가/제거 토글
/// - 연락처 데이터 처리
/// 
/// **설계 패턴**:
/// - Service Pattern: 비즈니스 로직 캡슐화
/// - Dependency Injection: 필요한 서비스 주입
/// - State Management: 연락처 상태 캡슐화
/// - Callback Pattern: UI 업데이트를 위한 콜백
/// 
/// **사용 예시**:
/// ```dart
/// // 초기화
/// _contactManager = ContactManager(
///   databaseService: _databaseService,
///   mobileContactsService: _mobileContactsService,
///   permissionHandler: _permissionHandler,
///   onStateChanged: () => setState(() {}),
/// );
/// 
/// // 장치 연락처 토글
/// await _contactManager.toggleDeviceContacts(context, authService);
/// 
/// // 즐겨찾기 토글
/// await _contactManager.toggleFavorite(context, contact);
/// ```
class ContactManager {
  final DatabaseService databaseService;
  final MobileContactsService mobileContactsService;
  final PermissionHandler permissionHandler;
  final VoidCallback onStateChanged;
  
  // 🔒 State Management: 연락처 상태
  bool _isLoadingDeviceContacts = false;
  bool _showDeviceContacts = false;
  List<ContactModel> _deviceContacts = [];
  bool _isTogglingFavorite = false;
  
  ContactManager({
    required this.databaseService,
    required this.mobileContactsService,
    required this.permissionHandler,
    required this.onStateChanged,
  });
  
  /// 상태 getter
  bool get isLoadingDeviceContacts => _isLoadingDeviceContacts;
  bool get showDeviceContacts => _showDeviceContacts;
  List<ContactModel> get deviceContacts => _deviceContacts;
  
  /// 🔄 장치 연락처 토글 (불러오기/숨기기)
  /// 
  /// **기능**: 장치에 저장된 연락처 표시/숨기기 전환
  /// - 장치 연락처가 표시 중이면: 숨김
  /// - 장치 연락처가 숨겨져 있으면: 권한 확인 후 불러오기
  /// 
  /// **고급 패턴**:
  /// - Permission Check: PermissionHandler를 통한 권한 확인
  /// - State Update: 상태 변경 후 콜백 호출
  /// - Error Handling: 에러 발생 시 사용자 안내
  /// - Loading State: 로딩 중 UI 업데이트
  Future<void> toggleDeviceContacts(
    BuildContext context,
    AuthService authService,
  ) async {
    // 이미 장치 연락처를 표시 중이면 숨김
    if (_showDeviceContacts) {
      _showDeviceContacts = false;
      _deviceContacts = [];
      onStateChanged();
      return;
    }

    _isLoadingDeviceContacts = true;
    onStateChanged();

    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔍 ===== ContactManager.toggleDeviceContacts START =====');
      }
      
      // 🎯 STEP 1 & 2: 권한 확인 및 요청 (PermissionHandler 사용)
      if (!context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        return;
      }
      
      _isLoadingDeviceContacts = false;
      onStateChanged();
      
      final hasPermission = await permissionHandler.checkAndRequestPermission(context);
      
      if (!hasPermission) {
        if (kDebugMode) {
          debugPrint('❌ ContactManager: 권한 거부됨 또는 취소됨');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('✅ ContactManager: 권한 확인 완료');
      }
      
      _isLoadingDeviceContacts = true;
      onStateChanged();

      // 🎯 STEP 3: 연락처 가져오기
      if (!context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        return;
      }
      
      if (kDebugMode) {
        debugPrint('✅ ContactManager: 권한 확인 완료 - 연락처 가져오기 시작');
      }
      
      final userId = authService.currentUser?.uid ?? '';
      final contacts = await mobileContactsService.getDeviceContacts(userId);
      
      if (kDebugMode) {
        debugPrint('📱 ContactManager: 연락처 ${contacts.length}개 가져옴');
        debugPrint('🔍 ===== ContactManager.toggleDeviceContacts END =====');
        debugPrint('');
      }

      if (!context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        return;
      }
      
      _deviceContacts = contacts;
      _showDeviceContacts = true;
      _isLoadingDeviceContacts = false;
      onStateChanged();

      if (contacts.isEmpty) {
        await DialogUtils.showWarning(
          context,
          '장치에 저장된 연락처가 없습니다.',
          duration: const Duration(seconds: 1),
        );
      } else {
        await DialogUtils.showSuccess(
          context,
          '${contacts.length}개의 연락처를 불러왔습니다.',
          duration: const Duration(seconds: 1),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        
        await DialogUtils.showError(
          context,
          '연락처 불러오기 실패: ${e.toString().split(':').last.trim()}',
        );
      }
    }
  }
  
  /// ⭐ 즐겨찾기 토글 (추가/제거)
  /// 
  /// **기능**: 연락처 즐겨찾기 상태 전환
  /// - 즐겨찾기에 추가된 경우: 제거
  /// - 즐겨찾기에 없는 경우: 추가
  /// 
  /// **고급 패턴**:
  /// - Database Update: Firestore 업데이트
  /// - User Feedback: 성공/실패 메시지 표시
  /// - Error Handling: 에러 발생 시 사용자 안내
  Future<void> toggleFavorite(
    BuildContext context,
    ContactModel contact,
  ) async {
    // 중복 실행 방지
    if (_isTogglingFavorite) {
      if (kDebugMode) {
        debugPrint('⚠️ toggleFavorite already in progress, ignoring');
      }
      return;
    }
    
    _isTogglingFavorite = true;
    
    try {
      await databaseService.updateContact(
        contact.id,
        {'isFavorite': !contact.isFavorite},
      );

      // SnackBar로 변경 (다이얼로그 쌓임 방지)
      if (context.mounted) {
        final message = contact.isFavorite
            ? '즐겨찾기에서 제거되었습니다'
            : '즐겨찾기에 추가되었습니다';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      // 에러는 다이얼로그로 표시 (중요한 정보)
      if (context.mounted) {
        await DialogUtils.showError(
          context,
          '오류 발생: $e',
        );
      }
    } finally {
      _isTogglingFavorite = false;
    }
  }
  
  /// 장치 연락처 상태 초기화 (로그아웃 시 등)
  void resetState() {
    _isLoadingDeviceContacts = false;
    _showDeviceContacts = false;
    _deviceContacts = [];
    onStateChanged();
  }
}
