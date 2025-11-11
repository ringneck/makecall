import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/user_session_manager.dart';
import 'services/dcmiws_service.dart';
import 'services/dcmiws_connection_manager.dart';
import 'services/inactivity_service.dart';
import 'providers/selected_extension_provider.dart';
import 'providers/dcmiws_event_provider.dart';
import 'screens/auth/login_screen.dart';
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
  
  // 백그라운드에서는 알림을 시스템이 자동으로 표시함
  // 앱이 다시 열리면 onMessageOpenedApp에서 처리됨
}

// 🔑 GlobalKey for Navigator (수신 전화 풀스크린 표시용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 (Native에서 이미 초기화되었으므로 Flutter에서는 연결만)
  try {
    // iOS: Native (AppDelegate)에서 이미 초기화됨
    // Android: 여기서 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase 초기화 완료 (Flutter)');
  } catch (e) {
    // Native에서 이미 초기화된 경우 무시 (정상 동작)
    if (e.toString().contains('duplicate-app') || 
        e.toString().contains('already created')) {
      print('✅ Firebase 이미 초기화됨 (Native에서) - 정상');
    } else {
      print('❌ Firebase 초기화 오류: $e');
      rethrow;
    }
  }
  
  // FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Hive 초기화
  await Hive.initFlutter();
  
  // 사용자 세션 관리자 초기화
  await UserSessionManager().loadLastUserId();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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

  @override
  void initState() {
    super.initState();
    
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
  
  /// 앱 초기화 (스플래시 스크린 표시 후 Firebase Auth 세션 체크)
  Future<void> _initializeApp() async {
    try {
      debugPrint('🚀 [스플래시] 앱 초기화 시작');
      
      // Firebase Auth 세션 확인 대기 (최대 2초)
      await Future.delayed(const Duration(seconds: 2));
      
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
          
          return MaterialApp(
            title: 'MAKECALL',
            navigatorKey: navigatorKey, // ✅ GlobalKey 등록
            debugShowCheckedModeBanner: false,
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
            home: _isInitializing
                ? const SplashScreen() // 💡 스플래시 스크린 표시
                : Consumer<AuthService>(
                    builder: (context, authService, _) {
                      // 🔔 FCM BuildContext 설정 (수신 전화 화면 표시를 위해 필수)
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          FCMService.setContext(context);
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
                                  if (mounted && navigatorKey.currentContext != null) {
                                    showDialog(
                                      context: navigatorKey.currentContext!,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
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
                                              Navigator.of(context).pop();
                                              _inactivityService.updateActivity(); // 활동 갱신
                                            },
                                            child: const Text('연장'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                onTimeout: () {
                                  // 30분 후 자동 로그아웃 (핸들러에서 처리)
                                  debugPrint('⏰ [비활성] 30분 경과 - 자동 로그아웃');
                                  
                                  // ✅ 기존 경고 팝업 모두 닫기
                                  if (navigatorKey.currentContext != null) {
                                    // 현재 화면에 표시된 다이얼로그 모두 닫기
                                    Navigator.of(navigatorKey.currentContext!, rootNavigator: true)
                                        .popUntil((route) => route is! DialogRoute);
                                  }
                                  
                                  // 자동 로그아웃 알림 팝업
                                  if (context.mounted) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
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
                                              Navigator.of(context).pop();
                                            },
                                            child: const Text('확인'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
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

                      if (authService.isAuthenticated) {
                        // ⏱️ 사용자 활동 감지 (GestureDetector로 전체 앱 감싸기)
                        return GestureDetector(
                          onTap: () => _inactivityService.updateActivity(),
                          onPanDown: (_) => _inactivityService.updateActivity(),
                          behavior: HitTestBehavior.translucent,
                          child: const MainScreen(), // 로그인 후 MAKECALL 메인 화면으로 이동
                        );
                      } else {
                        return const LoginScreen();
                      }
                    },
                  ),
          );
        },
      ),
    );
  }
}
