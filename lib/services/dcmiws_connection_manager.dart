import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dcmiws_service.dart';

/// 🚀 DCMIWS 연결 관리자
/// 
/// 앱 생명주기 전반에 걸친 WebSocket 연결 관리:
/// - 앱 시작 시 자동 연결
/// - 네트워크 변경 감지 및 자동 재연결
/// - 사용자 전환 시 자동 재연결
/// - 백그라운드/포그라운드 전환 최적화
/// - 배터리 절약형 재연결 전략
class DCMIWSConnectionManager with WidgetsBindingObserver {
  // Singleton 패턴
  static final DCMIWSConnectionManager _instance = DCMIWSConnectionManager._internal();
  factory DCMIWSConnectionManager() => _instance;
  DCMIWSConnectionManager._internal();

  // 서비스 인스턴스
  final DCMIWSService _dcmiwsService = DCMIWSService();
  final Connectivity _connectivity = Connectivity();
  
  // 구독 관리
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<User?>? _authSubscription;
  
  // 연결 상태
  bool _isManagerActive = false;
  bool _isAppInForeground = true;
  String? _currentUserId;
  
  // 재연결 전략 (Exponential backoff)
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const List<int> _reconnectDelays = [
    2,    // 2초
    5,    // 5초
    10,   // 10초
    30,   // 30초
    60,   // 1분
    120,  // 2분
    300,  // 5분
    600,  // 10분
    900,  // 15분
    1800, // 30분
  ];
  
  // 서버 설정 캐시 (Firestore 조회 최소화)
  String? _cachedServerAddress;
  int? _cachedServerPort;
  bool? _cachedServerSSL;
  bool? _cachedDcmiwsEnabled; // ⭐ dcmiwsEnabled 캐시 추가
  String? _cachedHttpAuthId; // HTTP Basic Auth ID
  String? _cachedHttpAuthPassword; // HTTP Basic Auth Password
  
  /// 연결 관리자 시작
  /// 
  /// ⭐ CRITICAL: dcmiwsEnabled 설정을 먼저 확인하여 PUSH 모드일 때는
  /// 웹소켓 연결을 시도하지 않습니다.
  Future<void> start() async {
    if (_isManagerActive) {
      if (kDebugMode) {
        debugPrint('🔌 DCMIWSConnectionManager: Already active');
      }
      return;
    }
    
    _isManagerActive = true;
    
    if (kDebugMode) {
      debugPrint('🚀 DCMIWSConnectionManager: Starting...');
    }
    
    // 1. 앱 생명주기 관찰자 등록
    WidgetsBinding.instance.addObserver(this);
    
    // 2. 네트워크 변경 감지 시작
    _startNetworkMonitoring();
    
    // 3. 사용자 인증 상태 변경 감지 시작
    _startAuthMonitoring();
    
    // 4. ⭐ CRITICAL: dcmiwsEnabled 설정 먼저 확인
    // PUSH 모드일 때는 초기 연결 시도를 건너뜀
    if (kDebugMode) {
      debugPrint('🔍 DCMIWSConnectionManager: Checking dcmiwsEnabled setting...');
    }
    
    // Firestore에서 dcmiwsEnabled 설정 확인
    final isDcmiwsEnabled = await _loadServerSettings();
    
    if (isDcmiwsEnabled) {
      if (kDebugMode) {
        debugPrint('✅ DCMIWSConnectionManager: DCMIWS mode - attempting initial connection');
      }
      // DCMIWS 모드: 초기 연결 시도
      await _attemptConnection();
    } else {
      if (kDebugMode) {
        debugPrint('⏭️ DCMIWSConnectionManager: PUSH mode - skipping initial connection');
        debugPrint('   - User prefers FCM push notifications');
        debugPrint('   - WebSocket connection will not be established');
      }
    }
    
    if (kDebugMode) {
      debugPrint('✅ DCMIWSConnectionManager: Started successfully');
    }
  }
  
  /// 연결 관리자 중지
  Future<void> stop() async {
    if (!_isManagerActive) return;
    
    _isManagerActive = false;
    
    if (kDebugMode) {
      debugPrint('🛑 DCMIWSConnectionManager: Stopping...');
    }
    
    // 모든 구독 취소
    await _connectivitySubscription?.cancel();
    await _authSubscription?.cancel();
    _reconnectTimer?.cancel();
    
    // 앱 생명주기 관찰자 제거
    WidgetsBinding.instance.removeObserver(this);
    
    // WebSocket 연결 종료
    await _dcmiwsService.disconnect();
    
    // 캐시 초기화
    _cachedServerAddress = null;
    _cachedServerPort = null;
    _cachedServerSSL = null;
    _cachedHttpAuthId = null;
    _cachedHttpAuthPassword = null;
    
    if (kDebugMode) {
      debugPrint('✅ DCMIWSConnectionManager: Stopped');
    }
  }
  
  /// 사용자 설정 변경 시 캐시 초기화 및 재연결
  /// ProfileDrawer에서 dcmiwsEnabled 변경 시 호출
  Future<void> refreshSettings() async {
    if (kDebugMode) {
      debugPrint('🔄 DCMIWSConnectionManager: Refreshing settings...');
    }
    
    // 기존 연결 종료
    await _dcmiwsService.disconnect();
    
    // 캐시 초기화 (서버 설정 다시 로드)
    _cachedServerAddress = null;
    _cachedServerPort = null;
    _cachedServerSSL = null;
    _cachedDcmiwsEnabled = null; // ⭐ dcmiwsEnabled 캐시도 초기화
    _cachedHttpAuthId = null;
    _cachedHttpAuthPassword = null;
    
    // 재연결 타이머 리셋
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    
    // 새 설정으로 연결 시도
    await _attemptConnection();
    
    if (kDebugMode) {
      debugPrint('✅ DCMIWSConnectionManager: Settings refreshed');
    }
  }
  
  /// 앱 생명주기 변경 감지 (WidgetsBindingObserver)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      debugPrint('🔄 DCMIWSConnectionManager: App lifecycle changed to $state');
    }
    
    switch (state) {
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 돌아옴
        _isAppInForeground = true;
        _onAppResumed();
        break;
        
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 이동
        _isAppInForeground = false;
        _onAppPaused();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }
  
  /// 네트워크 변경 감지 시작
  void _startNetworkMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (kDebugMode) {
          debugPrint('📡 DCMIWSConnectionManager: Network changed: $results');
        }
        
        // 네트워크 연결이 있는 경우에만 재연결 시도
        if (results.any((result) => result != ConnectivityResult.none)) {
          _onNetworkConnected();
        } else {
          _onNetworkDisconnected();
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ DCMIWSConnectionManager: Network monitoring error: $error');
        }
      },
    );
  }
  
  /// 사용자 인증 상태 변경 감지 시작
  void _startAuthMonitoring() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        if (kDebugMode) {
          debugPrint('👤 DCMIWSConnectionManager: Auth state changed: ${user?.uid}');
        }
        
        // 사용자 전환 감지
        if (_currentUserId != user?.uid) {
          _onUserChanged(user?.uid);
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ DCMIWSConnectionManager: Auth monitoring error: $error');
        }
      },
    );
  }
  
  /// 앱이 포그라운드로 돌아왔을 때
  void _onAppResumed() {
    if (kDebugMode) {
      debugPrint('🌞 DCMIWSConnectionManager: App resumed (foreground)');
    }
    
    // ⭐ PUSH 모드면 재연결 시도하지 않음
    if (_cachedDcmiwsEnabled == false) {
      if (kDebugMode) {
        debugPrint('⏭️ DCMIWSConnectionManager: PUSH mode - skipping reconnection');
      }
      return;
    }
    
    // 연결 상태 확인 및 재연결
    if (!_dcmiwsService.isConnected) {
      if (kDebugMode) {
        debugPrint('🔄 DCMIWSConnectionManager: Reconnecting after resume...');
      }
      _attemptConnection();
    }
  }
  
  /// 앱이 백그라운드로 이동했을 때
  void _onAppPaused() {
    if (kDebugMode) {
      debugPrint('🌙 DCMIWSConnectionManager: App paused (background)');
    }
    
    // 백그라운드에서는 연결 유지
    // 재연결 타이머만 취소하여 배터리 절약
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }
  
  /// 네트워크 연결됨
  void _onNetworkConnected() {
    if (kDebugMode) {
      debugPrint('📶 DCMIWSConnectionManager: Network connected');
    }
    
    // ⭐ PUSH 모드면 재연결 시도하지 않음
    if (_cachedDcmiwsEnabled == false) {
      if (kDebugMode) {
        debugPrint('⏭️ DCMIWSConnectionManager: PUSH mode - skipping reconnection');
      }
      return;
    }
    
    // 연결되지 않은 경우에만 재연결 시도
    if (!_dcmiwsService.isConnected) {
      _attemptConnection();
    }
  }
  
  /// 네트워크 연결 끊김
  void _onNetworkDisconnected() {
    if (kDebugMode) {
      debugPrint('📵 DCMIWSConnectionManager: Network disconnected');
    }
    
    // 재연결 타이머 취소 (네트워크 없으면 의미 없음)
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
  }
  
  /// 사용자 전환 감지
  Future<void> _onUserChanged(String? newUserId) async {
    if (kDebugMode) {
      debugPrint('🔄 DCMIWSConnectionManager: User changed');
      debugPrint('  Previous: $_currentUserId');
      debugPrint('  New: $newUserId');
    }
    
    _currentUserId = newUserId;
    
    // 캐시 초기화 (새 사용자의 설정을 가져와야 함)
    _cachedServerAddress = null;
    _cachedServerPort = null;
    _cachedServerSSL = null;
    _cachedDcmiwsEnabled = null; // ⭐ dcmiwsEnabled 캐시도 초기화
    
    // 기존 연결 종료
    await _dcmiwsService.disconnect();
    
    // 재연결 카운터 초기화
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    
    // 새 사용자로 연결 시도
    if (newUserId != null) {
      await _attemptConnection();
    }
  }
  
  /// 연결 시도 (스마트 재연결 전략)
  Future<void> _attemptConnection() async {
    if (!_isManagerActive) return;
    
    // 사용자가 로그인되지 않은 경우 연결하지 않음
    if (_currentUserId == null) {
      if (kDebugMode) {
        debugPrint('⚠️ DCMIWSConnectionManager: No user logged in, skipping connection');
      }
      return;
    }
    
    // 이미 연결된 경우 스킵
    if (_dcmiwsService.isConnected) {
      if (kDebugMode) {
        debugPrint('✅ DCMIWSConnectionManager: Already connected');
      }
      _reconnectAttempts = 0; // 연결 성공 시 카운터 리셋
      return;
    }
    
    try {
      // ⭐ CRITICAL: dcmiwsEnabled 설정을 제일 먼저 확인
      // 네트워크 체크나 로그 출력보다 먼저 실행하여 불필요한 로그 방지
      final isDcmiwsEnabled = await _loadServerSettings();
      
      // ⭐ PUSH 모드일 때는 즉시 종료 (재시도 없음)
      if (!isDcmiwsEnabled) {
        if (kDebugMode) {
          debugPrint('⏹️ DCMIWSConnectionManager: PUSH mode - no connection needed');
        }
        // 재연결 타이머 취소 및 카운터 리셋
        _reconnectTimer?.cancel();
        _reconnectAttempts = 0;
        return;  // ✅ 즉시 종료 - 네트워크 체크나 연결 시도 없음
      }
      
      // ✅ DCMIWS 모드 확인됨 - 연결 절차 진행
      
      // 네트워크 상태 확인
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.every((result) => result == ConnectivityResult.none)) {
        if (kDebugMode) {
          debugPrint('📵 DCMIWSConnectionManager: No network, skipping connection');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🔌 DCMIWSConnectionManager: Attempting connection (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');
      }
      
      if (_cachedServerAddress == null) {
        if (kDebugMode) {
          debugPrint('⚠️ DCMIWSConnectionManager: No server settings found (DCMIWS enabled but no server URL)');
        }
        _scheduleReconnect(); // DCMIWS 활성화되었지만 서버 URL 없을 때만 재시도
        return;
      }
      
      // WebSocket 연결 시도
      final success = await _dcmiwsService.connect(
        serverAddress: _cachedServerAddress!,
        port: _cachedServerPort ?? 6600,
        useSSL: _cachedServerSSL ?? false,
        httpAuthId: _cachedHttpAuthId,
        httpAuthPassword: _cachedHttpAuthPassword,
      );
      
      if (success) {
        if (kDebugMode) {
          debugPrint('✅ DCMIWSConnectionManager: Connection successful');
        }
        _reconnectAttempts = 0; // 성공 시 카운터 리셋
      } else {
        if (kDebugMode) {
          debugPrint('❌ DCMIWSConnectionManager: Connection failed');
        }
        _scheduleReconnect();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWSConnectionManager: Connection error: $e');
      }
      _scheduleReconnect();
    }
  }
  
  /// 서버 설정 로드 (Firestore 캐싱)
  /// 
  /// Returns: true if DCMIWS is enabled, false if PUSH mode
  Future<bool> _loadServerSettings() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;
      
      if (kDebugMode) {
        debugPrint('📥 DCMIWSConnectionManager: Loading server settings for user $userId');
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ DCMIWSConnectionManager: User document not found');
        }
        return false;
      }
      
      final userData = userDoc.data()!;
      
      // ⭐ CRITICAL: Check if DCMIWS is enabled (default: false = PUSH mode)
      // This check is ALWAYS performed, even if cache exists
      final dcmiwsEnabled = userData['dcmiwsEnabled'] as bool? ?? false;
      
      // ⭐ 캐시에 dcmiwsEnabled 저장 (생명주기 이벤트에서 재사용)
      _cachedDcmiwsEnabled = dcmiwsEnabled;
      
      // 🔍 DEBUG: Firestore 실제 값 확인
      if (kDebugMode) {
        debugPrint('🔍 DCMIWSConnectionManager: Firestore dcmiwsEnabled = $dcmiwsEnabled');
        debugPrint('   Raw value: ${userData['dcmiwsEnabled']}');
        debugPrint('   Type: ${userData['dcmiwsEnabled'].runtimeType}');
      }
      
      if (!dcmiwsEnabled) {
        if (kDebugMode) {
          debugPrint('⏭️ DCMIWSConnectionManager: DCMIWS disabled (PUSH mode)');
          debugPrint('   - User prefers FCM push notifications');
          debugPrint('   - WebSocket connection will not be established');
        }
        // Clear cache to prevent connection attempts
        _cachedServerAddress = null;
        _cachedServerPort = null;
        _cachedServerSSL = null;
        _cachedHttpAuthId = null;
        _cachedHttpAuthPassword = null;
        return false; // Return false = PUSH mode
      }
      
      if (kDebugMode) {
        debugPrint('✅ DCMIWSConnectionManager: DCMIWS enabled - loading server settings');
      }
      
      // Check if cache is already loaded and valid
      if (_cachedServerAddress != null) {
        if (kDebugMode) {
          debugPrint('ℹ️ DCMIWSConnectionManager: Using cached server settings');
        }
        return true; // Return true = DCMIWS enabled
      }
      
      // ProfileDrawer의 API Settings Dialog와 동일한 필드명 사용
      _cachedServerAddress = userData['websocketServerUrl'] as String?;
      _cachedServerPort = userData['websocketServerPort'] as int? ?? 6600;
      _cachedServerSSL = userData['websocketUseSSL'] as bool? ?? false;
      _cachedHttpAuthId = userData['websocketHttpAuthId'] as String?;
      _cachedHttpAuthPassword = userData['websocketHttpAuthPassword'] as String?;
      
      if (kDebugMode) {
        debugPrint('✅ DCMIWSConnectionManager: Server settings loaded');
        debugPrint('  Address: $_cachedServerAddress');
        debugPrint('  Port: $_cachedServerPort');
        debugPrint('  SSL: $_cachedServerSSL');
        if (_cachedHttpAuthId != null && _cachedHttpAuthId!.isNotEmpty) {
          debugPrint('  HTTP Auth: 설정됨 (ID: $_cachedHttpAuthId)');
        }
      }
      
      return true; // Return true = DCMIWS enabled
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWSConnectionManager: Failed to load server settings: $e');
      }
      return false; // Return false on error
    }
  }
  
  /// 재연결 스케줄링 (Exponential backoff)
  void _scheduleReconnect() {
    // 최대 재시도 횟수 초과
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWSConnectionManager: Max reconnect attempts reached');
      }
      return;
    }
    
    // 백그라운드에서는 재연결하지 않음 (배터리 절약)
    if (!_isAppInForeground) {
      if (kDebugMode) {
        debugPrint('🌙 DCMIWSConnectionManager: App in background, skipping reconnect');
      }
      return;
    }
    
    // Exponential backoff 지연 시간 계산
    final delaySeconds = _reconnectDelays[_reconnectAttempts.clamp(0, _reconnectDelays.length - 1)];
    _reconnectAttempts++;
    
    if (kDebugMode) {
      debugPrint('⏰ DCMIWSConnectionManager: Scheduling reconnect in ${delaySeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    }
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _attemptConnection();
    });
  }
  
  /// 수동 재연결 (외부에서 호출 가능)
  Future<void> reconnect() async {
    if (kDebugMode) {
      debugPrint('🔄 DCMIWSConnectionManager: Manual reconnect requested');
    }
    
    // 재연결 카운터 리셋
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    
    // 캐시 초기화 (최신 서버 설정 가져오기)
    _cachedServerAddress = null;
    _cachedServerPort = null;
    _cachedServerSSL = null;
    
    await _attemptConnection();
  }
  
  /// 현재 연결 상태 확인
  bool get isConnected => _dcmiwsService.isConnected;
  
  /// 연결 상태 스트림
  Stream<bool> get connectionState => _dcmiwsService.connectionState;
}
