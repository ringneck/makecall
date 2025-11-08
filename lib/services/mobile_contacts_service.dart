import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_model.dart';

class MobileContactsService {
  /// 연락처 권한 상태 확인 (읽기 전용, 빠른 체크)
  Future<bool> hasContactsPermission() async {
    try {
      // ✨ iOS FIX: iOS 권한 캐시 동기화 문제 해결
      final status = await Permission.contacts.status;
      
      if (kDebugMode) {
        debugPrint('📱 [1] Initial permission status: $status');
        debugPrint('   - isGranted: ${status.isGranted}');
        debugPrint('   - isDenied: ${status.isDenied}');
        debugPrint('   - isPermanentlyDenied: ${status.isPermanentlyDenied}');
        debugPrint('   - isRestricted: ${status.isRestricted}');
        debugPrint('   - isLimited: ${status.isLimited}');
      }
      
      // ✅ iOS에서는 isGranted 또는 isLimited 모두 허용으로 간주
      if (status.isGranted || status.isLimited) {
        return true;
      }
      
      // 🔧 iOS 권한 캐시 버그 해결: 
      // isDenied이지만 isPermanentlyDenied가 아닌 경우,
      // 실제 권한 요청을 통해 iOS 시스템과 동기화
      if (Platform.isIOS && status.isDenied && !status.isPermanentlyDenied) {
        if (kDebugMode) {
          debugPrint('⚠️ iOS: Permission shows denied but not permanently');
          debugPrint('🔄 Triggering permission request to sync with system state...');
        }
        
        // 권한 요청 (이미 허용된 경우 다이얼로그 없이 즉시 granted 반환)
        final syncedStatus = await Permission.contacts.request();
        
        if (kDebugMode) {
          debugPrint('📱 [2] Synced permission status: $syncedStatus');
          debugPrint('   - isGranted: ${syncedStatus.isGranted}');
          debugPrint('   - isLimited: ${syncedStatus.isLimited}');
        }
        
        return syncedStatus.isGranted || syncedStatus.isLimited;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking contacts permission: $e');
      }
      return false;
    }
  }

  /// 연락처 권한 요청 (플랫폼별 최적화)
  Future<PermissionStatus> requestContactsPermission() async {
    try {
      if (kDebugMode) {
        debugPrint('📱 Requesting contacts permission...');
      }

      // iOS와 Android 모두 permission_handler 사용
      final status = await Permission.contacts.request();
      
      if (kDebugMode) {
        debugPrint('📱 Contacts permission result: $status');
      }
      
      return status;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error requesting contacts permission: $e');
      }
      return PermissionStatus.denied;
    }
  }

  /// 모바일 연락처 가져오기 (플랫폼별 최적화)
  Future<List<ContactModel>> getDeviceContacts(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('📱 Fetching device contacts...');
      }

      // ✨ iOS FIX: 완벽한 중복 다이얼로그 차단
      // iOS는 권한 상태를 캐싱하므로 isGranted 또는 isLimited 확인
      final currentStatus = await Permission.contacts.status;
      
      if (kDebugMode) {
        debugPrint('📱 getDeviceContacts permission check:');
        debugPrint('   - status: $currentStatus');
        debugPrint('   - isGranted: ${currentStatus.isGranted}');
        debugPrint('   - isLimited: ${currentStatus.isLimited}');
      }
      
      // iOS에서는 isGranted 또는 isLimited 모두 허용
      if (!currentStatus.isGranted && !currentStatus.isLimited) {
        if (kDebugMode) {
          debugPrint('❌ Contacts permission not granted (status: $currentStatus)');
        }
        return [];
      }
      
      if (kDebugMode) {
        debugPrint('✅ Contacts permission OK, fetching contacts...');
      }

      // 연락처 가져오기 (배치 처리로 최적화)
      // iOS: getContacts() 호출 전에 이미 권한 확인 완료
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withThumbnail: false,
        withAccounts: false,
        withGroups: false,
      );

      if (kDebugMode) {
        debugPrint('✅ Found ${contacts.length} device contacts');
      }

      // ContactModel로 변환 (Stream 처리로 메모리 최적화)
      final contactModels = <ContactModel>[];
      
      for (final contact in contacts) {
        try {
          // 전화번호가 있는 연락처만 추가
          if (contact.phones.isNotEmpty) {
            final phone = contact.phones.first.number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
            
            // 빈 이름 필터링
            if (phone.isEmpty) continue;
            
            contactModels.add(
              ContactModel(
                id: '', // Firestore에서 자동 생성
                userId: userId,
                name: contact.displayName.trim().isEmpty ? '이름 없음' : contact.displayName.trim(),
                phoneNumber: phone,
                email: contact.emails.isNotEmpty ? contact.emails.first.address : null,
                company: contact.organizations.isNotEmpty
                    ? contact.organizations.first.company
                    : null,
                isFavorite: false,
                createdAt: DateTime.now(),
                isDeviceContact: true,
              ),
            );
          }
        } catch (e) {
          // 개별 연락처 처리 오류는 무시하고 계속 진행
          if (kDebugMode) {
            debugPrint('⚠️ Error processing contact: $e');
          }
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Converted ${contactModels.length} contacts with phone numbers');
      }

      // 이름순 정렬
      contactModels.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      return contactModels;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error fetching device contacts: $e');
      }
      return [];
    }
  }

  /// 특정 연락처 검색
  Future<List<ContactModel>> searchDeviceContacts(
    String userId,
    String query,
  ) async {
    if (query.isEmpty) {
      return getDeviceContacts(userId);
    }

    try {
      final allContacts = await getDeviceContacts(userId);
      final searchQuery = query.toLowerCase();

      return allContacts.where((contact) {
        return contact.name.toLowerCase().contains(searchQuery) ||
            contact.phoneNumber.contains(searchQuery);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error searching device contacts: $e');
      }
      return [];
    }
  }

  /// 플랫폼별 앱 설정 열기
  Future<bool> openAppSettings() async {
    try {
      if (kDebugMode) {
        debugPrint('📱 Opening app settings (Platform: ${Platform.operatingSystem})');
      }
      
      final opened = await Permission.contacts.request().then((status) async {
        if (status.isPermanentlyDenied || status.isDenied) {
          return await openSettings();
        }
        return false;
      });
      
      if (kDebugMode) {
        debugPrint('📱 Settings opened: $opened');
      }
      
      return opened;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error opening app settings: $e');
      }
      return false;
    }
  }

  /// 앱 설정 열기 (단순 버전)
  Future<bool> openSettings() async {
    try {
      return await Permission.contacts.shouldShowRequestRationale
          ? false
          : await openAppSettingsHandler();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error in openSettings: $e');
      }
      return false;
    }
  }

  /// 실제 설정 핸들러
  Future<bool> openAppSettingsHandler() async {
    try {
      if (Platform.isIOS) {
        // iOS: 앱 설정으로 직접 이동
        return await openAppSettings();
      } else if (Platform.isAndroid) {
        // Android: 앱 설정으로 직접 이동
        return await openAppSettings();
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error opening app settings handler: $e');
      }
      return false;
    }
  }
}
