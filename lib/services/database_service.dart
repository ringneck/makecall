import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/main_number_model.dart';
import '../models/extension_model.dart';
import '../models/call_history_model.dart';
import '../models/contact_model.dart';
import '../models/my_extension_model.dart';
import '../models/phonebook_model.dart';

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
      // 동일한 contactId가 있는지 확인
      final snapshot = await _firestore
          .collection('phonebook_contacts')
          .where('userId', isEqualTo: contact.userId)
          .where('phonebookId', isEqualTo: contact.phonebookId)
          .where('contactId', isEqualTo: contact.contactId)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        // 기존 문서 업데이트
        final docId = snapshot.docs.first.id;
        await _firestore.collection('phonebook_contacts').doc(docId).update(contact.toFirestore());
        return docId;
      } else {
        // 새 문서 추가
        final docRef = await _firestore.collection('phonebook_contacts').add(contact.toFirestore());
        return docRef.id;
      }
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
}
