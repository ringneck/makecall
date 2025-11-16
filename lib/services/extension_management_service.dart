import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../models/my_extension_model.dart';

/// 단말번호 관리 서비스
/// 
/// 단말번호 조회, 등록, 삭제 등의 비즈니스 로직을 담당합니다.
/// profile_tab.dart와 profile_drawer.dart에서 공통으로 사용됩니다.
class ExtensionManagementService {
  final AuthService _authService;
  final DatabaseService _dbService = DatabaseService();

  ExtensionManagementService(this._authService);

  /// 등록된 단말번호 정보 업데이트
  /// 
  /// 1. registered_extensions에서 내가 등록한 단말번호 가져오기
  /// 2. my_extensions에 누락된 단말번호 마이그레이션
  /// 3. API에서 최신 정보 가져와서 업데이트
  Future<void> updateSavedExtensions() async {
    final userModel = _authService.currentUserModel;
    final userId = _authService.currentUser?.uid ?? '';

    // API 설정이 없으면 종료
    if (userModel?.apiBaseUrl == null) {
      return;
    }

    try {
      // 1. registered_extensions에서 내가 등록한 단말번호 가져오기
      final registeredExtensions = await _dbService.getUserRegisteredExtensions(userId);

      // 2. my_extensions에서 이미 있는 단말번호 목록 가져오기
      final savedExtensions = await _dbService.getMyExtensions(userId).first;
      final existingExtensionNumbers = savedExtensions.map((e) => e.extension).toSet();

      // 3. registered_extensions에는 있지만 my_extensions에는 없는 단말번호 찾기
      final missingExtensions = registeredExtensions
          .where((ext) => !existingExtensionNumbers.contains(ext))
          .toList();

      // 4. 누락된 단말번호를 my_extensions에 추가 (마이그레이션)
      if (missingExtensions.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🔄 [ExtensionMgmt] 마이그레이션 시작: ${missingExtensions.length}개 단말번호를 my_extensions에 추가');
        }

        for (final extension in missingExtensions) {
          final myExtension = MyExtensionModel(
            id: '',
            userId: userId,
            extensionId: '',
            extension: extension,
            name: extension, // 이름을 모르므로 단말번호를 이름으로 사용
            classOfServicesId: '',
            createdAt: DateTime.now(),
            apiBaseUrl: userModel?.apiBaseUrl,
            companyId: userModel?.companyId,
            appKey: userModel?.appKey,
            apiHttpPort: userModel?.apiHttpPort,
            apiHttpsPort: userModel?.apiHttpsPort,
          );

          await _dbService.addMyExtension(myExtension);

          if (kDebugMode) {
            debugPrint('   ✅ $extension 추가 완료');
          }
        }
      }

      // 5. 등록된 단말번호 가져오기 (마이그레이션 후)
      final allSavedExtensions = await _dbService.getMyExtensions(userId).first;

      if (allSavedExtensions.isEmpty) {
        return;
      }

      // API Service 생성
      // apiHttpPort가 3501이면 HTTPS 사용, 3500이면 HTTP 사용
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;

      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // API에서 전체 단말번호 목록 가져오기
      final dataList = await apiService.getExtensions();

      // 등록된 각 단말번호에 대해 업데이트
      for (final savedExtension in allSavedExtensions) {
        // API 데이터에서 매칭되는 단말번호 찾기
        final matchedData = dataList.firstWhere(
          (item) => item['extension']?.toString() == savedExtension.extension,
          orElse: () => <String, dynamic>{},
        );

        if (matchedData.isNotEmpty) {
          // 새로운 정보로 업데이트
          final updatedExtension = MyExtensionModel.fromApi(
            userId: userId,
            apiData: matchedData,
          );

          // DB 업데이트 (addMyExtension은 중복 시 업데이트 수행)
          await _dbService.addMyExtension(updatedExtension);
        }
      }

      if (kDebugMode) {
        debugPrint('✅ [ExtensionMgmt] 등록된 단말번호 정보 업데이트 완료 (${savedExtensions.length}개)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ExtensionMgmt] 단말번호 업데이트 실패: $e');
      }
      // 에러가 발생해도 UI는 정상적으로 표시되도록 무시
    }
  }

  /// 내 전화번호로 단말번호 조회
  /// 
  /// Returns: 매칭된 단말번호 목록
  Future<List<Map<String, dynamic>>> searchMyExtensions() async {
    final userModel = _authService.currentUserModel;
    final userEmail = userModel?.email ?? '';

    if (userModel?.apiBaseUrl == null) {
      throw Exception('API 서버가 설정되지 않았습니다.');
    }

    if (userEmail.isEmpty) {
      throw Exception('사용자 이메일 정보가 없습니다.');
    }

    // API Service 생성
    final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;

    final apiService = ApiService(
      baseUrl: userModel.getApiUrl(useHttps: useHttps),
      companyId: userModel.companyId,
      appKey: userModel.appKey,
    );

    // 사용자 이메일로 단말번호 조회
    final matchedExtensions = await apiService.getMyExtensionsFromInternalPhonebook(
      userEmail: userEmail,
    );

    return matchedExtensions;
  }

  /// 단말번호 등록 가능 여부 확인
  /// 
  /// maxExtensions 제한을 확인합니다.
  /// Returns: true = 등록 가능, false = 제한 초과
  Future<bool> canRegisterExtension() async {
    final userId = _authService.currentUser?.uid ?? '';
    final maxExtensions = _authService.currentUserModel?.maxExtensions ?? 1;

    // my_extensions 컬렉션에서 실제 등록된 단말번호 개수 확인
    final myExtensionsSnapshot = await _dbService.getMyExtensions(userId).first;
    final currentExtensionCount = myExtensionsSnapshot.length;

    if (kDebugMode) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 [ExtensionMgmt] maxExtensions 제한 체크');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📊 현재 등록된 단말번호 개수: $currentExtensionCount');
      debugPrint('📊 최대 등록 가능 개수: $maxExtensions');
      debugPrint('📊 등록 가능 여부: ${currentExtensionCount < maxExtensions}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    return currentExtensionCount < maxExtensions;
  }

  /// 단말번호 등록 상태 확인
  /// 
  /// Returns: 등록 정보 (null이면 미등록)
  Future<Map<String, dynamic>?> checkExtensionRegistration(String extension) async {
    return await _dbService.checkExtensionRegistration(extension);
  }

  /// 단말번호 등록
  /// 
  /// 1. registered_extensions 컬렉션에 등록
  /// 2. my_extensions 컬렉션에 추가
  /// 3. users 문서 업데이트 (phoneNumber, phoneNumberName, myExtensions)
  Future<void> registerExtension(
    String extension,
    Map<String, dynamic> apiData,
  ) async {
    final userId = _authService.currentUser?.uid ?? '';
    final userEmail = _authService.currentUser?.email ?? '';
    final userName = _authService.currentUserModel?.phoneNumberName ?? '';
    final currentMyExtensions = _authService.currentUserModel?.myExtensions ?? [];

    final selectedName = apiData['name'] as String? ?? '';

    // 1. registered_extensions 컬렉션에 등록 (중복 방지용)
    await _dbService.registerExtension(
      extension: extension,
      userId: userId,
      userEmail: userEmail,
      userName: userName,
    );

    // 2. my_extensions 컬렉션에 추가 (UI 표시용)
    final myExtension = MyExtensionModel(
      id: '', // DatabaseService.addMyExtension에서 자동 생성
      userId: userId,
      extensionId: '', // API에서 가져올 때까지 비워둠
      extension: extension,
      name: selectedName,
      classOfServicesId: '', // API에서 가져올 때까지 비워둠
      createdAt: DateTime.now(),
      // API 설정은 사용자 프로필에서 가져옴
      apiBaseUrl: _authService.currentUserModel?.apiBaseUrl,
      companyId: _authService.currentUserModel?.companyId,
      appKey: _authService.currentUserModel?.appKey,
      apiHttpPort: _authService.currentUserModel?.apiHttpPort,
      apiHttpsPort: _authService.currentUserModel?.apiHttpsPort,
    );
    await _dbService.addMyExtension(myExtension);

    // 3. users 문서 업데이트
    // myExtensions 배열에 추가 (중복 방지)
    List<String>? updatedExtensions;
    if (!currentMyExtensions.contains(extension)) {
      updatedExtensions = [...currentMyExtensions, extension];
    }

    // phoneNumber와 phoneNumberName도 함께 업데이트
    await _authService.updateUserInfo(
      phoneNumber: extension,
      phoneNumberName: selectedName.isNotEmpty ? selectedName : extension,
      myExtensions: updatedExtensions ?? currentMyExtensions,
    );

    if (kDebugMode) {
      debugPrint('✅ [ExtensionMgmt] 단말번호 등록 완료: $extension');
      debugPrint('   - registered_extensions 등록');
      debugPrint('   - my_extensions 컬렉션 추가');
      debugPrint('   - users.myExtensions 배열 업데이트');
      debugPrint('   - users.phoneNumber: $extension');
      debugPrint('   - users.phoneNumberName: ${selectedName.isNotEmpty ? selectedName : extension}');
    }
  }

  /// 단말번호 삭제
  /// 
  /// 1. my_extensions 컬렉션에서 삭제
  /// 2. users 문서의 myExtensions 배열에서 제거
  /// 3. registered_extensions 컬렉션에서 등록 해제
  Future<void> deleteExtension(MyExtensionModel extension) async {
    // 1. my_extensions 컬렉션에서 삭제
    await _dbService.deleteMyExtension(extension.id);

    // 2. users 문서의 myExtensions 배열에서 제거
    final currentMyExtensions = _authService.currentUserModel?.myExtensions ?? [];
    final updatedExtensions = currentMyExtensions.where((e) => e != extension.extension).toList();
    await _authService.updateUserInfo(myExtensions: updatedExtensions);

    // 3. registered_extensions 컬렉션에서 등록 해제
    await _dbService.unregisterExtension(extension.extension);

    if (kDebugMode) {
      debugPrint('✅ [ExtensionMgmt] 단말번호 삭제 완료: ${extension.extension}');
      debugPrint('   - my_extensions 컬렉션 삭제');
      debugPrint('   - users.myExtensions 배열 업데이트');
      debugPrint('   - registered_extensions 등록 해제');
    }
  }

  /// 전체 단말번호 삭제
  /// 
  /// 1. my_extensions 컬렉션에서 전체 삭제
  /// 2. users 문서의 myExtensions 배열 비우기
  /// 3. registered_extensions에서 각 단말번호 등록 해제
  Future<void> deleteAllExtensions() async {
    final userId = _authService.currentUser?.uid ?? '';

    // 1. 현재 등록된 단말번호 목록 가져오기
    final currentMyExtensions = _authService.currentUserModel?.myExtensions ?? [];

    // 2. my_extensions 컬렉션에서 전체 삭제
    await _dbService.deleteAllMyExtensions(userId);

    // 3. users 문서의 myExtensions 배열 비우기
    await _authService.updateUserInfo(myExtensions: []);

    // 4. registered_extensions에서 각 단말번호 등록 해제
    for (final extension in currentMyExtensions) {
      await _dbService.unregisterExtension(extension);
    }

    if (kDebugMode) {
      debugPrint('✅ [ExtensionMgmt] 모든 단말번호 삭제 완료 (${currentMyExtensions.length}개)');
      debugPrint('   - my_extensions 컬렉션 전체 삭제');
      debugPrint('   - users.myExtensions 배열 초기화');
      debugPrint('   - registered_extensions 등록 해제: $currentMyExtensions');
    }
  }
}
