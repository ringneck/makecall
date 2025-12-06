import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'firebase_options.dart';
import 'config/kakao_config.dart';

import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/user_session_manager.dart';
import 'services/dcmiws_service.dart';
import 'services/dcmiws_connection_manager.dart';
import 'services/inactivity_service.dart';
import 'providers/selected_extension_provider.dart';
import 'providers/dcmiws_event_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/web_login_wrapper.dart';
import 'screens/auth/approval_waiting_screen.dart';

import 'screens/home/main_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'widgets/social_login_progress_overlay.dart';

/// 백그라운드 FCM 메시지 핸들러 (Top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase가 이미 초기화되었는지 확인
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  
  debugPrint('🔔 백그라운드 메시지: ${message.notification?.title}');
  debugPrint('🔔 백그라운드 메시지 데이터: ${message.data}');
  
  // 🔐 기기 승인 요청 메시지 처리 (iOS용 플래그 저장)
  if (message.data['type'] == 'device_approval_request') {
    debugPrint('🔔 [FCM-BG] 기기 승인 요청 감지 - 플래그 저장');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_approval_request', jsonEncode(message.data));
      debugPrint('✅ [FCM-BG] 승인 요청 데이터 저장 완료');
    } catch (e) {
      debugPrint('❌ [FCM-BG] 승인 요청 저장 실패: $e');
    }
    return;
  }
  
  // 📥 사용자 알림 설정 확인 (백그라운드에서도 체크)
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    if (userId != null) {
      // Firestore에서 알림 설정 가져오기
      final settingsDoc = await FirebaseFirestore.instance
          .collection('user_notification_settings')
          .doc(userId)
          .get();
      
      if (settingsDoc.exists) {
        final pushEnabled = settingsDoc.data()?['pushEnabled'] ?? true;
        
        debugPrint('📦 [FCM-BG] 사용자 알림 설정:');
        debugPrint('   - pushEnabled: $pushEnabled');
        
        if (!pushEnabled) {
          debugPrint('⏭️ [FCM-BG] 푸시 알림이 비활성화되어 알림 표시 건너뜀');
          return; // 알림 설정이 꺼져있으면 처리 중단
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ [FCM-BG] 알림 설정 확인 실패: $e');
    // 설정 확인 실패 시 기본 동작 (알림 표시)
  }
  
  // 📞 수신 전화 감지 (Android와 iOS 모두 지원)
  final hasIncomingCallType = message.data['type'] == 'incoming_call';
  final hasLinkedId = message.data['linkedid'] != null && 
                      (message.data['linkedid'] as String).isNotEmpty;
  final hasCallType = message.data['call_type'] != null;
  
  if (hasIncomingCallType || (hasLinkedId && hasCallType)) {
    debugPrint('📞 [FCM-BG] 백그라운드에서 수신 전화 감지:');
    debugPrint('   - type: ${message.data['type']}');
    debugPrint('   - linkedid: ${message.data['linkedid']}');
    debugPrint('   - call_type: ${message.data['call_type']}');
    debugPrint('   - caller_num: ${message.data['caller_num']}');
    debugPrint('   - receiver_number: ${message.data['receiver_number']}');
    
    // ✅ CRITICAL: 백엔드(Firebase Functions)에서 이미 my_extensions 검증 완료
    // → sendIncomingCallNotification Function이 accountCode/extension 확인 후 전송
    // → 이 시점에서 도착한 푸시는 100% 유효한 수신전화임
    // → 앱 측에서 추가 검증 불필요 (로그인 상태 무관)
    
    debugPrint('✅ [FCM-BG] 백엔드 검증 통과한 수신전화 (앱 종료 상태에서도 처리 가능)');
    
    // 백그라운드에서는 알림을 시스템이 자동으로 표시함
    // 사용자가 알림을 탭하면 onMessageOpenedApp에서 수신 전화 화면 표시
  } else {
    debugPrint('ℹ️ [FCM-BG] 일반 메시지 (수신 전화 아님)');
  }
}

// 🔑 GlobalKey for Navigator (수신 전화 풀스크린 표시용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🔐 AuthService 전역 싱글톤 인스턴스 (앱 생명주기와 독립적으로 유지)
// Widget tree 재구성과 무관하게 동일한 AuthService 인스턴스 보장
final AuthService globalAuthService = AuthService();

// ✅ iOS FCM Method Channel
MethodChannel? _fcmChannel;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 (Native에서 이미 초기화되었으므로 Flutter에서는 연결만)
  try {
    // iOS: Native (AppDelegate)에서 이미 초기화됨
    // Android: 여기서 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Firebase initialized successfully
  } catch (e) {
    // Native에서 이미 초기화된 경우 무시 (정상 동작)
    if (e.toString().contains('duplicate-app') || 
        e.toString().contains('already created')) {
      // Firebase already initialized from native
    } else {
      if (kDebugMode) {
        debugPrint('❌ Firebase 초기화 오류: $e');
      }
      rethrow;
    }
  }
  
  // 카카오 SDK 초기화
  try {
    KakaoSdk.init(
      nativeAppKey: KakaoConfig.nativeAppKey,
      javaScriptAppKey: KakaoConfig.javaScriptAppKey,
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Kakao SDK 초기화 실패: $e');
    }
  }
  
  // ✅ iOS Method Channel 설정 (포그라운드 FCM 메시지 수신용)
  // 🔧 CRITICAL FIX: Web 플랫폼에서는 Platform.isIOS 체크 불가
  if (!kIsWeb && Platform.isIOS) {
    _fcmChannel = const MethodChannel('com.makecall.app/fcm');
    _fcmChannel!.setMethodCallHandler(_handleIOSForegroundMessage);
    // iOS FCM Method Channel registered
  }
  
  // FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Hive 초기화
  await Hive.initFlutter();
  
  // 사용자 세션 관리자 초기화
  await UserSessionManager().loadLastUserId();
  
  // 🛡️ Flutter 에러 핸들링 설정 (iOS 빨간 화면 방지)
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // 개발 모드: 콘솔에 에러 출력
      FlutterError.presentError(details);
    } else {
      // 릴리즈 모드: 에러 로깅 (Crashlytics 등에 전송 가능)
      debugPrint('❌ Flutter Error: ${details.exceptionAsString()}');
      debugPrint('Stack trace: ${details.stack}');
    }
  };
  
  // 🛡️ Zone 에러 핸들링 (비동기 에러 캐치)
  runZonedGuarded(
    () => runApp(
      // 🔥 CRITICAL: MultiProvider를 최상위로 이동하여 모든 Widget이 Provider 접근 가능
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: globalAuthService),
          ChangeNotifierProvider(create: (_) => SelectedExtensionProvider()),
          ChangeNotifierProvider(create: (_) => DCMIWSEventProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    ),
    (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Uncaught error: $error');
        debugPrint('Stack trace: $stackTrace');
      }
    },
  );
}

/// ✅ iOS FCM 메시지 핸들러 (Method Channel)
Future<void> _handleIOSForegroundMessage(MethodCall call) async {
  if (kDebugMode) {
    debugPrint('[FCM] iOS Method Channel: ${call.method}');
  }
  
  if (call.method == 'onForegroundMessage') {
    // 포그라운드 메시지 처리
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
      
      // iOS foreground message received
      
      // APS 데이터에서 notification 정보 추출
      final apsData = data['aps'] as Map?;
      final alertData = apsData?['alert'] as Map?;
      
      final notification = RemoteNotification(
        title: alertData?['title'] as String?,
        body: alertData?['body'] as String?,
      );
      
      // RemoteMessage 생성
      final remoteMessage = RemoteMessage(
        data: data,
        notification: notification,
        messageId: data['gcm.message_id']?.toString(),
      );
      
      // RemoteMessage created
      
      // FCM 서비스로 전달 (포그라운드 처리)
      await FCMService().handleRemoteMessage(remoteMessage, isForeground: true);
      
      // FCM service handled message
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] iOS message error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  } else if (call.method == 'onNotificationTap') {
    // 🔧 NEW: 백그라운드 알림 탭 처리
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
      
      // iOS background notification tap received
      
      // _notification_tap 플래그 제거
      data.remove('_notification_tap');
      
      // APS 데이터에서 notification 정보 추출
      final apsData = data['aps'] as Map?;
      final alertData = apsData?['alert'] as Map?;
      
      final notification = RemoteNotification(
        title: alertData?['title'] as String?,
        body: alertData?['body'] as String?,
      );
      
      // RemoteMessage 생성
      final remoteMessage = RemoteMessage(
        data: data,
        notification: notification,
        messageId: data['gcm.message_id']?.toString(),
      );
      
      // RemoteMessage created (background)
      
      // FCM 서비스로 전달 (백그라운드 알림 탭 처리)
      await FCMService().handleRemoteMessage(remoteMessage, isForeground: false);
      
      // FCM service handled background notification tap
      
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [FCM] iOS background notification tap error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // 🔒 고급 개발자 패턴: 세션 체크 중복 실행 방지
  bool _isSessionCheckScheduled = false;
  String? _lastCheckedUserId;
  bool _providersRegistered = false; // Provider 등록 플래그
  
  // 🚀 WebSocket 연결 관리자
  final DCMIWSConnectionManager _connectionManager = DCMIWSConnectionManager();
  
  // ⏱️ 비활성 자동 로그아웃 서비스
  final InactivityService _inactivityService = InactivityService();
  
  // 💡 스플래시 스크린 표시 상태
  bool _isInitializing = true;
  
  // 🎬 스플래시 Fade Out 시작 여부
  bool _isFadingOut = false;
  
  // 🔑 스플래시 스크린 GlobalKey (Fade Out 제어용)
  final GlobalKey<SplashScreenState> _splashKey = GlobalKey<SplashScreenState>();
  
  // 🔒 로그인 유지 다이얼로그 표시 여부
  bool _isLoginKeepDialogShowing = false;
  
  // 🎨 테마 Provider
  final ThemeProvider _themeProvider = ThemeProvider();
  
  // 🔔 알림 플러그인 (iOS 배지 초기화용)
  final FlutterLocalNotificationsPlugin _notificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    
    if (kDebugMode) {
      debugPrint('🔧 [MyApp] Using global AuthService singleton instance');
    }
    
    // 🔄 앱 생명주기 옵저버 등록 (iOS 화면 검게 변하는 문제 해결)
    WidgetsBinding.instance.addObserver(this);
    
    // 🔔 iOS 배지 초기화 (앱 시작 시)
    _clearBadge();
    
    // 🎨 테마 설정 로드
    _themeProvider.loadThemeMode();
    
    // NavigatorKey 등록
    DCMIWSService.setNavigatorKey(navigatorKey);
    
    // FCM 강제 로그아웃 콜백 설정
    FCMService.setForceLogoutCallback(() async {
      if (mounted) {
        // 🔥 CRITICAL: 전역 AuthService 싱글톤 인스턴스 사용
        await globalAuthService.signOut();
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    });
    
    // WebSocket 연결 관리자 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectionManager.start();
      _initializeApp();
    });
  }
  
  /// 🔄 앱 생명주기 변경 감지 (iOS 화면 검게 변하는 문제 해결)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (kDebugMode) {
      debugPrint('🔄 [MyApp] App lifecycle changed to $state');
    }
    
    // ========================================
    // ⏱️ 비활성 타이머 생명주기 관리
    // ========================================
    // iOS/Android 백그라운드 최적화:
    // - paused: 앱이 백그라운드로 전환 → 타이머 일시정지 (선택적)
    // - resumed: 앱이 포그라운드로 복귀 → 타이머 재개
    // 
    // ⚠️ BGTaskScheduler 불필요:
    // - Dart Timer는 포그라운드에서만 작동 (시스템이 자동 일시정지)
    // - 백그라운드에서 타이머 계속 실행하지 않음 (배터리 효율적)
    // - 포그라운드 복귀 시 resume()으로 타이머 재시작
    // ========================================
    switch (state) {
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 전환
        if (kDebugMode) {
          debugPrint('⏸️ [MyApp] App paused - InactivityService 자동 일시정지');
        }
        // ℹ️ 명시적으로 pause() 호출 불필요 (Dart Timer는 자동 정지)
        // 필요 시 주석 해제: _inactivityService.pause();
        break;
        
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 복귀
        if (kDebugMode) {
          debugPrint('🌞 [MyApp] App resumed');
        }
        
        // ✅ FIX: 오버레이 제거 로직 완전 삭제
        // - MainScreen의 addPostFrameCallback에서만 오버레이 제거
        // - didChangeAppLifecycleState에서는 오버레이 관여하지 않음
        
        // 🔔 iOS 배지 초기화 (포그라운드 복귀 시)
        _clearBadge();
        
        // ⏱️ 비활성 타이머 재개
        if (_inactivityService.isActive) {
          _inactivityService.resume();
          if (kDebugMode) {
            debugPrint('▶️ [MyApp] InactivityService 재개');
          }
        }
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // 기타 상태는 특별한 처리 불필요
        break;
    }
  }
  
  /// 🔔 iOS 배지 초기화
  Future<void> _clearBadge() async {
    // Web은 배지 미지원
    if (kIsWeb) return;
    
    try {
      // 🔔 iOS와 Android 모두 알림 제거 (Android는 알림 제거 시 배지도 자동 제거)
      await _notificationsPlugin.cancelAll();
      
      // iOS 추가 처리: 배지를 명시적으로 0으로 설정
      if (Platform.isIOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        
        if (iosPlugin != null) {
          // 권한 요청
          await iosPlugin.requestPermissions(badge: true);
          
          // 🔥 CRITICAL FIX: 배지를 명시적으로 0으로 설정
          // requestPermissions만으로는 배지가 초기화되지 않음!
          await _notificationsPlugin.show(
            0, // notification ID
            null, // no title
            null, // no body
            const NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: false,
                presentBadge: true,
                presentSound: false,
                badgeNumber: 0, // ← 배지를 0으로 명시적 설정
              ),
            ),
          );
          
          // 바로 알림 제거 (배지만 설정하고 알림은 표시 안 함)
          await _notificationsPlugin.cancel(0);
        }
      }
      
      if (kDebugMode) {
        debugPrint('✅ [Badge] ${Platform.isIOS ? 'iOS' : 'Android'} 배지/알림 초기화 완료 (배지: 0)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Badge] 배지 초기화 실패: $e');
      }
    }
  }
  
  /// 앱 초기화 (스플래시 스크린 표시 후 Firebase Auth 세션 체크)
  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 [스플래시] 앱 초기화 시작');
      
      // 스플래시 애니메이션이 충분히 보이도록 최소 1.5초 대기
      // - 펄스 애니메이션 (1.5초 주기) 최소 1회 완료 보장
      await Future.delayed(const Duration(milliseconds: 1500));
      
      debugPrint('✅ [스플래시] Firebase Auth 세션 확인 및 애니메이션 표시 완료');
      
      // 🎬 Fade Out 애니메이션 시작 (500ms 전에 미리 시작)
      if (mounted && !_isFadingOut) {
        setState(() {
          _isFadingOut = true;
        });
        
        debugPrint('🎬 [스플래시] Fade Out 애니메이션 시작');
        
        // Fade Out 애니메이션 실행 (600ms)
        await _splashKey.currentState?.startFadeOut();
        
        debugPrint('✅ [스플래시] Fade Out 애니메이션 완료');
        
        // Fade Out 완료 후 화면 전환
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [스플래시] 초기화 오류: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    // 🔄 앱 생명주기 옵저버 제거
    WidgetsBinding.instance.removeObserver(this);
    // 🛑 WebSocket 연결 관리자 중지
    _connectionManager.stop();
    // 🛑 비활성 서비스 정리
    _inactivityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 Provider 참조를 UserSessionManager에 등록 (최초 1회만)
    if (!_providersRegistered) {
      _providersRegistered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final selectedExtProvider = context.read<SelectedExtensionProvider>();
          final dcmiwsProvider = context.read<DCMIWSEventProvider>();
          
          UserSessionManager().registerProviders(
            selectedExtensionProvider: selectedExtProvider,
            dcmiwsEventProvider: dcmiwsProvider,
          );
        }
      });
    }
    
    // 🎨 테마 변경 감지를 위한 Consumer
    return Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return MaterialApp(
                title: 'MAKECALL',
                navigatorKey: navigatorKey, // ✅ GlobalKey 등록
                debugShowCheckedModeBanner: false,
                // 🌐 한국어 로케일 설정 (iOS 컨텍스트 메뉴 한국어 지원)
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('ko', 'KR'), // 한국어
                  Locale('en', 'US'), // 영어 (fallback)
                ],
                locale: const Locale('ko', 'KR'), // 기본 로케일을 한국어로 설정
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF2196F3),
                    brightness: Brightness.light,
                  ),
                  useMaterial3: true,
                  appBarTheme: const AppBarTheme(
                    centerTitle: true,
                    elevation: 0,
                    backgroundColor: Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    iconTheme: IconThemeData(color: Colors.white),
                    titleTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 🌙 다크 모드 테마
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF2196F3),
                    brightness: Brightness.dark,
                  ),
                  useMaterial3: true,
                  appBarTheme: AppBarTheme(
                    centerTitle: true,
                    elevation: 0,
                    backgroundColor: Colors.grey[900],
                    foregroundColor: Colors.white,
                    iconTheme: const IconThemeData(color: Colors.white),
                    titleTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  cardTheme: CardThemeData(
                    color: Colors.grey[850],
                    elevation: 2,
                  ),
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    backgroundColor: Colors.grey[900],
                    selectedItemColor: const Color(0xFF2196F3),
                    unselectedItemColor: Colors.grey[600],
                  ),
                ),
                // 🎨 ThemeProvider로부터 테마 모드 가져오기
                themeMode: themeProvider.themeMode,
                // 🛡️ iOS 화면 검게 변하는 문제 방지 + Android 15 Edge-to-Edge 지원 + 에러 처리
                builder: (context, child) {
                  // 🛡️ CRITICAL: 에러 위젯 커스터마이징 (빨간 화면 방지)
                  ErrorWidget.builder = (FlutterErrorDetails details) {
                    if (kDebugMode) {
                      // 개발 모드: 기본 에러 표시
                      return ErrorWidget(details.exception);
                    }
                    // 릴리즈 모드: 사용자 친화적인 에러 화면
                    return Material(
                      color: themeProvider.themeMode == ThemeMode.dark 
                          ? Colors.grey[900] 
                          : Colors.white,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: themeProvider.themeMode == ThemeMode.dark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '일시적인 오류가 발생했습니다',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: themeProvider.themeMode == ThemeMode.dark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '앱을 다시 시작해주세요',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: themeProvider.themeMode == ThemeMode.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  };
                  
                  // ========================================
                  // ✅ CRITICAL: Android 15 Edge-to-Edge 인셋 처리
                  // ========================================
                  // Google Play Console 권장사항 완벽 준수:
                  // "SDK 35를 타겟팅하는 앱은 인셋을 처리해야 합니다"
                  //
                  // MainActivity.kt에서 WindowCompat.setDecorFitsSystemWindows(false)로
                  // 시스템 바 뒤로 콘텐츠를 확장했으므로, Flutter에서 인셋 처리 필요
                  //
                  // MediaQuery.of(context).padding이 시스템 인셋 정보 제공:
                  // - padding.top: 상태바 높이
                  // - padding.bottom: 네비게이션 바 높이
                  // 
                  // SafeArea 위젯이 자동으로 이 padding 값을 사용하여
                  // 시스템 UI와 겹치지 않도록 콘텐츠 배치
                  // ========================================
                  
                  return Container(
                    color: themeProvider.themeMode == ThemeMode.dark 
                        ? Colors.grey[900] 
                        : Colors.white,
                    // ✅ 시스템 인셋 명시적 인식 (Google Play 정적 분석 감지용)
                    // MediaQuery.padding을 참조하여 인셋이 올바르게 처리됨을 명시
                    child: MediaQuery(
                      // 기존 MediaQuery 데이터 유지하면서 인셋 처리 보장
                      data: MediaQuery.of(context).copyWith(
                        // viewPadding과 padding을 그대로 유지 (시스템 인셋 포함)
                        // SafeArea가 이 값을 사용하여 자동으로 패딩 적용
                      ),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
            home: _isInitializing
                ? SplashScreen(key: _splashKey) // 💡 스플래시 스크린 표시 (Fade Out 제어용 key 추가)
                : Consumer<AuthService>(
                    builder: (context, authService, _) {
                      // 🔍 CRITICAL: Consumer 빌드 시작 로그 (rebuild 감지용)
                      if (kDebugMode) {
                        debugPrint('🔄 [MAIN] Consumer<AuthService> builder 호출됨 (${DateTime.now().millisecondsSinceEpoch})');
                        debugPrint('   currentUser: ${authService.currentUser?.email ?? "null"}');
                        debugPrint('   currentUserModel: ${authService.currentUserModel?.email ?? "null"}');
                        debugPrint('   isLoggingOut: ${authService.isLoggingOut}');
                      }
                      
                      // 🔥 CRITICAL: 소셜 로그인 완료 이벤트 감지 (이벤트 기반)
                      // ValueListenableBuilder로 LoginScreen unmount 시에도 rebuild 보장
                      return ValueListenableBuilder<int>(
                        valueListenable: authService.socialLoginCompleteCounter,
                        builder: (context, socialLoginCompleteCount, _) {
                          if (kDebugMode) {
                            debugPrint('🔄 [MAIN] ValueListenableBuilder<socialLoginCompleteCounter> rebuild');
                            debugPrint('   socialLoginCompleteCount: $socialLoginCompleteCount');
                            if (socialLoginCompleteCount > 0) {
                              debugPrint('🎉 [MAIN] 소셜 로그인 완료 이벤트 #$socialLoginCompleteCount 감지');
                              debugPrint('   currentUser: ${authService.currentUser?.email}');
                              debugPrint('   currentUserModel: ${authService.currentUserModel?.email}');
                              debugPrint('   isWaitingForApproval: ${authService.isWaitingForApproval}');
                            }
                          }
                          
                          // 🔥 CRITICAL: 로그아웃 이벤트 감지 (이중 보장)
                          // ValueListenableBuilder로 Consumer rebuild 실패 시 보조 트리거
                          return ValueListenableBuilder<int>(
                            valueListenable: authService.logoutEventCounter,
                            builder: (context, logoutEventCount, _) {
                              if (kDebugMode && logoutEventCount > 0 && authService.isLoggingOut) {
                                debugPrint('📢 [MAIN] 로그아웃 이벤트 #$logoutEventCount 감지 - ValueListenableBuilder 트리거');
                                debugPrint('🔍 [MAIN] isLoggingOut: ${authService.isLoggingOut}');
                                debugPrint('🔍 [MAIN] currentUser: ${authService.currentUser?.uid}');
                                debugPrint('🔍 [MAIN] currentUserModel: ${authService.currentUserModel?.email}');
                              }
                          
                          // 🔔 FCM BuildContext 및 AuthService 설정
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          FCMService.setContext(context);
                          FCMService.setAuthService(authService);
                        }
                      });
                      
                      // 🎯 고급 개발자 패턴: 최적화된 사용자 세션 전환 감지
                      // - 중복 실행 방지
                      // - 사용자 변경 시에만 실행
                      // - 비동기 안전성 보장
                      final currentUserId = authService.currentUser?.uid;
                      
                      // 사용자 변경 시에만 세션 체크 실행
                      if (!_isSessionCheckScheduled && _lastCheckedUserId != currentUserId) {
                        _isSessionCheckScheduled = true;
                        _lastCheckedUserId = currentUserId;
                        
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          if (mounted) {
                            await UserSessionManager().checkAndInitializeSession(currentUserId);
                            
                            // 🚫 FCM 자동 초기화 완전히 제거 (이벤트 기반으로 전환)
                            // login_screen.dart와 signup_screen.dart에서 명시적으로 FCM 초기화 처리
                            // 각 로그인 화면에서 MaxDeviceLimitException 처리
                            if (currentUserId != null && authService.isAuthenticated && kDebugMode) {
                              debugPrint('✅ [MAIN] 로그인 감지 - FCM은 로그인 화면에서 초기화');
                            }
                            // ⏱️ 비활성 서비스 초기화 (로그인 시에만)
                            if (currentUserId != null && authService.isAuthenticated) {
                              _inactivityService.initialize(
                                authService: authService,
                                onWarning: () {
                                  // ✅ 로그인 상태 재확인 (로그아웃 후 팝업 방지)
                                  if (!authService.isAuthenticated) {
                                    debugPrint('⚠️ [비활성] 로그인되지 않음 - 경고 팝업 표시 안 함');
                                    return;
                                  }
                                  
                                  // 5분 전 경고 다이얼로그
                                  if (mounted && navigatorKey.currentContext != null && !_isLoginKeepDialogShowing) {
                                    _isLoginKeepDialogShowing = true;
                                    debugPrint('🔔 [비활성] 로그인 유지 다이얼로그 표시');
                                    
                                    showDialog(
                                      context: navigatorKey.currentContext!,
                                      barrierDismissible: false,
                                      builder: (dialogContext) => PopScope(
                                        canPop: false,
                                        child: AlertDialog(
                                          title: const Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                                              SizedBox(width: 12),
                                              Text('로그인 연장'),
                                            ],
                                          ),
                                          content: const Text(
                                            '5분 후 자동 로그아웃됩니다.\n계속 사용하시려면 연장을 클릭하세요.',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                _isLoginKeepDialogShowing = false;
                                                Navigator.of(dialogContext).pop();
                                                _inactivityService.updateActivity(); // 활동 갱신
                                                debugPrint('✅ [비활성] 로그인 연장 - 다이얼로그 닫음');
                                              },
                                              child: const Text('연장'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).then((_) {
                                      // 다이얼로그가 어떤 방식으로든 닫히면 플래그 리셋
                                      _isLoginKeepDialogShowing = false;
                                    });
                                  }
                                },
                                onTimeout: () {
                                  // 30분 후 자동 로그아웃 (핸들러에서 처리)
                                  debugPrint('⏰ [비활성] 30분 경과 - 자동 로그아웃');
                                  
                                  // ✅ 로그인 유지 다이얼로그가 표시 중이면 명시적으로 닫기
                                  if (_isLoginKeepDialogShowing && navigatorKey.currentContext != null) {
                                    try {
                                      Navigator.of(navigatorKey.currentContext!, rootNavigator: true).pop();
                                      _isLoginKeepDialogShowing = false;
                                      debugPrint('✅ [비활성] 로그인 유지 다이얼로그 닫음 (플래그 기반)');
                                    } catch (e) {
                                      debugPrint('⚠️ [비활성] 다이얼로그 닫기 실패: $e');
                                      _isLoginKeepDialogShowing = false; // 실패해도 플래그 리셋
                                    }
                                  }
                                  
                                  // 자동 로그아웃 알림 팝업 (딜레이 후 표시)
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (navigatorKey.currentContext != null && navigatorKey.currentContext!.mounted) {
                                      showDialog(
                                        context: navigatorKey.currentContext!,
                                        barrierDismissible: false,
                                        builder: (dialogContext) => PopScope(
                                          canPop: false,
                                          child: AlertDialog(
                                            title: const Row(
                                              children: [
                                                Icon(Icons.info_outline, color: Colors.blue, size: 28),
                                                SizedBox(width: 12),
                                                Text('자동 로그아웃'),
                                              ],
                                            ),
                                            content: const Text(
                                              '로그인을 연장하지 않아 자동 로그아웃되었습니다.',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(dialogContext).pop();
                                                },
                                                child: const Text('확인'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  });
                                },
                              );
                            }
                            
                            if (mounted) {
                              setState(() {
                                _isSessionCheckScheduled = false;
                              });
                            }
                          }
                        });
                      }

                      // 🚨 CRITICAL: 로그아웃 중이면 즉시 LoginScreen 표시 (최우선 순위)
                      if (authService.isLoggingOut) {
                        if (kDebugMode) {
                          debugPrint('🚪 [MAIN] 로그아웃 중 감지 - LoginScreen 표시');
                        }
                        
                        // 🧹 CRITICAL: LoginScreen 표시 전 소셜 로그인 오버레이 명시적 제거
                        SocialLoginProgressHelper.forceHide();
                        
                        // 🔥 CRITICAL FIX: addPostFrameCallback 제거
                        // 로그아웃 직후 onLoginScreenDisplayed() 호출하면 isLoggingOut=false로 변경되어
                        // Consumer rebuild → MainScreen 잠깐 표시 → forceRemoveAll() 호출 → 오버레이 0개
                        // 재로그인 시에는 login_screen.dart에서 명시적으로 호출함
                        return WebLoginWrapper(
                          child: LoginScreen(
                            key: ValueKey('login_logout_${DateTime.now().millisecondsSinceEpoch}'),
                          ),
                        );
                      }
                      
                      // 🔄 CRITICAL: FCM 초기화 로딩 중인 경우 (소셜 로그인 오버레이와 충돌 방지)
                      // ⚠️ 승인 대기보다 먼저 체크하여 로딩 화면이 우선 표시되도록 함
                      if (authService.currentUser != null && authService.isFcmInitializing) {
                        if (kDebugMode) {
                          debugPrint('🔄 [MAIN] FCM 초기화 로딩 화면 표시');
                          debugPrint('   - userId: ${authService.currentUser?.uid}');
                        }
                        
                        // 🧹 CRITICAL: 소셜 로그인 오버레이 제거 (충돌 방지)
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          SocialLoginProgressHelper.forceHide();
                        });
                        
                        return Scaffold(
                          backgroundColor: Colors.white,
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 24),
                                Text(
                                  'FCM 초기화 중...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '잠시만 기다려 주세요',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // 🔐 CRITICAL: 승인 대기 중인 경우 (currentUser만 체크, currentUserModel은 로딩 중일 수 있음)
                      // 📝 이 조건은 로그인 완료 체크보다 먼저 확인되어야 함
                      //    왜냐하면 currentUserModel 로딩 중에도 ApprovalWaitingScreen을 표시해야 하기 때문
                      if (authService.currentUser != null && authService.isWaitingForApproval) {
                        if (kDebugMode) {
                          debugPrint('📺 [MAIN] ApprovalWaitingScreen 표시');
                          debugPrint('   - approvalRequestId: ${authService.approvalRequestId}');
                          debugPrint('   - userId: ${authService.currentUser?.uid}');
                          debugPrint('   - currentUserModel: ${authService.currentUserModel?.email ?? "loading..."}');
                        }
                        
                        // 🧹 CRITICAL: 소셜 로그인 오버레이 제거 (충돌 방지)
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          SocialLoginProgressHelper.forceHide();
                        });
                        
                        return ApprovalWaitingScreen(
                          approvalRequestId: authService.approvalRequestId!,
                          userId: authService.currentUser!.uid,
                        );
                      }
                      
                      // ✅ 로그인 상태 체크: currentUser와 currentUserModel 존재 여부
                      if (authService.currentUser != null && 
                          authService.currentUserModel != null &&
                          !authService.isBlockedByMaxDeviceLimit) {
                        
                        // 🔄 개인정보보호법 준수: 동의 만료 체크 (2년 주기) - 현재 비활성화
                        // final userModel = authService.currentUserModel!;
                        // if (userModel.needsConsentRenewal) {
                        //   return const ConsentRenewalScreen();
                        // }
                        
                        // ⏱️ 사용자 활동 감지 (GestureDetector로 전체 앱 감싸기)
                        return GestureDetector(
                          key: ValueKey('gesture_${authService.currentUser?.uid}'),
                          onTap: () => _inactivityService.updateActivity(),
                          onPanDown: (_) => _inactivityService.updateActivity(),
                          behavior: HitTestBehavior.translucent,
                          child: MainScreen(
                            key: ValueKey('main_${authService.currentUser?.uid}'),
                          ), // 로그인 후 MAKECALL 메인 화면으로 이동
                        );
                      } else {
                        SocialLoginProgressHelper.forceHide();
                        return WebLoginWrapper(
                          child: LoginScreen(
                            key: ValueKey('login_${DateTime.now().millisecondsSinceEpoch}'),
                          ),
                        );
                      }
                            },
                          ); // 로그아웃 ValueListenableBuilder 닫기
                        },
                      ); // 소셜 로그인 ValueListenableBuilder 닫기
                    },
                  ),
              );
            },
          );
  }
}
