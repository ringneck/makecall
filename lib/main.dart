import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/user_session_manager.dart';
import 'providers/selected_extension_provider.dart';
import 'providers/dcmiws_event_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
