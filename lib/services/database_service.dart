import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/main_number_model.dart';
import '../models/extension_model.dart';
import '../models/call_history_model.dart';
import '../models/contact_model.dart';
import '../models/my_extension_model.dart';
import '../models/phonebook_model.dart';
import '../models/call_forward_info_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ===== 대표번호 관리 =====
  
  // 대표번호 추가
  Future<String> addMainNumber(MainNumberModel mainNumber) async {
    try {
      final docRef = await _firestore
          .collection('main_numbers')
          .add(mainNumber.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Add main number error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 대표번호 목록 조회
  Stream<List<MainNumberModel>> getUserMainNumbers(String userId) {
    return _firestore
        .collection('main_numbers')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final numbers = snapshot.docs
              .map((doc) => MainNumberModel.fromMap(doc.data(), doc.id))
              .toList();
          // 메모리에서 order 필드로 정렬 (복합 인덱스 불필요)
          numbers.sort((a, b) => a.order.compareTo(b.order));
          return numbers;
        });
  }
  
  // 대표번호 업데이트
  Future<void> updateMainNumber(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('main_numbers').doc(id).update(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update main number error: $e');
      }
      rethrow;
    }
  }
  
  // 대표번호 삭제
  Future<void> deleteMainNumber(String id) async {
    try {
      await _firestore.collection('main_numbers').doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Delete main number error: $e');
      }
      rethrow;
    }
  }
  
  // ===== 단말번호 관리 =====
  
  // 단말번호 추가
  Future<String> addExtension(ExtensionModel extension) async {
    try {
      final docRef = await _firestore
          .collection('extensions')
          .add(extension.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Add extension error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 단말번호 목록 조회
  Stream<List<ExtensionModel>> getUserExtensions(String userId) {
    return _firestore
        .collection('extensions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExtensionModel.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  // 단말번호 업데이트
  Future<void> updateExtension(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('extensions').doc(id).update(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update extension error: $e');
      }
      rethrow;
    }
  }
  
  // 단말번호 삭제
  Future<void> deleteExtension(String id) async {
    try {
      await _firestore.collection('extensions').doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Delete extension error: $e');
      }
      rethrow;
    }
  }
  
  // ===== 통화 기록 관리 =====
  
  // 통화 기록 추가
  Future<String> addCallHistory(CallHistoryModel callHistory) async {
    try {
      final docRef = await _firestore
          .collection('call_history')
          .add(callHistory.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Add call history error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 통화 기록 조회
  Stream<List<CallHistoryModel>> getUserCallHistory(String userId, {int limit = 50}) {
    return _firestore
        .collection('call_history')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final history = snapshot.docs
              .map((doc) => CallHistoryModel.fromMap(doc.data(), doc.id))
              .toList();
          // 메모리에서 통화 시간으로 정렬 (최신순, 복합 인덱스 불필요)
          history.sort((a, b) => b.callTime.compareTo(a.callTime));
          // limit 적용
          return history.take(limit).toList();
        });
  }
  
  // ===== 연락처 관리 =====
  
  // 연락처 추가
  Future<String> addContact(ContactModel contact) async {
    try {
      final docRef = await _firestore
          .collection('contacts')
          .add(contact.toMap());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Add contact error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 연락처 조회
  Stream<List<ContactModel>> getUserContacts(String userId) {
    return _firestore
        .collection('contacts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final contacts = snapshot.docs
              .map((doc) => ContactModel.fromMap(doc.data(), doc.id))
              .toList();
          // 메모리에서 이름으로 정렬 (복합 인덱스 불필요)
          contacts.sort((a, b) => a.name.compareTo(b.name));
          return contacts;
        });
  }
  
  // 즐겨찾기 연락처 조회
  Stream<List<ContactModel>> getFavoriteContacts(String userId) {
    return _firestore
        .collection('contacts')
        .where('userId', isEqualTo: userId)
        .where('isFavorite', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final contacts = snapshot.docs
              .map((doc) => ContactModel.fromMap(doc.data(), doc.id))
              .toList();
          // 메모리에서 이름으로 정렬 (복합 인덱스 불필요)
          contacts.sort((a, b) => a.name.compareTo(b.name));
          return contacts;
        });
  }
  
  // 연락처 업데이트
  Future<void> updateContact(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('contacts').doc(id).update(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update contact error: $e');
      }
      rethrow;
    }
  }
  
  // 연락처 삭제
  Future<void> deleteContact(String id) async {
    try {
      await _firestore.collection('contacts').doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Delete contact error: $e');
      }
      rethrow;
    }
  }
  
  // 전화번호로 연락처 검색
  Future<ContactModel?> findContactByPhone(String userId, String phoneNumber) async {
    try {
      final snapshot = await _firestore
          .collection('contacts')
          .where('userId', isEqualTo: userId)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return ContactModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Find contact by phone error: $e');
      }
      return null;
    }
  }
  
  // ===== 내 단말번호 관리 =====
  
  // 내 단말번호 추가 (중복 체크 후 추가 또는 업데이트)
  Future<String> addMyExtension(MyExtensionModel extension) async {
    try {
      // 중복 체크: 같은 사용자의 같은 extension이 이미 존재하는지 확인
      final existingSnapshot = await _firestore
          .collection('my_extensions')
          .where('userId', isEqualTo: extension.userId)
          .where('extension', isEqualTo: extension.extension)
          .limit(1)
          .get();
      
      if (existingSnapshot.docs.isNotEmpty) {
        // 이미 존재하면 기존 문서를 업데이트하고 ID 반환
        final docId = existingSnapshot.docs.first.id;
        await _firestore
            .collection('my_extensions')
            .doc(docId)
            .update(extension.toFirestore());
        
        if (kDebugMode) {
          debugPrint('✅ Updated existing extension: ${extension.extension} (ID: $docId)');
        }
        
        return docId;
      }
      
      // 새로 추가
      final docRef = await _firestore
          .collection('my_extensions')
          .add(extension.toFirestore());
      
      if (kDebugMode) {
        debugPrint('✅ Added new extension: ${extension.extension} (ID: ${docRef.id})');
      }
      
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Add my extension error: $e');
      }
      rethrow;
    }
  }
  
  // 여러 개의 내 단말번호를 한번에 추가 (배치 처리)
  Future<List<String>> addMyExtensionsBatch(List<MyExtensionModel> extensions) async {
    try {
      final addedIds = <String>[];
      
      for (final extension in extensions) {
        final id = await addMyExtension(extension);
        addedIds.add(id);
      }
      
      return addedIds;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Add my extensions batch error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 내 단말번호 목록 조회
  Stream<List<MyExtensionModel>> getMyExtensions(String userId) {
    return _firestore
        .collection('my_extensions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final extensions = snapshot.docs
              .map((doc) => MyExtensionModel.fromFirestore(doc.data(), doc.id))
              .toList();
          // 메모리에서 생성 시간으로 정렬 (최신순)
          extensions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return extensions;
        });
  }
  
  // 내 단말번호 삭제
  Future<void> deleteMyExtension(String id) async {
    try {
      await _firestore.collection('my_extensions').doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Delete my extension error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 모든 내 단말번호 삭제
  Future<void> deleteAllMyExtensions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('my_extensions')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Delete all my extensions error: $e');
      }
      rethrow;
    }
  }
  
  // 내 단말번호 업데이트 (API 설정 등)
  Future<void> updateMyExtension(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('my_extensions').doc(id).update(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update my extension error: $e');
      }
      rethrow;
    }
  }
  
  // 내 단말번호 API 설정 업데이트
  Future<void> updateMyExtensionApiConfig({
    required String id,
    required String apiBaseUrl,
    required String companyId,
    required String appKey,
    required int apiHttpPort,
    required int apiHttpsPort,
  }) async {
    try {
      await _firestore.collection('my_extensions').doc(id).update({
        'apiBaseUrl': apiBaseUrl,
        'companyId': companyId,
        'appKey': appKey,
        'apiHttpPort': apiHttpPort,
        'apiHttpsPort': apiHttpsPort,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update my extension API config error: $e');
      }
      rethrow;
    }
  }
  
  // ===== Phonebook 관리 =====
  
  // Phonebook 추가 또는 업데이트
  Future<String> addOrUpdatePhonebook(PhonebookModel phonebook) async {
    try {
      // 동일한 phonebookId가 있는지 확인
      final snapshot = await _firestore
          .collection('phonebooks')
          .where('userId', isEqualTo: phonebook.userId)
          .where('phonebookId', isEqualTo: phonebook.phonebookId)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        // 기존 문서 업데이트
        final docId = snapshot.docs.first.id;
        await _firestore.collection('phonebooks').doc(docId).update(phonebook.toFirestore());
        if (kDebugMode) {
          debugPrint('✅ Updated existing phonebook: ${phonebook.name}');
        }
        return docId;
      } else {
        // 새 문서 추가
        final docRef = await _firestore.collection('phonebooks').add(phonebook.toFirestore());
        if (kDebugMode) {
          debugPrint('✅ Added new phonebook: ${phonebook.name}');
        }
        return docRef.id;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Add/Update phonebook error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 Phonebook 목록 조회
  Stream<List<PhonebookModel>> getUserPhonebooks(String userId) {
    return _firestore
        .collection('phonebooks')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhonebookModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }
  
  // Phonebook 연락처 추가 또는 업데이트
  Future<String> addOrUpdatePhonebookContact(PhonebookContactModel contact) async {
    try {
      // 동일한 telephone 값이 있는지 먼저 확인 (우선순위 1)
      final telephoneSnapshot = await _firestore
          .collection('phonebook_contacts')
          .where('userId', isEqualTo: contact.userId)
          .where('phonebookId', isEqualTo: contact.phonebookId)
          .where('telephone', isEqualTo: contact.telephone)
          .get();
      
      if (telephoneSnapshot.docs.isNotEmpty) {
        // 동일한 전화번호가 있으면 업데이트 (즐겨찾기 상태 보존)
        final docId = telephoneSnapshot.docs.first.id;
        final existingData = telephoneSnapshot.docs.first.data();
        final existingIsFavorite = existingData['isFavorite'] as bool? ?? false;
        
        // 기존 즐겨찾기 상태를 유지하면서 다른 데이터 업데이트
        final updatedData = contact.toFirestore();
        updatedData['isFavorite'] = existingIsFavorite; // 즐겨찾기 상태 보존
        
        await _firestore.collection('phonebook_contacts').doc(docId).update(updatedData);
        
        if (kDebugMode) {
          debugPrint('✅ Updated existing contact by telephone: ${contact.telephone} (isFavorite: $existingIsFavorite preserved)');
        }
        
        return docId;
      }
      
      // telephone로 찾지 못했으면 contactId로 확인 (우선순위 2)
      final contactIdSnapshot = await _firestore
          .collection('phonebook_contacts')
          .where('userId', isEqualTo: contact.userId)
          .where('phonebookId', isEqualTo: contact.phonebookId)
          .where('contactId', isEqualTo: contact.contactId)
          .get();
      
      if (contactIdSnapshot.docs.isNotEmpty) {
        // contactId로 찾았으면 업데이트 (즐겨찾기 상태 보존)
        final docId = contactIdSnapshot.docs.first.id;
        final existingData = contactIdSnapshot.docs.first.data();
        final existingIsFavorite = existingData['isFavorite'] as bool? ?? false;
        
        // 기존 즐겨찾기 상태를 유지하면서 다른 데이터 업데이트
        final updatedData = contact.toFirestore();
        updatedData['isFavorite'] = existingIsFavorite; // 즐겨찾기 상태 보존
        
        await _firestore.collection('phonebook_contacts').doc(docId).update(updatedData);
        
        if (kDebugMode) {
          debugPrint('✅ Updated existing contact by contactId: ${contact.contactId} (isFavorite: $existingIsFavorite preserved)');
        }
        
        return docId;
      }
      
      // 새 문서 추가 (telephone, contactId 모두 없는 경우)
      final docRef = await _firestore.collection('phonebook_contacts').add(contact.toFirestore());
      
      if (kDebugMode) {
        debugPrint('✅ Added new contact: ${contact.name} (${contact.telephone})');
      }
      
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Add/Update phonebook contact error: $e');
      }
      rethrow;
    }
  }
  
  // 특정 Phonebook의 연락처 목록 조회
  Stream<List<PhonebookContactModel>> getPhonebookContacts(String userId, String phonebookId) {
    return _firestore
        .collection('phonebook_contacts')
        .where('userId', isEqualTo: userId)
        .where('phonebookId', isEqualTo: phonebookId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhonebookContactModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }
  
  // 사용자의 모든 Phonebook 연락처 조회
  Stream<List<PhonebookContactModel>> getAllPhonebookContacts(String userId) {
    return _firestore
        .collection('phonebook_contacts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhonebookContactModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }
  
  // Phonebook 연락처 즐겨찾기 토글
  Future<void> togglePhonebookContactFavorite(String contactDocId, bool currentFavoriteState) async {
    try {
      await _firestore.collection('phonebook_contacts').doc(contactDocId).update({
        'isFavorite': !currentFavoriteState,
      });
      if (kDebugMode) {
        debugPrint('✅ Favorite toggled: $contactDocId -> ${!currentFavoriteState}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Toggle favorite error: $e');
      }
      rethrow;
    }
  }
  
  // Phonebook 즐겨찾기 연락처만 조회
  Stream<List<PhonebookContactModel>> getFavoritePhonebookContacts(String userId) {
    return _firestore
        .collection('phonebook_contacts')
        .where('userId', isEqualTo: userId)
        .where('isFavorite', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final contacts = snapshot.docs
              .map((doc) => PhonebookContactModel.fromFirestore(doc.data(), doc.id))
              .toList();
          // 메모리에서 이름으로 정렬
          contacts.sort((a, b) => a.name.compareTo(b.name));
          return contacts;
        });
  }

  // ===== 착신전환 정보 관리 =====

  // 착신전환 정보 조회 (실시간 스트림)
  Stream<CallForwardInfoModel?> getCallForwardInfo(String userId, String extensionNumber) {
    final docId = '${userId}_$extensionNumber';
    return _firestore
        .collection('call_forward_info')
        .doc(docId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return CallForwardInfoModel.fromFirestore(doc);
          }
          return null;
        });
  }

  // 착신전환 정보 저장/업데이트
  Future<void> saveCallForwardInfo(CallForwardInfoModel info) async {
    try {
      final docId = '${info.userId}_${info.extensionNumber}';
      await _firestore
          .collection('call_forward_info')
          .doc(docId)
          .set(info.toFirestore(), SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ Call forward info saved: $docId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Save call forward info error: $e');
      }
      rethrow;
    }
  }

  // 착신전환 활성화 상태 업데이트
  Future<void> updateCallForwardEnabled(
    String userId,
    String extensionNumber,
    bool isEnabled,
  ) async {
    try {
      final docId = '${userId}_$extensionNumber';
      await _firestore.collection('call_forward_info').doc(docId).set({
        'userId': userId,
        'extensionNumber': extensionNumber,
        'isEnabled': isEnabled,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ Call forward enabled updated: $docId -> $isEnabled');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Update call forward enabled error: $e');
      }
      rethrow;
    }
  }

  // 착신번호 업데이트
  Future<void> updateCallForwardDestination(
    String userId,
    String extensionNumber,
    String destinationNumber,
  ) async {
    try {
      final docId = '${userId}_$extensionNumber';
      await _firestore.collection('call_forward_info').doc(docId).set({
        'userId': userId,
        'extensionNumber': extensionNumber,
        'destinationNumber': destinationNumber,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ Call forward destination updated: $docId -> $destinationNumber');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Update call forward destination error: $e');
      }
      rethrow;
    }
  }

  // 착신전환 정보 삭제
  Future<void> deleteCallForwardInfo(String userId, String extensionNumber) async {
    try {
      final docId = '${userId}_$extensionNumber';
      await _firestore.collection('call_forward_info').doc(docId).delete();
      
      if (kDebugMode) {
        debugPrint('✅ Call forward info deleted: $docId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Delete call forward info error: $e');
      }
      rethrow;
    }
  }
}
