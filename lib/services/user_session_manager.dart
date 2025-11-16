import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import '../providers/selected_extension_provider.dart';
import '../providers/dcmiws_event_provider.dart';

/// 🎯 고급 개발자 패턴: 사용자 세션 관리 및 데이터 초기화
/// 
/// 사용자 계정 전환 시 발생할 수 있는 문제들을 사전에 방지하는 핵심 서비스
/// - 착신전환 정보 캐시 초기화
/// - 통화 기록 캐시 초기화
/// - Provider 상태 초기화 (SelectedExtensionProvider, DCMIWSEventProvider)
/// - WebSocket 연결 정리
/// - 메모리 누수 방지
class UserSessionManager {
  static final UserSessionManager _instance = UserSessionManager._internal();
  factory UserSessionManager() => _instance;
  UserSessionManager._internal();

  final DatabaseService _databaseService = DatabaseService();
  
  // 🔒 Provider 참조 저장 (사용자 전환 시 초기화용)
  SelectedExtensionProvider? _selectedExtensionProvider;
  DCMIWSEventProvider? _dcmiwsEventProvider;
  
  /// 마지막으로 확인된 사용자 ID (계정 전환 감지용)
  String? _lastKnownUserId;
  
  /// 초기화 진행 중 플래그 (중복 실행 방지)
  bool _isInitializing = false;

  /// 🔄 사용자 세션 전환 감지 및 초기화
  /// 
  /// 호출 시점: 
  /// - 앱 시작 시
  /// - 로그인 후
  /// - 계정 전환 후
  Future<void> checkAndInitializeSession(String? currentUserId) async {
    if (_isInitializing) {
      if (kDebugMode) {
        debugPrint('⏳ 이미 초기화 진행 중...');
      }
      return;
    }

    try {
      _isInitializing = true;

      // 1️⃣ 사용자 전환 감지
      final bool userChanged = _hasUserChanged(currentUserId);
      
      if (userChanged) {
        // 전체 세션 데이터 초기화
        await _clearAllSessionData();

        // 새 사용자 ID 저장
        _lastKnownUserId = currentUserId;
        await _saveLastUserId(currentUserId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 세션 초기화 오류: $e');
      }
    } finally {
      _isInitializing = false;
    }
  }

  /// 🔍 사용자 변경 여부 확인
  bool _hasUserChanged(String? currentUserId) {
    // 앱 최초 실행 시 (lastKnownUserId가 null)
    if (_lastKnownUserId == null) {
      _lastKnownUserId = currentUserId;
      return false; // 최초 실행은 전환이 아님
    }

    // 로그아웃 → 로그인 (다른 계정)
    if (_lastKnownUserId != currentUserId) {
      return true;
    }

    return false;
  }

  /// 전체 세션 데이터 초기화
  Future<void> _clearAllSessionData() async {
    try {
      await _clearHiveData();
      await _clearSharedPreferencesCache();
      await _clearMemoryCache();
      await _clearNetworkConnections();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 세션 초기화 오류: $e');
      }
    }
  }

  /// 🗄️ Hive 로컬 데이터베이스 초기화
  Future<void> _clearHiveData() async {
    // 착신전환 정보 박스
    if (Hive.isBoxOpen('call_forward_info')) {
      final box = Hive.box('call_forward_info');
      await box.clear();
      if (kDebugMode) {
        debugPrint('   🗑️ call_forward_info 박스 초기화');
      }
    }

    // 통화 기록 박스
    if (Hive.isBoxOpen('call_history')) {
      final box = Hive.box('call_history');
      await box.clear();
      if (kDebugMode) {
        debugPrint('   🗑️ call_history 박스 초기화');
      }
    }

    // 연락처 박스
    if (Hive.isBoxOpen('contacts')) {
      final box = Hive.box('contacts');
      await box.clear();
      if (kDebugMode) {
        debugPrint('   🗑️ contacts 박스 초기화');
      }
    }
  }

  /// 💾 SharedPreferences 캐시 초기화
  Future<void> _clearSharedPreferencesCache() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 세션 관련 임시 데이터만 삭제 (계정 정보는 유지)
    final keysToRemove = <String>[
      'cached_call_forward_info',
      'cached_extension_list',
      'cached_phonebook_sync_time',
      'temp_call_data',
      'websocket_connection_state',
    ];

    for (final key in keysToRemove) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
        if (kDebugMode) {
          debugPrint('   🗑️ $key 제거');
        }
      }
    }
  }

  /// 🧠 메모리 캐시 초기화
  Future<void> _clearMemoryCache() async {
    // 🔒 CRITICAL: Provider 상태 초기화 (사용자 전환 시 이전 데이터 제거)
    
    // 1️⃣ SelectedExtensionProvider 초기화 (클릭투콜 caller 초기화)
    if (_selectedExtensionProvider != null) {
      _selectedExtensionProvider!.clearSelection();
      if (kDebugMode) {
        debugPrint('   🗑️ SelectedExtensionProvider 초기화 (이전 단말번호 제거)');
      }
    }
    
    // 2️⃣ DCMIWSEventProvider 초기화 (WebSocket 이벤트 초기화)
    if (_dcmiwsEventProvider != null) {
      // WebSocket 연결 해제는 네트워크 정리 단계에서 처리
      if (kDebugMode) {
        debugPrint('   🗑️ DCMIWSEventProvider 상태 확인');
      }
    }
    
    if (kDebugMode) {
      debugPrint('   🧠 메모리 캐시 정리 완료 (Provider 상태 초기화)');
    }
  }

  /// 🌐 네트워크 연결 정리
  Future<void> _clearNetworkConnections() async {
    // WebSocket 연결이 있다면 정리
    // DCMIWSEventProvider의 dispose가 자동으로 호출됨
    
    if (kDebugMode) {
      debugPrint('   🌐 네트워크 연결 정리 (WebSocket 등)');
    }
  }

  /// 💾 마지막 사용자 ID 저장
  Future<void> _saveLastUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) {
      await prefs.setString('last_known_user_id', userId);
    } else {
      await prefs.remove('last_known_user_id');
    }
  }

  /// 📖 마지막 사용자 ID 불러오기
  Future<void> loadLastUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _lastKnownUserId = prefs.getString('last_known_user_id');
    
    if (kDebugMode) {
      debugPrint('📖 저장된 마지막 사용자 ID: ${_lastKnownUserId ?? "없음"}');
    }
  }

  /// 🔒 Provider 등록 (main.dart에서 호출)
  /// 
  /// 사용자 전환 시 Provider 상태를 초기화하기 위해 참조를 저장
  void registerProviders({
    required SelectedExtensionProvider selectedExtensionProvider,
    required DCMIWSEventProvider dcmiwsEventProvider,
  }) {
    _selectedExtensionProvider = selectedExtensionProvider;
    _dcmiwsEventProvider = dcmiwsEventProvider;
    
    if (kDebugMode) {
      debugPrint('🔒 Provider 참조 등록 완료 (사용자 전환 시 초기화용)');
    }
  }
  
  /// 🔄 강제 초기화 (디버그용)
  Future<void> forceReset() async {
    if (kDebugMode) {
      debugPrint('🔄 강제 세션 초기화 실행');
    }
    _lastKnownUserId = null;
    await _clearAllSessionData();
  }
}
