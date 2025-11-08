import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_model.dart';

class MobileContactsService {
  /// 연락처 권한 상태 확인 (읽기 전용, 빠른 체크)
  Future<bool> hasContactsPermission() async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔍 ===== hasContactsPermission CHECK START =====');
      }
      
      // 🎯 CRITICAL FIX: flutter_contacts를 PRIMARY 권한 체크로 사용
      // flutter_contacts는 iOS/Android 네이티브 권한 API와 직접 통합
      // readonly: true로 호출하면 다이얼로그 없이 현재 상태만 확인
      final flutterContactsPermission = await FlutterContacts.requestPermission(readonly: true);
      
      if (kDebugMode) {
        debugPrint('📱 FlutterContacts.requestPermission(readonly: true): $flutterContactsPermission');
      }
      
      // flutter_contacts가 true를 반환하면 권한이 확실히 있음
      if (flutterContactsPermission) {
        if (kDebugMode) {
          debugPrint('✅ FlutterContacts confirms permission GRANTED');
          debugPrint('🔍 ===== hasContactsPermission CHECK END =====');
          debugPrint('');
        }
        return true;
      }
      
      // flutter_contacts가 false를 반환하면 권한 없음
      if (kDebugMode) {
        debugPrint('❌ FlutterContacts confirms permission DENIED');
        debugPrint('🔍 ===== hasContactsPermission CHECK END =====');
        debugPrint('');
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking contacts permission: $e');
        debugPrint('🔍 ===== hasContactsPermission CHECK END (ERROR) =====');
        debugPrint('');
      }
      return false;
    }
  }

  /// 연락처 권한 요청 (flutter_contacts 사용)
  Future<PermissionStatus> requestContactsPermission() async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔍 ===== requestContactsPermission START =====');
        debugPrint('📱 Calling FlutterContacts.requestPermission()...');
      }

      // 🎯 CRITICAL FIX: flutter_contacts를 사용하여 권한 요청
      // readonly: false로 호출하면 실제 시스템 권한 다이얼로그 표시
      final granted = await FlutterContacts.requestPermission();
      
      if (kDebugMode) {
        debugPrint('📱 FlutterContacts.requestPermission() result: $granted');
        debugPrint('🔍 ===== requestContactsPermission END =====');
        debugPrint('');
      }
      
      // bool을 PermissionStatus로 변환
      return granted ? PermissionStatus.granted : PermissionStatus.denied;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error requesting contacts permission: $e');
        debugPrint('🔍 ===== requestContactsPermission END (ERROR) =====');
        debugPrint('');
      }
      return PermissionStatus.denied;
    }
  }

  /// 모바일 연락처 가져오기 (플랫폼별 최적화)
  Future<List<ContactModel>> getDeviceContacts(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔍 ===== getDeviceContacts START =====');
      }

      // 🎯 CRITICAL FIX: flutter_contacts로 권한 확인 (permission_handler 사용 안 함)
      // hasContactsPermission()과 동일한 방식 사용
      final hasPermission = await FlutterContacts.requestPermission(readonly: true);
      
      if (kDebugMode) {
        debugPrint('📱 FlutterContacts permission check: $hasPermission');
      }
      
      if (!hasPermission) {
        if (kDebugMode) {
          debugPrint('❌ Contacts permission not granted');
          debugPrint('🔍 ===== getDeviceContacts END (NO PERMISSION) =====');
          debugPrint('');
        }
        return [];
      }
      
      if (kDebugMode) {
        debugPrint('✅ Contacts permission OK, fetching contacts...');
      }

      // 연락처 가져오기 (배치 처리로 최적화)
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withThumbnail: false,
        withAccounts: false,
        withGroups: false,
      );

      if (kDebugMode) {
        debugPrint('✅ FlutterContacts.getContacts() returned ${contacts.length} contacts');
      }

      // ContactModel로 변환
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

      if (kDebugMode) {
        debugPrint('📱 Returning ${contactModels.length} contacts');
        debugPrint('🔍 ===== getDeviceContacts END =====');
        debugPrint('');
      }

      return contactModels;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error fetching device contacts: $e');
        debugPrint('🔍 ===== getDeviceContacts END (ERROR) =====');
        debugPrint('');
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
