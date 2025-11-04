import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/user_session_manager.dart';
import 'services/fcm_service.dart';
import 'providers/selected_extension_provider.dart';
import 'providers/dcmiws_event_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';

/// 백그라운드 FCM 메시지 핸들러 (Top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  debugPrint('🔔 백그라운드 메시지 수신:');
  debugPrint('  제목: ${message.notification?.title}');
  debugPrint('  내용: ${message.notification?.body}');
  debugPrint('  데이터: ${message.data}');
  
  // 백그라운드에서는 로컬 알림만 표시
  // 풀스크린은 앱이 포그라운드로 돌아왔을 때 표시
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🔔 FCM 백그라운드 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // 🗄️ Hive 초기화 (로컬 데이터 저장소)
  await Hive.initFlutter();
  
  // 🎯 사용자 세션 관리자 초기화 (고급 개발자 패턴)
  // 마지막 로그인한 사용자 ID 불러오기
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
          
          // 🎯 FCMService에 BuildContext 등록 (한 번만 실행)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              FCMService.setContext(context);
            }
          });
          
          return MaterialApp(
            title: 'MAKECALL',
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
