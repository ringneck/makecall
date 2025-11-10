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
import 'providers/selected_extension_provider.dart';
import 'providers/dcmiws_event_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';

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
    });
  }
  
  @override
  void dispose() {
    // 🛑 WebSocket 연결 관리자 중지
    _connectionManager.stop();
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
            home: Consumer<AuthService>(
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
                      if (mounted) {
                        setState(() {
                          _isSessionCheckScheduled = false;
                        });
                      }
                    }
                  });
                }

                if (authService.isAuthenticated) {
                  return const MainScreen(); // 로그인 후 MAKECALL 메인 화면으로 이동
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
