import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/user_model.dart';
import 'account_manager_service.dart';
import 'fcm_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountManagerService _accountManager = AccountManagerService();
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  
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
      } else {
        if (kDebugMode) {
          debugPrint('🔓 Auth 상태 변경: 로그아웃');
          debugPrint('   - currentUserModel 초기화');
        }
        _currentUserModel = null;
      }
      notifyListeners();
    });
  }
  
  // 비밀번호를 일시적으로 저장하기 위한 변수 (로그인 시에만 사용)
  String? _tempPassword;
  
  Future<void> _loadUserModel(String uid, {String? password}) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _currentUserModel = UserModel.fromMap(data, uid);
        
        // 계정 저장 (비밀번호 포함)
        await _accountManager.saveAccount(_currentUserModel!, password: password ?? _tempPassword);
        
        // 일시 비밀번호 삭제
        _tempPassword = null;
        
        // 🔍 확장된 디버그 로깅 (API 서버 및 WebSocket 정보 포함)
        if (kDebugMode) {
          debugPrint('📥 ========== Firestore 사용자 데이터 로드 ==========');
          debugPrint('   📧 Email: ${data['email']}');
          debugPrint('   🏢 Company: ${data['companyName'] ?? "(없음)"}');
          debugPrint('   🆔 CompanyId: ${data['companyId'] ?? "(없음)"}');
          debugPrint('   🔑 AppKey: ${data['appKey'] ?? "(없음)"}');
          debugPrint('');
          debugPrint('   🌐 API 서버 정보:');
          debugPrint('      - apiBaseUrl: ${data['apiBaseUrl'] ?? "(없음)"}');
          debugPrint('      - apiHttpPort: ${data['apiHttpPort'] ?? "(없음)"}');
          debugPrint('      - apiHttpsPort: ${data['apiHttpsPort'] ?? "(없음)"}');
          debugPrint('');
          debugPrint('   🔌 WebSocket 서버 정보:');
          debugPrint('      - websocketServerUrl: ${data['websocketServerUrl'] ?? "(없음)"}');
          debugPrint('      - websocketServerPort: ${data['websocketServerPort'] ?? "(없음)"}');
          debugPrint('      - websocketUseSSL: ${data['websocketUseSSL'] ?? "(없음)"}');
          debugPrint('      - amiServerId: ${data['amiServerId'] ?? "(없음)"}');
          debugPrint('');
          debugPrint('   📱 단말번호 정보:');
          debugPrint('      - myExtensions (raw): ${data['myExtensions']} (타입: ${data['myExtensions'].runtimeType})');
          debugPrint('      - myExtensions (파싱): ${_currentUserModel?.myExtensions}');
          debugPrint('      - maxExtensions: ${data['maxExtensions'] ?? 1}');
          debugPrint('');
          debugPrint('   ✅ UserModel 생성 완료:');
          debugPrint('      - apiBaseUrl: ${_currentUserModel?.apiBaseUrl ?? "(null)"}');
          debugPrint('      - websocketServerUrl: ${_currentUserModel?.websocketServerUrl ?? "(null)"}');
          debugPrint('================================================');
        }
        
        notifyListeners();
      } else {
        // Firestore에 사용자 문서가 없는 경우
        if (kDebugMode) {
          debugPrint('⚠️ Firestore에 사용자 문서 없음');
          debugPrint('   - UID: $uid');
          debugPrint('   - Email: ${_auth.currentUser?.email}');
          debugPrint('   - 사용자 문서 자동 생성 중...');
        }
        
        // 기본 사용자 문서 자동 생성
        final newUserData = {
          'email': _auth.currentUser?.email ?? '',
          'createdAt': DateTime.now().toIso8601String(),
          'isActive': true,
          'isPremium': false,
          'maxExtensions': 1,
        };
        
        await _firestore.collection('users').doc(uid).set(newUserData);
        
        if (kDebugMode) {
          debugPrint('✅ 사용자 문서 생성 완료');
        }
        
        // 생성된 문서로 UserModel 로드
        _currentUserModel = UserModel.fromMap(newUserData, uid);
        
        // 계정 저장 (비밀번호 포함)
        await _accountManager.saveAccount(_currentUserModel!, password: password ?? _tempPassword);
        
        // 일시 비밀번호 삭제
        _tempPassword = null;
        
        notifyListeners();
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
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .update({'lastLoginAt': DateTime.now().toIso8601String()});
        
        // 비밀번호를 _loadUserModel에 전달하여 자동 저장
        await _loadUserModel(credential.user!.uid, password: password);
        
        // FCM 초기화 (로그인 성공 후)
        try {
          if (kDebugMode) {
            debugPrint('');
            debugPrint('🔔 로그인 성공 - FCM 초기화 시작...');
          }
          final fcmService = FCMService();
          await fcmService.initialize(credential.user!.uid);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️  FCM 초기화 오류 (로그인은 정상): $e');
          }
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
  Future<void> signOut() async {
    if (kDebugMode) {
      debugPrint('🔓 로그아웃 시작');
      debugPrint('   - 현재 사용자: ${_currentUserModel?.email ?? "없음"}');
    }
    
    // FCM 토큰 비활성화
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final fcmService = FCMService();
        await fcmService.deactivateToken(userId);
        if (kDebugMode) {
          debugPrint('✅ FCM 토큰 비활성화 완료');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  FCM 토큰 비활성화 오류: $e');
      }
    }
    
    await _auth.signOut();
    _currentUserModel = null;
    
    if (kDebugMode) {
      debugPrint('✅ currentUserModel 초기화 완료');
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
