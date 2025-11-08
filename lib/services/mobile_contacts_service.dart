import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_model.dart';

class MobileContactsService {
  /// 연락처 권한 상태 확인 (읽기 전용, 빠른 체크)
  Future<bool> hasContactsPermission() async {
    try {
      final status = await Permission.contacts.status;
      if (kDebugMode) {
        debugPrint('📱 Contacts permission status: $status');
      }
      return status.isGranted;
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

      // ✨ iOS FIX: 이미 권한 체크를 call_tab에서 했으므로 여기서는 바로 가져오기
      // FlutterContacts.requestPermission() 호출 시 iOS에서 권한 다이얼로그가 다시 표시됨
      // 대신 현재 권한 상태만 확인하고 거부되면 빈 리스트 반환
      final currentStatus = await Permission.contacts.status;
      
      if (!currentStatus.isGranted) {
        if (kDebugMode) {
          debugPrint('❌ Contacts permission not granted (current status: $currentStatus)');
        }
        return [];
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
