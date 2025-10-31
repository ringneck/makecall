import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  final String baseUrl;
  final String? companyId;
  final String? appKey;
  
  ApiService({
    required this.baseUrl,
    this.companyId,
    this.appKey,
  });
  
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (appKey != null) 'App-Key': appKey!,
    if (companyId != null) 'Company-ID': companyId!,
  };
  
  // CORS 에러 감지 및 사용자 친화적 메시지 생성
  Exception _handleError(dynamic error, String operation) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('cors') || 
        errorString.contains('access-control-allow-origin') ||
        errorString.contains('preflight')) {
      return Exception(
        '⚠️ CORS 정책 오류\n\n'
        '웹 브라우저에서는 API 서버의 CORS 설정이 필요합니다.\n\n'
        '해결 방법:\n'
        '1. API 서버에서 CORS 허용 설정\n'
        '2. Android/iOS 앱 사용 (CORS 제한 없음)\n'
        '3. 프록시 서버 사용\n\n'
        '현재 요청: $operation\n'
        'API 서버: $baseUrl'
      );
    }
    
    if (errorString.contains('timeout')) {
      return Exception('⏱️ 요청 시간 초과\n\nAPI 서버 응답이 없습니다.\n서버 주소를 확인해주세요: $baseUrl');
    }
    
    if (errorString.contains('failed host lookup') || 
        errorString.contains('socketexception')) {
      return Exception('🌐 네트워크 오류\n\nAPI 서버에 연결할 수 없습니다.\n서버 주소를 확인해주세요: $baseUrl');
    }
    
    return Exception('$operation 실패: $error');
  }
  
  // 단말 목록 조회
  Future<List<Map<String, dynamic>>> getExtensions() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 API 요청: GET $baseUrl/extensions');
        debugPrint('📋 헤더: $_headers');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/extensions'),
        headers: _headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('요청 시간 초과 (30초)'),
      );
      
      if (kDebugMode) {
        debugPrint('✅ 응답 상태: ${response.statusCode}');
        debugPrint('📦 응답 본문: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // 응답 구조 확인: data 배열이 있는지 체크
        if (responseData is Map && responseData.containsKey('data')) {
          // data 배열에서 extension 객체들 추출
          final dataList = responseData['data'];
          if (dataList is List) {
            return List<Map<String, dynamic>>.from(dataList);
          }
        }
        
        // 이전 구조 지원 (extensions 배열)
        if (responseData is Map && responseData.containsKey('extensions')) {
          return List<Map<String, dynamic>>.from(responseData['extensions']);
        }
        
        // 응답이 배열인 경우
        if (responseData is List) {
          return List<Map<String, dynamic>>.from(responseData);
        }
        
        return [];
      } else {
        throw Exception('서버 오류 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Get extensions error: $e');
      }
      throw _handleError(e, '단말 목록 조회');
    }
  }
  
  // 사용자 단말 정보 조회
  Future<Map<String, dynamic>> getExtensionDevices(String extensionId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 API 요청: GET $baseUrl/extensions/$extensionId/devices');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/extensions/$extensionId/devices'),
        headers: _headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('요청 시간 초과 (30초)'),
      );
      
      if (kDebugMode) {
        debugPrint('✅ 응답 상태: ${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('서버 오류 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Get extension devices error: $e');
      }
      throw _handleError(e, '단말 상세 정보 조회');
    }
  }
  
  // 클릭투콜 (단말통화)
  Future<Map<String, dynamic>> clickToCall({
    required String caller,        // 단말번호
    required String callee,        // 착신번호
    required String cosId,         // COS ID
    required String cidName,       // 대표번호 이름
    required String cidNumber,     // 대표번호
    required String accountCode,   // 사용자 번호
  }) async {
    try {
      final body = {
        "caller": caller,
        "callee": callee,
        "cos_id": cosId,
        "cid_name": cidName,
        "cid_number": cidNumber,
        "variables": {
          "EXEC_AA": "yes",
          "CHANNEL(language)": "ko",
          "CHANNEL(accountcode)": accountCode,
        }
      };
      
      if (kDebugMode) {
        debugPrint('🔄 Click to call request: ${json.encode(body)}');
        debugPrint('🔄 API 요청: POST $baseUrl/core/click_to_call');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/core/click_to_call'),
        headers: _headers,
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('요청 시간 초과 (30초)'),
      );
      
      if (kDebugMode) {
        debugPrint('✅ 응답 상태: ${response.statusCode}');
        debugPrint('📦 응답 본문: ${response.body}');
      }
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('통화 연결 실패 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Click to call error: $e');
      }
      throw _handleError(e, '클릭투콜 (단말통화)');
    }
  }
  
  // API 연결 테스트
  Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 API 연결 테스트: $baseUrl/health');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      if (kDebugMode) {
        debugPrint('✅ 연결 테스트 응답: ${response.statusCode}');
      }
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Connection test error: $e');
      }
      return false;
    }
  }
  
  // Phonebook 목록 조회
  Future<List<Map<String, dynamic>>> getPhonebooks() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 API 요청: GET $baseUrl/phonebooks');
        debugPrint('📋 헤더: $_headers');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/phonebooks'),
        headers: _headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('요청 시간 초과 (30초)'),
      );
      
      if (kDebugMode) {
        debugPrint('✅ 응답 상태: ${response.statusCode}');
        debugPrint('📦 응답 본문: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // 응답 구조 확인: data 배열이 있는지 체크
        if (responseData is Map && responseData.containsKey('data')) {
          final dataList = responseData['data'];
          if (dataList is List) {
            return List<Map<String, dynamic>>.from(dataList);
          }
        }
        
        // 응답이 배열인 경우
        if (responseData is List) {
          return List<Map<String, dynamic>>.from(responseData);
        }
        
        return [];
      } else {
        throw Exception('서버 오류 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Get phonebooks error: $e');
      }
      throw _handleError(e, 'Phonebook 목록 조회');
    }
  }
  
  // Phonebook 연락처 목록 조회
  Future<List<Map<String, dynamic>>> getPhonebookContacts(String phonebookId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 API 요청: GET $baseUrl/phonebooks/$phonebookId/contacts');
        debugPrint('📋 헤더: $_headers');
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/phonebooks/$phonebookId/contacts'),
        headers: _headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('요청 시간 초과 (30초)'),
      );
      
      if (kDebugMode) {
        debugPrint('✅ 응답 상태: ${response.statusCode}');
        debugPrint('📦 응답 본문: ${response.body}');
      }
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // 응답 구조 확인: data 배열이 있는지 체크
        if (responseData is Map && responseData.containsKey('data')) {
          final dataList = responseData['data'];
          if (dataList is List) {
            return List<Map<String, dynamic>>.from(dataList);
          }
        }
        
        // 응답이 배열인 경우
        if (responseData is List) {
          return List<Map<String, dynamic>>.from(responseData);
        }
        
        return [];
      } else {
        throw Exception('서버 오류 (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Get phonebook contacts error: $e');
      }
      throw _handleError(e, 'Phonebook 연락처 조회');
    }
  }
}
