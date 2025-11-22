import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../services/dcmiws_service.dart';
import '../../../providers/selected_extension_provider.dart';
import '../../../utils/dialog_utils.dart';
import '../../../widgets/call_method_dialog.dart';

/// 🔧 CallManager Service
/// 
/// **책임 (Single Responsibility)**:
/// - 통화 발신 방법 결정 (착신전환 상태 기반)
/// - 기능번호 자동 발신 처리
/// - Click to Call API 호출 관리
/// - 통화 기록 준비 및 저장
/// 
/// **설계 패턴**:
/// - Service Pattern: 비즈니스 로직 캡슐화
/// - Dependency Injection: 필요한 서비스 주입
/// - Context-aware: 다이얼로그 표시 및 Provider 접근
/// - Event-driven: 착신전환 상태에 따른 동작 분기
/// 
/// **사용 예시**:
/// ```dart
/// // 초기화
/// _callManager = CallManager(
///   databaseService: _databaseService,
///   onTabChanged: (index) => setState(() => _currentTabIndex = index),
/// );
/// 
/// // 통화 발신
/// await _callManager.showCallMethodDialog(context, authService, phoneNumber);
/// ```
class CallManager {
  final DatabaseService databaseService;
  final void Function(int) onTabChanged;
  
  CallManager({
    required this.databaseService,
    required this.onTabChanged,
  });
  
  /// 🔍 기능번호 판별 (Feature Code Detection)
  /// 
  /// **기능**: * 문자로 시작하는 번호를 기능번호로 판별
  /// - 기능번호 예시: *98 (음성사서함), *99 (에코테스트) 등
  bool isFeatureCode(String phoneNumber) {
    return phoneNumber.startsWith('*');
  }
  
  /// 🔥 착신전환 상태를 확인하여 발신 방법 결정
  /// 
  /// **기능**: 착신전환 상태에 따라 통화 발신 방법 자동 결정
  /// - 기능번호: 다이얼로그 없이 즉시 클릭투콜 실행
  /// - 5자리 이하 내선번호: 다이얼로그 없이 즉시 클릭투콜 실행
  /// - 착신전환 비활성화: 즉시 클릭투콜 실행
  /// - 착신전환 활성화: 발신 방법 선택 다이얼로그 표시
  /// 
  /// **고급 패턴**:
  /// - Feature Detection: 기능번호 자동 감지
  /// - Extension Validation: DB에서 단말번호 존재 확인
  /// - Forward Check: 착신전환 상태 확인
  /// - Automatic Fallback: 오류 시 다이얼로그 표시
  Future<void> showCallMethodDialog(
    BuildContext context,
    AuthService authService,
    String phoneNumber,
  ) async {
    // 기능번호는 다이얼로그 없이 바로 Click to Call
    if (isFeatureCode(phoneNumber)) {
      if (kDebugMode) {
        debugPrint('🌟 즐겨찾기/최근통화 기능번호 감지: $phoneNumber');
      }
      await handleFeatureCodeCall(context, authService, phoneNumber);
      return;
    }

    // 5자리 이하 숫자만 있는 단말번호는 자동으로 클릭투콜 실행 (다이얼로그 없음)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length > 0 && cleanNumber.length <= 5 && cleanNumber == phoneNumber) {
      if (kDebugMode) {
        debugPrint('🔥 5자리 이하 내선번호 감지: $phoneNumber');
        debugPrint('📞 자동으로 클릭투콜 실행 (다이얼로그 건너뛰기)');
      }
      await handleFeatureCodeCall(context, authService, phoneNumber);
      return;
    }

    // 🔍 착신전환 상태 확인 (현재 선택된 단말번호 기준)
    try {
      final userId = authService.currentUser?.uid ?? '';
      final userModel = authService.currentUserModel;
      final selectedExtension = context.read<SelectedExtensionProvider>().selectedExtension;
      
      if (selectedExtension == null) {
        throw Exception('선택된 단말번호가 없습니다.\n왼쪽 상단 프로필에서 단말번호를 등록해주세요.');
      }

      // 🔥 CRITICAL: DB에 단말번호가 실제로 존재하는지 확인
      final dbExtensions = await databaseService.getMyExtensions(userId).first;
      final extensionExists = dbExtensions.any((ext) => ext.extension == selectedExtension.extension);
      
      if (!extensionExists) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호가 DB에서 삭제됨: ${selectedExtension.extension}');
          debugPrint('🔄 착신전환 비활성화 시도');
        }
        
        // 착신전환 비활성화 시도 (DCMIWS 웹소켓으로 전송)
        try {
          if (userModel != null &&
              userModel.amiServerId != null && 
              userModel.tenantId != null && 
              selectedExtension.extension.isNotEmpty) {
            final dcmiws = DCMIWSService();
            await dcmiws.setCallForwardEnabled(
              amiServerId: userModel.amiServerId!,
              tenantId: userModel.tenantId!,
              extensionId: selectedExtension.extension,
              enabled: false,
              diversionType: 'CFI',
            );
            
            if (kDebugMode) {
              debugPrint('✅ 착신전환 비활성화 요청 전송 완료');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️  착신전환 비활성화 실패: $e');
          }
        }
        
        throw Exception('등록된 단말번호가 없습니다.\n\n프로필 드로어에서 단말번호가 삭제되었습니다.\n다시 등록해주세요.');
      }

      final callForwardInfo = await databaseService
          .getCallForwardInfoOnce(userId, selectedExtension.extension);
      
      final isForwardEnabled = callForwardInfo?.isEnabled ?? false;

      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔍 ========== 최근통화 발신 방법 결정 ==========');
        debugPrint('   📞 발신 대상: $phoneNumber');
        debugPrint('   📱 단말번호: ${selectedExtension.extension}');
        debugPrint('   🔄 착신전환 상태: ${isForwardEnabled ? "활성화" : "비활성화"}');
        if (isForwardEnabled) {
          debugPrint('   ➡️  착신번호: ${callForwardInfo?.destinationNumber ?? "미설정"}');
        }
        debugPrint('================================================');
        debugPrint('');
      }

      // 🎯 착신전환 비활성화 시: 즉시 클릭투콜 실행
      if (!isForwardEnabled) {
        if (kDebugMode) {
          debugPrint('✅ 착신전환 비활성화 → 즉시 클릭투콜 실행');
        }
        await handleFeatureCodeCall(context, authService, phoneNumber);
        return;
      }

      // 🎯 착신전환 활성화 시: 발신 방법 선택 다이얼로그 표시
      if (kDebugMode) {
        debugPrint('⚠️  착신전환 활성화 → 발신 방법 선택 다이얼로그 표시');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 착신전환 상태 확인 실패: $e');
        debugPrint('   → 기본 동작: 발신 방법 선택 다이얼로그 표시');
      }
    }

    // 일반 전화번호는 발신 방법 선택 다이얼로그 표시
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(
        phoneNumber: phoneNumber, 
        autoCallShortExtension: false,
        onClickToCallSuccess: () {
          // 🔄 클릭투콜 성공 시 최근통화 탭으로 전환
          onTabChanged(1); // 최근통화 탭
          if (kDebugMode) {
            debugPrint('✅ 클릭투콜 성공 → 최근통화 탭으로 전환');
          }
        },
      ),
    );
  }
  
  /// 📞 기능번호 자동 발신 (Click to Call API 직접 호출)
  /// 
  /// **기능**: 기능번호나 내선번호를 다이얼로그 없이 즉시 발신
  /// - DB에서 단말번호 존재 확인
  /// - 착신전환 정보 조회
  /// - Pending Storage에 통화 기록 준비
  /// - Click to Call API 호출
  /// - 성공 시 최근통화 탭으로 전환
  /// 
  /// **고급 패턴**:
  /// - Race Condition Prevention: API 호출 전 Pending Storage 저장
  /// - Extension Validation: DB에서 단말번호 존재 확인
  /// - Forward Info Preparation: 착신전환 정보 포함 저장
  /// - DCMIWS Integration: 웹소켓을 통한 통화 기록 준비
  Future<void> handleFeatureCodeCall(
    BuildContext context,
    AuthService authService,
    String phoneNumber,
  ) async {
    try {
      final userId = authService.currentUser?.uid ?? '';
      final userModel = authService.currentUserModel;

      if (userModel?.companyId == null || userModel?.appKey == null) {
        throw Exception('API 인증 정보가 설정되지 않았습니다. 내 정보에서 설정해주세요.');
      }

      if (userModel?.apiBaseUrl == null) {
        throw Exception('API 서버 주소가 설정되지 않았습니다. 내 정보 > API 설정에서 설정해주세요.');
      }

      // 홈 탭에서 선택된 단말번호 가져오기 (실시간 반영)
      final selectedExtension = context.read<SelectedExtensionProvider>().selectedExtension;
      
      if (selectedExtension == null) {
        throw Exception('선택된 단말번호가 없습니다.\n왼쪽 상단 프로필에서 단말번호를 등록해주세요.');
      }

      // 🔥 CRITICAL: DB에 단말번호가 실제로 존재하는지 확인
      final dbExtensions = await databaseService.getMyExtensions(userId).first;
      final extensionExists = dbExtensions.any((ext) => ext.extension == selectedExtension.extension);
      
      if (!extensionExists) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호가 DB에서 삭제됨: ${selectedExtension.extension}');
          debugPrint('🔄 착신전환 비활성화 시도');
        }
        
        // 착신전환 비활성화 시도 (DCMIWS 웹소켓으로 전송)
        try {
          if (userModel != null &&
              userModel.amiServerId != null && 
              userModel.tenantId != null && 
              selectedExtension.extension.isNotEmpty) {
            final dcmiws = DCMIWSService();
            await dcmiws.setCallForwardEnabled(
              amiServerId: userModel.amiServerId!,
              tenantId: userModel.tenantId!,
              extensionId: selectedExtension.extension,
              enabled: false,
              diversionType: 'CFI',
            );
            
            if (kDebugMode) {
              debugPrint('✅ 착신전환 비활성화 요청 전송 완료');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️  착신전환 비활성화 실패: $e');
          }
        }
        
        throw Exception('등록된 단말번호가 없습니다.\n\n프로필 드로어에서 단말번호가 삭제되었습니다.\n다시 등록해주세요.');
      }

      if (kDebugMode) {
        debugPrint('🌟 즐겨찾기/최근통화 기능번호 자동 발신 시작 (다이얼로그 건너뛰기)');
        debugPrint('📞 선택된 단말번호: ${selectedExtension.extension}');
        debugPrint('👤 단말 이름: ${selectedExtension.name}');
        debugPrint('🔑 COS ID: ${selectedExtension.classOfServicesId}');
        debugPrint('🎯 기능번호: $phoneNumber');
      }

      // CID 설정: 고정값 사용
      String cidName = '클릭투콜';
      String cidNumber = phoneNumber;

      if (kDebugMode) {
        debugPrint('📞 CID Name: $cidName (고정값)');
        debugPrint('📞 CID Number: $cidNumber (callee 값)');
      }

      // 로딩 표시
      if (context.mounted) {
        await DialogUtils.showInfo(
          context,
          '기능번호 발신 중...',
          duration: const Duration(seconds: 1),
        );
      }

      // 🔥 Step 1: 착신전환 정보 먼저 조회 (API 호출 전)
      final callForwardInfo = await databaseService
          .getCallForwardInfoOnce(userId, selectedExtension.extension);
      
      final isForwardEnabled = callForwardInfo?.isEnabled ?? false;
      final forwardDestination = (callForwardInfo?.destinationNumber ?? '').trim();

      if (kDebugMode) {
        debugPrint('');
        debugPrint('💾 ========== 통화 기록 준비 (착신전환 정보 포함) ==========');
        debugPrint('   📱 단말번호: ${selectedExtension.extension}');
        debugPrint('   📞 발신 대상: $phoneNumber');
        debugPrint('   🔄 착신전환 활성화: $isForwardEnabled');
        debugPrint('   ➡️  착신전환 목적지: ${isForwardEnabled ? forwardDestination : "비활성화"}');
        debugPrint('   📦 준비 데이터:');
        debugPrint('      - callForwardEnabled: $isForwardEnabled');
        debugPrint('      - callForwardDestination: ${(isForwardEnabled && forwardDestination.isNotEmpty) ? forwardDestination : "null"}');
        debugPrint('========================================================');
        debugPrint('');
      }

      // 🚀 Step 2: Pending Storage에 먼저 저장 (Race Condition 방지!)
      final dcmiws = DCMIWSService();
      dcmiws.storePendingClickToCallRecord(
        extensionNumber: selectedExtension.extension,
        phoneNumber: phoneNumber,
        userId: userId,
        mainNumberUsed: cidNumber,
        callForwardEnabled: isForwardEnabled,
        callForwardDestination: (isForwardEnabled && forwardDestination.isNotEmpty) ? forwardDestination : null,
      );

      // API 서비스 생성
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 📞 Step 3: Click to Call API 호출
      final result = await apiService.clickToCall(
        caller: selectedExtension.extension,
        callee: phoneNumber,
        cosId: selectedExtension.classOfServicesId,
        cidName: cidName,
        cidNumber: cidNumber,
        accountCode: userModel.phoneNumber ?? '',
      );

      if (kDebugMode) {
        debugPrint('✅ 즐겨찾기/최근통화 기능번호 Click to Call 성공: $result');
        debugPrint('   → Newchannel 이벤트 대기 중... (Pending Storage 준비 완료)');
      }

      // 성공 메시지
      if (context.mounted) {
        final extensionDisplay = selectedExtension.name.isEmpty 
            ? selectedExtension.extension 
            : selectedExtension.name;
        await DialogUtils.showSuccess(
          context,
          '🌟 기능번호 발신 완료\n\n단말: $extensionDisplay\n기능번호: $phoneNumber',
          duration: const Duration(seconds: 1),
        );
      }
      
      // 🔄 기능번호 발신 성공 시 최근통화 탭으로 전환
      onTabChanged(1); // 최근통화 탭
      if (kDebugMode) {
        debugPrint('✅ 기능번호 발신 성공 → 최근통화 탭으로 전환');
      }
      
    } catch (e, stackTrace) {
      // 에러 메시지
      if (context.mounted) {
        await DialogUtils.showError(
          context,
          '기능번호 발신 실패: $e',
        );
      }
      
      if (kDebugMode) {
        debugPrint('❌ [CallManager] 기능번호 발신 오류 발생');
        debugPrint('   에러: $e');
        debugPrint('   스택 트레이스: $stackTrace');
      }
    }
  }
}
