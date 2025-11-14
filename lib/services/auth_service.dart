import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/user_model.dart';
import 'account_manager_service.dart';
import 'fcm_service.dart';
import 'dcmiws_connection_manager.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountManagerService _accountManager = AccountManagerService();
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _currentUserModel != null;
  
  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;
  
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        if (kDebugMode) {
          debugPrint('🔐 Auth 상태 변경: 로그인');
          debugPrint('   - UID: ${user.uid}');
          debugPrint('   - Email: ${user.email}');
        }
        _loadUserModel(user.uid);
        // ⚠️ 로그인 시에는 notifyListeners() 호출 안 함 (_loadUserModel에서 호출)
      } else {
        if (kDebugMode) {
          debugPrint('🔓 Auth 상태 변경: 로그아웃');
          debugPrint('   - currentUserModel 초기화');
        }
        _currentUserModel = null;
        notifyListeners(); // ✅ 로그아웃 시에만 여기서 notifyListeners() 호출
      }
    });
  }
  
  // 비밀번호를 일시적으로 저장하기 위한 변수 (로그인 시에만 사용)
  String? _tempPassword;
  
  Future<void> _loadUserModel(String uid, {String? password}) async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔄 ========== _loadUserModel 호출 ==========');
        debugPrint('   🆔 UID: $uid');
        debugPrint('   🔍 Firestore에서 users 문서 조회 중...');
      }
      
      final doc = await _firestore.collection('users').doc(uid).get();
      
      if (kDebugMode) {
        debugPrint('   📄 문서 존재 여부: ${doc.exists}');
      }
      
      if (doc.exists) {
        final data = doc.data()!;
        
        if (kDebugMode) {
          debugPrint('   📦 Firestore Raw Data:');
          debugPrint('      - 전체 필드 개수: ${data.keys.length}');
          debugPrint('      - 필드 목록: ${data.keys.toList()}');
          debugPrint('      - maxExtensions (raw): ${data['maxExtensions']}');
          debugPrint('      - myExtensions (raw): ${data['myExtensions']}');
        }
        _currentUserModel = UserModel.fromMap(data, uid);
        
        if (kDebugMode) {
          debugPrint('   ✅ UserModel 생성 완료:');
          debugPrint('      - maxExtensions: ${_currentUserModel?.maxExtensions}');
          debugPrint('      - myExtensions: ${_currentUserModel?.myExtensions}');
          debugPrint('      - myExtensions length: ${_currentUserModel?.myExtensions?.length ?? 0}');
        }
        
        // 계정 저장 (비밀번호 포함)
        await _accountManager.saveAccount(_currentUserModel!, password: password ?? _tempPassword);
        
        // 일시 비밀번호 삭제
        _tempPassword = null;
        
        // 🔍 확장된 디버그 로깅 (API 서버 및 WebSocket 정보 포함)
        if (kDebugMode) {
          debugPrint('');
          debugPrint('📥 ========== Firestore 사용자 데이터 로드 ==========');
          debugPrint('   📧 Email: ${data['email']}');
          debugPrint('   🏢 Company: ${data['companyName'] ?? "(없음)"}');
          debugPrint('   🆔 CompanyId: ${data['companyId'] ?? "(없음)"}');
          debugPrint('   🔑 AppKey: ${data['appKey'] ?? "(없음)"}');
          debugPrint('');
          debugPrint('   🌐 API 서버 정보 (Firestore Raw):');
          debugPrint('      - apiBaseUrl: ${data['apiBaseUrl'] ?? "(없음)"}');
          debugPrint('      - apiHttpPort: ${data['apiHttpPort'] ?? "(없음)"}');
          debugPrint('      - apiHttpsPort: ${data['apiHttpsPort'] ?? "(없음)"}');
          debugPrint('');
          debugPrint('   🔌 WebSocket 서버 정보 (Firestore Raw):');
          debugPrint('      - websocketServerUrl: ${data['websocketServerUrl'] ?? "(없음)"}');
          debugPrint('      - websocketServerPort: ${data['websocketServerPort'] ?? "(없음)"}');
          debugPrint('      - websocketUseSSL: ${data['websocketUseSSL'] ?? "(없음)"}');
          debugPrint('      - amiServerId: ${data['amiServerId'] ?? "(없음)"}');
          debugPrint('');
          debugPrint('   📱 단말번호 제한 정보:');
          debugPrint('      - maxExtensions: ${data['maxExtensions'] ?? 1} (등록 가능한 최대 개수)');
          debugPrint('      - myExtensions: ${data['myExtensions'] ?? "null"} (⚠️ 참고용 - 실제는 my_extensions 컬렉션에서 조회)');
          debugPrint('');
          debugPrint('   ✅ UserModel 생성 완료:');
          debugPrint('      - apiBaseUrl: ${_currentUserModel?.apiBaseUrl ?? "(null)"}');
          debugPrint('      - websocketServerUrl: ${_currentUserModel?.websocketServerUrl ?? "(null)"}');
          debugPrint('');
          debugPrint('   🔒 데이터 보존 검증:');
          final hasApiConfig = _currentUserModel?.apiBaseUrl != null && _currentUserModel!.apiBaseUrl!.isNotEmpty;
          final hasWebSocketConfig = _currentUserModel?.websocketServerUrl != null && _currentUserModel!.websocketServerUrl!.isNotEmpty;
          debugPrint('      - API 설정 존재: ${hasApiConfig ? "✅ 정상" : "⚠️ 없음"}');
          debugPrint('      - WebSocket 설정 존재: ${hasWebSocketConfig ? "✅ 정상" : "⚠️ 없음"}');
          if (!hasApiConfig || !hasWebSocketConfig) {
            debugPrint('');
            debugPrint('   ⚠️⚠️⚠️ 경고: API/WebSocket 설정이 없습니다!');
            debugPrint('      - 로그아웃 전에 데이터가 저장되지 않았을 가능성');
            debugPrint('      - Profile 탭에서 API 서버 정보를 다시 입력하세요');
          } else {
            debugPrint('   ✅✅✅ 데이터 보존 성공: 모든 설정이 정상적으로 로드됨');
          }
          debugPrint('================================================');
          debugPrint('');
        }
        
        notifyListeners();
      } else {
        // 🚫 Firestore에 사용자 문서가 없는 경우 - 로그인 거부
        if (kDebugMode) {
          debugPrint('');
          debugPrint('❌ ========================================');
          debugPrint('❌ Firestore에 사용자 문서 없음 - 로그인 거부');
          debugPrint('❌ ========================================');
          debugPrint('   - UID: $uid');
          debugPrint('   - Email: ${_auth.currentUser?.email}');
          debugPrint('');
          debugPrint('🔒 보안 정책:');
          debugPrint('   - 관리자가 먼저 사용자 계정을 생성해야 합니다');
          debugPrint('   - Firebase Authentication만으로는 로그인 불가');
          debugPrint('   - Firestore users 컬렉션에 문서 존재 필수');
          debugPrint('');
          debugPrint('🔄 Firebase Authentication 로그아웃 처리 중...');
        }
        
        // Firebase Authentication 로그아웃
        await _auth.signOut();
        
        if (kDebugMode) {
          debugPrint('✅ 로그아웃 완료');
          debugPrint('❌ ========================================');
          debugPrint('');
        }
        
        // 일시 비밀번호 삭제
        _tempPassword = null;
        
        // 예외 발생 - UI에서 처리
        throw Exception('Account not authorized. Please contact administrator to create your account in the system.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load user model: $e');
      }
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
  
  // 회원가입
  Future<UserCredential?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Firestore에 사용자 정보 저장
      if (credential.user != null) {
        final userModel = UserModel(
          uid: credential.user!.uid,
          email: email,
          createdAt: DateTime.now(),
        );
        
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userModel.toMap());
        
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
        await _loadUserModel(credential.user!.uid, password: password);
        
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
    
    // 1️⃣ FCM 토큰 비활성화
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
    
    notifyListeners();
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
  
  // 회사명(조직명) 업데이트
  Future<void> updateCompanyName(String? companyName) async {
    if (currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'companyName': companyName,
      });
      
      // 사용자 모델 다시 로드
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
        return '비밀번호는 최소 6자 이상이어야 합니다.';
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
}
