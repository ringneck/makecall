import 'dart:io' show Platform;
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
        
        // 🔑 Android KeyHash 자동 출력 (카카오 개발자 콘솔 등록용)
        if (!kIsWeb && Platform.isAndroid) {
          try {
            final keyHash = await kakao.KakaoSdk.origin;
            debugPrint('');
            debugPrint('🔑 ========== [Kakao] Android KeyHash ==========');
            debugPrint('   KeyHash: $keyHash');
            debugPrint('   💡 이 KeyHash를 카카오 개발자 콘솔에 등록해주세요!');
            debugPrint('   👉 https://developers.kakao.com/console/app');
            debugPrint('   위치: 내 애플리케이션 > 앱 설정 > 플랫폼 > Android');
            debugPrint('================================================');
            debugPrint('');
          } catch (e) {
            debugPrint('⚠️  [Kakao] KeyHash 추출 실패: $e');
          }
        }
      }

      // 🔍 기존 토큰 확인
      bool hasToken = false;
      try {
        hasToken = await kakao.AuthApi.instance.hasToken();
        if (kDebugMode) {
          debugPrint('');
          debugPrint('🔍 ========== [Kakao] 토큰 확인 시작 ==========');
          debugPrint('   기존 토큰 존재 여부: $hasToken');
          if (!hasToken) {
            debugPrint('   ⚠️  앱 내부에 저장된 카카오 토큰이 없습니다');
            debugPrint('   💡 카카오톡 앱 로그인을 시도하면 자동으로 토큰을 받아옵니다');
          }
          debugPrint('================================================');
          debugPrint('');
        }
        
        if (hasToken) {
          // 토큰 유효성 검사
          try {
            final tokenInfo = await kakao.UserApi.instance.accessTokenInfo();
            if (kDebugMode) {
              debugPrint('✅ [Kakao] 기존 토큰 유효 (만료: ${tokenInfo.expiresIn}초 후)');
              debugPrint('🔄 [Kakao] 기존 토큰으로 사용자 정보 조회 중...');
            }
            
            // 기존 토큰으로 바로 사용자 정보 조회
            final user = await kakao.UserApi.instance.me();
            
            if (kDebugMode) {
              debugPrint('✅ [Kakao] 기존 토큰으로 사용자 정보 조회 성공');
              debugPrint('   - User ID: ${user.id}');
              debugPrint('   - Email: ${user.kakaoAccount?.email}');
              debugPrint('   - Nickname: ${user.kakaoAccount?.profile?.nickname}');
            }
            
            // Firebase 인증으로 바로 진행
            return await _kakaoFirebaseAuth(user);
            
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️  [Kakao] 기존 토큰 무효 또는 만료: $e');
              debugPrint('🔄 [Kakao] 새로운 로그인 진행...');
            }
            hasToken = false;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  [Kakao] 토큰 확인 실패: $e');
        }
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
      
      kakao.OAuthToken token;
      
      if (kDebugMode) {
        debugPrint('🔄 [Kakao] 카카오톡 설치 여부: $isKakaoTalkInstalled');
      }
      
      // 카카오톡 앱 로그인 시도
      if (isKakaoTalkInstalled) {
        try {
          if (kDebugMode) {
            debugPrint('🔄 [Kakao] 카카오톡 앱 로그인 시도...');
            debugPrint('   💡 카카오톡 앱이 이미 로그인되어 있다면 자동으로 토큰을 받아옵니다');
          }
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
          if (kDebugMode) {
            debugPrint('✅ [Kakao] 카카오톡 앱 로그인 성공');
            debugPrint('   - Access Token: ${token.accessToken.substring(0, 20)}...');
            debugPrint('   - Refresh Token: ${token.refreshToken?.substring(0, 20) ?? "null"}...');
          }
        } on PlatformException catch (e) {
          if (kDebugMode) {
            debugPrint('');
            debugPrint('⚠️  ========== [Kakao] 카카오톡 앱 로그인 실패 ==========');
            debugPrint('   에러 코드: ${e.code}');
            debugPrint('   에러 메시지: ${e.message}');
            debugPrint('   에러 상세: ${e.details}');
            debugPrint('================================================');
            debugPrint('');
          }
          
          // CANCELED인 경우 예외 재발생 (최상위 catch에서 처리)
          if (e.code == 'CANCELED') {
            if (kDebugMode) {
              debugPrint('ℹ️  [Kakao] 사용자가 카카오톡 앱 로그인을 취소 → 예외 재발생');
            }
            rethrow;
          }
          
          // 기타 오류는 웹뷰로 전환
          if (kDebugMode) {
            debugPrint('🔄 [Kakao] 웹뷰 로그인으로 전환 시도...');
          }
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
          if (kDebugMode) {
            debugPrint('✅ [Kakao] 웹뷰 로그인 성공');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️  [Kakao] 카카오톡 앱 로그인 실패 (일반 예외), 웹뷰로 전환: $e');
            
            // 🔑 KeyHash 검증 실패 감지
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('keyhash') || errorStr.contains('key hash')) {
              debugPrint('');
              debugPrint('🚨 ========== [Kakao] KeyHash 검증 실패 ==========');
              debugPrint('   Android KeyHash가 카카오 개발자 콘솔에 등록되지 않았습니다!');
              debugPrint('   위의 🔑 KeyHash 로그를 확인하고 등록해주세요.');
              debugPrint('   등록 위치: https://developers.kakao.com/console/app');
              debugPrint('   내 애플리케이션 > 앱 설정 > 플랫폼 > Android');
              debugPrint('   💡 Debug와 Release KeyHash가 다를 수 있으니 둘 다 등록하세요!');
              debugPrint('================================================');
              debugPrint('');
            }
          }
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
          if (kDebugMode) {
            debugPrint('✅ [Kakao] 웹뷰 로그인 성공');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔄 [Kakao] 카카오톡 미설치 → 웹뷰 로그인 시도...');
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

      // Firebase 인증 진행
      return await _kakaoFirebaseAuth(user);

    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('❌ ========== [Kakao] PlatformException 발생 ==========');
        debugPrint('   에러 코드: ${e.code}');
        debugPrint('   에러 메시지: ${e.message}');
        debugPrint('   에러 상세: ${e.details}');
        debugPrint('   전체 에러: $e');
        debugPrint('================================================');
        debugPrint('');
      }
      
      // CANCELED - 사용자가 로그인 취소
      if (e.code == 'CANCELED') {
        if (kDebugMode) {
          debugPrint('ℹ️  [Kakao] 사용자가 로그인을 취소했습니다');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인이 취소되었습니다',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      // NOT_SUPPORTED - 카카오톡이 설치되지 않았거나 버전이 낮음
      if (e.code == 'NOT_SUPPORTED') {
        if (kDebugMode) {
          debugPrint('⚠️  [Kakao] 카카오톡 미설치 또는 버전 낮음 → 웹뷰로 재시도 필요');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오톡 앱이 설치되지 않았거나\n버전이 낮습니다.\n\n웹 로그인으로 다시 시도해주세요.',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      // UNKNOWN - 알 수 없는 오류
      if (e.code == 'UNKNOWN') {
        if (kDebugMode) {
          debugPrint('❌ [Kakao] 알 수 없는 오류 발생');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인 중 알 수 없는 오류가 발생했습니다.\n\n다시 시도해주세요.',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      // 기타 PlatformException
      if (kDebugMode) {
        debugPrint('⚠️  [Kakao] 기타 PlatformException: ${e.code}');
      }
      return SocialLoginResult(
        success: false,
        errorMessage: '카카오 로그인 오류\n\n에러 코드: ${e.code}\n${e.message ?? ""}',
        provider: SocialLoginProvider.kakao,
      );
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('❌ ========== [Kakao] 일반 예외 발생 ==========');
        debugPrint('   에러 타입: ${e.runtimeType}');
        debugPrint('   에러 내용: $e');
        debugPrint('================================================');
        debugPrint('');
      }
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancel') || errorString.contains('취소')) {
        if (kDebugMode) {
          debugPrint('ℹ️  [Kakao] 취소 키워드 감지');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '카카오 로그인이 취소되었습니다',
          provider: SocialLoginProvider.kakao,
        );
      }
      
      return SocialLoginResult(
        success: false,
        errorMessage: '카카오 로그인 오류\n\n$e',
        provider: SocialLoginProvider.kakao,
      );
    }
  }

  /// ===== 3. 애플 로그인 =====
  Future<SocialLoginResult> signInWithApple() async {
    try {
      if (kDebugMode) {
        debugPrint('🍎 [Apple] 로그인 시작');
        if (kIsWeb) {
          debugPrint('   플랫폼: Web (webAuthenticationOptions 사용)');
        } else if (Platform.isIOS) {
          debugPrint('   플랫폼: iOS (Native Sign In)');
        } else if (Platform.isAndroid) {
          debugPrint('   플랫폼: Android (webAuthenticationOptions 사용)');
        }
      }
      
      // 플랫폼별 설정 분리
      // iOS: Native Apple Sign In (webAuthenticationOptions 불필요)
      // Android & Web: Web-based authentication (webAuthenticationOptions 필수)
      final credential = (!kIsWeb && Platform.isIOS)
          ? await SignInWithApple.getAppleIDCredential(
              scopes: [
                AppleIDAuthorizationScopes.email,
                AppleIDAuthorizationScopes.fullName,
              ],
              // iOS: Native Sign In - no webAuthenticationOptions needed
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
              // Android & Web: Web-based authentication via WebView/Browser
            );

      if (kDebugMode) {
        debugPrint('✅ [Apple] Apple 인증 정보 수신 완료');
        debugPrint('   - Credential Type: ${credential.runtimeType}');
        
        // 안전한 타입 체크
        try {
          debugPrint('   - identityToken: ${credential.identityToken != null ? "있음 (${credential.identityToken!.length}자)" : "null"}');
        } catch (e) {
          debugPrint('   - identityToken: 타입 변환 에러 - $e');
        }
        
        try {
          debugPrint('   - authorizationCode: ${credential.authorizationCode != null ? "있음 (${credential.authorizationCode!.length}자)" : "null"}');
        } catch (e) {
          debugPrint('   - authorizationCode: 타입 변환 에러 - $e');
        }
        
        debugPrint('   - email: ${credential.email ?? "null"}');
        debugPrint('   - givenName: ${credential.givenName ?? "null"}');
        debugPrint('   - familyName: ${credential.familyName ?? "null"}');
      }

      // CRITICAL: identityToken과 authorizationCode null 체크 + 타입 안전 처리
      // 웹 플랫폼에서 JavaScript 객체 타입을 Dart String으로 안전하게 변환
      String? identityToken;
      String? authorizationCode;
      
      try {
        // 웹 플랫폼 특별 처리: dynamic 타입으로 먼저 받은 후 String 변환
        final dynamic rawIdentityToken = credential.identityToken;
        final dynamic rawAuthorizationCode = credential.authorizationCode;
        
        if (rawIdentityToken != null) {
          identityToken = rawIdentityToken.toString();
        }
        
        if (rawAuthorizationCode != null) {
          authorizationCode = rawAuthorizationCode.toString();
        }
        
        if (kDebugMode) {
          debugPrint('🔍 [Apple] 타입 변환 성공');
          debugPrint('   - identityToken type: ${rawIdentityToken.runtimeType}');
          debugPrint('   - authorizationCode type: ${rawAuthorizationCode.runtimeType}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [Apple] 인증 정보 타입 변환 실패: $e');
          debugPrint('   - Error Type: ${e.runtimeType}');
          debugPrint('   - Stack Trace: ${StackTrace.current}');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: 'Apple 로그인 인증 정보 처리 오류\n\n'
              '웹 플랫폼에서 타입 변환에 실패했습니다.\n'
              '다시 시도해주세요.\n\n'
              '오류: ${e.toString()}',
          provider: SocialLoginProvider.apple,
        );
      }
      
      if (identityToken == null) {
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

      if (authorizationCode == null) {
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
        debugPrint('   - identityToken 길이: ${identityToken.length}');
        debugPrint('   - authorizationCode 길이: ${authorizationCode.length}');
      }

      final oAuthProvider = OAuthProvider('apple.com');
      final firebaseCredential = oAuthProvider.credential(
        idToken: identityToken,
        accessToken: authorizationCode,
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

  /// ===== Kakao Firebase 인증 헬퍼 메서드 =====
  /// Kakao 사용자 정보를 받아 Firebase Custom Token을 생성하고 로그인 처리
  Future<SocialLoginResult> _kakaoFirebaseAuth(kakao.User user) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [Kakao] Firebase 인증 시작');
        debugPrint('   - Kakao User ID: ${user.id}');
      }

      // Firebase Functions를 통한 Custom Token 생성
      final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
      final callable = functions.httpsCallable('createCustomTokenForKakao');

      final requestData = {
        'kakaoUid': user.id.toString(),
        'email': user.kakaoAccount?.email,
        'displayName': user.kakaoAccount?.profile?.nickname,
        'photoUrl': user.kakaoAccount?.profile?.profileImageUrl,
      };

      if (kDebugMode) {
        debugPrint('🔄 [Kakao] Firebase Functions 호출 중...');
        debugPrint('   - Function: createCustomTokenForKakao');
        debugPrint('   - Region: asia-northeast3');
      }

      final response = await callable.call(requestData);
      final customToken = response.data['customToken'] as String;

      if (kDebugMode) {
        debugPrint('✅ [Kakao] Custom Token 수신 완료');
        debugPrint('🔄 [Kakao] Firebase 로그인 중...');
      }

      // Custom Token으로 Firebase 로그인
      final userCredential = await _auth.signInWithCustomToken(customToken);

      if (kDebugMode) {
        debugPrint('✅ [Kakao] Firebase 로그인 성공');
        debugPrint('   - Firebase UID: ${userCredential.user?.uid}');
      }

      return SocialLoginResult(
        success: true,
        userId: userCredential.user?.uid,
        email: user.kakaoAccount?.email,
        displayName: user.kakaoAccount?.profile?.nickname,
        photoUrl: user.kakaoAccount?.profile?.profileImageUrl,
        provider: SocialLoginProvider.kakao,
      );

    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Kakao] Firebase Functions 에러');
        debugPrint('   에러 코드: ${e.code}');
        debugPrint('   에러 메시지: ${e.message}');
        debugPrint('   에러 상세: ${e.details}');
      }

      final errorString = e.toString().toLowerCase();

      // PERMISSION_DENIED 에러 감지
      if (errorString.contains('permission-denied') || e.code == 'permission-denied') {
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
      if (kDebugMode) {
        debugPrint('❌ [Kakao] Firebase 인증 중 예외 발생: $e');
      }

      return SocialLoginResult(
        success: false,
        errorMessage: 'Firebase 인증 오류\n\n$e',
        provider: SocialLoginProvider.kakao,
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
