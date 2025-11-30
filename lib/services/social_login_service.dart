import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  // 🔧 Android Google Sign In 설정
  // google-services.json이 있으면 자동으로 Android OAuth Client 사용
  // serverClientId는 필요 없음 (Android Native는 google-services.json에서 자동 처리)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// ===== 1. 구글 로그인 =====
  Future<SocialLoginResult> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        debugPrint('🔵 [Google] 로그인 시작');
        debugPrint('   플랫폼: ${kIsWeb ? "Web" : "Mobile"}');
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [Google] 사용자가 로그인을 취소했습니다 (googleUser == null)');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '로그인이 취소되었습니다',
          provider: SocialLoginProvider.google,
        );
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // 웹 플랫폼 타입 안전 처리
      String? accessToken;
      String? idToken;
      
      try {
        accessToken = googleAuth.accessToken?.toString();
        idToken = googleAuth.idToken?.toString();
        
        if (kDebugMode) {
          debugPrint('   - accessToken: ${accessToken != null ? "있음" : "null"}');
          debugPrint('   - idToken: ${idToken != null ? "있음" : "null"}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [Google] 토큰 타입 변환 실패: $e');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '구글 로그인 인증 정보 처리 오류\n\n다시 시도해주세요.',
          provider: SocialLoginProvider.google,
        );
      }
      
      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
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
      // 🔥 CRITICAL: catch 블록 진입
      print('❌ [Google] 로그인 오류: $e');
      
      // 사용자 취소 감지
      final errorString = e.toString().toLowerCase();
      print('🔍 [Google] errorString: $errorString');
      
      final isCanceled = errorString.contains('sign_in_failed') || 
          errorString.contains('access_denied') ||
          errorString.contains('canceled') ||
          errorString.contains('cancelled');
          
      print('🔍 [Google] 취소 감지: $isCanceled');
      
      if (isCanceled) {
        print('⚠️ [Google] 사용자가 로그인을 취소했습니다 (PlatformException)');
        print('🔙 [Google] Returning cancel result...');
        return SocialLoginResult(
          success: false,
          errorMessage: '로그인이 취소되었습니다',
          provider: SocialLoginProvider.google,
        );
      }
      
      print('🔙 [Google] Returning error result...');
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
      // 기존 토큰 확인 및 재사용
      bool hasToken = false;
      try {
        hasToken = await kakao.AuthApi.instance.hasToken();
        
        if (hasToken) {
          try {
            await kakao.UserApi.instance.accessTokenInfo();
            final user = await kakao.UserApi.instance.me();
            return await _kakaoFirebaseAuth(user);
          } catch (e) {
            // 토큰 무효 시 새로운 로그인 진행
            hasToken = false;
          }
        }
      } catch (e) {
        hasToken = false;
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
      
      // 카카오톡 앱 또는 웹뷰로 로그인
      kakao.OAuthToken token;
      if (isKakaoTalkInstalled) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } on PlatformException catch (e) {
          if (e.code == 'CANCELED') {
            rethrow;
          }
          // 카카오톡 로그인 실패 시 웹뷰로 폴백
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        } catch (e) {
          // 기타 오류 시 웹뷰로 폴백
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 사용자 정보 조회 및 Firebase 인증
      final user = await kakao.UserApi.instance.me();
      return await _kakaoFirebaseAuth(user);

    } on PlatformException catch (e) {
      // 사용자 로그인 취소
      if (e.code == 'CANCELED') {
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인이 취소되었습니다',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      // 카카오톡 미설치 또는 버전 낮음
      if (e.code == 'NOT_SUPPORTED') {
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오톡 앱이 설치되지 않았거나\n버전이 낮습니다.\n\n웹 로그인으로 다시 시도해주세요.',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      // 알 수 없는 오류
      if (e.code == 'UNKNOWN') {
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인 중 알 수 없는 오류가 발생했습니다.\n\n다시 시도해주세요.',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      // 기타 플랫폼 예외
      return SocialLoginResult(
        success: false,
        errorMessage: '카카오 로그인 오류\n\n에러 코드: ${e.code}\n${e.message ?? ""}',
        provider: SocialLoginProvider.kakao,
      );
      
    } catch (e) {
      // 취소 관련 예외 처리
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancel') || errorString.contains('취소')) {
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인이 취소되었습니다',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      // 일반 예외
      return SocialLoginResult(
        success: false,
        errorMessage: '카카오 로그인 오류\n\n$e',
        provider: SocialLoginProvider.kakao,
      );
    }
  }

  /// ===== 3. 애플 로그인 =====
  /// 
  /// 플랫폼별 로그인 방식:
  /// - iOS: Native Apple Sign In → Firebase Custom Token
  /// - Android: WebView OAuth → Firebase Custom Token (sessionStorage 문제 우회)
  /// - Web: WebView OAuth → Firebase Custom Token
  Future<SocialLoginResult> signInWithApple() async {
    try {
      // Apple 인증 정보 가져오기
      final credential = (!kIsWeb && Platform.isIOS)
          ? await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
            )
          : await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
              webAuthenticationOptions: WebAuthenticationOptions(
                clientId: 'com.olssoo.makecall.signin',
                redirectUri: Uri.parse('https://makecallio.firebaseapp.com/__/auth/handler'),
              ),
            );

      // identityToken 추출 및 타입 안전 처리
      String? identityToken;
      try {
        final dynamic rawToken = credential.identityToken;
        if (rawToken != null) {
          identityToken = rawToken.toString();
        }
      } catch (e) {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인 인증 정보 처리 오류',
          provider: SocialLoginProvider.apple,
        );
      }
      
      if (identityToken == null) {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인 인증 정보를 받지 못했습니다',
          provider: SocialLoginProvider.apple,
        );
      }

      // identityToken에서 Apple User ID 추출 (JWT의 sub claim)
      final appleUid = _extractAppleUidFromToken(identityToken);
      if (appleUid == null) {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 사용자 ID를 추출할 수 없습니다',
          provider: SocialLoginProvider.apple,
        );
      }

      // 사용자 정보 준비
      String? displayName;
      if (credential.givenName != null || credential.familyName != null) {
        displayName = '${credential.familyName ?? ''}${credential.givenName ?? ''}'.trim();
      }

      // Firebase Custom Token 생성 요청
      return await _appleFirebaseAuth(
        appleUid: appleUid,
        email: credential.email,
        displayName: displayName,
        identityToken: identityToken,
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
    } on FirebaseFunctionsException catch (e) {
      String errorMessage = 'Apple 로그인 처리 중 오류가 발생했습니다';
      if (e.code == 'unavailable') {
        errorMessage = 'Firebase Functions 서버에 연결할 수 없습니다';
      }
      return SocialLoginResult(
        success: false,
        errorMessage: errorMessage,
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

  /// ===== Kakao Firebase 인증 헬퍼 메서드 =====
  /// Kakao 사용자 정보를 받아 Firebase Custom Token을 생성하고 로그인 처리
  Future<SocialLoginResult> _kakaoFirebaseAuth(kakao.User user) async {
    try {
      // Firebase Functions를 통한 Custom Token 생성
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      final callable = functions.httpsCallable('createCustomTokenForKakao');

      final requestData = {
        'kakaoUid': user.id.toString(),
        'email': user.kakaoAccount?.email,
        'displayName': user.kakaoAccount?.profile?.nickname,
        'photoUrl': user.kakaoAccount?.profile?.profileImageUrl,
      };

      final response = await callable.call(requestData);
      final customToken = response.data['customToken'] as String;

      // Custom Token으로 Firebase 로그인
      final userCredential = await _auth.signInWithCustomToken(customToken);

      return SocialLoginResult(
        success: true,
        userId: userCredential.user?.uid,
        email: user.kakaoAccount?.email,
        displayName: user.kakaoAccount?.profile?.nickname,
        photoUrl: user.kakaoAccount?.profile?.profileImageUrl,
        provider: SocialLoginProvider.kakao,
      );

    } on FirebaseFunctionsException catch (e) {
      // PERMISSION_DENIED 에러
      if (e.code == 'permission-denied') {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Firebase Functions 권한 오류\n\n'
              'createCustomTokenForKakao 함수가\n'
              '배포되지 않았거나 권한이 없습니다.\n\n'
              '관리자에게 문의해주세요.',
          provider: SocialLoginProvider.kakao,
        );
      }

      return SocialLoginResult(
        success: false,
        errorMessage: 'Firebase 인증 오류\n\n${e.message ?? e.code}',
        provider: SocialLoginProvider.kakao,
      );

    } catch (e) {
      return SocialLoginResult(
        success: false,
        errorMessage: 'Firebase 인증 오류\n\n$e',
        provider: SocialLoginProvider.kakao,
      );
    }
  }

  /// ===== Apple Firebase 인증 헬퍼 메서드 =====
  /// Apple 사용자 정보를 받아 Firebase Custom Token을 생성하고 로그인 처리
  /// 
  /// Android WebView OAuth 리다이렉트 문제를 우회하기 위해
  /// Firebase Functions를 통해 Custom Token을 생성합니다.
  Future<SocialLoginResult> _appleFirebaseAuth({
    required String appleUid,
    String? email,
    String? displayName,
    required String identityToken,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      final callable = functions.httpsCallable('createCustomTokenForApple');

      final requestData = {
        'appleUid': appleUid,
        'email': email,
        'displayName': displayName,
        'identityToken': identityToken,
      };

      final response = await callable.call(requestData);
      final customToken = response.data['customToken'] as String;

      // Custom Token으로 Firebase 로그인
      final userCredential = await _auth.signInWithCustomToken(customToken);

      return SocialLoginResult(
        success: true,
        userId: userCredential.user?.uid,
        email: email,
        displayName: displayName,
        photoUrl: null,
        provider: SocialLoginProvider.apple,
      );

    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        return SocialLoginResult(
          success: false,
          errorMessage: 'Firebase Functions 권한 오류\n\n'
              'createCustomTokenForApple 함수가\n'
              '배포되지 않았거나 권한이 없습니다.\n\n'
              '관리자에게 문의해주세요.',
          provider: SocialLoginProvider.apple,
        );
      }

      return SocialLoginResult(
        success: false,
        errorMessage: 'Firebase 인증 오류\n\n${e.message ?? e.code}',
        provider: SocialLoginProvider.apple,
      );

    } catch (e) {
      return SocialLoginResult(
        success: false,
        errorMessage: 'Firebase 인증 오류\n\n$e',
        provider: SocialLoginProvider.apple,
      );
    }
  }

  /// ===== JWT에서 Apple User ID 추출 =====
  /// Apple Identity Token (JWT)의 payload에서 sub claim을 추출합니다.
  /// 
  /// JWT 구조: header.payload.signature
  /// payload는 Base64 URL-safe 인코딩된 JSON입니다.
  String? _extractAppleUidFromToken(String identityToken) {
    try {
      // JWT를 '.'으로 분할 (header.payload.signature)
      final parts = identityToken.split('.');
      if (parts.length != 3) {
        return null;
      }

      // Payload 파트 추출 (인덱스 1)
      String payload = parts[1];
      
      // Base64 URL-safe 디코딩을 위한 패딩 추가
      // JWT는 패딩을 생략하므로 수동으로 추가해야 함
      switch (payload.length % 4) {
        case 0:
          break; // 패딩 불필요
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          return null; // 잘못된 길이
      }

      // Base64 URL-safe 디코딩
      // '-' → '+', '_' → '/' 변환
      final normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64.decode(normalized));
      
      // JSON 파싱
      final Map<String, dynamic> json = jsonDecode(decoded);
      
      // 'sub' claim 추출 (Apple User ID)
      return json['sub'] as String?;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Apple] JWT 파싱 오류: $e');
      }
      return null;
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
