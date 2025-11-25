import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'dart:convert';
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
import 'screens/auth/consent_renewal_screen.dart';
import 'screens/home/main_screen.dart';
import 'screens/splash/splash_screen.dart';

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
    
    // 백그라운드에서는 알림을 시스템이 자동으로 표시함
    // 사용자가 알림을 탭하면 onMessageOpenedApp에서 수신 전화 화면 표시
  } else {
    debugPrint('ℹ️ [FCM-BG] 일반 메시지 (수신 전화 아님)');
  }
}

// 🔑 GlobalKey for Navigator (수신 전화 풀스크린 표시용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      print('❌ Firebase 초기화 오류: $e');
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
  
  runApp(const MyApp());
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
  
  // 🔒 로그인 유지 다이얼로그 표시 여부
  bool _isLoginKeepDialogShowing = false;
  
  // 🎨 테마 Provider
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  void initState() {
    super.initState();
    
    // 🔄 앱 생명주기 옵저버 등록 (iOS 화면 검게 변하는 문제 해결)
    WidgetsBinding.instance.addObserver(this);
    
    // 🎨 테마 설정 로드
    _themeProvider.loadThemeMode();
    
    // NavigatorKey 등록
    DCMIWSService.setNavigatorKey(navigatorKey);
    
    // FCM 강제 로그아웃 콜백 설정
    FCMService.setForceLogoutCallback(() async {
      if (mounted) {
        final authService = context.read<AuthService>();
        await authService.signOut();
        
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
    
    // iOS에서 포그라운드 복귀 시 UI 강제 재렌더링
    if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        debugPrint('🌞 [MyApp] App resumed - forcing UI rebuild');
      }
      
      if (mounted) {
        setState(() {
          // UI 강제 재렌더링 트리거
        });
      }
    }
  }
  
  /// 앱 초기화 (스플래시 스크린 표시 후 Firebase Auth 세션 체크)
  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 [스플래시] 앱 초기화 시작');
      
      // Firebase Auth 세션 확인 대기 (최대 2초)
      await Future.delayed(const Duration(seconds: 1));
      
      debugPrint('✅ [스플래시] Firebase Auth 세션 확인 완료');
      
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SelectedExtensionProvider()),
        ChangeNotifierProvider(create: (_) => DCMIWSEventProvider()),
        ChangeNotifierProvider.value(value: _themeProvider),
      ],
      child: Builder(
        builder: (context) {
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
                // 🛡️ iOS 화면 검게 변하는 문제 방지: Scaffold background 명시
                builder: (context, child) {
                  return Container(
                    color: themeProvider.themeMode == ThemeMode.dark 
                        ? Colors.grey[900] 
                        : Colors.white,
                    child: child,
                  );
                },
            home: _isInitializing
                ? const SplashScreen() // 💡 스플래시 스크린 표시
                : Consumer<AuthService>(
                    builder: (context, authService, _) {
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
                            
                            // 🔔 FCM 자동 초기화 (앱 업데이트 후 자동 로그인 시)
                            if (currentUserId != null && authService.isAuthenticated) {
                              try {
                                debugPrint('🔔 [MAIN] 자동 로그인 감지 - FCM 초기화 시작');
                                debugPrint('   User ID: $currentUserId');
                                
                                final fcmService = FCMService();
                                await fcmService.initialize(currentUserId);
                                
                                debugPrint('✅ [MAIN] FCM 초기화 완료 (앱 시작 시)');
                              } catch (e, stackTrace) {
                                debugPrint('❌ [MAIN] FCM 초기화 오류: $e');
                                debugPrint('Stack trace: $stackTrace');
                              }
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
                                      builder: (dialogContext) => WillPopScope(
                                        onWillPop: () async => false,
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
                                        builder: (dialogContext) => WillPopScope(
                                          onWillPop: () async => false,
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

                      // 🔐 승인 대기 중인 경우
                      if (authService.isWaitingForApproval) {
                        return ApprovalWaitingScreen(
                          approvalRequestId: authService.approvalRequestId!,
                          userId: authService.currentUser!.uid,
                        );
                      }
                      
                      // ✅ 로그인 상태 체크: currentUser와 currentUserModel 존재 여부
                      // isAuthenticated 대신 직접 체크 (승인 대기 상태와 독립적)
                      if (authService.currentUser != null && 
                          authService.currentUserModel != null &&
                          !authService.isLoggingOut) {
                        
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
                        return WebLoginWrapper(
                          child: LoginScreen(
                            key: ValueKey('login_${DateTime.now().millisecondsSinceEpoch}'),
                          ),
                        );
                      }
                    },
                  ),
              );
            },
          );
        },
      ),
    );
  }
}
