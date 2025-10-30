import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFF2196F3).withAlpha(51),
            child: const Icon(Icons.person, size: 50, color: Color(0xFF2196F3)),
          ),
          const SizedBox(height: 16),
          Text(
            userModel?.email ?? '이메일 없음',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
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
          // API Base URL 정보 표시
          if (userModel?.apiBaseUrl != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'API 서버 정보',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // API Base URL 표시
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dns, size: 16, color: Color(0xFF2196F3)),
                            const SizedBox(width: 8),
                            const Text(
                              'API Base URL:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userModel!.apiBaseUrl!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              'HTTP 포트: ${userModel.apiHttpPort}  |  HTTPS 포트: ${userModel.apiHttpsPort}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'API 엔드포인트 (자동 생성)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.https, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text(
                              'HTTPS + /api/v2:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userModel.getApiUrl(useHttps: true),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.http, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text(
                              'HTTP + /api/v2:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userModel.getApiUrl(useHttps: false),
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
          ],
          // 사용자 전화번호 정보
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('내 전화번호'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userModel?.phoneNumberName != null)
                  Text(
                    '${userModel!.phoneNumberName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                Text(userModel?.phoneNumber ?? '미설정'),
              ],
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _showPhoneNumberDialog(context),
          ),
          const Divider(),
          
          // 내 전화번호로 단말번호 조회 섹션
          if (userModel?.phoneNumber != null && userModel?.apiBaseUrl != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '내 단말번호 조회',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSearching ? null : () => _searchMyExtensions(context),
                        icon: _isSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search, size: 20),
                        label: Text(_isSearching ? '조회 중...' : '조회'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '내 전화번호(${userModel!.phoneNumber})와 일치하는 단말번호를 검색하고 DB에 저장합니다.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 검색 결과 표시
                  if (_searchError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              _searchError!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
          ],
          
          // 저장된 내 단말번호 목록 표시
          if (userId.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '저장된 내 단말번호',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<MyExtensionModel>>(
                    stream: DatabaseService().getMyExtensions(userId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '오류: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      
                      final extensions = snapshot.data ?? [];
                      
                      if (extensions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  '저장된 단말번호가 없습니다.\n위의 조회 버튼을 눌러 단말번호를 검색하세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return Column(
                        children: extensions.map((ext) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF2196F3).withAlpha(51),
                                child: const Icon(
                                  Icons.phone_android,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                              title: Text(
                                ext.extension,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '이름: ${ext.name}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'COS ID: ${ext.classOfServicesId}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteExtension(context, ext),
                              ),
                              onTap: () {
                                _showExtensionDetails(context, ext);
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
        ],
      ),
    );
  }

  // 내 전화번호로 단말번호 조회 및 DB 저장
  Future<void> _searchMyExtensions(BuildContext context) async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';

    if (userModel == null || userModel.phoneNumber == null) {
      setState(() {
        _searchError = '전화번호가 설정되지 않았습니다.';
      });
      return;
    }

    if (userModel.apiBaseUrl == null) {
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
      // API Service 생성
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: false), // HTTP 사용
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // data 배열에서 단말번호 조회
      final dataList = await apiService.getExtensions();

      // 내 전화번호와 일치하는 extension 필터링
      final myPhoneNumber = userModel.phoneNumber!.replaceAll(RegExp(r'[^0-9]'), ''); // 숫자만 추출
      
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
                '내 전화번호와 일치하는 단말번호를 찾을 수 없습니다.',
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

      // DB에 저장 (배치 처리)
      final dbService = DatabaseService();
      await dbService.addMyExtensionsBatch(extensionModels);

      setState(() {
        _isSearching = false;
      });

      // 성공 메시지 표시
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${extensionModels.length}개의 단말번호를 저장했습니다.'),
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

  // 단말번호 상세 정보 표시
  void _showExtensionDetails(BuildContext context, MyExtensionModel extension) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone_android, color: Color(0xFF2196F3)),
            const SizedBox(width: 8),
            Text(extension.extension),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  void _showPhoneNumberDialog(BuildContext context) {
    final authService = context.read<AuthService>();
    final nameController = TextEditingController(
      text: authService.currentUserModel?.phoneNumberName ?? '',
    );
    final numberController = TextEditingController(
      text: authService.currentUserModel?.phoneNumber ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 전화번호 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '전화번호 이름',
                hintText: '예: 내 휴대폰, 사무실 전화',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '전화번호',
                hintText: '010-1234-5678',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<AuthService>().updateUserInfo(
                      phoneNumberName: nameController.text.trim().isEmpty 
                          ? null 
                          : nameController.text.trim(),
                      phoneNumber: numberController.text.trim().isEmpty 
                          ? null 
                          : numberController.text.trim(),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('전화번호 정보가 저장되었습니다')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $e')),
                  );
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
