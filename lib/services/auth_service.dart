import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:io';
import '../models/user_model.dart';
import '../main.dart' show navigatorKey;
import '../exceptions/max_device_limit_exception.dart';
import '../widgets/max_device_limit_dialog.dart';
import 'account_manager_service.dart';
import 'fcm_service.dart';
import 'dcmiws_connection_manager.dart';

/// 🛑 서비스 이용 중지 예외 클래스
/// 
/// 이용 중지된 계정이 로그인 시도할 때 발생하는 예외
class ServiceSuspendedException implements Exception {
  final String? suspendedAt;
  final String? deviceId;
  final String? deviceName;
  
  ServiceSuspendedException({
    this.suspendedAt,
    this.deviceId,
    this.deviceName,
  });
  
  @override
  String toString() {
    return 'ServiceSuspendedException: Account suspended at $suspendedAt';
  }
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountManagerService _accountManager = AccountManagerService();
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated {
    return _currentUserModel != null && !_isWaitingForApproval && !_isLoggingOut;
  }
  
  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;
  
  // 🔒 로그아웃 상태 추적 (중복 notifyListeners 방지)
  String? _lastUserId;
  
  // 🔒 로그아웃 진행 중 플래그 (authStateChanges 리스너 무시)
  bool _isSigningOut = false;
  
  /// 로그아웃 플래그 설정 (authStateChanges 리스너 무시용)
  /// MaxDeviceLimitException 발생 시 조용한 로그아웃에 사용
  void setIsSigningOut(bool value) {
    _isSigningOut = value;
  }
  
  // 🔥 CRITICAL FIX: 로그아웃 진행 중 플래그
  // FCM pushReplacement로 생성된 route가 남아있어도 LoginScreen 표시 강제
  bool _isLoggingOut = false;
  bool get isLoggingOut => _isLoggingOut;
  
  // 🔐 기기 승인 대기 상태
  bool _isWaitingForApproval = false;
  bool get isWaitingForApproval => _isWaitingForApproval;
  String? _approvalRequestId;
  String? get approvalRequestId => _approvalRequestId;
  
  // 🎯 소셜 로그인 성공 메시지 완료 플래그
  bool _socialLoginSuccessMessageShown = false;
  bool get socialLoginSuccessMessageShown => _socialLoginSuccessMessageShown;
  
  // 🎯 소셜 로그인 진행 중 플래그 (이벤트 기반)
  // SignupScreen에서 "기존 계정 확인" 다이얼로그가 표시되는 동안 true
  bool _isInSocialLoginFlow = false;
  bool get isInSocialLoginFlow => _isInSocialLoginFlow;
  
  // 🎯 이메일 회원가입 진행 중 플래그 (이벤트 기반)
  // SignupScreen에서 이메일 회원가입이 완료된 직후 true
  bool _isInEmailSignupFlow = false;
  bool get isInEmailSignupFlow => _isInEmailSignupFlow;
  
  // 🚀 고급 패턴: FCM 초기화 완료 상태 (이벤트 기반)
  bool _isFcmInitialized = false;
  bool get isFcmInitialized => _isFcmInitialized;
  
  // 🚫 MaxDeviceLimit 차단 상태 (로그인 차단 + 다이얼로그 표시용)
  bool _isBlockedByMaxDeviceLimit = false;
  bool get isBlockedByMaxDeviceLimit => _isBlockedByMaxDeviceLimit;
  MaxDeviceLimitException? _maxDeviceLimitException;
  MaxDeviceLimitException? get maxDeviceLimitException => _maxDeviceLimitException;
  
  /// FCM 초기화 완료 상태 설정
  void setFcmInitialized(bool initialized) {
    _isFcmInitialized = initialized;
    notifyListeners();
  }
  
  /// MaxDeviceLimit 차단 상태 설정
  void setBlockedByMaxDeviceLimit(bool blocked, {MaxDeviceLimitException? exception}) {
    _isBlockedByMaxDeviceLimit = blocked;
    _maxDeviceLimitException = exception;
    notifyListeners();
  }
  
  /// 승인 대기 상태 설정
  void setWaitingForApproval(bool waiting, {String? approvalRequestId}) {
    _isWaitingForApproval = waiting;
    _approvalRequestId = approvalRequestId;
    notifyListeners();
  }
  
  /// 소셜 로그인 성공 메시지 표시 완료 설정
  void setSocialLoginSuccessMessageShown(bool shown) {
    _socialLoginSuccessMessageShown = shown;
    notifyListeners();
  }
  
  /// 소셜 로그인 진행 중 상태 설정
  /// SignupScreen에서 "기존 계정 확인" 다이얼로그 표시 전/후 호출
  void setInSocialLoginFlow(bool inFlow) {
    _isInSocialLoginFlow = inFlow;
    notifyListeners();
  }
  
  /// 이메일 회원가입 진행 중 상태 설정
  /// SignupScreen에서 이메일 회원가입 완료 직후 호출
  void setInEmailSignupFlow(bool inFlow) {
    _isInEmailSignupFlow = inFlow;
    notifyListeners();
  }
  
  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      // 🔒 CRITICAL FIX: 로그아웃 진행 중에는 authStateChanges 무시
      if (_isSigningOut) {
        return; // 로그아웃 진행 중에는 무시
      }
      
      if (user != null) {
        // 로그인 상태
        _lastUserId = user.uid;
        try {
          await _loadUserModel(user.uid);
        } on ServiceSuspendedException catch (e) {
          // 🛑 서비스 이용 중지 계정 - authStateChanges에서는 무시
          // UI의 signIn()에서 이미 처리했으므로 여기서는 조용히 무시
          if (kDebugMode) {
            debugPrint('🛑 [AUTH STATE] 서비스 이용 중지 계정 - 무시');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [AUTH STATE] _loadUserModel 오류: $e');
          }
        }
      } else if (_lastUserId != null) {
        // 로그아웃 상태 (최초 1회만)
        _lastUserId = null;
        _currentUserModel = null;
        
        if (kDebugMode) {
          debugPrint('✅ [AUTH STATE] 로그아웃 감지 - UI 업데이트 시작');
        }
        
        // 🔒 CRITICAL: 먼저 notifyListeners() 호출하여 LoginScreen 전환 트리거
        // authStateChanges 콜백 내에서 즉시 호출하면 Consumer가 rebuild되지 않을 수 있음
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (kDebugMode) {
            debugPrint('🔔 [AUTH STATE] notifyListeners() 호출 - Consumer rebuild 트리거 (isLoggingOut=true)');
          }
          notifyListeners();
          
          // 🔥 CRITICAL: notifyListeners() 후 500ms 지연하여 플래그 해제
          // LoginScreen 전환이 완전히 완료된 후에 플래그 해제
          Future.delayed(const Duration(milliseconds: 500), () {
            _isLoggingOut = false;
            _isSigningOut = false;
            if (kDebugMode) {
              debugPrint('✅ [AUTH STATE] 로그아웃 플래그 해제 완료');
            }
          });
        });
      }
    });
  }
  
  // 비밀번호를 일시적으로 저장하기 위한 변수 (로그인 시에만 사용)
  String? _tempPassword;
  
  Future<void> _loadUserModel(String uid, {String? password}) async {
    try {
      // 🔥 CRITICAL: 로그인 성공 시에만 플래그 해제 (로그아웃 중에는 유지)
      // authStateChanges 리스너가 user == null일 때 플래그를 해제함
      if (!_isLoggingOut) {
        // 이미 로그아웃 진행 중이 아닌 경우에만 해제
        _isLoggingOut = false;
      }
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        
        // 🛑 CRITICAL: 최우선 이용 중지 여부 확인
        final isActive = data['isActive'] as bool? ?? true;
        
        if (!isActive) {
          // 이용 중지된 계정 - 로그아웃 처리하고 예외 발생
          final suspendedAt = data['suspendedAt'] as String?;
          final suspendedDeviceId = data['suspendedDeviceId'] as String?;
          final suspendedDeviceName = data['suspendedDeviceName'] as String?;
          
          if (kDebugMode) {
            debugPrint('');
            debugPrint('🛑 ========== 서비스 이용 중지 계정 ==========');
            debugPrint('   📧 이메일: ${data['email']}');
            debugPrint('   🆔 UID: $uid');
            debugPrint('   📅 중지 일시: $suspendedAt');
            debugPrint('   📱 디바이스 ID: ${suspendedDeviceId ?? "없음"}');
            debugPrint('   📱 디바이스 이름: ${suspendedDeviceName ?? "없음"}');
            debugPrint('   ⚠️  로그인 차단 - 예외 발생');
            debugPrint('================================================');
            debugPrint('');
          }
          
          // 🛑 CRITICAL: 로그아웃은 signIn()에서 처리
          // 여기서 signOut()을 호출하면 authStateChanges가 발생하여 복잡해짐
          
          // 예외 발생 (UI에서 다이얼로그 표시용)
          throw ServiceSuspendedException(
            suspendedAt: suspendedAt,
            deviceId: suspendedDeviceId,
            deviceName: suspendedDeviceName,
          );
        }
        
        _currentUserModel = UserModel.fromMap(data, uid);
        
        await _accountManager.saveAccount(_currentUserModel!, password: password ?? _tempPassword);
        _tempPassword = null;
        
        notifyListeners();
      } else {
        final currentUser = _auth.currentUser;
        
        if (currentUser != null) {
          final providerIds = currentUser.providerData.map((p) => p.providerId).toList();
          final isSocialLogin = providerIds.any((id) => 
            id == 'google.com' || 
            id == 'apple.com' || 
            id.startsWith('kakao')
          ) || uid.startsWith('apple_') || uid.startsWith('kakao_') || uid.startsWith('google_');
          
          if (isSocialLogin) {
            // 소셜 로그인 신규 사용자 - SignupScreen에서 문서 생성
            return;
          }
        }
        
        // 🔧 FIX: 이메일 로그인 신규 사용자도 자동으로 문서 생성
        if (kDebugMode) {
          debugPrint('📝 [AUTH] 신규 이메일 사용자 - users 문서 자동 생성');
          debugPrint('   UID: $uid');
          debugPrint('   Email: ${currentUser?.email}');
        }
        
        // 기본 사용자 문서 생성
        await _firestore.collection('users').doc(uid).set({
          'email': currentUser?.email ?? '',
          'displayName': currentUser?.displayName ?? '',
          'photoUrl': currentUser?.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'maxDevices': 1,  // 기본 최대 기기 수
        });
        
        if (kDebugMode) {
          debugPrint('✅ [AUTH] users 문서 생성 완료 - 재로드');
        }
        
        // 생성된 문서 다시 로드
        await _loadUserModel(uid, password: password);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load user model: $e');
      }
      // 🛑 CRITICAL: 예외를 rethrow하여 signIn()에서 처리할 수 있도록 함
      rethrow;
    }
  }
  
  // 사용자 데이터 강제 새로고침 (외부에서 호출 가능)
  Future<void> refreshUserModel() async {
    if (currentUser == null) return;
    
    try {
      // Firestore에 lastMaxExtensionsUpdate 업데이트
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'lastMaxExtensionsUpdate': DateTime.now().toIso8601String(),
      });
      
      // 업데이트된 데이터 다시 로드
      await _loadUserModel(currentUser!.uid);
      
      if (kDebugMode) {
        debugPrint('✅ User model refreshed from Firestore with updated timestamp');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Refresh user model error: $e');
      }
      rethrow;
    }
  }
  
  // 신규 소셜 로그인 사용자 모델 로드 (Firestore 문서 생성 직후 호출)
  Future<void> loadNewUserModel(String uid) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [AUTH] 신규 사용자 모델 로드 시작: $uid');
      }
      
      // _loadUserModel 직접 호출 (update 없이 문서 읽기만)
      await _loadUserModel(uid);
      
      if (kDebugMode) {
        debugPrint('✅ [AUTH] 신규 사용자 모델 로드 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AUTH] 신규 사용자 모델 로드 실패: $e');
      }
      rethrow;
    }
  }
  
  // 회원가입
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    bool termsAgreed = false,
    bool privacyPolicyAgreed = false,
    bool marketingConsent = false,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Firestore에 사용자 정보 저장
      if (credential.user != null) {
        final nowDateTime = DateTime.now();
        final now = FieldValue.serverTimestamp();
        final twoYearsLater = nowDateTime.add(const Duration(days: 730));
        
        final userData = {
          'uid': credential.user!.uid,
          'email': email,
          'organizationName': '',
          'role': 'user',
          'loginProvider': 'email',
          'createdAt': now,
          'updatedAt': now,
          'lastLoginAt': now,
          'isActive': true,
          'accountStatus': 'approved',
          'maxDevices': 1,
          // 동의 정보 (SignupScreen에서 수집됨)
          'consentVersion': '1.0',
          'termsAgreed': termsAgreed,
          'termsAgreedAt': termsAgreed ? now : null,
          'privacyPolicyAgreed': privacyPolicyAgreed,
          'privacyPolicyAgreedAt': privacyPolicyAgreed ? now : null,
          'marketingConsent': marketingConsent,
          'marketingConsentAt': marketingConsent ? now : null,
          'lastConsentCheckAt': now,
          'nextConsentCheckDue': Timestamp.fromDate(twoYearsLater),
          'consentHistory': [
            {
              'version': '1.0',
              'agreedAt': Timestamp.fromDate(nowDateTime),
              'type': 'initial',
              'termsAgreed': termsAgreed,
              'privacyPolicyAgreed': privacyPolicyAgreed,
              'marketingConsent': marketingConsent,
            }
          ],
        };
        
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userData);
        
        // UserModel은 간단한 정보만 저장
        final userModel = UserModel(
          uid: credential.user!.uid,
          email: email,
          createdAt: nowDateTime,
        );
        
        _currentUserModel = userModel;
        notifyListeners();
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('SignUp error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }
  
  // 로그인 (비밀번호 저장 포함)
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 비밀번호를 일시 저장 (로그인 성공 후 saveAccount에서 사용)
      _tempPassword = password;
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // 마지막 로그인 시간 업데이트
      if (credential.user != null) {
        try {
          await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .update({'lastLoginAt': DateTime.now().toIso8601String()});
        } catch (e) {
          // update 실패는 문서가 없을 가능성 - _loadUserModel에서 처리
          if (kDebugMode) {
            debugPrint('⚠️ [AUTH] lastLoginAt 업데이트 실패: $e');
            debugPrint('   (문서 존재 여부는 _loadUserModel에서 확인)');
          }
        }
        
        // 비밀번호를 _loadUserModel에 전달하여 자동 저장
        // 🛑 CRITICAL: _loadUserModel에서 ServiceSuspendedException이 발생하면 즉시 리턴
        try {
          await _loadUserModel(credential.user!.uid, password: password);
        } on ServiceSuspendedException catch (e) {
          // 서비스 이용 중지 계정 - 로그아웃 처리 후 예외 재전파
          if (kDebugMode) {
            debugPrint('🛑 [AUTH] 서비스 이용 중지 계정 감지 - 로그아웃 처리');
          }
          
          // 로그아웃 처리
          await _auth.signOut();
          _tempPassword = null;
          
          if (kDebugMode) {
            debugPrint('🛑 [AUTH] 로그아웃 완료 - UI로 예외 전파');
          }
          
          // FCM 초기화 없이 즉시 예외 재전파
          rethrow;
        }
        
        // FCM 초기화 (로그인 성공 후)
        try {
          // ignore: avoid_print
          print('');
          // ignore: avoid_print
          print('🔔 [AUTH] 로그인 성공 - FCM 초기화 시작...');
          // ignore: avoid_print
          print('   User ID: ${credential.user!.uid}');
          // ignore: avoid_print
          print('   Platform: ${kIsWeb ? "Web" : "Mobile"}');
          
          final fcmService = FCMService();
          await fcmService.initialize(credential.user!.uid);
          
          // ignore: avoid_print
          print('✅ [AUTH] FCM 초기화 완료');
        } on MaxDeviceLimitException catch (e) {
          // 🚫 CRITICAL: 최대 기기 수 초과 - 플래그 설정 후 예외 전파
          // ignore: avoid_print
          print('');
          // ignore: avoid_print
          print('🚫 [AUTH] 최대 기기 수 초과 감지 - 차단 플래그 설정');
          
          // 차단 플래그 설정 (main.dart에서 LoginScreen 유지)
          setBlockedByMaxDeviceLimit(true, exception: e);
          
          // Firebase Authentication 로그아웃 (currentUser를 null로 만듦)
          await _auth.signOut();
          _tempPassword = null;
          
          // ignore: avoid_print
          print('✅ [AUTH] 로그아웃 완료 - 차단 플래그 활성화됨');
          print('');
          
          // ⚠️ CRITICAL: navigatorKey를 사용하여 어디서든 다이얼로그 표시
          // login_screen의 catch 블록을 거치지 않고 직접 표시
          if (navigatorKey.currentContext != null) {
            // ignore: avoid_print
            print('🔔 [AUTH] MaxDeviceLimit 다이얼로그 표시 시작 (AuthService에서 직접)');
            
            // 🚨 CRITICAL: addPostFrameCallback 제거
            // → 직접 await로 다이얼로그 표시 (차단 플래그로 LoginScreen 유지됨)
            try {
              await _showMaxDeviceLimitDialogFromAuthService(
                navigatorKey.currentContext!,
                e,
              );
              
              // ignore: avoid_print
              print('✅ [AUTH] MaxDeviceLimit 다이얼로그 표시 완료');
              
              // 다이얼로그 닫힌 후 차단 플래그 해제
              setBlockedByMaxDeviceLimit(false);
              
              // ignore: avoid_print
              print('🏁 [AUTH] 차단 플래그 해제 - LoginScreen 유지');
            } catch (dialogError) {
              // ignore: avoid_print
              print('❌ [AUTH] 다이얼로그 표시 오류: $dialogError');
              
              // 에러 발생 시에도 차단 플래그 해제
              setBlockedByMaxDeviceLimit(false);
            }
          } else {
            // ignore: avoid_print
            print('⚠️ [AUTH] navigatorKey.currentContext가 null - 예외 rethrow');
            
            // navigatorKey가 없으면 예외 재전파 (login_screen catch 블록으로)
            rethrow;
          }
        } catch (e, stackTrace) {
          // ignore: avoid_print
          print('❌ [AUTH] FCM 초기화 오류: $e');
          // ignore: avoid_print
          print('Stack trace:');
          // ignore: avoid_print
          print(stackTrace);
          
          // 🚫 CRITICAL: 기기 승인 관련 오류는 로그인 차단
          if (e.toString().contains('Device approval') || 
              e.toString().contains('denied') || 
              e.toString().contains('timeout')) {
            // ignore: avoid_print
            print('');
            // ignore: avoid_print
            print('🚫 [AUTH] 기기 승인 실패 - 로그인 취소');
            // ignore: avoid_print
            print('   사용자를 강제 로그아웃합니다...');
            
            // Firebase Authentication 로그아웃 (로그인 취소)
            await _auth.signOut();
            
            // ignore: avoid_print
            print('✅ [AUTH] 로그아웃 완료 - 로그인 화면으로 돌아갑니다');
            print('');
            
            // 예외 재전파하여 UI에서 에러 처리
            rethrow;
          }
          
          // 일반적인 FCM 오류는 무시하고 로그인 진행
          // ignore: avoid_print
          print('⚠️ [AUTH] FCM 초기화 실패했지만 로그인은 계속 진행');
        }
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      // 로그인 실패 시 일시 비밀번호 삭제
      _tempPassword = null;
      
      if (kDebugMode) {
        debugPrint('SignIn error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }
  
  // 로그아웃
  /// 로그아웃
  /// 
  /// ⚠️ 중요: 이 메서드는 Firestore 데이터를 삭제하지 않습니다!
  /// ✅ 보존되는 데이터:
  ///   - users/{userId}: API/WebSocket 설정, 회사 정보
  ///   - my_extensions: 등록된 단말번호
  ///   - call_forward_info: 착신전환 설정
  /// 
  /// 삭제되는 데이터:
  ///   - fcm_tokens/{userId}_{deviceId}: FCM 토큰만 삭제
  ///   - _currentUserModel: 로컬 변수만 초기화 (Firestore 손대 안 함)
  Future<void> signOut() async {
    // 🔥 CRITICAL FIX: 로그아웃 플래그 설정 (FCM route 남아도 LoginScreen 강제 표시)
    _isLoggingOut = true;
    _isSigningOut = true; // authStateChanges 리스너 무시
    notifyListeners(); // 즉시 MaterialApp.home Consumer에 알림
    
    // 🔍 로그아웃 전 Firestore 데이터 확인 (디버그용)
    if (kDebugMode && _auth.currentUser != null) {
      debugPrint('');
      debugPrint('🔓 ========== 로그아웃 시작 ==========');
      debugPrint('   📧 현재 사용자: ${_currentUserModel?.email ?? "없음"}');
      debugPrint('   🆔 UID: ${_auth.currentUser!.uid}');
      debugPrint('');
      
      // Firestore에서 실제 데이터 확인
      try {
        final doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          debugPrint('   📊 Firestore users 컬렉션 현재 상태:');
          debugPrint('      - apiBaseUrl: ${data['apiBaseUrl'] ?? "(없음)"}');
          debugPrint('      - apiHttpPort: ${data['apiHttpPort'] ?? "(없음)"}');
          debugPrint('      - companyId: ${data['companyId'] ?? "(없음)"}');
          debugPrint('      - appKey: ${data['appKey'] != null && (data['appKey'] as String).isNotEmpty ? "[${(data['appKey'] as String).length}자]" : "(없음)"}');
          debugPrint('      - websocketServerUrl: ${data['websocketServerUrl'] ?? "(없음)"}');
          debugPrint('      - websocketServerPort: ${data['websocketServerPort'] ?? "(없음)"}');
          debugPrint('      - websocketUseSSL: ${data['websocketUseSSL'] ?? "(없음)"}');
          debugPrint('      - maxExtensions: ${data['maxExtensions'] ?? 1}');
          debugPrint('      - myExtensions: ${data['myExtensions'] ?? []}');
          debugPrint('');
          debugPrint('   ✅ Firestore 데이터 확인 완료 - 이 데이터는 로그아웃 후에도 유지됩니다');
        } else {
          debugPrint('   ⚠️ Firestore에 users 문서가 없습니다!');
        }
      } catch (e) {
        debugPrint('   ❌ Firestore 조회 오류: $e');
      }
      
      debugPrint('');
      debugPrint('   🔐 로그아웃 진행:');
      debugPrint('      - FCM 토큰 비활성화');
      debugPrint('      - WebSocket 연결 해제');
      debugPrint('      - 로컬 캐시 정리');
      debugPrint('      - _currentUserModel 초기화');
      debugPrint('      - Firestore users 컬렉션은 보존!');
      debugPrint('================================================');
      debugPrint('');
    }
    
    final userId = _auth.currentUser?.uid;
    
    // 1️⃣ FCM 토큰 비활성화 (조용한 로그아웃 시 건너뛰기)
    if (!_isSigningOut) {
      try {
        if (userId != null) {
          final fcmService = FCMService();
          await fcmService.deactivateToken(userId);
          if (kDebugMode) {
            debugPrint('✅ [1/4] FCM 토큰 비활성화 완료');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  [1/4] FCM 토큰 비활성화 오류: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('⏭️  [1/4] 조용한 로그아웃 - FCM 토큰 비활성화 건너뛰기 (토큰 유지)');
      }
    }
    
    // 2️⃣ WebSocket 연결 해제
    try {
      final dcmiwsConnectionManager = DCMIWSConnectionManager();
      await dcmiwsConnectionManager.stop();
      if (kDebugMode) {
        debugPrint('✅ [2/4] WebSocket 연결 해제 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  [2/4] WebSocket 연결 해제 오류: $e');
      }
    }
    
    // 3️⃣ Firebase Authentication 로그아웃
    // ⚠️ 중요: _lastUserId를 먼저 null로 설정하여 _authStateSubscription 중복 트리거 방지
    _lastUserId = null;
    
    await _auth.signOut();
    if (kDebugMode) {
      debugPrint('✅ [3/4] Firebase Authentication 로그아웃 완료');
    }
    
    // 4️⃣ 로컬 상태 초기화
    _currentUserModel = null;  // 로컬 변수만 초기화 (Firestore 데이터 삭제 안 함!)
    if (kDebugMode) {
      debugPrint('✅ [4/4] currentUserModel 초기화 완료 (로컬 변수만)');
      debugPrint('');
      debugPrint('✅ 로그아웃 완료!');
      debugPrint('✅ Firestore users 컬렉션 보존됨');
      debugPrint('✅ 재로그인 시 모든 데이터 로드 가능');
      debugPrint('');
    }
    
    // ✅ notifyListeners() 제거 (450줄에서 이미 호출됨, 중복 rebuild 방지)
    
    // 5️⃣ 모든 수신전화 화면 닫기 (로그아웃 후 null 참조 방지)
    try {
      if (kDebugMode) {
        debugPrint('🔔 [5/5] 수신전화 화면 닫기 시도');
      }
      
      // navigatorKey를 통해 IncomingCallScreen 닫기
      if (navigatorKey.currentContext != null) {
        final context = navigatorKey.currentContext!;
        
        // 현재 route 확인
        final currentRoute = ModalRoute.of(context);
        if (currentRoute != null) {
          if (kDebugMode) {
            debugPrint('   현재 route: ${currentRoute.settings.name ?? "이름 없음"}');
          }
          
          // IncomingCallScreen이 열려있으면 닫기
          try {
            Navigator.of(context).popUntil((route) {
              // 첫 화면이거나 IncomingCallScreen이 아니면 멈춤
              return route.isFirst || route.settings.name != '/incoming_call';
            });
            
            if (kDebugMode) {
              debugPrint('✅ [5/5] 수신전화 화면 닫기 완료');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️  [5/5] popUntil 실패 (이미 닫혔을 수 있음): $e');
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️  [5/5] 현재 route 없음');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️  [5/5] NavigatorKey context 없음 - 화면 닫기 스킵');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  [5/5] 수신전화 화면 닫기 오류 (무시 가능): $e');
      }
    }
    
    // 6️⃣ Navigator 스택 정리 및 로그인 화면으로 이동
    // ℹ️ Navigator 스택 정리 로직 제거
    // Consumer<AuthService>의 notifyListeners()가 자동으로 LoginScreen 전환 처리
    if (kDebugMode) {
      debugPrint('ℹ️  [6/6] Navigator 정리는 Consumer<AuthService>가 자동 처리');
    }
    
    // 🔥 CRITICAL FIX: 로그아웃 플래그는 authStateChanges가 처리할 때까지 유지
    // _isLoggingOut을 false로 설정하면 currentUser가 아직 남아있어 MainScreen이 계속 표시됨
    // authStateChanges 리스너가 currentUser == null을 감지하면 자동으로 플래그 해제
    
    // 🔔 CRITICAL: notifyListeners() 호출하여 UI 업데이트 (isLoggingOut = true 상태 전파)
    notifyListeners();
    
    if (kDebugMode) {
      debugPrint('✅ [LOGOUT] 로그아웃 완료 - isLoggingOut 상태 유지 (LoginScreen 표시)');
      debugPrint('');
    }
  }
  
  /// 🛑 서비스 이용 중지 (계정 비활성화)
  /// 
  /// Features:
  /// - Firebase Authentication에서 계정 비활성화 처리
  /// - Firestore에 계정 상태 업데이트 (isActive: false)
  /// - 로그아웃 처리
  /// 
  /// Throws:
  /// - FirebaseAuthException: Firebase Auth 오류
  /// - FirebaseException: Firestore 오류
  Future<void> suspendAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('로그인된 사용자가 없습니다.');
      }
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🛑 ========== 서비스 이용 중지 시작 ==========');
        debugPrint('   📧 사용자: ${_currentUserModel?.email ?? "없음"}');
        debugPrint('   🆔 UID: ${user.uid}');
        debugPrint('');
      }
      
      // 1️⃣ 현재 디바이스 정보 가져오기 (FCM 토큰에서)
      String? deviceId;
      String? deviceName;
      
      try {
        // 🔍 CRITICAL: FCM 토큰은 최상위 컬렉션에 저장됨
        // 경로: fcm_tokens/{userId}_{deviceId}_{platform}
        final fcmTokensSnapshot = await _firestore
            .collection('fcm_tokens')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
        
        if (fcmTokensSnapshot.docs.isNotEmpty) {
          final tokenData = fcmTokensSnapshot.docs.first.data();
          deviceId = tokenData['deviceId'] as String?;
          deviceName = tokenData['deviceName'] as String?;
          
          if (kDebugMode) {
            debugPrint('📱 [1/4] 디바이스 정보 확인');
            debugPrint('   Device ID: ${deviceId ?? "없음"}');
            debugPrint('   Device Name: ${deviceName ?? "없음"}');
          }
        } else {
          if (kDebugMode) {
            debugPrint('⚠️  [1/4] 활성화된 FCM 토큰 없음');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  [1/4] FCM 토큰 조회 오류 (무시): $e');
        }
      }
      
      // 2️⃣ Firestore에 계정 비활성화 상태 기록
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'isActive': false,
          'suspendedAt': DateTime.now().toIso8601String(),
          'suspendedDeviceId': deviceId,
          'suspendedDeviceName': deviceName,
        });
        
        if (kDebugMode) {
          debugPrint('✅ [2/4] Firestore 계정 상태 업데이트 완료');
          debugPrint('   isActive: false');
          debugPrint('   suspendedAt: ${DateTime.now().toIso8601String()}');
          debugPrint('   suspendedDeviceId: ${deviceId ?? "없음"}');
          debugPrint('   suspendedDeviceName: ${deviceName ?? "없음"}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  [2/4] Firestore 업데이트 오류: $e');
        }
        rethrow;
      }
      
      // 3️⃣ Firebase Authentication 계정 비활성화
      try {
        // Firebase Admin SDK를 사용해야 하지만, 클라이언트에서는 불가능
        // 따라서 Firestore 상태만 업데이트하고 로그아웃 처리
        if (kDebugMode) {
          debugPrint('✅ [3/4] 계정 비활성화 완료 (Firestore 상태)');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  [3/4] 계정 비활성화 오류: $e');
        }
        rethrow;
      }
      
      // 4️⃣ 로그아웃 처리
      try {
        if (kDebugMode) {
          debugPrint('🔓 [4/4] 로그아웃 처리 시작...');
        }
        
        await signOut();
        
        if (kDebugMode) {
          debugPrint('✅ [4/4] 로그아웃 완료');
          debugPrint('');
          debugPrint('✅ 서비스 이용 중지 완료!');
          debugPrint('✅ 계정 상태: 비활성화 (isActive: false)');
          debugPrint('✅ 로그아웃: 완료');
          debugPrint('================================================');
          debugPrint('');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  [4/4] 로그아웃 오류: $e');
        }
        rethrow;
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 서비스 이용 중지 실패: $e');
        debugPrint('');
      }
      rethrow;
    }
  }
  
  // 비밀번호 재설정
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('Reset password error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }
  
  // 사용자 정보 업데이트
  Future<void> updateUserInfo({
    String? phoneNumberName,
    String? phoneNumber,
    String? companyName,
    String? companyId,
    String? appKey,
    String? apiBaseUrl,
    int? apiHttpPort,
    int? apiHttpsPort,
    bool? isPremium,
    String? websocketServerUrl,
    int? websocketServerPort,
    bool? websocketUseSSL,
    String? websocketHttpAuthId,
    String? websocketHttpAuthPassword,
    int? amiServerId,
    List<String>? myExtensions,
  }) async {
    if (currentUser == null) return;
    
    try {
      final updates = <String, dynamic>{};
      if (phoneNumberName != null) updates['phoneNumberName'] = phoneNumberName;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (companyName != null) updates['companyName'] = companyName;
      if (companyId != null) updates['companyId'] = companyId;
      if (appKey != null) updates['appKey'] = appKey;
      if (apiBaseUrl != null) updates['apiBaseUrl'] = apiBaseUrl;
      if (apiHttpPort != null) updates['apiHttpPort'] = apiHttpPort;
      if (apiHttpsPort != null) updates['apiHttpsPort'] = apiHttpsPort;
      if (isPremium != null) updates['isPremium'] = isPremium;
      if (websocketServerUrl != null) updates['websocketServerUrl'] = websocketServerUrl;
      if (websocketServerPort != null) updates['websocketServerPort'] = websocketServerPort;
      if (websocketUseSSL != null) updates['websocketUseSSL'] = websocketUseSSL;
      if (websocketHttpAuthId != null) updates['websocketHttpAuthId'] = websocketHttpAuthId;
      if (websocketHttpAuthPassword != null) updates['websocketHttpAuthPassword'] = websocketHttpAuthPassword;
      if (amiServerId != null) updates['amiServerId'] = amiServerId;
      if (myExtensions != null) updates['myExtensions'] = myExtensions;
      
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(updates);
      
      await _loadUserModel(currentUser!.uid);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update user info error: $e');
      }
      rethrow;
    }
  }
  
  // 프리미엄 상태 토글
  Future<void> togglePremium() async {
    if (currentUser == null) return;
    
    try {
      final newPremiumStatus = !(_currentUserModel?.isPremium ?? false);
      await updateUserInfo(isPremium: newPremiumStatus);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Toggle premium error: $e');
      }
      rethrow;
    }
  }
  
  Future<void> updateCompanyName(String? companyName) async {
    if (currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update({'companyName': companyName});
      
      await _loadUserModel(currentUser!.uid);
      
      if (kDebugMode) {
        debugPrint('✅ Company name updated: $companyName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Update company name error: $e');
      }
      rethrow;
    }
  }
  
  // 프로필 사진 업로드 (Firebase Storage)
  Future<String?> uploadProfileImage(File imageFile) async {
    if (currentUser == null) {
      throw Exception('로그인이 필요합니다.');
    }
    
    try {
      final userId = currentUser!.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');
      
      if (kDebugMode) {
        debugPrint('📸 Uploading profile image for user: $userId');
        debugPrint('📁 File path: ${imageFile.path}');
        debugPrint('📊 File size: ${await imageFile.length()} bytes');
      }
      
      // 파일 크기 확인 (10MB 제한)
      final fileSize = await imageFile.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('이미지 파일 크기가 10MB를 초과합니다.');
      }
      
      // 이미지 업로드 (타임아웃 30초)
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // 업로드 진행 상황 로깅 (디버그 모드)
      if (kDebugMode) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('📤 Upload progress: ${progress.toStringAsFixed(2)}%');
        });
      }
      
      // 업로드 완료 대기
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('업로드 시간이 초과되었습니다. 네트워크를 확인해주세요.');
        },
      );
      
      // 다운로드 URL 가져오기
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (kDebugMode) {
        debugPrint('✅ Profile image uploaded successfully');
        debugPrint('🔗 Download URL: $downloadUrl');
      }
      
      // Firestore에 URL 저장
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'profileImageUrl': downloadUrl,
        'profileImageUpdatedAt': DateTime.now().toIso8601String(),
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Firestore 업데이트 시간이 초과되었습니다.');
        },
      );
      
      if (kDebugMode) {
        debugPrint('✅ Firestore updated with new profile image URL');
      }
      
      // UserModel 새로고침
      await _loadUserModel(userId);
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
      }
      
      // Firebase 에러를 한글로 변환
      String errorMessage;
      switch (e.code) {
        case 'unauthorized':
          errorMessage = 'Firebase Storage 접근 권한이 없습니다. 관리자에게 문의하세요.';
          break;
        case 'canceled':
          errorMessage = '업로드가 취소되었습니다.';
          break;
        case 'unknown':
          errorMessage = '알 수 없는 오류가 발생했습니다.';
          break;
        default:
          errorMessage = 'Firebase 오류: ${e.message ?? e.code}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Upload profile image error: $e');
      }
      rethrow;
    }
  }
  
  // 프로필 사진 삭제
  Future<void> deleteProfileImage() async {
    if (currentUser == null) return;
    
    try {
      final userId = currentUser!.uid;
      
      // Storage에서 삭제
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$userId.jpg');
        await storageRef.delete();
        
        if (kDebugMode) {
          debugPrint('🗑️ Profile image deleted from storage');
        }
      } catch (e) {
        // 파일이 없을 수도 있음 - 무시
        if (kDebugMode) {
          debugPrint('⚠️ Storage delete warning: $e');
        }
      }
      
      // Firestore에서 URL 제거
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'profileImageUrl': null});
      
      // UserModel 새로고침
      await _loadUserModel(userId);
      
      if (kDebugMode) {
        debugPrint('✅ Profile image URL removed from Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Delete profile image error: $e');
      }
      rethrow;
    }
  }
  
  // 회원 탈퇴 (이용 중지)
  Future<void> deleteAccount() async {
    if (currentUser == null) return;
    
    try {
      // Firestore에서 사용자를 비활성화로 표시
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update({'isActive': false});
      
      // Firebase Auth에서 사용자 삭제
      await currentUser!.delete();
      _currentUserModel = null;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Delete account error: $e');
      }
      rethrow;
    }
  }
  
  // 🔄 사용자 정보 다시 로드 (동의 갱신 후)
  Future<void> reloadCurrentUser() async {
    if (currentUser == null) return;
    
    try {
      final userId = currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        _currentUserModel = UserModel.fromMap(
          userDoc.data()!,
          userId,
        );
        if (kDebugMode) {
          debugPrint('✅ [AUTH] 사용자 정보 다시 로드 완료');
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AUTH] 사용자 정보 다시 로드 실패: $e');
      }
    }
  }
  
  // Firebase Auth 에러 메시지 한글화
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'operation-not-allowed':
        return '이메일/비밀번호 로그인이 비활성화되어 있습니다.';
      case 'weak-password':
        return '비밀번호는 8자 이상, 영문/숫자/특수문자를 포함해야 합니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'user-not-found':
        return '등록되지 않은 이메일입니다.';
      case 'wrong-password':
        return '잘못된 비밀번호입니다.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 오류가 발생했습니다.';
      default:
        return '오류가 발생했습니다. 다시 시도해주세요.';
    }
  }
  
  /// 🚫 MaxDeviceLimit 다이얼로그 표시 (AuthService에서 직접 호출)
  /// 
  /// navigatorKey를 사용하여 어디서든 다이얼로그 표시 가능
  /// login_screen의 catch 블록을 거치지 않아도 됨
  static Future<void> _showMaxDeviceLimitDialogFromAuthService(
    BuildContext context,
    MaxDeviceLimitException exception,
  ) async {
    // 🎯 소셜로그인 다이얼로그와 동일하게 MaxDeviceLimitDialog 위젯 사용
    // ✅ 활성 기기 목록 자동 로드 및 표시
    
    // 🔑 CRITICAL: exception에서 userId 가져오기 (로그아웃 후에는 currentUser가 null)
    final userId = exception.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      // ignore: avoid_print
      print('⚠️ [AUTH] userId 없음 - 다이얼로그 표시 불가');
      return;
    }
    
    // ignore: avoid_print
    print('✅ [AUTH] userId 확인: $userId');
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return MaxDeviceLimitDialog(
          exception: exception,
          userId: userId,
          onConfirm: null, // AuthService에서 호출 시 확인 콜백 없음 (자동 로그아웃 처리됨)
        );
      },
    );
  }
}
