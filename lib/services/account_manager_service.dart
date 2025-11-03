import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/saved_account_model.dart';
import '../models/user_model.dart';

class AccountManagerService {
  static const String _savedAccountsKey = 'saved_accounts';
  static const String _currentAccountUidKey = 'current_account_uid';
  static const String _keepLoginKey = 'keep_login_enabled';
  static const String _switchTargetEmailKey = 'switch_target_email'; // 계정 전환 대상 이메일

  // 저장된 모든 계정 가져오기
  Future<List<SavedAccountModel>> getSavedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accountsJson = prefs.getString(_savedAccountsKey);
      final String? currentUid = prefs.getString(_currentAccountUidKey);

      if (accountsJson == null) {
        return [];
      }

      final List<dynamic> accountsList = json.decode(accountsJson);
      return accountsList.map((json) {
        final account = SavedAccountModel.fromMap(json as Map<String, dynamic>);
        // 현재 계정 표시
        return account.copyWith(isCurrentAccount: account.uid == currentUid);
      }).toList()
        ..sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt)); // 최근 로그인 순
    } catch (e) {
      print('❌ Error loading saved accounts: $e');
      return [];
    }
  }

  // 계정 저장 또는 업데이트
  Future<void> saveAccount(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 기존 계정 목록 가져오기
      List<SavedAccountModel> accounts = await getSavedAccounts();
      
      // 같은 uid의 계정이 있으면 업데이트, 없으면 추가
      final existingIndex = accounts.indexWhere((acc) => acc.uid == user.uid);
      
      final newAccount = SavedAccountModel(
        uid: user.uid,
        email: user.email,
        organizationName: user.organizationName,
        profileImageUrl: user.profileImageUrl,
        lastLoginAt: DateTime.now(),
        isCurrentAccount: true,
      );

      if (existingIndex >= 0) {
        accounts[existingIndex] = newAccount;
      } else {
        accounts.add(newAccount);
      }

      // 모든 계정의 isCurrentAccount를 false로 설정 후 현재 계정만 true
      accounts = accounts.map((acc) => 
        acc.copyWith(isCurrentAccount: acc.uid == user.uid)
      ).toList();

      // 저장
      final accountsJson = json.encode(accounts.map((acc) => acc.toMap()).toList());
      await prefs.setString(_savedAccountsKey, accountsJson);
      await prefs.setString(_currentAccountUidKey, user.uid);

      print('✅ Account saved: ${user.email} (${user.organizationName ?? "no org name"})');
    } catch (e) {
      print('❌ Error saving account: $e');
    }
  }

  // 계정 삭제
  Future<void> removeAccount(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<SavedAccountModel> accounts = await getSavedAccounts();
      
      accounts.removeWhere((acc) => acc.uid == uid);
      
      final accountsJson = json.encode(accounts.map((acc) => acc.toMap()).toList());
      await prefs.setString(_savedAccountsKey, accountsJson);

      print('✅ Account removed: $uid');
    } catch (e) {
      print('❌ Error removing account: $e');
    }
  }

  // 현재 계정 UID 가져오기
  Future<String?> getCurrentAccountUid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentAccountUidKey);
    } catch (e) {
      print('❌ Error getting current account uid: $e');
      return null;
    }
  }

  // 현재 계정 설정
  Future<void> setCurrentAccount(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentAccountUidKey, uid);
      
      // 저장된 계정 목록도 업데이트
      List<SavedAccountModel> accounts = await getSavedAccounts();
      accounts = accounts.map((acc) => 
        acc.copyWith(isCurrentAccount: acc.uid == uid)
      ).toList();
      
      final accountsJson = json.encode(accounts.map((acc) => acc.toMap()).toList());
      await prefs.setString(_savedAccountsKey, accountsJson);

      print('✅ Current account set to: $uid');
    } catch (e) {
      print('❌ Error setting current account: $e');
    }
  }

  // 조직명 업데이트
  Future<void> updateOrganizationName(String uid, String organizationName) async {
    try {
      List<SavedAccountModel> accounts = await getSavedAccounts();
      
      final index = accounts.indexWhere((acc) => acc.uid == uid);
      if (index >= 0) {
        accounts[index] = accounts[index].copyWith(organizationName: organizationName);
        
        final prefs = await SharedPreferences.getInstance();
        final accountsJson = json.encode(accounts.map((acc) => acc.toMap()).toList());
        await prefs.setString(_savedAccountsKey, accountsJson);

        print('✅ Organization name updated for: $uid');
      }
    } catch (e) {
      print('❌ Error updating organization name: $e');
    }
  }

  // 모든 계정 삭제 (로그아웃 시)
  Future<void> clearAllAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedAccountsKey);
      await prefs.remove(_currentAccountUidKey);
      print('✅ All accounts cleared');
    } catch (e) {
      print('❌ Error clearing accounts: $e');
    }
  }

  // 로그인 유지 설정 가져오기 (기본값: true)
  Future<bool> getKeepLoginEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool? storedValue = prefs.getBool(_keepLoginKey);
      final bool result = storedValue ?? true; // 기본값을 true로 변경
      
      print('🔍 Keep Login Setting: stored=$storedValue, result=$result');
      
      // 처음 사용하는 경우 (storedValue가 null) 기본값을 저장
      if (storedValue == null) {
        await prefs.setBool(_keepLoginKey, true);
        print('✅ Keep Login Setting initialized to true');
      }
      
      return result;
    } catch (e) {
      print('❌ Error getting keep login setting: $e');
      return true; // 에러 시에도 true 반환
    }
  }

  // 로그인 유지 설정 저장
  Future<void> setKeepLoginEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keepLoginKey, enabled);
      print('✅ Keep login setting updated: $enabled');
    } catch (e) {
      print('❌ Error setting keep login: $e');
    }
  }

  // 계정 전환 대상 이메일 저장
  Future<void> setSwitchTargetEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_switchTargetEmailKey, email);
      print('✅ Switch target email set: $email');
    } catch (e) {
      print('❌ Error setting switch target email: $e');
    }
  }

  // 계정 전환 대상 이메일 가져오기 (가져온 후 삭제)
  Future<String?> getSwitchTargetEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_switchTargetEmailKey);
      
      // 읽은 후 바로 삭제 (일회용)
      if (email != null) {
        await prefs.remove(_switchTargetEmailKey);
        print('✅ Switch target email retrieved and cleared: $email');
      }
      
      return email;
    } catch (e) {
      print('❌ Error getting switch target email: $e');
      return null;
    }
  }
}
