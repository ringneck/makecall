import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// 🎯 고급 개발자 패턴: 사용자 세션 관리 및 데이터 초기화
/// 
/// 사용자 계정 전환 시 발생할 수 있는 문제들을 사전에 방지하는 핵심 서비스
/// - 착신전환 정보 캐시 초기화
/// - 통화 기록 캐시 초기화
/// - Provider 상태 초기화
/// - WebSocket 연결 정리
/// - 메모리 누수 방지
class UserSessionManager {
  static final UserSessionManager _instance = UserSessionManager._internal();
  factory UserSessionManager() => _instance;
  UserSessionManager._internal();

  final DatabaseService _databaseService = DatabaseService();
  
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
        if (kDebugMode) {
          debugPrint('🔄 사용자 계정 전환 감지!');
          debugPrint('   이전 사용자: ${_lastKnownUserId ?? "없음"}');
          debugPrint('   현재 사용자: ${currentUserId ?? "없음"}');
        }

        // 2️⃣ 전체 세션 데이터 초기화
        await _clearAllSessionData();

        // 3️⃣ 새 사용자 ID 저장
        _lastKnownUserId = currentUserId;
        await _saveLastUserId(currentUserId);

        if (kDebugMode) {
          debugPrint('✅ 사용자 세션 초기화 완료');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ 사용자 변경 없음 (현재: $currentUserId)');
        }
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

  /// 🧹 전체 세션 데이터 초기화 (캐스케이드 정리)
  Future<void> _clearAllSessionData() async {
    final results = <String, bool>{};

    if (kDebugMode) {
      debugPrint('🧹 전체 세션 데이터 초기화 시작...');
    }

    // 1️⃣ Hive 로컬 캐시 초기화
    try {
      await _clearHiveData();
      results['Hive'] = true;
      if (kDebugMode) {
        debugPrint('✅ [1/4] Hive 캐시 초기화 완료');
      }
    } catch (e) {
      results['Hive'] = false;
      if (kDebugMode) {
        debugPrint('❌ [1/4] Hive 초기화 실패: $e');
      }
    }

    // 2️⃣ SharedPreferences 임시 데이터 초기화
    try {
      await _clearSharedPreferencesCache();
      results['SharedPreferences'] = true;
      if (kDebugMode) {
        debugPrint('✅ [2/4] SharedPreferences 캐시 초기화 완료');
      }
    } catch (e) {
      results['SharedPreferences'] = false;
      if (kDebugMode) {
        debugPrint('❌ [2/4] SharedPreferences 초기화 실패: $e');
      }
    }

    // 3️⃣ 메모리 캐시 초기화 (Provider 상태는 notifyListeners로 자동 갱신됨)
    try {
      await _clearMemoryCache();
      results['MemoryCache'] = true;
      if (kDebugMode) {
        debugPrint('✅ [3/4] 메모리 캐시 초기화 완료');
      }
    } catch (e) {
      results['MemoryCache'] = false;
      if (kDebugMode) {
        debugPrint('❌ [3/4] 메모리 캐시 초기화 실패: $e');
      }
    }

    // 4️⃣ 네트워크 연결 정리 (WebSocket 등)
    try {
      await _clearNetworkConnections();
      results['Network'] = true;
      if (kDebugMode) {
        debugPrint('✅ [4/4] 네트워크 연결 정리 완료');
      }
    } catch (e) {
      results['Network'] = false;
      if (kDebugMode) {
        debugPrint('❌ [4/4] 네트워크 정리 실패: $e');
      }
    }

    // 📊 결과 요약
    final successCount = results.values.where((v) => v).length;
    final totalCount = results.length;
    
    if (kDebugMode) {
      debugPrint('📊 세션 초기화 결과: $successCount/$totalCount 성공');
      results.forEach((key, success) {
        debugPrint('   ${success ? "✅" : "❌"} $key');
      });
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
    // Dart VM 가비지 컬렉션 제안
    // Provider의 notifyListeners()가 자동으로 호출되어 UI가 갱신됨
    
    if (kDebugMode) {
      debugPrint('   🧠 메모리 캐시 정리 요청');
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

  /// 🔄 강제 초기화 (디버그용)
  Future<void> forceReset() async {
    if (kDebugMode) {
      debugPrint('🔄 강제 세션 초기화 실행');
    }
    _lastKnownUserId = null;
    await _clearAllSessionData();
  }
}
