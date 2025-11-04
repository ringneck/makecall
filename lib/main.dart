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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SelectedExtensionProvider()),
        ChangeNotifierProvider(create: (_) => DCMIWSEventProvider()),
      ],
      child: MaterialApp(
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
            // 🎯 고급 개발자 패턴: 사용자 세션 전환 감지 및 데이터 초기화
            // 로그인/로그아웃/계정 전환 시 자동으로 이전 데이터 정리
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final currentUserId = authService.currentUser?.uid;
              await UserSessionManager().checkAndInitializeSession(currentUserId);
            });

            if (authService.isAuthenticated) {
              return const MainScreen(); // 로그인 후 MAKECALL 메인 화면으로 이동
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}
