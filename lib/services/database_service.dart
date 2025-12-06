import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/main_number_model.dart';
import '../models/extension_model.dart';
import '../models/call_history_model.dart';
import '../models/contact_model.dart';
import '../models/my_extension_model.dart';
import '../models/phonebook_model.dart';
import '../models/call_forward_info_model.dart';
import '../models/user_model.dart';
import '../models/fcm_token_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// 🛡️ Stream 에러 핸들러: 로그아웃 시 Permission Denied 에러를 조용히 무시
  Stream<T> _handleStreamErrors<T>(Stream<T> stream) {
    return stream.handleError((error) {
      // Permission denied 에러는 조용히 무시 (로그아웃 시 정상)
      final errorString = error.toString();
      if (errorString.contains('PERMISSION_DENIED') || 
          errorString.contains('Missing or insufficient permissions')) {
        if (kDebugMode) {
          debugPrint('🔒 [DB-STREAM] Permission denied (logged out) - ignoring');
        }
        // 에러를 조용히 무시하고 전파하지 않음
        return;
      }
      
      // 다른 예상치 못한 에러는 로그 출력 후 rethrow
      if (kDebugMode) {
        debugPrint('❌ [DB-STREAM] Unexpected error: $error');
      }
      throw error;
    });
  }
  
  /// 🔐 Auth-safe Stream Wrapper: Firebase Auth 상태가 준비될 때까지 대기
  /// 
  /// 재로그인 시나리오에서 authStateChanges와 Firestore Stream을 동기화하여
  /// Permission Denied 오류를 근본적으로 방지합니다.
  /// 
  /// **작동 원리:**
  /// 1. Firebase Auth의 authStateChanges를 감지
  /// 2. 사용자가 인증된 상태인지 확인
  /// 3. 인증이 완료된 후에만 Firestore 쿼리 시작
  /// 4. 로그아웃 시 빈 스트림 반환
  Stream<T> _authSafeStream<T>(
    String userId,
    Stream<T> Function() createStream, {
    T? emptyValue,
  }) {
    // 🔒 CRITICAL: Firebase Auth 상태 변화를 감지하여 동기화
    return _auth.authStateChanges().asyncExpand((user) {
      // 로그아웃 상태이거나 userId 불일치 시 빈 스트림 반환
      if (user == null || user.uid != userId) {
        if (kDebugMode) {
          debugPrint('🔒 [AUTH-SAFE-STREAM] Not authenticated or userId mismatch - returning empty');
        }
        return emptyValue != null 
            ? Stream.value(emptyValue)
            : Stream.empty();
      }
      
      // 인증 완료 - Firestore 스트림 시작
      if (kDebugMode) {
        debugPrint('✅ [AUTH-SAFE-STREAM] Authenticated - starting Firestore stream');
      }
      return _handleStreamErrors(createStream());
    });
  }
  
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
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [DatabaseService] 통화 기록 저장 실패: $e');
      rethrow;
    }
  }
  
  // 사용자의 통화 기록 조회
  Stream<List<CallHistoryModel>> getUserCallHistory(String userId, {int limit = 50}) {
    // 🔒 로그아웃 체크: userId가 비어있거나 null이면 빈 Stream 반환
    if (userId.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ [DB] getUserCallHistory: userId empty, returning empty stream');
      }
      return Stream.value([]);
    }
    
    // 🔐 Auth-safe Stream: authStateChanges와 동기화
    return _authSafeStream<List<CallHistoryModel>>(
      userId,
      () => _firestore
          .collection('call_history')
          .where('userId', isEqualTo: userId)
          .snapshots(includeMetadataChanges: true)
          .handleError((error) {
            // Permission denied 에러 시 빈 리스트 반환
            if (kDebugMode) {
              debugPrint('⚠️ [DB] getUserCallHistory error: $error');
            }
            return <CallHistoryModel>[];
          })
          .map((snapshot) {
            final history = snapshot.docs
                .map((doc) => CallHistoryModel.fromMap(doc.data(), doc.id))
                .toList();
            // 메모리에서 통화 시간으로 정렬 (최신순, 복합 인덱스 불필요)
            history.sort((a, b) => b.callTime.compareTo(a.callTime));
            // limit 적용
            return history.take(limit).toList();
          }),
      emptyValue: <CallHistoryModel>[], // 인증 실패 시 빈 리스트 반환
    );
  }
  
  // ===== 연락처 관리 =====
  
  // 연락처 추가
  /// 🔒 고급 개발자 패턴: 전화번호 정규화 및 중복 체크
  /// 전화번호에서 하이픈, 공백, 괄호 등을 제거하여 순수 숫자만 추출
  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
  }
  
  /// 🔍 전화번호 중복 체크 (정규화된 번호로 비교)
  /// 반환: {isDuplicate: bool, existingContact: ContactModel?}
  Future<Map<String, dynamic>> checkPhoneNumberDuplicate(String userId, String phoneNumber, {String? excludeContactId}) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      
      // 모든 사용자 연락처 가져오기
      final snapshot = await _firestore
          .collection('contacts')
          .where('userId', isEqualTo: userId)
          .get();
      
      // 정규화된 번호로 비교
      for (final doc in snapshot.docs) {
        // 수정 시 자기 자신은 제외
        if (excludeContactId != null && doc.id == excludeContactId) {
          continue;
        }
        
        final existingPhone = doc.data()['phoneNumber'] as String?;
        if (existingPhone != null) {
          final normalizedExisting = _normalizePhoneNumber(existingPhone);
          if (normalizedExisting == normalizedPhone) {
            return {
              'isDuplicate': true,
              'existingContact': ContactModel.fromMap(doc.data(), doc.id),
            };
          }
        }
      }
      
      return {'isDuplicate': false, 'existingContact': null};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Phone number duplicate check error: $e');
      }
      return {'isDuplicate': false, 'existingContact': null};
    }
  }

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
    // 🔒 로그아웃 체크
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    
    return _handleStreamErrors(
      _firestore
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
          }),
    );
  }
  
  // 즐겨찾기 연락처 조회
  Stream<List<ContactModel>> getFavoriteContacts(String userId) {
    // 🔒 로그아웃 체크
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    
    // 🔐 Auth-safe Stream: authStateChanges와 동기화
    return _authSafeStream<List<ContactModel>>(
      userId,
      () => _firestore
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
          }),
      emptyValue: <ContactModel>[], // 인증 실패 시 빈 리스트
    );
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
  
  /// 이벤트 기반 업데이트: Firestore 변경 완료 대기
  Future<void> updateContactAndWaitForSync(
    String id, 
    Map<String, dynamic> data,
  ) async {
    final docRef = _firestore.collection('contacts').doc(id);
    final completer = Completer<void>();
    StreamSubscription? subscription;
    
    try {
      subscription = docRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) return;
        
        final docData = snapshot.data();
        if (docData == null) return;
        
        bool allFieldsMatch = true;
        for (final entry in data.entries) {
          if (docData[entry.key] != entry.value) {
            allFieldsMatch = false;
            break;
          }
        }
        
        if (allFieldsMatch && !completer.isCompleted) {
          completer.complete();
        }
      });
      
      await docRef.update(data);
      
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Update contact with sync error: $e');
      }
      rethrow;
    } finally {
      await subscription?.cancel();
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
    // 🔒 로그아웃 체크
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    
    // 🔐 Auth-safe Stream: authStateChanges와 동기화
    return _authSafeStream<List<MyExtensionModel>>(
      userId,
      () => _firestore
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
          }),
      emptyValue: <MyExtensionModel>[], // 인증 실패 시 빈 리스트
    );
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
  
  // 사용자의 등록된 단말번호 목록 가져오기 (전화번호만)
  Future<List<String>> getMyExtensionNumbers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('my_extensions')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs
          .map((doc) => doc.data()['extension'] as String? ?? '')
          .where((ext) => ext.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get my extension numbers error: $e');
      }
      return [];
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
  
  // 사용자의 모든 Phonebook 데이터 삭제 (새로고침 시 사용)
  Future<void> deleteAllPhonebookData(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🗑️ 기존 Phonebook 데이터 삭제 시작...');
      }
      
      // 1. phonebook_contacts 컬렉션에서 사용자의 모든 연락처 삭제
      final contactsSnapshot = await _firestore
          .collection('phonebook_contacts')
          .where('userId', isEqualTo: userId)
          .get();
      
      int contactsDeleted = 0;
      for (var doc in contactsSnapshot.docs) {
        await doc.reference.delete();
        contactsDeleted++;
      }
      
      if (kDebugMode) {
        debugPrint('✅ Phonebook 연락처 ${contactsDeleted}개 삭제 완료');
      }
      
      // 2. phonebooks 컬렉션에서 사용자의 모든 phonebook 삭제
      final phonebooksSnapshot = await _firestore
          .collection('phonebooks')
          .where('userId', isEqualTo: userId)
          .get();
      
      int phonebooksDeleted = 0;
      for (var doc in phonebooksSnapshot.docs) {
        await doc.reference.delete();
        phonebooksDeleted++;
      }
      
      if (kDebugMode) {
        debugPrint('✅ Phonebook ${phonebooksDeleted}개 삭제 완료');
        debugPrint('✅ 총 ${contactsDeleted}개 연락처, ${phonebooksDeleted}개 phonebook 삭제됨');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Delete all phonebook data error: $e');
      }
      rethrow;
    }
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
    return _handleStreamErrors(
      _firestore
          .collection('phonebook_contacts')
          .where('userId', isEqualTo: userId)
          .where('phonebookId', isEqualTo: phonebookId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => PhonebookContactModel.fromFirestore(doc.data(), doc.id))
              .toList()),
    );
  }
  
  // 사용자의 모든 Phonebook 연락처 조회
  Stream<List<PhonebookContactModel>> getAllPhonebookContacts(String userId) {
    // 🔒 로그아웃 체크
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    
    return _handleStreamErrors(
      _firestore
          .collection('phonebook_contacts')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => PhonebookContactModel.fromFirestore(doc.data(), doc.id))
              .toList()),
    );
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
  
  /// 🔥 이벤트 기반 Phonebook 즐겨찾기 토글: Firestore 변경 완료 대기
  Future<void> togglePhonebookContactFavoriteAndWaitForSync(
    String contactDocId, 
    bool currentFavoriteState,
  ) async {
    final docRef = _firestore.collection('phonebook_contacts').doc(contactDocId);
    final newFavoriteState = !currentFavoriteState;
    final completer = Completer<void>();
    StreamSubscription? subscription;
    
    try {
      // 1. 변경 감지 리스너 설정
      subscription = docRef.snapshots().listen((snapshot) {
        if (!snapshot.exists) return;
        
        final isFavorite = snapshot.data()?['isFavorite'] as bool?;
        if (isFavorite == newFavoriteState && !completer.isCompleted) {
          completer.complete();
        }
      });
      
      // 2. 업데이트 실행
      await docRef.update({'isFavorite': newFavoriteState});
      
      // 3. 변경 완료 대기 (최대 2초)
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Toggle phonebook favorite with sync error: $e');
      }
      rethrow;
    } finally {
      await subscription?.cancel();
    }
  }
  
  // Phonebook 즐겨찾기 연락처만 조회
  Stream<List<PhonebookContactModel>> getFavoritePhonebookContacts(String userId) {
    // 🔒 로그아웃 체크
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    
    // 🔐 Auth-safe Stream: authStateChanges와 동기화
    return _authSafeStream<List<PhonebookContactModel>>(
      userId,
      () => _firestore
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
          }),
      emptyValue: <PhonebookContactModel>[], // 인증 실패 시 빈 리스트
    );
  }

  // ===== 등록된 단말번호 관리 (중복 방지) =====
  
  // 단말번호가 이미 다른 사용자에 의해 등록되었는지 확인
  Future<Map<String, dynamic>?> checkExtensionRegistration(String extension) async {
    try {
      final doc = await _firestore
          .collection('registered_extensions')
          .doc(extension)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        if (kDebugMode) {
          debugPrint('📱 단말번호 "$extension" 이미 등록됨: ${data['userEmail']} (${data['userName']})');
        }
        return data;
      }
      
      if (kDebugMode) {
        debugPrint('✅ 단말번호 "$extension" 사용 가능');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Check extension registration error: $e');
      }
      rethrow;
    }
  }
  
  // 단말번호 등록 (registered_extensions 컬렉션에 추가)
  Future<void> registerExtension({
    required String extension,
    required String userId,
    required String userEmail,
    String? userName,
  }) async {
    try {
      await _firestore
          .collection('registered_extensions')
          .doc(extension)
          .set({
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName ?? '',
        'registeredAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ 단말번호 "$extension" 등록 완료: $userEmail');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Register extension error: $e');
      }
      rethrow;
    }
  }
  
  // 단말번호 등록 해제 (registered_extensions 컬렉션에서 삭제)
  Future<void> unregisterExtension(String extension) async {
    try {
      await _firestore
          .collection('registered_extensions')
          .doc(extension)
          .delete();
      
      if (kDebugMode) {
        debugPrint('✅ 단말번호 "$extension" 등록 해제 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Unregister extension error: $e');
      }
      rethrow;
    }
  }
  
  // 사용자의 모든 등록된 단말번호 조회
  Future<List<String>> getUserRegisteredExtensions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('registered_extensions')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Get user registered extensions error: $e');
      }
      rethrow;
    }
  }

  // 모든 사용자의 등록된 단말번호 가져오기 (registered_extensions 컬렉션 전체)
  Future<List<String>> getAllRegisteredExtensions() async {
    try {
      final snapshot = await _firestore
          .collection('registered_extensions')
          .get();
      
      final extensions = snapshot.docs.map((doc) => doc.id).toList();
      
      if (kDebugMode) {
        debugPrint('📱 전체 등록된 단말번호: ${extensions.length}개');
      }
      
      return extensions;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Get all registered extensions error: $e');
      }
      rethrow;
    }
  }

  // 사용자 문서 조회 (users 컬렉션)
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Get user by id error: $e');
      }
      return null;
    }
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

  // 🔥 착신전환 정보 직접 조회 (Stream이 아닌 Future 반환)
  Future<CallForwardInfoModel?> getCallForwardInfoOnce(String userId, String extensionNumber) async {
    try {
      final docId = '${userId}_$extensionNumber';
      
      final doc = await _firestore
          .collection('call_forward_info')
          .doc(docId)
          .get();
      
      if (doc.exists) {
        final model = CallForwardInfoModel.fromFirestore(doc);
        return model;
      }
      
      return null;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [DatabaseService] Get call forward info error: $e');
      return null;
    }
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

  // ===== FCM 토큰 관리 (중복 로그인 방지) =====

  /// FCM 토큰 저장 또는 업데이트
  /// 
  /// 사용자의 FCM 토큰을 저장합니다. 동일한 userId를 가진 기존 토큰이 있으면
  /// isActive를 false로 설정하여 무효화합니다.
  /// 
  /// @param tokenModel FCM 토큰 모델
  /// @return 저장된 문서 ID
  Future<String> saveFcmToken(FcmTokenModel tokenModel) async {
    try {
      // ignore: avoid_print
      print('🔐 [DatabaseService] FCM 토큰 저장 시작');
      // ignore: avoid_print
      print('   userId: ${tokenModel.userId}');
      // ignore: avoid_print
      print('   deviceId: ${tokenModel.deviceId}');
      // ignore: avoid_print
      print('   platform: ${tokenModel.platform}');

      // 1. 다중 기기 로그인 허용 - 동일 기기+플랫폼의 기존 토큰만 확인
      // ignore: avoid_print
      print('   🔄 [다중 기기 지원] 동일 기기+플랫폼의 토큰만 업데이트');
      
      final sameDeviceDoc = await _firestore
          .collection('fcm_tokens')
          .doc('${tokenModel.userId}_${tokenModel.deviceId}_${tokenModel.platform}')
          .get();

      if (sameDeviceDoc.exists) {
        // ignore: avoid_print
        print('   ℹ️ 동일 기기 토큰 갱신');
      } else {
        // ignore: avoid_print
        print('   ℹ️ 새 기기 토큰 추가 (중복 로그인 허용)');
      }

      // 2. 새 토큰 저장 (deviceId + platform을 문서 ID로 사용하여 중복 방지)
      // 🔑 CRITICAL: Platform 포함으로 iOS/Android 기기 구분
      final docRef = _firestore
          .collection('fcm_tokens')
          .doc('${tokenModel.userId}_${tokenModel.deviceId}_${tokenModel.platform}');

      // 🔍 CRITICAL: 저장할 데이터 확인
      final dataToSave = tokenModel.toMap();
      // ignore: avoid_print
      print('🔍 [DatabaseService] 저장할 데이터:');
      // ignore: avoid_print
      print('   - isApproved: ${dataToSave['isApproved']}');
      // ignore: avoid_print
      print('   - isActive: ${dataToSave['isActive']}');
      // ignore: avoid_print
      print('   - fcmToken: ${dataToSave['fcmToken']?.substring(0, 20)}...');
      
      await docRef.set(dataToSave);

      // 🔍 CRITICAL: 저장 후 문서 재확인
      final savedDoc = await docRef.get();
      if (savedDoc.exists) {
        final savedData = savedDoc.data();
        // ignore: avoid_print
        print('✅ [DatabaseService] Firestore 저장 후 확인:');
        // ignore: avoid_print
        print('   - isApproved: ${savedData?['isApproved']}');
        // ignore: avoid_print
        print('   - isActive: ${savedData?['isActive']}');
      }

      // ignore: avoid_print
      print('✅ [DatabaseService] FCM 토큰 저장 완료 (문서 ID: ${docRef.id})');

      return docRef.id;
    } catch (e) {
      // ignore: avoid_print
      print('❌ [DatabaseService] FCM 토큰 저장 실패: $e');
      rethrow;
    }
  }

  /// 사용자의 활성 FCM 토큰 조회
  /// 
  /// @param userId 사용자 ID
  /// @return 활성 FCM 토큰 모델 (없으면 null)
  Future<FcmTokenModel?> getActiveFcmToken(String userId) async {
    try {
      // ignore: avoid_print
      print('🔍 [DatabaseService] 활성 FCM 토큰 조회');
      // ignore: avoid_print
      print('   userId: $userId');

      final querySnapshot = await _firestore
          .collection('fcm_tokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // ignore: avoid_print
        print('   ⚠️  활성 FCM 토큰 없음');
        return null;
      }

      final tokenModel = FcmTokenModel.fromFirestore(querySnapshot.docs.first);
      // ignore: avoid_print
      print('   ✅ 활성 FCM 토큰 발견: ${tokenModel.deviceName}');

      return tokenModel;
    } catch (e) {
      // ignore: avoid_print
      print('❌ [DatabaseService] FCM 토큰 조회 실패: $e');
      return null;
    }
  }

  /// 사용자의 모든 활성 FCM 토큰 조회 (다중 기기 지원)
  /// 
  /// @param userId 사용자 ID
  /// @return 활성 FCM 토큰 모델 리스트
  Future<List<FcmTokenModel>> getAllActiveFcmTokens(String userId) async {
    try {
      // ignore: avoid_print
      print('🔍 [DatabaseService] 모든 활성 FCM 토큰 조회');
      // ignore: avoid_print
      print('   userId: $userId');

      final querySnapshot = await _firestore
          .collection('fcm_tokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          // 🔧 FIX: isApproved 조건 제거 - 승인 여부와 관계없이 활성 기기 모두 조회
          // ✅ 최대 기기 수 체크 시 승인 대기 중인 기기도 포함해야 함
          .get();

      if (querySnapshot.docs.isEmpty) {
        // ignore: avoid_print
        print('   ⚠️  활성 FCM 토큰 없음');
        return [];
      }

      final tokens = querySnapshot.docs
          .map((doc) => FcmTokenModel.fromFirestore(doc))
          .toList();
      
      // ignore: avoid_print
      print('   ✅ 활성 FCM 토큰 ${tokens.length}개 발견');
      for (var token in tokens) {
        // ignore: avoid_print
        print('      - ${token.deviceName} (${token.platform})');
      }

      return tokens;
    } catch (e) {
      // ignore: avoid_print
      print('❌ [DatabaseService] 모든 FCM 토큰 조회 실패: $e');
      return [];
    }
  }

  /// 특정 기기의 FCM 토큰 조회
  /// 
  /// @param userId 사용자 ID
  /// @param deviceId 기기 ID
  /// @return FCM 토큰 모델 (없으면 null)
  Future<FcmTokenModel?> getFcmTokenByDevice(String userId, String deviceId) async {
    try {
      final docId = '${userId}_$deviceId';
      final doc = await _firestore
          .collection('fcm_tokens')
          .doc(docId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return FcmTokenModel.fromFirestore(doc);
    } catch (e) {
      // ignore: avoid_print
      print('❌ [DatabaseService] 기기별 FCM 토큰 조회 실패: $e');
      return null;
    }
  }

  /// FCM 토큰 삭제 (로그아웃 시 사용)
  /// 
  /// ⚠️ 중요: 이 메서드는 오직 fcm_tokens 컬렉션만 삭제합니다!
  /// ✅ users/{userId} 컬렉션은 절대 삭제하지 않습니다.
  /// ✅ my_extensions, call_forward_info 등 모든 사용자 데이터는 보존됩니다.
  /// 
  /// @param userId 사용자 ID
  /// @param deviceId 기기 ID
  /// FCM 토큰 비활성화 (현재 기기만)
  /// 
  /// 로그아웃 시 현재 기기의 토큰만 비활성화합니다.
  /// 다른 기기의 토큰은 영향받지 않습니다.
  /// 
  /// @param userId 사용자 ID
  /// @param deviceId 기기 ID
  /// @param platform 플랫폼 (iOS, Android 등)
  Future<void> deactivateFcmToken(String userId, String deviceId, String platform) async {
    try {
      // ignore: avoid_print
      print('🔓 [DatabaseService] FCM 토큰 비활성화 시작');
      // ignore: avoid_print
      print('   userId: $userId');
      // ignore: avoid_print
      print('   deviceId: $deviceId');
      // ignore: avoid_print
      print('   platform: $platform');
      // ignore: avoid_print
      print('   🎯 현재 기기+플랫폼만 비활성화 (다른 기기는 계속 활성)');

      // 🔑 CRITICAL: Platform 포함으로 iOS/Android 기기 구분
      final docId = '${userId}_${deviceId}_$platform';
      
      // 🔧 FIX: 삭제가 아니라 isActive를 false로 변경
      await _firestore.collection('fcm_tokens').doc(docId).update({
        'isActive': false,
        'deactivatedAt': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('✅ [DatabaseService] FCM 토큰 비활성화 완료');
      // ignore: avoid_print
      print('   📱 현재 기기: 비활성화됨 (isActive: false)');
      // ignore: avoid_print
      print('   📱 다른 기기: 영향 없음 (계속 활성 유지)');
      // ignore: avoid_print
      print('   🔒 보존된 데이터:');
      // ignore: avoid_print
      print('      - users/{userId}: API/WebSocket 설정, 회사 정보');
      // ignore: avoid_print
      print('      - my_extensions: 단말번호 정보');
      // ignore: avoid_print
      print('      - call_forward_info: 착신전환 설정');
      // ignore: avoid_print
      print('   ✅ 재로그인 시 모든 데이터가 정상 로드됩니다');
    } catch (e) {
      // 🔧 문서가 없는 경우 (이미 삭제됨) - 정상으로 처리
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('not-found') || 
          errorString.contains('not_found') ||
          errorString.contains('no document to update')) {
        // ignore: avoid_print
        print('ℹ️  [DatabaseService] FCM 토큰 문서 없음 (이미 삭제되었거나 생성되지 않음)');
        // ignore: avoid_print
        print('   ✅ 정상: 비활성화할 토큰이 없으므로 비활성화 완료로 처리');
        return;
      }
      
      // 다른 에러는 로그 출력 후 rethrow
      // ignore: avoid_print
      print('❌ [DatabaseService] FCM 토큰 비활성화 실패: $e');
      rethrow;
    }
  }

  Future<void> deleteFcmToken(String userId, String deviceId, String platform) async {
    try {
      // ignore: avoid_print
      print('🗑️  [DatabaseService] FCM 토큰 삭제 시작');
      // ignore: avoid_print
      print('   userId: $userId');
      // ignore: avoid_print
      print('   deviceId: $deviceId');
      // ignore: avoid_print
      print('   platform: $platform');
      // ignore: avoid_print
      print('   ⚠️  삭제 범위: fcm_tokens 컬렉션만 (단일 문서)');

      // 🔑 CRITICAL: Platform 포함으로 iOS/Android 기기 구분
      final docId = '${userId}_${deviceId}_$platform';
      await _firestore.collection('fcm_tokens').doc(docId).delete();

      // ignore: avoid_print
      print('✅ [DatabaseService] FCM 토큰 삭제 완료');
      // ignore: avoid_print
      print('   🔒 보존된 데이터:');
      // ignore: avoid_print
      print('      - users/{userId}: API/WebSocket 설정, 회사 정보');
      // ignore: avoid_print
      print('      - my_extensions: 단말번호 정보');
      // ignore: avoid_print
      print('      - call_forward_info: 착신전환 설정');
      // ignore: avoid_print
      print('   ✅ 재로그인 시 모든 데이터가 정상 로드됩니다');
    } catch (e) {
      // ignore: avoid_print
      print('❌ [DatabaseService] FCM 토큰 삭제 실패: $e');
      rethrow;
    }
  }

  /// FCM 토큰 마지막 활동 시간 업데이트
  /// 
  /// @param userId 사용자 ID
  /// @param deviceId 기기 ID
  /// @param platform 플랫폼 (ios, android, web)
  Future<void> updateFcmTokenActivity(String userId, String deviceId, String platform) async {
    try {
      // 🔑 CRITICAL: Platform 포함으로 iOS/Android 기기 구분
      final docId = '${userId}_${deviceId}_$platform';
      await _firestore.collection('fcm_tokens').doc(docId).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // 에러 무시 (중요하지 않은 작업)
      if (kDebugMode) {
        debugPrint('⚠️  FCM 토큰 활동 시간 업데이트 실패: $e');
      }
    }
  }

  /// 현재 기기의 승인 상태 조회
  /// 
  /// @param userId 사용자 ID
  /// @param deviceId 기기 ID
  /// @param platform 플랫폼 (iOS, Android)
  /// @return 승인 여부 (true: 승인됨, false: 미승인 또는 토큰 없음)
  Future<bool> isCurrentDeviceApproved(String userId, String deviceId, String platform) async {
    try {
      // 🔑 CRITICAL: Platform 포함으로 iOS/Android 기기 구분
      final docId = '${userId}_${deviceId}_$platform';
      
      if (kDebugMode) {
        debugPrint('🔍 [DB] 승인 상태 조회 시작');
        debugPrint('   - userId: $userId');
        debugPrint('   - deviceId: $deviceId');
        debugPrint('   - platform: $platform');
        debugPrint('   - 문서 ID: $docId');
      }
      
      final tokenDoc = await _firestore
          .collection('fcm_tokens')
          .doc(docId)
          .get();
      
      if (!tokenDoc.exists) {
        // 토큰 없음 - 미승인으로 처리
        if (kDebugMode) {
          debugPrint('⚠️ [DB] fcm_tokens 문서 없음 - 미승인으로 처리');
          debugPrint('   📝 찾으려고 한 문서 ID: $docId');
          
          // 🔍 디버깅: 해당 userId의 모든 토큰 조회
          debugPrint('🔍 [DB] 디버깅: 해당 사용자의 모든 fcm_tokens 조회 중...');
          final allTokens = await _firestore
              .collection('fcm_tokens')
              .where('userId', isEqualTo: userId)
              .get();
          
          if (allTokens.docs.isEmpty) {
            debugPrint('   ❌ 해당 사용자의 fcm_tokens 문서가 하나도 없음!');
          } else {
            debugPrint('   📋 발견된 문서 ${allTokens.docs.length}개:');
            for (var doc in allTokens.docs) {
              debugPrint('      - 문서 ID: ${doc.id}');
              final data = doc.data();
              debugPrint('        deviceId: ${data['deviceId']}');
              debugPrint('        platform: ${data['platform']}');
              debugPrint('        isApproved: ${data['isApproved']}');
            }
          }
        }
        return false;
      }
      
      final data = tokenDoc.data();
      if (data == null) {
        return false;
      }
      
      // isApproved 필드 확인 (기본값: true for backward compatibility)
      final isApproved = data['isApproved'] as bool? ?? true;
      
      if (kDebugMode) {
        debugPrint('🔐 [DB] 기기 승인 상태 조회: $isApproved (deviceId: $deviceId, platform: $platform)');
      }
      
      return isApproved;
    } catch (e) {
      // 에러 발생 시 안전하게 미승인으로 처리
      if (kDebugMode) {
        debugPrint('❌ [DB] 승인 상태 조회 실패 - 미승인으로 처리: $e');
      }
      return false;
    }
  }

  /// 사용자의 모든 FCM 토큰 조회 (관리 목적)
  /// 
  /// @param userId 사용자 ID
  /// @return FCM 토큰 목록
  Future<List<FcmTokenModel>> getAllFcmTokens(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('fcm_tokens')
          .where('userId', isEqualTo: userId)
          .get();

      return querySnapshot.docs
          .map((doc) => FcmTokenModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('❌ [DatabaseService] 전체 FCM 토큰 조회 실패: $e');
      return [];
    }
  }

  /// 만료된 FCM 토큰 정리 (주기적으로 실행)
  /// 
  /// @param expiryDays 만료 기준 일수 (기본 30일)
  Future<void> cleanupExpiredFcmTokens({int expiryDays = 30}) async {
    try {
      final expiryDate = DateTime.now().subtract(Duration(days: expiryDays));
      
      final querySnapshot = await _firestore
          .collection('fcm_tokens')
          .where('lastActiveAt', isLessThan: Timestamp.fromDate(expiryDate))
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('✅ 만료된 FCM 토큰 없음');
        }
        return;
      }

      // 배치 삭제
      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (kDebugMode) {
        debugPrint('✅ ${querySnapshot.docs.length}개의 만료된 FCM 토큰 삭제 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCM 토큰 정리 실패: $e');
      }
    }
  }

  /// 🔧 레거시 FCM 토큰 정리 (플랫폼 정보 없는 옛날 토큰 삭제)
  /// 
  /// 문서 ID 형식: userId_deviceId (플랫폼 없음)
  /// 새 형식: userId_deviceId_platform
  /// 
  /// 로그인 시 자동으로 호출되어 오래된 형식의 토큰을 정리합니다.
  Future<void> cleanupLegacyFcmTokens(String userId) async {
    try {
      // ignore: avoid_print
      print('🧹 [DatabaseService] 레거시 FCM 토큰 정리 시작...');
      
      // 해당 사용자의 모든 토큰 조회
      final allTokens = await _firestore
          .collection('fcm_tokens')
          .where('userId', isEqualTo: userId)
          .get();
      
      // 플랫폼 정보가 없는 옛날 형식 필터링
      // 새 형식: userId_deviceId_platform (3개 파트)
      // 옛날 형식: userId_deviceId (2개 파트)
      final legacyTokens = allTokens.docs.where((doc) {
        final docId = doc.id;
        final parts = docId.split('_');
        // 2개 파트면 옛날 형식 (userId_deviceId)
        return parts.length == 2;
      }).toList();
      
      if (legacyTokens.isEmpty) {
        // ignore: avoid_print
        print('✅ [DatabaseService] 정리할 레거시 토큰 없음');
        return;
      }
      
      // ignore: avoid_print
      print('🗑️ [DatabaseService] ${legacyTokens.length}개의 레거시 토큰 삭제 중...');
      
      // 배치 삭제 (최대 500개씩)
      final batch = _firestore.batch();
      int count = 0;
      
      for (var doc in legacyTokens) {
        batch.delete(doc.reference);
        count++;
        
        // ignore: avoid_print
        print('   - 삭제: ${doc.id}');
        
        if (count >= 500) {
          await batch.commit();
          // ignore: avoid_print
          print('   ✅ 500개 배치 삭제 완료');
          count = 0;
        }
      }
      
      // 남은 문서 삭제
      if (count > 0) {
        await batch.commit();
      }
      
      // ignore: avoid_print
      print('✅ [DatabaseService] 레거시 토큰 ${legacyTokens.length}개 정리 완료');
      
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ [DatabaseService] 레거시 토큰 정리 중 오류 (무시): $e');
      // 에러를 던지지 않음 - 로그인은 계속 진행
    }
  }

  /// 사용자 특정 필드 업데이트
  /// 
  /// @param userId 사용자 UID
  /// @param field 업데이트할 필드명
  /// @param value 업데이트할 값
  Future<void> updateUserField(String userId, String field, dynamic value) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({field: value});
      
      if (kDebugMode) {
        debugPrint('✅ [DatabaseService] 사용자 필드 업데이트 완료: $field = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DatabaseService] 사용자 필드 업데이트 실패: $e');
      }
      rethrow;
    }
  }

  /// 🔥 이벤트 기반 연락처 추가 대기
  /// 
  /// 새 연락처가 Firestore에 추가되고 스냅샷에 나타날 때까지 대기
  /// 
  /// @param userId 사용자 ID
  /// @param contactId 추가된 연락처 문서 ID
  Future<void> waitForContactAdded(String userId, String contactId) async {
    final docRef = _firestore.collection('contacts').doc(contactId);
    final completer = Completer<void>();
    StreamSubscription? subscription;
    
    try {
      // 1. 스냅샷 리스너 설정 (문서 존재 확인)
      subscription = docRef.snapshots().listen((snapshot) {
        if (snapshot.exists && !completer.isCompleted) {
          if (kDebugMode) {
            debugPrint('✅ Firestore 신규 연락처 감지 완료: $contactId');
          }
          completer.complete();
        }
      });
      
      // 2. 변경 확인 대기 (최대 2초)
      await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('⚠️ Firestore 신규 연락처 감지 타임아웃 (2초 초과)');
          }
        },
      );
      
    } finally {
      await subscription?.cancel();
    }
  }
  
  // ===== 공유 API 설정 관리 =====
  
  /// 📤 API 설정 내보내기 (isAdmin 사용자 전용)
  /// 조직명과 App-Key로 검색 가능하게 Firestore에 저장
  Future<void> exportApiSettings({
    required String userId,
    required String userEmail,
    required String organizationName,
    required String appKey,
    String? companyName,
    String? companyId,
    String? apiBaseUrl,
    int? apiHttpPort,
    int? apiHttpsPort,
    String? websocketServerUrl,
    int? websocketServerPort,
    bool? websocketUseSSL,
    String? websocketHttpAuthId,
    String? websocketHttpAuthPassword,
    int? amiServerId,
    int? maxExtensions, // 🔧 maxExtensions 추가
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📤 [DB] API 설정 내보내기 시작');
        debugPrint('   조직명: $organizationName');
        debugPrint('   App-Key: $appKey');
        debugPrint('   사용자: $userEmail');
      }
      
      // ⚡ 최적화: 단일 where() + 메모리 필터링 (복합 인덱스 불필요)
      // exportedByUserId로 조회하고 organizationName, appKey는 메모리에서 필터링
      final existingQuery = await _firestore
          .collection('shared_api_settings')
          .where('exportedByUserId', isEqualTo: userId)
          .get();
      
      // 메모리에서 organizationName과 appKey로 필터링
      final existingDocs = existingQuery.docs.where((doc) {
        final data = doc.data();
        return data['organizationName'] == organizationName && 
               data['appKey'] == appKey;
      }).toList();
      
      final now = DateTime.now();
      final settingsData = {
        'organizationName': organizationName,
        'appKey': appKey,
        'companyName': companyName,
        'companyId': companyId,
        'apiBaseUrl': apiBaseUrl,
        'apiHttpPort': apiHttpPort ?? 3500,
        'apiHttpsPort': apiHttpsPort ?? 3501,
        'websocketServerUrl': websocketServerUrl,
        'websocketServerPort': websocketServerPort ?? 6600,
        'websocketUseSSL': websocketUseSSL ?? false,
        'websocketHttpAuthId': websocketHttpAuthId,
        'websocketHttpAuthPassword': websocketHttpAuthPassword,
        'amiServerId': amiServerId ?? 1,
        'maxExtensions': maxExtensions ?? 1, // 🔧 maxExtensions 포함
        'exportedByUserId': userId,
        'exportedByEmail': userEmail,
        'lastUpdatedAt': now.toIso8601String(),
      };
      
      if (existingDocs.isNotEmpty) {
        // 기존 설정 업데이트
        final docId = existingDocs.first.id;
        if (kDebugMode) {
          debugPrint('🔄 [DB] 기존 설정 업데이트: $docId');
        }
        await _firestore
            .collection('shared_api_settings')
            .doc(docId)
            .update(settingsData);
      } else {
        // 새로운 설정 생성
        settingsData['exportedAt'] = now.toIso8601String();
        
        if (kDebugMode) {
          debugPrint('✨ [DB] 새 설정 생성');
        }
        await _firestore
            .collection('shared_api_settings')
            .add(settingsData);
      }
      
      if (kDebugMode) {
        debugPrint('✅ [DB] API 설정 내보내기 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DB] API 설정 내보내기 실패: $e');
      }
      rethrow;
    }
  }
  
  /// 🔍 조직명과 App-Key로 공유 API 설정 조회
  /// 일반 사용자가 조직 설정을 검색할 때 사용
  Future<List<Map<String, dynamic>>> searchSharedApiSettings({
    required String organizationName,
    required String appKey,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 [DB] 공유 API 설정 조회');
        debugPrint('   조직명: $organizationName');
        debugPrint('   App-Key: $appKey');
      }
      
      // ⚡ 최적화: where() 하나만 사용 (인덱스 불필요)
      // organizationName으로만 조회하고 appKey는 메모리에서 필터링
      final querySnapshot = await _firestore
          .collection('shared_api_settings')
          .where('organizationName', isEqualTo: organizationName)
          .get();
      
      // 메모리에서 appKey 필터링
      final filtered = querySnapshot.docs.where((doc) {
        final data = doc.data();
        return data['appKey'] == appKey;
      }).toList();
      
      // Map으로 변환
      final results = filtered.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // lastUpdatedAt 또는 exportedAt으로 정렬
      results.sort((a, b) {
        final aTime = a['lastUpdatedAt'] ?? a['exportedAt'];
        final bTime = b['lastUpdatedAt'] ?? b['exportedAt'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        try {
          final aDate = DateTime.parse(aTime as String);
          final bDate = DateTime.parse(bTime as String);
          return bDate.compareTo(aDate); // 내림차순 (최신순)
        } catch (e) {
          return 0;
        }
      });
      
      if (kDebugMode) {
        debugPrint('✅ [DB] 공유 API 설정 조회 완료');
        debugPrint('   결과 개수: ${results.length}');
      }
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DB] 공유 API 설정 조회 실패: $e');
      }
      rethrow;
    }
  }
  
  /// 🔍 조직명으로만 모든 공유 API 설정 조회 (App-Key 필터 없음)
  /// 일반 사용자가 조직의 모든 등록된 설정을 조회할 때 사용
  Future<List<Map<String, dynamic>>> searchSharedApiSettingsByOrganization({
    required String organizationName,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔍 [DB] 공유 API 설정 조회 시작');
        debugPrint('   조직명: $organizationName');
        // Firebase Auth 상태 확인
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          debugPrint('   ✅ Firebase Auth: 인증됨 (UID: ${currentUser.uid})');
        } else {
          debugPrint('   ⚠️  Firebase Auth: 인증되지 않음');
        }
      }
      
      // ⚡ 단일 where() 사용 (복합 인덱스 불필요)
      final querySnapshot = await _firestore
          .collection('shared_api_settings')
          .where('organizationName', isEqualTo: organizationName)
          .get();
      
      // Map으로 변환
      final results = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // lastUpdatedAt 또는 exportedAt으로 정렬 (최신순)
      results.sort((a, b) {
        final aTime = a['lastUpdatedAt'] ?? a['exportedAt'];
        final bTime = b['lastUpdatedAt'] ?? b['exportedAt'];
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        try {
          final aDate = DateTime.parse(aTime as String);
          final bDate = DateTime.parse(bTime as String);
          return bDate.compareTo(aDate); // 내림차순 (최신순)
        } catch (e) {
          return 0;
        }
      });
      
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DB] 조직명 기반 공유 API 설정 조회 실패: $e');
      }
      rethrow;
    }
  }
  
  /// 🔍 현재 사용자의 기존 내보내기 정보 조회
  /// 내보내기 전에 기존 내보내기 이력이 있는지 확인할 때 사용
  Future<Map<String, dynamic>?> getExistingExportInfo({
    required String userId,
    required String organizationName,
    required String appKey,
  }) async {
    try {
      // ⚡ 최적화: 단일 where() + 메모리 필터링 (복합 인덱스 불필요)
      final querySnapshot = await _firestore
          .collection('shared_api_settings')
          .where('exportedByUserId', isEqualTo: userId)
          .get();
      
      // 메모리에서 organizationName과 appKey로 필터링
      final filtered = querySnapshot.docs.where((doc) {
        final data = doc.data();
        return data['organizationName'] == organizationName && 
               data['appKey'] == appKey;
      }).toList();
      
      if (filtered.isEmpty) {
        return null;
      }
      
      final doc = filtered.first;
      final data = doc.data();
      data['id'] = doc.id;
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DB] 기존 내보내기 정보 조회 실패: $e');
      }
      rethrow;
    }
  }
  
  /// 📥 공유 API 설정을 사용자 계정에 적용
  /// 선택한 공유 설정을 현재 사용자의 users 문서에 저장
  Future<void> importApiSettings({
    required String userId,
    required Map<String, dynamic> sharedSettings,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('📥 [DB] API 설정 가져오기 시작');
        debugPrint('   사용자 ID: $userId');
        debugPrint('   조직명: ${sharedSettings['organizationName']}');
      }
      
      // 🔧 STEP 1: 현재 사용자의 maxExtensions 값 확인
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final currentMaxExtensions = userDoc.data()?['maxExtensions'] as int? ?? 1;
      final newMaxExtensions = sharedSettings['maxExtensions'] as int? ?? 1;
      
      if (kDebugMode) {
        debugPrint('🔍 [DB] maxExtensions 변경 확인:');
        debugPrint('   현재 maxExtensions: $currentMaxExtensions');
        debugPrint('   새로운 maxExtensions: $newMaxExtensions');
      }
      
      // 🔧 STEP 2: maxExtensions가 변경되거나 1로 제한되는 경우 기존 registered_extensions 삭제
      if (newMaxExtensions != currentMaxExtensions) {
        if (kDebugMode) {
          debugPrint('⚠️  [DB] maxExtensions 변경 감지 - 기존 등록된 단말번호 삭제 필요');
        }
        
        // 현재 사용자의 모든 registered_extensions 문서 조회
        final registeredQuery = await _firestore
            .collection('registered_extensions')
            .where('userId', isEqualTo: userId)
            .get();
        
        if (registeredQuery.docs.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('🗑️  [DB] 삭제할 registered_extensions: ${registeredQuery.docs.length}개');
          }
          
          // 배치 삭제
          final batch = _firestore.batch();
          for (final doc in registeredQuery.docs) {
            batch.delete(doc.reference);
            if (kDebugMode) {
              debugPrint('   - 삭제: ${doc.id} (userId: ${doc.data()['userId']})');
            }
          }
          await batch.commit();
          
          if (kDebugMode) {
            debugPrint('✅ [DB] registered_extensions 삭제 완료');
          }
        } else {
          if (kDebugMode) {
            debugPrint('ℹ️  [DB] 삭제할 registered_extensions 없음');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️  [DB] maxExtensions 변경 없음 - registered_extensions 유지');
        }
      }
      
      // 🔧 STEP 3: 사용자 문서에 API 설정 필드 업데이트 (maxExtensions 포함)
      await _firestore.collection('users').doc(userId).update({
        'companyName': sharedSettings['companyName'],
        'companyId': sharedSettings['companyId'],
        'appKey': sharedSettings['appKey'],
        'apiBaseUrl': sharedSettings['apiBaseUrl'],
        'apiHttpPort': sharedSettings['apiHttpPort'] ?? 3500,
        'apiHttpsPort': sharedSettings['apiHttpsPort'] ?? 3501,
        'websocketServerUrl': sharedSettings['websocketServerUrl'],
        'websocketServerPort': sharedSettings['websocketServerPort'] ?? 6600,
        'websocketUseSSL': sharedSettings['websocketUseSSL'] ?? false,
        'websocketHttpAuthId': sharedSettings['websocketHttpAuthId'],
        'websocketHttpAuthPassword': sharedSettings['websocketHttpAuthPassword'],
        'amiServerId': sharedSettings['amiServerId'] ?? 1,
        'maxExtensions': newMaxExtensions, // 🔧 maxExtensions 업데이트
        'lastMaxExtensionsUpdate': FieldValue.serverTimestamp(), // 업데이트 시간 기록
      });
      
      if (kDebugMode) {
        debugPrint('✅ [DB] API 설정 가져오기 완료 (maxExtensions: $newMaxExtensions)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DB] API 설정 가져오기 실패: $e');
      }
      rethrow;
    }
  }
}
