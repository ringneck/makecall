import 'package:flutter/material.dart';
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
  String? _searchError;
  final _phoneNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 저장된 전화번호 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      if (authService.currentUserModel?.phoneNumber != null) {
        _phoneNumberController.text = authService.currentUserModel!.phoneNumber!;
      }
    });
  }

  @override
  void dispose() {
    _phoneNumberController.dispose();
    super.dispose();
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
          // 프리미엄 뱃지
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: userModel?.isPremium == true
                      ? Colors.amber[100]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: userModel?.isPremium == true
                        ? Colors.amber
                        : Colors.grey,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      userModel?.isPremium == true
                          ? Icons.star
                          : Icons.person,
                      size: 16,
                      color: userModel?.isPremium == true
                          ? Colors.amber[700]
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      userModel?.isPremium == true ? '프리미엄 회원' : '무료 회원',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: userModel?.isPremium == true
                            ? Colors.amber[900]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 프리미엄 토글 버튼 (개발/테스트용)
              if (userId.isNotEmpty)
                InkWell(
                  onTap: () async {
                    try {
                      await authService.togglePremium();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              userModel?.isPremium == true
                                  ? '무료 회원으로 전환되었습니다.'
                                  : '프리미엄 회원으로 전환되었습니다.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('전환 실패: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      size: 16,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 단말번호 제한 안내
          Text(
            '단말번호 저장 가능: ${userModel?.maxExtensions ?? 1}개',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          
          // API 설정
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('API 설정'),
            subtitle: Text(
              userModel?.apiBaseUrl != null
                  ? '${userModel!.apiBaseUrl} (HTTP:${userModel.apiHttpPort}, HTTPS:${userModel.apiHttpsPort})'
                  : 'API 서버 주소 미설정',
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
                                        Icons.vpn_key,
                                        'Extension ID',
                                        ext.extensionId,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildInfoRow(
                                        Icons.class_,
                                        'COS ID',
                                        ext.classOfServicesId,
                                        highlight: true,
                                      ),
                                      const SizedBox(height: 8),
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
                    userModel?.isPremium == true
                        ? '프리미엄 회원은 최대 3개까지 저장 가능합니다.'
                        : '무료 회원은 최대 1개까지 저장 가능합니다.',
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
                  if (userModel?.isPremium != true) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '프리미엄 회원으로 업그레이드하면\n최대 3개까지 저장할 수 있습니다!',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                '${userModel.isPremium ? "프리미엄 회원은" : "무료 회원은"} '
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
              _buildDetailRow('단말번호', extension.extension),
              _buildDetailRow('이름', extension.name),
              _buildDetailRow('Extension ID', extension.extensionId),
              _buildDetailRow('COS ID', extension.classOfServicesId),
              const Divider(height: 24),
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
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      // 로딩 다이얼로그 표시
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
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
        );
      }

      // Firebase Storage에 업로드
      final imageFile = File(pickedFile.path);
      await authService.uploadProfileImage(imageFile);

      if (context.mounted) {
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
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 로딩 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 업로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
