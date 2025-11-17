import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:flutter_naver_login/interface/types/naver_login_result.dart';
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
      bool isKakaoTalkInstalled = false;
      
      try {
        isKakaoTalkInstalled = await kakao.isKakaoTalkInstalled();
      } catch (checkError) {
        if (kDebugMode) {
          debugPrint('⚠️ [Kakao] 카카오톡 설치 확인 실패: $checkError');
        }
        // MissingPluginException인 경우 명확한 에러 메시지
        if (checkError.toString().contains('MissingPluginException')) {
          return SocialLoginResult(
            success: false,
            errorMessage: '카카오 로그인 플러그인이 초기화되지 않았습니다.\n\n'
                '앱을 완전히 종료한 후 다시 시작해주세요.\n'
                '(Hot Reload가 아닌 앱 재시작 필요)',
            provider: SocialLoginProvider.kakao,
          );
        }
      }
      
      kakao.OAuthToken token;
      
      // 🔧 임시 수정: 카카오톡 앱 로그인 시도 중 에러 발생 시 웹뷰로 fallback
      if (isKakaoTalkInstalled) {
        try {
          // 카카오톡으로 로그인 시도
          if (kDebugMode) {
            debugPrint('📱 [Kakao] 카카오톡 앱으로 로그인 시도');
          }
          token = await kakao.UserApi.instance.loginWithKakaoTalk();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [Kakao] 카카오톡 앱 로그인 실패, 웹뷰로 전환');
            debugPrint('   - 에러: $e');
          }
          // 웹뷰로 fallback
          token = await kakao.UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 카카오 계정으로 로그인 (웹뷰)
        if (kDebugMode) {
          debugPrint('🌐 [Kakao] 카카오톡 미설치, 카카오 계정으로 로그인');
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

      // Firebase Custom Token 생성 및 로그인
      try {
        if (kDebugMode) {
          debugPrint('🔐 [Kakao] Firebase Custom Token 생성 요청');
        }
        
        final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
        final callable = functions.httpsCallable('createCustomTokenForKakao');
        
        final response = await callable.call<Map<String, dynamic>>({
          'kakaoUid': user.id.toString(),
          'email': user.kakaoAccount?.email,
          'displayName': user.kakaoAccount?.profile?.nickname,
          'photoUrl': user.kakaoAccount?.profile?.profileImageUrl,
        });
        
        final customToken = response.data['customToken'] as String;
        
        if (kDebugMode) {
          debugPrint('✅ [Kakao] Custom Token 생성 완료');
        }
        
        // Firebase Authentication 로그인
        final userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);
        
        if (kDebugMode) {
          debugPrint('✅ [Kakao] Firebase Authentication 로그인 완료');
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
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [Kakao] Firebase Custom Token 생성 실패: $e');
        }
        
        // 에러 메시지 분석
        final errorString = e.toString().toLowerCase();
        
        // IAM 권한 에러 감지
        if (errorString.contains('permission') || 
            errorString.contains('iam.serviceaccounts.signblob')) {
          return SocialLoginResult(
            success: false,
            errorMessage: 'Firebase 설정이 완료되지 않았습니다.\n\n'
                '관리자가 IAM 권한을 설정 중입니다.\n'
                '잠시 후 다시 시도해주세요.',
            provider: SocialLoginProvider.kakao,
          );
        }
        
        // 일반 INTERNAL 에러
        if (errorString.contains('internal')) {
          return SocialLoginResult(
            success: false,
            errorMessage: 'Firebase 서버 설정 오류\n\n'
                '가능한 원인:\n'
                '1. Firebase Functions가 배포되지 않음\n'
                '2. IAM 권한이 설정되지 않음\n'
                '3. Functions Region 불일치\n\n'
                'Firebase Console에서 확인 필요:\n'
                '- Functions > createCustomTokenForKakao 배포 확인\n'
                '- Functions 로그에서 에러 메시지 확인\n'
                '- IAM 권한 (Service Account Token Creator) 설정 확인',
            provider: SocialLoginProvider.kakao,
          );
        }
        
        return SocialLoginResult(
          success: false,
          errorMessage: 'Firebase 인증 실패: ${e.toString()}',
          provider: SocialLoginProvider.kakao,
        );
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Kakao] 로그인 오류: $e');
        debugPrint('❌ [Kakao] 오류 타입: ${e.runtimeType}');
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
        errorMessage: e.toString(),
        provider: SocialLoginProvider.kakao,
      );
    }
  }

  /// ===== 3. 네이버 로그인 =====
  Future<SocialLoginResult> signInWithNaver() async {
    try {
      if (kDebugMode) {
        debugPrint('🟢 [Naver] 로그인 시작 (iOS/Android 지원)');
      }

      if (kDebugMode) {
        debugPrint('🔧 [Naver] 네이버 로그인 시작');
      }

      // 네이버 로그인 (계정 정보가 result.account에 포함됨)
      NaverLoginResult result;
      
      try {
        result = await FlutterNaverLogin.logIn();
      } catch (loginError) {
        if (kDebugMode) {
          debugPrint('❌ [Naver] 로그인 호출 실패: $loginError');
        }
        
        // MissingPluginException 감지
        if (loginError.toString().contains('MissingPluginException')) {
          return SocialLoginResult(
            success: false,
            errorMessage: '네이버 로그인 플러그인 오류\n\n'
                '해결 방법:\n'
                '1. 앱을 완전히 종료하세요 (백그라운드에서도 제거)\n'
                '2. 기기를 재부팅하세요\n'
                '3. 앱을 다시 시작하세요\n\n'
                '문제가 계속되면 앱을 재설치해주세요.',
            provider: SocialLoginProvider.naver,
          );
        }
        
        // 기타 에러
        return SocialLoginResult(
          success: false,
          errorMessage: '네이버 로그인 오류: ${loginError.toString()}',
          provider: SocialLoginProvider.naver,
        );
      }

      if (result.status == NaverLoginStatus.loggedIn && result.account != null) {
        final account = result.account!;
        
        if (kDebugMode) {
          debugPrint('✅ [Naver] 로그인 성공');
          debugPrint('   - ID: ${account.id}');
          debugPrint('   - Email: ${account.email}');
          debugPrint('   - Name: ${account.name}');
        }

        // Firebase Custom Token 생성 및 로그인
        try {
          if (kDebugMode) {
            debugPrint('🔐 [Naver] Firebase Custom Token 생성 요청');
          }
          
          final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
          final callable = functions.httpsCallable('createCustomTokenForNaver');
          
          final response = await callable.call<Map<String, dynamic>>({
            'naverId': account.id,
            'email': account.email,
            'nickname': account.name,
            'profileImage': account.profileImage,
          });
          
          final customToken = response.data['customToken'] as String;
          
          if (kDebugMode) {
            debugPrint('✅ [Naver] Custom Token 생성 완료');
          }
          
          // Firebase Authentication 로그인
          final userCredential = await FirebaseAuth.instance.signInWithCustomToken(customToken);
          
          if (kDebugMode) {
            debugPrint('✅ [Naver] Firebase Authentication 로그인 완료');
            debugPrint('   - Firebase UID: ${userCredential.user?.uid}');
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
            debugPrint('❌ [Naver] Firebase Custom Token 생성 실패: $e');
          }
          
          // 에러 메시지 분석
          final errorString = e.toString().toLowerCase();
          
          // IAM 권한 에러 감지
          if (errorString.contains('permission') || 
              errorString.contains('iam.serviceaccounts.signblob')) {
            return SocialLoginResult(
              success: false,
              errorMessage: 'Firebase 설정이 완료되지 않았습니다.\n\n'
                  '관리자가 IAM 권한을 설정 중입니다.\n'
                  '잠시 후 다시 시도해주세요.',
              provider: SocialLoginProvider.naver,
            );
          }
          
          // 일반 INTERNAL 에러
          if (errorString.contains('internal')) {
            return SocialLoginResult(
              success: false,
              errorMessage: 'Firebase 서버 설정 오류\n\n'
                  '가능한 원인:\n'
                  '1. Firebase Functions가 배포되지 않음\n'
                  '2. IAM 권한이 설정되지 않음\n'
                  '3. Functions Region 불일치\n\n'
                  'Firebase Console에서 확인 필요:\n'
                  '- Functions > createCustomTokenForNaver 배포 확인\n'
                  '- Functions 로그에서 에러 메시지 확인\n'
                  '- IAM 권한 (Service Account Token Creator) 설정 확인',
              provider: SocialLoginProvider.naver,
            );
          }
          
          return SocialLoginResult(
            success: false,
            errorMessage: 'Firebase 인증 실패: ${e.toString()}',
            provider: SocialLoginProvider.naver,
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [Naver] 로그인 취소 또는 실패: ${result.status}');
        }
        return SocialLoginResult(
          success: false,
          errorMessage: '로그인이 취소되었거나 실패했습니다',
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

    } on SignInWithAppleAuthorizationException catch (e) {
      // Apple Sign-In 특정 에러 처리
      if (kDebugMode) {
        debugPrint('❌ [Apple] 인증 예외: ${e.code} - ${e.message}');
      }
      
      // Error code 1001은 사용자 취소
      if (e.code == AuthorizationErrorCode.canceled) {
        return SocialLoginResult(
          success: false,
          errorMessage: '사용자가 Apple 로그인을 취소했습니다',
          provider: SocialLoginProvider.apple,
        );
      }
      
      // 기타 Apple Sign-In 에러
      String errorMessage = 'Apple 로그인 중 오류가 발생했습니다';
      if (e.message != null && e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }
      
      return SocialLoginResult(
        success: false,
        errorMessage: errorMessage,
        provider: SocialLoginProvider.apple,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Apple] 로그인 오류: $e');
      }
      
      // 일반 에러 메시지에서 취소 키워드 확인
      String errorString = e.toString();
      if (errorString.contains('canceled') || 
          errorString.contains('1001') ||
          errorString.contains('취소')) {
        return SocialLoginResult(
          success: false,
          errorMessage: '사용자가 Apple 로그인을 취소했습니다',
          provider: SocialLoginProvider.apple,
        );
      }
      
      return SocialLoginResult(
        success: false,
        errorMessage: 'Apple 로그인 중 오류가 발생했습니다',
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
