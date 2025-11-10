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
  debugPrint('\n${'=' * 80}');
  debugPrint('🔔 [BACKGROUND-001] 백그라운드 메시지 핸들러 실행');
  debugPrint('📊 Timestamp: ${DateTime.now().toIso8601String()}');
  debugPrint('${'=' * 80}');
  
  // Firebase가 이미 초기화되었는지 확인
  debugPrint('🔍 [BACKGROUND-002] Firebase 상태 체크');
  debugPrint('   - Firebase.apps.isEmpty: ${Firebase.apps.isEmpty}');
  debugPrint('   - Firebase.apps.length: ${Firebase.apps.length}');
  
  if (Firebase.apps.isEmpty) {
    debugPrint('⚠️  [BACKGROUND-003] Firebase 미초기화 감지 - 초기화 시작...');
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      debugPrint('✅ [BACKGROUND-004] Firebase 초기화 완료');
    } catch (e) {
      debugPrint('❌ [BACKGROUND-ERROR-004] Firebase 초기화 실패: $e');
      rethrow;
    }
  } else {
    debugPrint('✅ [BACKGROUND-003] Firebase 이미 초기화됨');
  }
  
  debugPrint('📨 [BACKGROUND-005] 메시지 상세:');
  debugPrint('   - 제목: ${message.notification?.title}');
  debugPrint('   - 내용: ${message.notification?.body}');
  debugPrint('   - 데이터: ${message.data}');
  debugPrint('${'=' * 80}\n');
  
  // 백그라운드에서는 로컬 알림만 표시
  // 풀스크린은 앱이 포그라운드로 돌아왔을 때 표시
}

// 🔑 GlobalKey for Navigator (수신 전화 풀스크린 표시용)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 🚀 [TRACE-001] Flutter 엔진 초기화 시작
  debugPrint('\n${'=' * 80}');
  debugPrint('🚀 [TRACE-001] main() 실행 시작');
  debugPrint('📊 Timestamp: ${DateTime.now().toIso8601String()}');
  debugPrint('${'=' * 80}\n');
  
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('✅ [TRACE-002] WidgetsFlutterBinding 초기화 완료\n');
  
  // 🔍 [TRACE-003] Firebase 초기화 전 상태 확인
  debugPrint('${'=' * 80}');
  debugPrint('🔍 [TRACE-003] Firebase 초기화 전 상태 체크');
  debugPrint('📊 Firebase.apps.length: ${Firebase.apps.length}');
  debugPrint('📊 Firebase.apps.isEmpty: ${Firebase.apps.isEmpty}');
  if (Firebase.apps.isNotEmpty) {
    debugPrint('⚠️  WARNING: Firebase가 이미 초기화되어 있습니다!');
    for (var app in Firebase.apps) {
      debugPrint('   - App name: ${app.name}');
      debugPrint('   - App options: ${app.options}');
    }
  }
  debugPrint('${'=' * 80}\n');
  
  // 🔥 Firebase 초기화
  try {
    debugPrint('🔥 [TRACE-004] Firebase.initializeApp() 호출 시작...');
    final firebaseApp = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ [TRACE-005] Firebase 초기화 완료!');
    debugPrint('   - App name: ${firebaseApp.name}');
    debugPrint('   - Project ID: ${firebaseApp.options.projectId}');
    debugPrint('   - Platform: ${DefaultFirebaseOptions.currentPlatform}');
    debugPrint('   - Firebase.apps.length: ${Firebase.apps.length}\n');
  } catch (e, stackTrace) {
    debugPrint('❌ [TRACE-ERROR-005] Firebase 초기화 실패!');
    debugPrint('   Error: $e');
    debugPrint('   StackTrace: $stackTrace\n');
    rethrow;
  }
  
  // 🔔 FCM 백그라운드 핸들러 등록
  debugPrint('🔔 [TRACE-006] FCM 백그라운드 핸들러 등록...');
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  debugPrint('✅ [TRACE-007] FCM 백그라운드 핸들러 등록 완료\n');
  
  // 🗄️ Hive 초기화 (로컬 데이터 저장소)
  debugPrint('🗄️  [TRACE-008] Hive 초기화...');
  await Hive.initFlutter();
  debugPrint('✅ [TRACE-009] Hive 초기화 완료\n');
  
  // 🎯 사용자 세션 관리자 초기화 (고급 개발자 패턴)
  debugPrint('🎯 [TRACE-010] UserSessionManager 초기화...');
  await UserSessionManager().loadLastUserId();
  debugPrint('✅ [TRACE-011] UserSessionManager 초기화 완료\n');
  
  debugPrint('${'=' * 80}');
  debugPrint('🎉 [TRACE-012] main() 초기화 완료 - runApp() 호출');
  debugPrint('${'=' * 80}\n');
  
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
    
    debugPrint('\n${'=' * 80}');
    debugPrint('🎨 [WIDGET-001] MyApp.initState() 실행');
    debugPrint('📊 Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('${'=' * 80}');
    
    // 🔍 Firebase 상태 체크
    debugPrint('🔍 [WIDGET-002] Firebase 상태:');
    debugPrint('   - Firebase.apps.length: ${Firebase.apps.length}');
    debugPrint('   - Firebase.apps.isEmpty: ${Firebase.apps.isEmpty}');
    if (Firebase.apps.isNotEmpty) {
      for (var app in Firebase.apps) {
        debugPrint('   - App name: ${app.name}');
      }
    }
    debugPrint('');
    
    // 🔑 NavigatorKey를 DCMIWSService에 등록
    debugPrint('🔑 [WIDGET-003] NavigatorKey 등록...');
    DCMIWSService.setNavigatorKey(navigatorKey);
    debugPrint('✅ [WIDGET-004] NavigatorKey 등록 완료\n');
    
    // 🔐 FCM 강제 로그아웃 콜백 설정 (중복 로그인 방지)
    debugPrint('🔐 [WIDGET-005] FCM 강제 로그아웃 콜백 설정...');
    FCMService.setForceLogoutCallback(() async {
      debugPrint('🚨 [WIDGET-CALLBACK] 강제 로그아웃 실행');
      
      if (mounted) {
        final authService = context.read<AuthService>();
        await authService.signOut();
        
        // 로그인 화면으로 이동
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    });
    debugPrint('✅ [WIDGET-006] FCM 강제 로그아웃 콜백 설정 완료\n');
    
    // 🚀 WebSocket 연결 관리자 시작
    debugPrint('🚀 [WIDGET-007] WebSocket 연결 관리자 시작 예약...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔌 [WIDGET-POST-FRAME] WebSocket 연결 관리자 시작');
      _connectionManager.start();
    });
    
    debugPrint('${'=' * 80}');
    debugPrint('✅ [WIDGET-008] MyApp.initState() 완료');
    debugPrint('${'=' * 80}\n');
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
