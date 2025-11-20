import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 소셜 로그인 제공자 타입
enum SocialLoginProvider {
  google,
  kakao,
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
/// 3가지 소셜 로그인 제공자를 통합 관리:
/// - Google
/// - Kakao
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

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        return SocialLoginResult(
          success: false,
          errorMessage: '로그인이 취소되었습니다',
          provider: SocialLoginProvider.google,
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        if (kDebugMode) {
          debugPrint('✅ [Google] 로그인 성공');
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
        errorMessage: '구글 로그인 오류',
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
      bool isKakaoTalkInstalled = false;
      
      try {
        isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
      } catch (checkError) {
        if (checkError.toString().contains('MissingPluginException')) {
          return SocialLoginResult(
            success: false,
            errorMessage: '카카오 로그인 플러그인 오류\n\n'
                '앱을 완전히 종료한 후\n'
                '다시 시작해주세요.',
            provider: SocialLoginProvider.kakao,
          );
        }
      }
      
      kakao.OAuthToken token;
      
      if (kDebugMode) {
        debugPrint('🔄 [Kakao] 카카오톡 설치 여부: $isKakaoTalkInstalled');
      }
      
      // 카카오톡 앱 로그인 시도
      if (isKakaoTalkInstalled) {
        try {
          if (kDebugMode) {
            debugPrint('🔄 [Kakao] 카카오톡 앱 로그인 시도...');
          }
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
          if (kDebugMode) {
            debugPrint('✅ [Kakao] 카카오톡 앱 로그인 성공');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [Kakao] 카카오톡 앱 로그인 실패, 웹뷰로 전환: $e');
          }
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
          if (kDebugMode) {
            debugPrint('✅ [Kakao] 웹뷰 로그인 성공');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔄 [Kakao] 웹뷰 로그인 시도...');
        }
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
        if (kDebugMode) {
          debugPrint('✅ [Kakao] 웹뷰 로그인 성공');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ [Kakao] OAuth 토큰 획득 완료');
        debugPrint('🔄 [Kakao] 사용자 정보 조회 중...');
      }

      kakao.User user = await kakao.UserApi.instance.me();
      
      if (kDebugMode) {
        debugPrint('✅ [Kakao] 사용자 정보 조회 완료');
        debugPrint('   - User ID: ${user.id}');
        debugPrint('   - Email: ${user.kakaoAccount?.email}');
        debugPrint('   - Nickname: ${user.kakaoAccount?.profile?.nickname}');
      }

      // Firebase Custom Token 생성 및 로그인
      try {
        if (kDebugMode) {
          debugPrint('🔄 [Kakao] Firebase Custom Token 생성 요청 중...');
        }
        
        final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
        final callable = functions.httpsCallable('createCustomTokenForKakao');
        
        final response = await callable.call<Map<String, dynamic>>({
          'kakaoUid': user.id.toString(),
          'email': user.kakaoAccount?.email,
          'displayName': user.kakaoAccount?.profile?.nickname,
          'photoUrl': user.kakaoAccount?.profile?.profileImageUrl,
        });
        
        if (kDebugMode) {
          debugPrint('✅ [Kakao] Firebase Custom Token 생성 완료');
        }
        
        final customToken = response.data['customToken'] as String;
        
        if (kDebugMode) {
          debugPrint('🔄 [Kakao] Firebase 로그인 중...');
        }
        
        final userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);
        
        if (kDebugMode) {
          debugPrint('✅ [Kakao] Firebase 로그인 완료');
          debugPrint('✅ [Kakao] 전체 로그인 프로세스 성공');
        }
        
        return SocialLoginResult(
          success: true,
          userId: userCredential.user?.uid,
          email: user.kakaoAccount?.email,
          displayName: user.kakaoAccount?.profile?.nickname,
          photoUrl: user.kakaoAccount?.profile?.profileImageUrl,
          provider: SocialLoginProvider.kakao,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [Kakao] Firebase 인증 실패: $e');
        }
        
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('internal')) {
          return SocialLoginResult(
            success: false,
            errorMessage: '서버 설정 오류\n\n'
                '카카오 로그인 서버가 준비 중입니다.\n'
                '관리자에게 문의해주세요.',
            provider: SocialLoginProvider.kakao,
          );
        }
        
        return SocialLoginResult(
          success: false,
          errorMessage: 'Firebase 인증 실패\n\n'
              '잠시 후 다시 시도해주세요.',
          provider: SocialLoginProvider.kakao,
        );
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Kakao] 로그인 오류: $e');
      }
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancel') || errorString.contains('취소')) {
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인이 취소되었습니다',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      return SocialLoginResult(
        success: false,
        errorMessage: '카카오 로그인 오류',
        provider: SocialLoginProvider.kakao,
      );
    }
  }

  /// ===== 3. 애플 로그인 =====
  Future<SocialLoginResult> signInWithApple() async {
    try {
      if (kDebugMode) {
        debugPrint('🍎 [Apple] 로그인 시작');
      }
      
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'com.olssoo.makecall.signin',
          redirectUri: Uri.parse('https://makecallio.web.app/auth/callback'),
        ),
      );

      if (kDebugMode) {
        debugPrint('✅ [Apple] Apple 인증 정보 수신 완료');
        debugPrint('   - identityToken: ${credential.identityToken != null ? "있음 (${credential.identityToken!.length}자)" : "null"}');
        debugPrint('   - authorizationCode: ${credential.authorizationCode != null ? "있음 (${credential.authorizationCode!.length}자)" : "null"}');
        debugPrint('   - email: ${credential.email ?? "null"}');
        debugPrint('   - givenName: ${credential.givenName ?? "null"}');
        debugPrint('   - familyName: ${credential.familyName ?? "null"}');
      }

      // CRITICAL: identityToken과 authorizationCode null 체크
      if (credential.identityToken == null) {
        if (kDebugMode) {
          debugPrint('❌ [Apple] identityToken이 null입니다');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인 인증 정보를 받지 못했습니다.\n\n'
              'identityToken이 null입니다.\n'
              '다시 시도해주세요.',
          provider: SocialLoginProvider.apple,
        );
      }

      if (credential.authorizationCode == null) {
        if (kDebugMode) {
          debugPrint('❌ [Apple] authorizationCode가 null입니다');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인 인증 정보를 받지 못했습니다.\n\n'
              'authorizationCode가 null입니다.\n'
              '다시 시도해주세요.',
          provider: SocialLoginProvider.apple,
        );
      }

      if (kDebugMode) {
        debugPrint('🔄 [Apple] Firebase 자격증명 생성 중...');
      }

      final oAuthProvider = OAuthProvider('apple.com');
      final firebaseCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      if (kDebugMode) {
        debugPrint('🔄 [Apple] Firebase 로그인 시도 중...');
      }

      final UserCredential userCredential = await _auth.signInWithCredential(firebaseCredential);
      
      if (kDebugMode) {
        debugPrint('✅ [Apple] Firebase 로그인 완료');
        debugPrint('   - userCredential.user: ${userCredential.user != null ? "있음" : "null"}');
      }
      
      final User? user = userCredential.user;

      if (user != null) {
        if (kDebugMode) {
          debugPrint('✅ [Apple] 로그인 성공');
          debugPrint('   - UID: ${user.uid}');
          debugPrint('   - Email: ${user.email ?? "null"}');
          debugPrint('   - DisplayName: ${user.displayName ?? "null"}');
        }

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

    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인이 취소되었습니다',
          provider: SocialLoginProvider.apple,
        );
      }
      
      return SocialLoginResult(
        success: false,
        errorMessage: 'Apple 로그인 오류',
        provider: SocialLoginProvider.apple,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Apple] 로그인 오류: $e');
        debugPrint('   - Error Type: ${e.runtimeType}');
        debugPrint('   - Error Details: ${e.toString()}');
      }
      
      String errorString = e.toString();
      
      // 취소 감지
      if (errorString.contains('canceled') || errorString.contains('취소')) {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인이 취소되었습니다',
          provider: SocialLoginProvider.apple,
        );
      }
      
      // Android WebView 관련 오류 감지
      if (errorString.contains('WebView') || errorString.contains('redirect')) {
        if (kDebugMode) {
          debugPrint('⚠️ [Apple] WebView 관련 오류 감지 (Android)');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인 웹뷰 오류\n\n'
              'Android에서 Apple 로그인 중 문제가 발생했습니다.\n'
              '다시 시도해주세요.\n\n'
              '문제가 계속되면 다른 로그인 방법을 사용해주세요.',
          provider: SocialLoginProvider.apple,
        );
      }
      
      // identityToken/authorizationCode 관련 오류
      if (errorString.contains('identityToken') || 
          errorString.contains('authorizationCode') ||
          errorString.contains('credential')) {
        if (kDebugMode) {
          debugPrint('⚠️ [Apple] 인증 정보 수신 오류');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 인증 정보를 받지 못했습니다\n\n'
              '다시 시도해주세요.\n\n'
              '오류 상세: ${errorString.length > 100 ? errorString.substring(0, 100) : errorString}',
          provider: SocialLoginProvider.apple,
        );
      }
      
      // 일반 오류
      return SocialLoginResult(
        success: false,
        errorMessage: 'Apple 로그인 오류\n\n'
            '${errorString.length > 150 ? errorString.substring(0, 150) : errorString}',
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
