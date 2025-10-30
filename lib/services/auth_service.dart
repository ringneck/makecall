import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  
  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;
  
  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadUserModel(user.uid);
      } else {
        _currentUserModel = null;
      }
      notifyListeners();
    });
  }
  
  Future<void> _loadUserModel(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUserModel = UserModel.fromMap(doc.data()!, uid);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load user model: $e');
      }
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
  
  // 로그인
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
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
        
        await _loadUserModel(credential.user!.uid);
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('SignIn error: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }
  
  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUserModel = null;
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
    String? companyId,
    String? appKey,
    String? apiBaseUrl,
    int? apiHttpPort,
    int? apiHttpsPort,
    bool? isPremium,
  }) async {
    if (currentUser == null) return;
    
    try {
      final updates = <String, dynamic>{};
      if (phoneNumberName != null) updates['phoneNumberName'] = phoneNumberName;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (companyId != null) updates['companyId'] = companyId;
      if (appKey != null) updates['appKey'] = appKey;
      if (apiBaseUrl != null) updates['apiBaseUrl'] = apiBaseUrl;
      if (apiHttpPort != null) updates['apiHttpPort'] = apiHttpPort;
      if (apiHttpsPort != null) updates['apiHttpsPort'] = apiHttpsPort;
      if (isPremium != null) updates['isPremium'] = isPremium;
      
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
