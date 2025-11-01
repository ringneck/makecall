import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../models/my_extension_model.dart';
import 'api_settings_dialog.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isSearching = false;
  bool _isRefreshing = false;
  String? _searchError;
  final _phoneNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 저장된 전화번호 불러오기 및 단말번호 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      if (authService.currentUserModel?.phoneNumber != null) {
        _phoneNumberController.text = authService.currentUserModel!.phoneNumber!;
      }
      // 저장된 단말번호 정보 업데이트
      _updateSavedExtensions();
    });
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
  }

  // 수동 업데이트 핸들러 (Firestore에서 사용자 데이터 새로고침)
  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      final authService = context.read<AuthService>();
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ 사용자 ID가 없어서 새로고침을 건너뜁니다');
        }
        return;
      }

      // Firestore에서 사용자 데이터 강제 새로고침
      await authService.refreshUserModel();
      
      if (kDebugMode) {
        debugPrint('✅ 사용자 데이터 새로고침 완료');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('정보가 업데이트되었습니다'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 새로고침 실패: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('업데이트 실패: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // 타임스탬프 포맷 함수 (한국어 형식)
  String _formatUpdateTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // 1분 이내
    if (difference.inSeconds < 60) {
      return '방금 업데이트됨';
    }
    // 1시간 이내
    else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전 업데이트';
    }
    // 24시간 이내
    else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전 업데이트';
    }
    // 그 외 - 전체 날짜 표시
    else {
      final year = timestamp.year;
      final month = timestamp.month;
      final day = timestamp.day;
      final hour = timestamp.hour;
      final minute = timestamp.minute;
      final period = hour >= 12 ? '오후' : '오전';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      
      return '$year년 $month월 $day일 $period $displayHour:${minute.toString().padLeft(2, '0')} 업데이트';
    }
  }

  // 저장된 단말번호 정보 업데이트
  Future<void> _updateSavedExtensions() async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';

    // API 설정이 없으면 종료
    if (userModel?.apiBaseUrl == null) {
      return;
    }

    try {
      // 저장된 단말번호 가져오기
      final dbService = DatabaseService();
      final savedExtensions = await dbService.getMyExtensions(userId).first;

      if (savedExtensions.isEmpty) {
        return;
      }

      // API Service 생성
      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: false),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // API에서 전체 단말번호 목록 가져오기
      final dataList = await apiService.getExtensions();

      // 저장된 각 단말번호에 대해 업데이트
      for (final savedExtension in savedExtensions) {
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
          await dbService.addMyExtension(updatedExtension);
        }
      }

      print('✅ 저장된 단말번호 정보 업데이트 완료 (${savedExtensions.length}개)');
    } catch (e) {
      print('⚠️ 단말번호 업데이트 실패: $e');
      // 에러가 발생해도 UI는 정상적으로 표시되도록 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // 사용자 정보
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => _showProfileImageOptions(context, authService),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF2196F3).withAlpha(51),
                  backgroundImage: userModel?.profileImageUrl != null
                      ? NetworkImage(userModel!.profileImageUrl!)
                      : null,
                  child: userModel?.profileImageUrl == null
                      ? const Icon(Icons.person, size: 50, color: Color(0xFF2196F3))
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showProfileImageOptions(context, authService),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            userModel?.email ?? '이메일 없음',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // 단말번호 제한 안내
          Text(
            '단말번호 저장 가능: 최대 ${userModel?.maxExtensions ?? 1}개',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 4),
          // 마지막 업데이트 타임스탬프 표시 및 수동 업데이트 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (userModel?.lastMaxExtensionsUpdate != null)
                Text(
                  _formatUpdateTimestamp(userModel!.lastMaxExtensionsUpdate!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(width: 8),
              // 수동 업데이트 버튼
              InkWell(
                onTap: _isRefreshing ? null : _handleManualRefresh,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isRefreshing 
                        ? Colors.grey[300] 
                        : const Color(0xFF2196F3).withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isRefreshing 
                          ? Colors.grey[400]! 
                          : const Color(0xFF2196F3).withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isRefreshing
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[600]!,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              size: 14,
                              color: const Color(0xFF2196F3),
                            ),
                      const SizedBox(width: 4),
                      Text(
                        _isRefreshing ? '업데이트 중...' : '새로고침',
                        style: TextStyle(
                          fontSize: 11,
                          color: _isRefreshing 
                              ? Colors.grey[600] 
                              : const Color(0xFF2196F3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          
          // 기본 설정
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('기본 설정'),
            subtitle: Text(
              userModel?.companyName != null
                  ? userModel!.companyName!
                  : '회사명 미설정',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const ApiSettingsDialog(),
              );
            },
          ),
          const Divider(),
          
          // 내 단말번호 조회 및 관리 (통합 UI)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_android, color: Color(0xFF2196F3)),
                    SizedBox(width: 8),
                    Text(
                      '내 단말번호',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 전화번호 입력 및 조회
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '전화번호로 등록된 번호 조회',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _phoneNumberController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: '전화번호',
                                hintText: '010-1234-5678',
                                prefixIcon: const Icon(Icons.phone),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) async {
                                // 전화번호가 변경되면 Firestore에 저장
                                if (value.trim().isNotEmpty) {
                                  await context.read<AuthService>().updateUserInfo(
                                    phoneNumber: value.trim(),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isSearching || userModel?.apiBaseUrl == null
                                ? null
                                : () => _searchMyExtensions(context),
                            icon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.search),
                            label: Text(_isSearching ? '조회 중' : '조회'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userModel?.apiBaseUrl != null
                            ? '전화번호를 입력하고 조회 버튼을 누르면 API에서 단말번호를 검색합니다.'
                            : '⚠️ API 서버를 먼저 설정해주세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: userModel?.apiBaseUrl != null
                              ? Colors.grey[700]
                              : Colors.red,
                        ),
                      ),
                      
                      // 에러 메시지 표시
                      if (_searchError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _searchError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 저장된 내 단말번호 목록
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '저장된 내 단말번호',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (userId.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _deleteAllExtensions(context, userId),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('전체 삭제'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // StreamBuilder로 실시간 목록 표시
                if (userId.isNotEmpty)
                  StreamBuilder<List<MyExtensionModel>>(
                    stream: DatabaseService().getMyExtensions(userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '오류: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final extensions = snapshot.data ?? [];
                      
                      if (extensions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  '저장된 단말번호가 없습니다.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '위의 전화번호를 입력하고 조회 버튼을 눌러주세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // 단말번호 목록 표시
                      return Column(
                        children: [
                          // 총 개수 표시
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '총 ${extensions.length}개의 단말번호',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // 단말번호 카드 목록
                          ...extensions.map((ext) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: ext.hasApiConfig ? Colors.green.withAlpha(102) : Colors.grey.withAlpha(51),
                                  width: ext.hasApiConfig ? 2 : 1,
                                ),
                              ),
                              child: InkWell(
                                onTap: () => _showExtensionDetails(context, ext),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 헤더: 단말번호 및 액션 버튼
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color(0xFF2196F3).withAlpha(51),
                                            child: const Icon(
                                              Icons.phone_android,
                                              color: Color(0xFF2196F3),
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ext.extension,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: Color(0xFF2196F3),
                                                  ),
                                                ),
                                                if (ext.name.isNotEmpty)
                                                  Text(
                                                    ext.name,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteExtension(context, ext),
                                            tooltip: '삭제',
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      
                                      // 기본 정보
                                      _buildInfoRow(
                                        Icons.access_time,
                                        '저장 시간',
                                        ext.createdAt.toString().substring(0, 19),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 정보 행 위젯
  Widget _buildInfoRow(IconData icon, String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: highlight ? Colors.orange : Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: highlight ? Colors.orange[800] : Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: highlight ? Colors.orange[900] : Colors.black87,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
  
  // 내 전화번호로 단말번호 조회 및 DB 저장
  Future<void> _searchMyExtensions(BuildContext context) async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';
    final phoneNumber = _phoneNumberController.text.trim();

    if (phoneNumber.isEmpty) {
      setState(() {
        _searchError = '전화번호를 입력해주세요.';
      });
      return;
    }

    if (userModel?.apiBaseUrl == null) {
      setState(() {
        _searchError = 'API 서버가 설정되지 않았습니다.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // 현재 저장된 단말번호 개수 확인
      final dbService = DatabaseService();
      final currentExtensions = await dbService.getMyExtensions(userId).first;
      final maxExtensions = userModel?.maxExtensions ?? 1;

      // 저장 가능한 개수를 초과하는지 확인
      if (currentExtensions.length >= maxExtensions) {
        setState(() {
          _isSearching = false;
        });
        
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 48,
              ),
              title: const Text('저장 제한 초과'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '최대 $maxExtensions개까지 저장할 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '현재 저장된 개수: ${currentExtensions.length}개',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '기존 단말번호를 삭제한 후 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Firestore에 전화번호 저장
      await authService.updateUserInfo(phoneNumber: phoneNumber);

      // API Service 생성
      final apiService = ApiService(
        baseUrl: userModel!.getApiUrl(useHttps: false), // HTTP 사용
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // data 배열에서 단말번호 조회
      final dataList = await apiService.getExtensions();

      // 내 전화번호와 일치하는 extension 필터링
      final myPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), ''); // 숫자만 추출
      
      final matched = dataList.where((item) {
        final extNumber = item['extension']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        // extension 필드가 내 전화번호와 일치하는지 확인
        return extNumber.isNotEmpty && myPhoneNumber.contains(extNumber);
      }).toList();

      if (matched.isEmpty) {
        // 결과가 없으면 팝업으로 알림
        if (context.mounted) {
          setState(() {
            _isSearching = false;
          });
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.error_outline, color: Colors.orange, size: 48),
              title: const Text('단말번호 없음'),
              content: const Text(
                '해당 단말번호가 존재하지 않습니다.\n\n'
                '입력한 전화번호와 일치하는 단말번호를 찾을 수 없습니다.',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 매칭된 단말번호를 MyExtensionModel로 변환
      final extensionModels = matched.map((item) {
        return MyExtensionModel.fromApi(
          userId: userId,
          apiData: item,
        );
      }).toList();

      // 중복된 단말번호와 새로운 단말번호 구분
      final existingExtensions = currentExtensions.map((e) => e.extension).toSet();
      final newExtensions = extensionModels.where((ext) => !existingExtensions.contains(ext.extension)).toList();
      final duplicateExtensions = extensionModels.where((ext) => existingExtensions.contains(ext.extension)).toList();

      // 새로운 단말번호만 저장 허용 수에 포함
      final totalCount = currentExtensions.length + newExtensions.length;
      if (totalCount > maxExtensions) {
        setState(() {
          _isSearching = false;
        });
        
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange[700],
                size: 48,
              ),
              title: const Text('저장 제한 초과'),
              content: Text(
                '조회된 단말번호: ${extensionModels.length}개\n'
                '새로운 단말번호: ${newExtensions.length}개\n'
                '중복 단말번호: ${duplicateExtensions.length}개\n'
                '현재 저장된 개수: ${currentExtensions.length}개\n'
                '최대 저장 가능: $maxExtensions개\n\n'
                '최대 $maxExtensions개까지만 저장할 수 있습니다.\n'
                '일부 단말번호를 삭제한 후 다시 시도해주세요.',
                textAlign: TextAlign.center,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // DB에 저장 (배치 처리 - 중복 체크는 addMyExtension에서 처리)
      await dbService.addMyExtensionsBatch(extensionModels);

      setState(() {
        _isSearching = false;
      });

      // 성공 메시지 표시
      if (context.mounted) {
        String message;
        if (duplicateExtensions.isNotEmpty && newExtensions.isNotEmpty) {
          message = '${newExtensions.length}개의 단말번호를 저장하고, ${duplicateExtensions.length}개의 중복 단말번호를 업데이트했습니다.';
        } else if (duplicateExtensions.isNotEmpty) {
          message = '${duplicateExtensions.length}개의 단말번호를 업데이트했습니다.';
        } else {
          message = '${newExtensions.length}개의 단말번호를 저장했습니다.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchError = '단말번호 조회 실패: ${e.toString()}';
      });
    }
  }

  // 단말번호 삭제
  Future<void> _deleteExtension(BuildContext context, MyExtensionModel extension) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('단말번호 삭제'),
        content: Text('${extension.extension} (${extension.name})을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService().deleteMyExtension(extension.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('단말번호가 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 전체 삭제
  Future<void> _deleteAllExtensions(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 삭제'),
        content: const Text('저장된 모든 단말번호를 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService().deleteAllMyExtensions(userId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('모든 단말번호가 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 단말번호 상세 정보 표시
  void _showExtensionDetails(BuildContext context, MyExtensionModel extension) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone_android, color: Color(0xFF2196F3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                extension.extension,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기본 정보
              _buildDetailRow('단말번호', extension.extension),
              _buildDetailRow('이름', extension.name),
              _buildDetailRow('계정코드', extension.accountCode),
              
              // 외부발신 정보
              if (extension.externalCidName != null && extension.externalCidName!.isNotEmpty)
                const Divider(height: 24),
              if (extension.externalCidName != null && extension.externalCidName!.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '외부발신 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              _buildDetailRow('외부발신 이름', extension.externalCidName),
              _buildDetailRow('외부발신 번호', extension.externalCidNumber),
              
              // SIP 정보
              if (extension.sipUserId != null && extension.sipUserId!.isNotEmpty)
                const Divider(height: 24),
              if (extension.sipUserId != null && extension.sipUserId!.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'SIP 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
              _buildDetailRow('SIP user id', extension.sipUserId),
              _buildDetailRowWithCopy('SIP secret', extension.sipSecret, context),
              
              // 시스템 정보
              const Divider(height: 24),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '시스템 정보',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              _buildDetailRow('Extension ID', extension.extensionId),
              _buildDetailRow('COS ID', extension.classOfServicesId),
              _buildDetailRow('User ID', extension.userId),
              _buildDetailRow('저장 시간', extension.createdAt.toString().substring(0, 19)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithCopy(String label, String? value, BuildContext context) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SIP secret이 클립보드에 복사되었습니다'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: '복사',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 프로필 사진 옵션 다이얼로그
  void _showProfileImageOptions(BuildContext context, AuthService authService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '프로필 사진',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2196F3)),
              title: const Text('사진 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, authService);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2196F3)),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, authService);
              },
            ),
            if (authService.currentUserModel?.profileImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('프로필 사진 삭제'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteProfileImage(authService);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 이미지 선택
  Future<void> _pickImage(ImageSource source, AuthService authService) async {
    try {
      if (kDebugMode) {
        debugPrint('🖼️ Starting image picker with source: $source');
      }
      
      final picker = ImagePicker();
      
      // iOS hang 방지: 약간의 지연을 추가하여 UI 스레드가 완전히 정리되도록 함
      await Future.delayed(const Duration(milliseconds: 100));
      
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,  // iOS에서 메타데이터 요청을 건너뛰어 성능 향상
      );

      if (pickedFile == null) {
        if (kDebugMode) {
          debugPrint('⚠️ Image picker cancelled by user');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ Image picked: ${pickedFile.path}');
      }

      // 로딩 다이얼로그 표시
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,  // 백버튼으로 닫기 방지
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('프로필 사진 업로드 중...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Firebase Storage에 업로드 (비동기 처리)
      final imageFile = File(pickedFile.path);
      
      if (kDebugMode) {
        debugPrint('📤 Uploading image to Firebase Storage...');
      }
      
      await authService.uploadProfileImage(imageFile);

      if (kDebugMode) {
        debugPrint('✅ Image upload completed successfully');
      }

      if (!mounted) return;
      
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('프로필 사진이 업데이트되었습니다'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Image upload error: $e');
      }
      
      if (!mounted) return;
      
      // 로딩 다이얼로그가 열려있으면 닫기
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('이미지 업로드 실패: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 프로필 사진 삭제
  Future<void> _deleteProfileImage(AuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 사진 삭제'),
        content: const Text('프로필 사진을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await authService.deleteProfileImage();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('프로필 사진이 삭제되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


}
