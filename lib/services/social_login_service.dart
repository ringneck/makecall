import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

/// 플랫폼 확인 헬퍼 (웹 플랫폼 안전 처리)
bool get _isIOS => !kIsWeb && Platform.isIOS;
bool get _isAndroid => !kIsWeb && Platform.isAndroid;

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
  
  // Android 네이티브 통신용 MethodChannel
  static const MethodChannel _channel = MethodChannel('com.olssoo.makecall_app/webview');

  /// ===== 1. 구글 로그인 (Android 네이티브 전용) =====
  Future<SocialLoginResult> signInWithGoogle() async {
    try {
      // Android만 지원
      if (!_isAndroid) {
        return SocialLoginResult(
          success: false,
          errorMessage: '구글 로그인은 Android 앱에서만 지원됩니다.',
          provider: SocialLoginProvider.google,
        );
      }

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

  /// ===== 2. 카카오 로그인 (Android 네이티브 전용) =====
  Future<SocialLoginResult> signInWithKakao() async {
    try {
      // Android만 지원
      if (!_isAndroid) {
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인은 Android 앱에서만 지원됩니다.',
          provider: SocialLoginProvider.kakao,
        );
      }

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
      
      // 카카오톡 앱 로그인 시도
      if (isKakaoTalkInstalled) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          // 카카오톡 로그인 실패 시 웹뷰로 전환
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 카카오톡 미설치 시 웹뷰 로그인
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 사용자 정보 가져오기
      kakao.User user = await kakao.UserApi.instance.me();

      // Firebase Custom Token 생성 및 로그인
      try {
        final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
        final callable = functions.httpsCallable('createCustomTokenForKakao');
        
        final response = await callable.call<Map<String, dynamic>>({
          'kakaoUid': user.id.toString(),
          'email': user.kakaoAccount?.email,
          'displayName': user.kakaoAccount?.profile?.nickname,
          'photoUrl': user.kakaoAccount?.profile?.profileImageUrl,
        });
        
        final customToken = response.data['customToken'] as String;
        final userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);
        
        if (kDebugMode) {
          debugPrint('✅ [Kakao] 로그인 성공');
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
          debugPrint('   Error Type: ${e.runtimeType}');
        }
        
        // INTERNAL 에러 감지
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('internal')) {
          if (kDebugMode) {
            debugPrint('⚠️ [Kakao] Firebase Functions INTERNAL 오류');
            debugPrint('   가능한 원인:');
            debugPrint('   1. Firebase Functions 미배포 (createCustomTokenForKakao)');
            debugPrint('   2. IAM 권한 미설정 (Service Account Token Creator)');
            debugPrint('   3. Functions Region 불일치 (asia-northeast3)');
          }
          
          return SocialLoginResult(
            success: false,
            errorMessage: '서버 설정 오류\n\n'
                '카카오 로그인 서버가 준비 중입니다.\n'
                '관리자에게 문의해주세요.\n\n'
                '오류 코드: FIREBASE_INTERNAL',
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
      
      // 사용자 취소 감지
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

  /// Android WebView 쿠키 삭제 (네이버 무한 동의 화면 방지)
  Future<void> _clearNaverWebViewCookies() async {
    if (!_isAndroid) return;
    
    try {
      await _channel.invokeMethod('clearNaverCookies');
      if (kDebugMode) {
        debugPrint('✅ [Naver] WebView 쿠키 삭제 완료');
      }
    } catch (e) {
      // 쿠키 삭제 실패해도 로그인 진행
    }
  }

  /// ===== 3. 네이버 로그인 (Android 네이티브 앱 전용) =====
  Future<SocialLoginResult> signInWithNaver() async {
    try {
      // Android만 지원
      if (!_isAndroid) {
        return SocialLoginResult(
          success: false,
          errorMessage: '네이버 로그인은 Android 앱에서만 지원됩니다.',
          provider: SocialLoginProvider.naver,
        );
      }

      if (kDebugMode) {
        debugPrint('🟢 [Naver] 로그인 시작');
      }

      // STEP 1: Android WebView 쿠키 삭제 (무한 동의 화면 방지)
      await _clearNaverWebViewCookies();

      // STEP 2: 기존 세션 로그아웃
      try {
        await FlutterNaverLogin.logOut();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (logoutError) {
        // 로그아웃 실패해도 계속 진행
      }

      // STEP 3: 네이버 로그인 시도
      NaverLoginResult result;
      final startTime = DateTime.now();
      
      if (kDebugMode) {
        debugPrint('🔄 [Naver] FlutterNaverLogin.logIn() 호출 중...');
      }
      
      try {
        result = await FlutterNaverLogin.logIn();
        
        final elapsedTime = DateTime.now().difference(startTime);
        
        if (kDebugMode) {
          debugPrint('✅ [Naver] 로그인 응답 받음');
          debugPrint('   - status: ${result.status}');
          debugPrint('   - status.name: ${result.status.name}');
          debugPrint('   - errorMessage: ${result.errorMessage ?? "없음"}');
          debugPrint('   - account: ${result.account != null ? "있음" : "없음"}');
          debugPrint('   - elapsed time: ${elapsedTime.inMilliseconds}ms');
          
          // 네이버 앱 미설치 가능성 체크
          if (result.status == NaverLoginStatus.error) {
            debugPrint('🔍 [Naver] ERROR 상태 감지 - 네이버 앱 미설치 가능성');
            debugPrint('   - errorMessage 내용: "${result.errorMessage}"');
          }
          
          if (result.status == NaverLoginStatus.loggedOut && elapsedTime.inSeconds < 3) {
            debugPrint('🔍 [Naver] loggedOut 상태 + 빠른 종료 (${elapsedTime.inMilliseconds}ms)');
            debugPrint('   → 네이버 앱 미설치 가능성 높음');
          }
        }
      } catch (loginError) {
        if (kDebugMode) {
          debugPrint('❌ [Naver] 로그인 호출 중 Exception 발생');
          debugPrint('   - Error Type: ${loginError.runtimeType}');
          debugPrint('   - Error: $loginError');
        }
        
        // Exception 발생 시 일반 오류로 처리
        return SocialLoginResult(
          success: false,
          errorMessage: '네이버 로그인 중 오류가 발생했습니다.\n\n'
              '잠시 후 다시 시도해주세요.',
          provider: SocialLoginProvider.naver,
        );
      }

      if (result.status == NaverLoginStatus.loggedIn && result.account != null) {
        final account = result.account!;
        
        if (kDebugMode) {
          debugPrint('✅ [Naver] 로그인 성공');
        }

        // Firebase Custom Token 생성 및 로그인
        try {
          final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
          final callable = functions.httpsCallable('createCustomTokenForNaver');
          
          final response = await callable.call<Map<String, dynamic>>({
            'naverId': account.id,
            'email': account.email,
            'nickname': account.name,
            'profileImage': account.profileImage,
          });
          
          final customToken = response.data['customToken'] as String;
          final userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);
          
          if (kDebugMode) {
            debugPrint('✅ [Naver] Firebase 로그인 완료');
          }
          
          return SocialLoginResult(
            success: true,
            userId: userCredential.user?.uid,
            email: account.email,
            displayName: account.name,
            photoUrl: account.profileImage,
            provider: SocialLoginProvider.naver,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ [Naver] Firebase 인증 실패: $e');
            debugPrint('   Error Type: ${e.runtimeType}');
          }
          
          // INTERNAL 에러 감지
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('internal')) {
            if (kDebugMode) {
              debugPrint('⚠️ [Naver] Firebase Functions INTERNAL 오류');
              debugPrint('   가능한 원인:');
              debugPrint('   1. Firebase Functions 미배포 (createCustomTokenForNaver)');
              debugPrint('   2. IAM 권한 미설정 (Service Account Token Creator)');
              debugPrint('   3. Functions Region 불일치 (asia-northeast3)');
            }
            
            return SocialLoginResult(
              success: false,
              errorMessage: '서버 설정 오류\n\n'
                  '네이버 로그인 서버가 준비 중입니다.\n'
                  '관리자에게 문의해주세요.\n\n'
                  '오류 코드: FIREBASE_INTERNAL',
              provider: SocialLoginProvider.naver,
            );
          }
          
          return SocialLoginResult(
            success: false,
            errorMessage: 'Firebase 인증 실패\n\n'
                '잠시 후 다시 시도해주세요.',
            provider: SocialLoginProvider.naver,
          );
        }
      } else {
        // 로그인 취소 또는 실패
        if (kDebugMode) {
          debugPrint('ℹ️ [Naver] 로그인 미완료');
          debugPrint('   - status: ${result.status}');
          debugPrint('   - errorMessage: ${result.errorMessage ?? "없음"}');
        }
        
        String errorMessage;
        final elapsedTime = DateTime.now().difference(startTime);
        
        if (result.status == NaverLoginStatus.error) {
          // 에러 상태
          if (kDebugMode) {
            debugPrint('ℹ️ [Naver] ERROR 상태');
          }
          errorMessage = '네이버 로그인 중 오류가 발생했습니다.\n\n'
              '잠시 후 다시 시도해주세요.';
        } else if (result.status == NaverLoginStatus.loggedOut) {
          // 사용자 취소
          if (kDebugMode) {
            debugPrint('ℹ️ [Naver] 사용자 취소 (${elapsedTime.inMilliseconds}ms)');
          }
          errorMessage = '로그인이 취소되었습니다';
        } else {
          // 알 수 없는 상태
          errorMessage = '네이버 로그인에 실패했습니다.\n\n'
              '잠시 후 다시 시도해주세요.';
        }
        
        return SocialLoginResult(
          success: false,
          errorMessage: errorMessage,
          provider: SocialLoginProvider.naver,
        );
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ [Naver] 로그인 처리 중 예외: $e');
      }
      
      // 최종 catch - 네이버 앱 필수 안내
      return SocialLoginResult(
        success: false,
        errorMessage: '📱 네이버 앱 로그인 안내\n\n'
            '네이버 계정으로 로그인하기 위해서는\n'
            '네이버 앱이 설치되고,\n'
            '네이버 앱으로 로그인해야 합니다.\n\n'
            '✅ Play 스토어에서 네이버 앱을 설치한 후\n'
            '다시 시도해주세요.',
        provider: SocialLoginProvider.naver,
      );
    }
  }

  /// ===== 4. 애플 로그인 (Android 네이티브 전용) =====
  Future<SocialLoginResult> signInWithApple() async {
    try {
      // Android만 지원
      if (!_isAndroid) {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인은 Android 앱에서만 지원됩니다.',
          provider: SocialLoginProvider.apple,
        );
      }

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
      }
      
      // 사용자 취소 감지
      String errorString = e.toString();
      if (errorString.contains('canceled') || errorString.contains('취소')) {
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
