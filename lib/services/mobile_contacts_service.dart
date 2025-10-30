import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_model.dart';

class MobileContactsService {
  /// 연락처 권한 요청
  Future<bool> requestContactsPermission() async {
    try {
      final status = await Permission.contacts.request();
      if (kDebugMode) {
        debugPrint('📱 Contacts permission status: $status');
      }
      return status.isGranted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error requesting contacts permission: $e');
      }
      return false;
    }
  }

  /// 모바일 연락처 가져오기
  Future<List<ContactModel>> getDeviceContacts(String userId) async {
    try {
      // 권한 확인
      if (!await FlutterContacts.requestPermission()) {
        if (kDebugMode) {
          debugPrint('❌ Contacts permission denied');
        }
        return [];
      }

      if (kDebugMode) {
        debugPrint('📱 Fetching device contacts...');
      }

      // 연락처 가져오기 (전화번호 포함)
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (kDebugMode) {
        debugPrint('✅ Found ${contacts.length} device contacts');
      }

      // ContactModel로 변환
      final contactModels = <ContactModel>[];
      for (final contact in contacts) {
        // 전화번호가 있는 연락처만 추가
        if (contact.phones.isNotEmpty) {
          final phone = contact.phones.first.number;
          
          contactModels.add(
            ContactModel(
              id: '', // Firestore에서 자동 생성
              userId: userId,
              name: contact.displayName.isEmpty ? '이름 없음' : contact.displayName,
              phoneNumber: phone,
              email: contact.emails.isNotEmpty ? contact.emails.first.address : null,
              company: contact.organizations.isNotEmpty
                  ? contact.organizations.first.company
                  : null,
              isFavorite: false,
              createdAt: DateTime.now(),
              isDeviceContact: true, // 장치 연락처 표시
            ),
          );
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Converted ${contactModels.length} contacts with phone numbers');
      }

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

  /// 연락처 권한 상태 확인
  Future<bool> hasContactsPermission() async {
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking contacts permission: $e');
      }
      return false;
    }
  }
}
