import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

/// 소셜 로그인 제공자 타입
enum SocialLoginProvider {
  google,
  kakao,
  naver,
  apple,
}

/// 소셜 로그인 결과
class SocialLoginResult {
  final bool success;
  final String? userId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? errorMessage;
  final SocialLoginProvider provider;

  SocialLoginResult({
    required this.success,
    this.userId,
    this.email,
    this.displayName,
    this.photoUrl,
    this.errorMessage,
    required this.provider,
  });
}

/// 소셜 로그인 통합 서비스
/// 
/// 4가지 소셜 로그인 제공자를 통합 관리:
/// - Google
/// - Kakao
/// - Naver
/// - Apple (iOS 전용)
class SocialLoginService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// ===== 1. 구글 로그인 =====
  Future<SocialLoginResult> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        debugPrint('🔵 [Google] 로그인 시작');
      }

      // Google Sign In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // 사용자가 로그인 취소
        if (kDebugMode) {
          debugPrint('⚠️ [Google] 사용자가 로그인 취소');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '로그인이 취소되었습니다',
          provider: SocialLoginProvider.google,
        );
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase 자격증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase 로그인
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        if (kDebugMode) {
          debugPrint('✅ [Google] 로그인 성공');
          debugPrint('   - UID: ${user.uid}');
          debugPrint('   - Email: ${user.email}');
          debugPrint('   - Name: ${user.displayName}');
        }

        return SocialLoginResult(
          success: true,
          userId: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoUrl: user.photoURL,
          provider: SocialLoginProvider.google,
        );
      }

      return SocialLoginResult(
        success: false,
        errorMessage: 'Firebase 로그인 실패',
        provider: SocialLoginProvider.google,
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Google] 로그인 오류: $e');
      }
      return SocialLoginResult(
        success: false,
        errorMessage: e.toString(),
        provider: SocialLoginProvider.google,
      );
    }
  }

  /// ===== 2. 카카오 로그인 =====
  Future<SocialLoginResult> signInWithKakao() async {
    try {
      if (kDebugMode) {
        debugPrint('🟡 [Kakao] 로그인 시작');
      }

      // 카카오톡 설치 여부 확인
      bool isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
      
      kakao.OAuthToken token;
      if (isKakaoTalkInstalled) {
        // 카카오톡으로 로그인
        if (kDebugMode) {
          debugPrint('📱 [Kakao] 카카오톡 앱으로 로그인');
        }
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        // 카카오 계정으로 로그인 (웹뷰)
        if (kDebugMode) {
          debugPrint('🌐 [Kakao] 카카오 계정으로 로그인');
        }
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      if (kDebugMode) {
        debugPrint('✅ [Kakao] 토큰 발급 성공');
      }

      // 사용자 정보 가져오기
      kakao.User user = await kakao.UserApi.instance.me();

      if (kDebugMode) {
        debugPrint('✅ [Kakao] 사용자 정보 조회 성공');
        debugPrint('   - ID: ${user.id}');
        debugPrint('   - Email: ${user.kakaoAccount?.email}');
        debugPrint('   - Nickname: ${user.kakaoAccount?.profile?.nickname}');
      }

      // Firebase Custom Token 방식으로 로그인
      // 🔧 TODO: 백엔드에서 카카오 ID를 받아 Firebase Custom Token 생성 필요
      // 현재는 카카오 로그인 성공 정보만 반환
      
      return SocialLoginResult(
        success: true,
        userId: user.id.toString(),
        email: user.kakaoAccount?.email,
        displayName: user.kakaoAccount?.profile?.nickname,
        photoUrl: user.kakaoAccount?.profile?.profileImageUrl,
        provider: SocialLoginProvider.kakao,
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Kakao] 로그인 오류: $e');
      }
      return SocialLoginResult(
        success: false,
        errorMessage: e.toString(),
        provider: SocialLoginProvider.kakao,
      );
    }
  }

  /// ===== 3. 네이버 로그인 =====
  Future<SocialLoginResult> signInWithNaver() async {
    try {
      if (kDebugMode) {
        debugPrint('🟢 [Naver] 로그인 시작');
      }

      // 네이버 로그인
      final NaverLoginResult result = await FlutterNaverLogin.logIn();

      if (result.status == NaverLoginStatus.loggedIn) {
        if (kDebugMode) {
          debugPrint('✅ [Naver] 로그인 성공');
        }

        // 네이버 계정 정보 가져오기
        final NaverAccountResult accountResult = await FlutterNaverLogin.currentAccount();

        if (kDebugMode) {
          debugPrint('✅ [Naver] 사용자 정보 조회 성공');
          debugPrint('   - ID: ${accountResult.id}');
          debugPrint('   - Email: ${accountResult.email}');
          debugPrint('   - Name: ${accountResult.name}');
        }

        // Firebase Custom Token 방식으로 로그인
        // 🔧 TODO: 백엔드에서 네이버 ID를 받아 Firebase Custom Token 생성 필요
        
        return SocialLoginResult(
          success: true,
          userId: accountResult.id,
          email: accountResult.email,
          displayName: accountResult.name,
          photoUrl: accountResult.profileImage,
          provider: SocialLoginProvider.naver,
        );
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [Naver] 로그인 취소 또는 실패: ${result.status}');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: result.errorMessage ?? '로그인이 취소되었습니다',
          provider: SocialLoginProvider.naver,
        );
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Naver] 로그인 오류: $e');
      }
      return SocialLoginResult(
        success: false,
        errorMessage: e.toString(),
        provider: SocialLoginProvider.naver,
      );
    }
  }

  /// ===== 4. 애플 로그인 (iOS 전용) =====
  Future<SocialLoginResult> signInWithApple() async {
    try {
      // iOS 플랫폼 확인
      if (!Platform.isIOS && !kIsWeb) {
        if (kDebugMode) {
          debugPrint('⚠️ [Apple] iOS 전용 기능');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인은 iOS에서만 지원됩니다',
          provider: SocialLoginProvider.apple,
        );
      }

      if (kDebugMode) {
        debugPrint('🍎 [Apple] 로그인 시작');
      }

      // Apple 로그인
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (kDebugMode) {
        debugPrint('✅ [Apple] 자격증명 발급 성공');
      }

      // Firebase 자격증명 생성
      final oAuthProvider = OAuthProvider('apple.com');
      final firebaseCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      // Firebase 로그인
      final UserCredential userCredential = await _auth.signInWithCredential(firebaseCredential);
      final User? user = userCredential.user;

      if (user != null) {
        if (kDebugMode) {
          debugPrint('✅ [Apple] 로그인 성공');
          debugPrint('   - UID: ${user.uid}');
          debugPrint('   - Email: ${user.email}');
        }

        // 이름 정보 업데이트 (첫 로그인 시)
        String? displayName = user.displayName;
        if (displayName == null || displayName.isEmpty) {
          if (credential.givenName != null || credential.familyName != null) {
            displayName = '${credential.familyName ?? ''}${credential.givenName ?? ''}'.trim();
            await user.updateDisplayName(displayName);
          }
        }

        return SocialLoginResult(
          success: true,
          userId: user.uid,
          email: user.email ?? credential.email,
          displayName: displayName,
          photoUrl: user.photoURL,
          provider: SocialLoginProvider.apple,
        );
      }

      return SocialLoginResult(
        success: false,
        errorMessage: 'Firebase 로그인 실패',
        provider: SocialLoginProvider.apple,
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Apple] 로그인 오류: $e');
      }
      return SocialLoginResult(
        success: false,
        errorMessage: e.toString(),
        provider: SocialLoginProvider.apple,
      );
    }
  }

  /// ===== 로그아웃 =====
  Future<void> signOut(SocialLoginProvider provider) async {
    try {
      switch (provider) {
        case SocialLoginProvider.google:
          await _googleSignIn.signOut();
          await _auth.signOut();
          if (kDebugMode) {
            debugPrint('✅ [Google] 로그아웃 완료');
          }
          break;

        case SocialLoginProvider.kakao:
          await kakao.UserApi.instance.logout();
          if (kDebugMode) {
            debugPrint('✅ [Kakao] 로그아웃 완료');
          }
          break;

        case SocialLoginProvider.naver:
          await FlutterNaverLogin.logOut();
          if (kDebugMode) {
            debugPrint('✅ [Naver] 로그아웃 완료');
          }
          break;

        case SocialLoginProvider.apple:
          await _auth.signOut();
          if (kDebugMode) {
            debugPrint('✅ [Apple] 로그아웃 완료');
          }
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [$provider] 로그아웃 오류: $e');
      }
    }
  }

  /// ===== 현재 로그인 상태 확인 =====
  User? get currentUser => _auth.currentUser;

  /// ===== Firebase Auth 상태 스트림 =====
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
