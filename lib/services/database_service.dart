import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/main_number_model.dart';
import '../models/extension_model.dart';
import '../models/call_history_model.dart';
import '../models/contact_model.dart';

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
}
