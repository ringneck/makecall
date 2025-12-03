import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../providers/selected_extension_provider.dart';

/// 🔧 ExtensionInitializer Service
/// 
/// **책임 (Single Responsibility)**:
/// - 단말번호 자동 초기화 로직 처리
/// - 신규 사용자 감지 및 ProfileDrawer 자동 열기
/// - 초기화 상태 관리 (중복 실행 방지)
/// 
/// **설계 패턴**:
/// - Service Pattern: 비즈니스 로직 캡슐화
/// - Dependency Injection: AuthService, DatabaseService 주입
/// - Idempotent Execution: 플래그를 통한 중복 실행 방지
/// - Early Return Pattern: 빠른 검증 실패 처리
/// - Event-driven: AuthService 상태 변화에 따른 재초기화
/// 
/// **사용 예시**:
/// ```dart
/// // 초기화
/// _extensionInitializer = ExtensionInitializer(
///   authService: _authService!,
///   databaseService: _databaseService,
///   scaffoldKey: _scaffoldKey,
/// );
/// 
/// // 단말번호 초기화
/// await _extensionInitializer.initializeExtensions(context);
/// 
/// // 신규 사용자 체크
/// await _extensionInitializer.checkAndOpenProfileDrawerForNewUser(context);
/// ```
class ExtensionInitializer {
  final AuthService authService;
  final DatabaseService databaseService;
  final GlobalKey<ScaffoldState> scaffoldKey;
  
  // 🔒 State Management: 중복 실행 방지 플래그
  bool _hasCheckedNewUser = false;
  
  ExtensionInitializer({
    required this.authService,
    required this.databaseService,
    required this.scaffoldKey,
  });
  
  /// 신규 사용자 체크 완료 여부 getter/setter
  bool get hasCheckedNewUser => _hasCheckedNewUser;
  set hasCheckedNewUser(bool value) => _hasCheckedNewUser = value;
  
  /// 🔄 단말번호 자동 초기화 (Firestore Stream)
  /// 
  /// **기능**: 사용자의 첫 번째 단말번호를 자동으로 SelectedExtensionProvider에 설정
  /// - Firestore에서 단말번호 목록 조회 (Stream)
  /// - 단말번호가 있는 경우 첫 번째 단말번호를 자동 선택
  /// - 단말번호가 없는 경우 silent fail (ExtensionDrawer에서 수동 선택 가능)
  /// 
  /// **고급 패턴**:
  /// - Idempotent: Provider에 이미 설정된 경우 재설정하지 않음 (성능 최적화)
  /// - Early Return: 인증 상태/userId 검증 실패 시 빠른 종료
  /// - Fail Silent: 초기화 실패는 치명적이지 않음 (수동 선택 가능)
  /// - Stream-based: Firestore Stream의 첫 번째 이벤트만 사용
  /// 
  /// **호출 시점**:
  /// - CallTab initState에서 자동 호출
  /// - AuthService 상태 변화 시 재호출 가능
  Future<void> initializeExtensions(BuildContext context) async {
    // 🔒 Early Return: 인증 상태 검증
    if (authService.currentUser == null || !(authService.isAuthenticated)) {
      if (kDebugMode) debugPrint('⚠️ 단말번호 초기화 스킵: 로그아웃 상태');
      return;
    }
    
    // 🔒 Early Return: userId 검증
    final userId = authService.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      if (kDebugMode) debugPrint('⚠️ 단말번호 초기화 스킵: userId 없음');
      return;
    }
    
    try {
      if (kDebugMode) debugPrint('🔄 단말번호 자동 초기화 시작...');
      
      // 🔒 단말번호 조회 (Firestore Stream)
      final extensions = await databaseService.getMyExtensions(userId).first;
      
      if (extensions.isEmpty) {
        if (kDebugMode) {
          debugPrint('ℹ️ 등록된 단말번호 없음 - 설정에서 단말번호를 조회하세요');
        }
        return;
      }
      
      if (!context.mounted) return;
      
      // 🔒 Provider 상태 업데이트 (Idempotent)
      final provider = context.read<SelectedExtensionProvider>();
      
      // 이미 설정된 경우 재설정하지 않음 (성능 최적화)
      if (provider.selectedExtension == null) {
        provider.setSelectedExtension(extensions.first);
        if (kDebugMode) {
          debugPrint('✅ 단말번호 자동 선택: ${extensions.first.extension}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ 단말번호 이미 설정됨: ${provider.selectedExtension?.extension}');
        }
      }
    } catch (e) {
      // 🔒 Fail Silent: 단말번호 초기화 실패는 치명적이지 않음
      // ExtensionDrawer에서 수동으로 선택 가능
      if (kDebugMode) {
        debugPrint('❌ 단말번호 초기화 실패: $e');
      }
    }
  }
  
  /// 🎉 신규 사용자 설정 완료 여부 감지 (고급 이벤트 기반 패턴)
  /// 
  /// **기능**: 회원가입 직후 기본 설정이 필요한 신규 사용자를 감지합니다
  /// - API 설정, WebSocket 설정, 단말번호 모두 완료된 경우 설정 완료로 처리
  /// - 설정이 부족한 경우 로그만 출력 (ProfileDrawer 자동 열기 비활성화됨)
  /// - 사용자가 직접 ProfileDrawer를 열어 설정을 완료해야 함
  /// - 최초 1회만 실행 (중복 체크 방지)
  /// 
  /// **고급 패턴**:
  /// - FCM 초기화 완료 대기 (이벤트 기반)
  /// - 초기화 미완료 시 스킵 → FCM 완료 후 재실행 (_onAuthServiceStateChanged에서)
  /// 
  /// **설정 체크 항목**:
  /// - hasApiSettings: apiBaseUrl, companyId, appKey
  /// - hasWebSocketSettings: websocketServerUrl
  /// - hasExtensions: 등록된 단말번호 존재 여부
  /// 
  /// **Returns**: 설정 체크 완료 여부 (hasCheckedSettings 업데이트용)
  Future<bool> checkAndOpenProfileDrawerForNewUser(
    BuildContext context,
    bool Function() getHasCheckedSettings,
    void Function(bool) setHasCheckedSettings,
  ) async {
    if (_hasCheckedNewUser) return false;

    try {
      // 🔒 Early Return: 인증 상태 검증 (CRITICAL FIX for blank screen issue)
      if (authService.currentUser == null || !(authService.isAuthenticated)) {
        if (kDebugMode) debugPrint('⚠️ 신규 사용자 체크 스킵: 로그아웃 상태');
        return false;
      }
      
      // FCM 초기화 완료 대기 (이벤트 기반)
      if (!(authService.isFcmInitialized)) {
        return false; // FCM 완료 후 _onAuthServiceStateChanged에서 재실행
      }
      
      _hasCheckedNewUser = true;
      
      // 기기 승인 대기 중인 경우 ProfileDrawer 열지 않음
      if ((authService.isWaitingForApproval) || authService.approvalRequestId != null) {
        return false;
      }
      
      final userId = authService.currentUser?.uid;
      if (userId == null) return false;

      // 🔐 userModel 로드 확인 (이벤트 기반)
      // ❌ 시간 기반 polling 제거: while + Future.delayed (불안정)
      // ✅ 이벤트 기반: currentUserModel 직접 체크 (안정적)
      final userModel = authService.currentUserModel;
      if (userModel == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [신규사용자] userModel 아직 로드 안 됨 - AuthService 리스너가 재호출');
        }
        _hasCheckedNewUser = false;
        return false;  // AuthService의 notifyListeners()가 다시 호출할 것
      }

      // 🔐 소셜 로그인 진행 중인 경우 설정 체크 건너뛰기 (이벤트 기반)
      if (authService.isInSocialLoginFlow) {
        if (kDebugMode) {
          debugPrint('⏭️ 소셜 로그인 진행 중 - ProfileDrawer 자동 열기 건너뛰기');
        }
        return false; // 플래그를 설정하지 않고 return
      }

      // 필수 설정 확인
      final hasApiSettings = (userModel.apiBaseUrl?.isNotEmpty ?? false) &&
                            (userModel.companyId?.isNotEmpty ?? false) &&
                            (userModel.appKey?.isNotEmpty ?? false);
      final hasWebSocketSettings = userModel.websocketServerUrl?.isNotEmpty ?? false;
      final extensions = await databaseService.getMyExtensions(userId).first;
      final hasExtensions = extensions.isNotEmpty;

      if (!context.mounted) return false;

      // 모든 설정 완료 시 ProfileDrawer 열지 않음
      if (hasApiSettings && hasWebSocketSettings && hasExtensions) {
        setHasCheckedSettings(true);
        return true; // 설정 완료됨
      }

      // 🔒 설정이 부족한 경우에도 ProfileDrawer 자동 열기 비활성화
      if (kDebugMode) {
        debugPrint('');
        debugPrint('='*60);
        debugPrint('⚠️ 설정 미완료 감지!');
        debugPrint('='*60);
        debugPrint('   → 사용자가 직접 설정을 완료해야 합니다');
        debugPrint('   → ProfileDrawer 자동 열기 비활성화됨');
        debugPrint('='*60);
        debugPrint('');
      }

      // 설정 체크 완료 플래그 설정
      setHasCheckedSettings(true);
      
      return true; // 설정 체크 완료
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 신규 사용자 체크 오류: $e');
      }
      return false;
    }
  }
  
  /// 신규 사용자 체크 플래그 초기화 (로그아웃 시 등)
  void resetNewUserCheck() {
    _hasCheckedNewUser = false;
  }
}
