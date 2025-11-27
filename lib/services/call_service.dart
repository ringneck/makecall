import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import '../models/call_history_model.dart';
import '../models/extension_model.dart';
import '../models/main_number_model.dart';
import 'api_service.dart';
import 'database_service.dart';

class CallService {
  final DatabaseService _databaseService = DatabaseService();
  
  // 로컬 전화 발신 (일반 전화 앱 사용)
  Future<bool> makeLocalCall(String phoneNumber, String userId) async {
    try {
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        // 통화 기록 저장
        await _databaseService.addCallHistory(
          CallHistoryModel(
            id: '',
            userId: userId,
            phoneNumber: phoneNumber,
            callType: CallType.outgoing,
            callMethod: CallMethod.local,
            callTime: DateTime.now(),
          ),
        );
        
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Local call error: $e');
      }
      return false;
    }
  }
  
  // 로컬 앱 통화 (앱 내부 다이얼러 사용 - 추후 구현)
  Future<bool> makeLocalAppCall(
    String phoneNumber,
    String userId,
    MainNumberModel? mainNumber,
  ) async {
    try {
      // 앱 내부 다이얼러 구현 (WebRTC 또는 SIP 클라이언트)
      // 여기서는 일반 전화 발신으로 대체
      final uri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        // 통화 기록 저장
        await _databaseService.addCallHistory(
          CallHistoryModel(
            id: '',
            userId: userId,
            phoneNumber: phoneNumber,
            callType: CallType.outgoing,
            callMethod: CallMethod.localApp,
            callTime: DateTime.now(),
            mainNumberUsed: mainNumber?.number,
          ),
        );
        
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Local app call error: $e');
      }
      return false;
    }
  }
  
  // 단말 통화 (Click to Call API 사용)
  // ⚠️ 주의: 이 함수는 현재 사용되지 않습니다. 실제 발신은 다른 파일에서 처리됩니다.
  Future<bool> makeExtensionCall({
    required String phoneNumber,
    required String userId,
    required ExtensionModel extension,
    required MainNumberModel mainNumber,
    required String userPhoneNumber,
    required ApiService apiService,
  }) async {
    try {
      final result = await apiService.clickToCall(
        caller: extension.extensionNumber,
        callee: phoneNumber,
        cosId: extension.cosId ?? '2',
        cidName: '클릭투콜',            // 고정값: "클릭투콜"
        cidNumber: phoneNumber,          // callee 값 사용
        accountCode: userPhoneNumber,
      );
      
      if (kDebugMode) {
        debugPrint('Click to call result: $result');
      }
      
      // 🔥 착신전환 정보 조회 (현재 시점 기준)
      final callForwardInfo = await _databaseService
          .getCallForwardInfoOnce(userId, extension.extensionNumber);
      
      final isForwardEnabled = callForwardInfo?.isEnabled ?? false;
      final forwardDestination = (callForwardInfo?.destinationNumber ?? '').trim();
      
      // 통화 기록 저장 (착신전환 정보 포함)
      await _databaseService.addCallHistory(
        CallHistoryModel(
          id: '',
          userId: userId,
          phoneNumber: phoneNumber,
          callType: CallType.outgoing,
          callMethod: CallMethod.extension,
          callTime: DateTime.now(),
          mainNumberUsed: mainNumber.number,
          extensionUsed: extension.extensionNumber,
          callForwardEnabled: isForwardEnabled,
          callForwardDestination: (isForwardEnabled && forwardDestination.isNotEmpty) ? forwardDestination : null,
        ),
      );
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Extension call error: $e');
      }
      return false;
    }
  }
}
