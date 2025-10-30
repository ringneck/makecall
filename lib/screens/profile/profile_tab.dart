import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'api_settings_dialog.dart';
import 'extension_management_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  List<Map<String, dynamic>> _matchedExtensions = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userModel = authService.currentUserModel;

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
          // 단말번호 관리
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('단말번호 관리'),
            subtitle: const Text('단말번호 조회 및 선택'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExtensionManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
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
                    '내 전화번호(${userModel!.phoneNumber})와 일치하는 단말번호를 검색합니다.',
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
                    )
                  else if (_matchedExtensions.isEmpty && !_isSearching)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              '조회 버튼을 눌러 단말번호를 검색하세요.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_matchedExtensions.isNotEmpty)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${_matchedExtensions.length}개의 단말번호를 찾았습니다.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 단말번호 목록
                        ..._matchedExtensions.map((ext) {
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
                                ext['extension']?.toString() ?? '알 수 없음',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (ext['name'] != null)
                                    Text(
                                      '이름: ${ext['name']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (ext['type'] != null)
                                    Text(
                                      '타입: ${ext['type']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (ext['status'] != null)
                                    Text(
                                      '상태: ${ext['status']}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // 단말번호 상세 정보 표시
                                _showExtensionDetails(context, ext);
                              },
                            ),
                          );
                        }).toList(),
                      ],
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

  // 내 전화번호로 단말번호 조회
  Future<void> _searchMyExtensions(BuildContext context) async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;

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
      _matchedExtensions = [];
    });

    try {
      // API Service 생성
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: false), // HTTP 사용
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 모든 단말번호 조회
      final extensions = await apiService.getExtensions();

      // 내 전화번호와 일치하는 extension 필터링
      final myPhoneNumber = userModel.phoneNumber!.replaceAll(RegExp(r'[^0-9]'), ''); // 숫자만 추출
      
      final matched = extensions.where((ext) {
        final extNumber = ext['extension']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
        // extension 필드가 내 전화번호와 일치하는지 확인
        return extNumber.isNotEmpty && myPhoneNumber.contains(extNumber);
      }).toList();

      setState(() {
        _matchedExtensions = matched;
        _isSearching = false;
        
        if (matched.isEmpty) {
          _searchError = '일치하는 단말번호를 찾을 수 없습니다.';
        }
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchError = '단말번호 조회 실패: ${e.toString()}';
      });
    }
  }

  // 단말번호 상세 정보 표시
  void _showExtensionDetails(BuildContext context, Map<String, dynamic> extension) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone_android, color: Color(0xFF2196F3)),
            const SizedBox(width: 8),
            Text(extension['extension']?.toString() ?? '단말번호'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('단말번호', extension['extension']?.toString()),
              _buildDetailRow('이름', extension['name']?.toString()),
              _buildDetailRow('타입', extension['type']?.toString()),
              _buildDetailRow('상태', extension['status']?.toString()),
              _buildDetailRow('설명', extension['description']?.toString()),
              
              // 추가 정보가 있으면 표시
              if (extension.keys.length > 5)
                const Divider(),
              
              ...extension.entries
                  .where((e) => !['extension', 'name', 'type', 'status', 'description'].contains(e.key))
                  .map((e) => _buildDetailRow(
                        e.key,
                        e.value?.toString(),
                      ))
                  .toList(),
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
            width: 80,
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
