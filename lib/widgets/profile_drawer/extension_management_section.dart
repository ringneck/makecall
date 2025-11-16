import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../services/dcmiws_service.dart';
import '../../models/my_extension_model.dart';
import '../../utils/dialog_utils.dart';
import '../profile_drawer.dart';

/// 📱 단말번호 관리 섹션
/// 
/// 내 단말번호 조회, 등록, 삭제 기능을 제공하는 섹션입니다.
class ExtensionManagementSection extends StatefulWidget {
  const ExtensionManagementSection({super.key});

  @override
  State<ExtensionManagementSection> createState() => _ExtensionManagementSectionState();
}

class _ExtensionManagementSectionState extends State<ExtensionManagementSection> {
  bool _isSearching = false;
  String? _searchError;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userId = authService.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder<List<MyExtensionModel>>(
        stream: DatabaseService().getMyExtensions(userId),
        builder: (context, snapshot) {
          final extensions = snapshot.data ?? [];
          final extensionCount = extensions.length;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 단말번호 카드
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [Colors.cyan[900]!.withValues(alpha: 0.3), Colors.cyan[800]!.withValues(alpha: 0.3)]
                        : [Colors.cyan[50]!, Colors.cyan[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.cyan[700]! : Colors.cyan[200]!, 
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: isDark ? 0.2 : 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.cyan[900]!.withValues(alpha: 0.5) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone_android_rounded,
                      size: 20,
                      color: isDark ? Colors.cyan[300] : Colors.cyan[700],
                    ),
                  ),
                  title: Text(
                    '내 단말번호',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.cyan[200] : Colors.cyan[900],
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (extensionCount > 0) ...[
                        // 수신번호 표시
                        Text(
                          '수신번호: ${extensions.map((e) => e.accountCode ?? '미설정').join(", ")}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.green[300] : Colors.green[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // 단말번호 표시
                        Text(
                          '등록됨: ${extensions.map((e) => e.extension).join(", ")}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.cyan[300] : Colors.cyan[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else
                        Text(
                          '등록된 단말번호가 없습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.cyan[400] : Colors.cyan[600],
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (extensionCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.cyan[900]!.withValues(alpha: 0.5)
                                : Colors.cyan[700]!.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$extensionCount개',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.cyan[300] : Colors.cyan[700],
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: isDark ? Colors.cyan[400] : Colors.cyan[600],
                      ),
                    ],
                  ),
                  onTap: () => _showExtensionsManagementDialog(context, extensions),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 📋 단말번호 관리 상세 다이얼로그
  void _showExtensionsManagementDialog(BuildContext context, List<MyExtensionModel> extensions) {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    final userId = authService.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_android, 
                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '내 단말번호 관리',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[200] : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // 단말번호 조회 버튼
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching || userModel?.apiBaseUrl == null
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _searchMyExtensions(context);
                          },
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search, size: 20),
                    label: Text(_isSearching ? '조회 중...' : '단말번호 조회 및 등록'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              
              // 에러 메시지
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.red[900]!.withAlpha(77) : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.red[700]! : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline, 
                          color: isDark ? Colors.red[300] : Colors.red, 
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _searchError!,
                            style: TextStyle(
                              fontSize: 12, 
                              color: isDark ? Colors.red[300] : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const Divider(height: 24),
              
              // 등록된 단말번호 목록 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '등록된 단말번호',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (extensions.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _deleteAllExtensions(context, userId);
                        },
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: const Text('전체 삭제', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              
              // 단말번호 목록
              Flexible(
                child: extensions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined, 
                              size: 64, 
                              color: isDark ? Colors.grey[700] : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '등록된 단말번호가 없습니다',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '위의 조회 버튼을 눌러주세요',
                              style: TextStyle(
                                fontSize: 12, 
                                color: isDark ? Colors.grey[500] : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: extensions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final ext = extensions[index];
                          return _buildExtensionCard(context, ext, index, dialogContext);
                        },
                      ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtensionCard(
    BuildContext context, 
    MyExtensionModel ext, 
    int index,
    BuildContext dialogContext,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!, 
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withAlpha(51)
                : Colors.grey.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작은 숫자 아이콘
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.blue[900]!.withAlpha(128)
                    : const Color(0xFF2196F3).withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isDark 
                        ? Colors.blue[300] 
                        : const Color(0xFF2196F3),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // 정보 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 (첫 번째 줄)
                  Text(
                    ext.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 단말번호 (두 번째 줄)
                  Text(
                    ext.extension,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 수신번호 (세 번째 줄 - 강조 표시)
                  if (ext.accountCode != null && ext.accountCode!.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.call_received,
                          size: 14,
                          color: isDark ? Colors.green[300] : Colors.green[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '수신번호: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        Text(
                          ext.accountCode!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.green[300] : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  
                  // 수신번호 (길게 누르면 복사)
                  if (ext.accountCode != null && ext.accountCode!.isNotEmpty) ...[
                    _buildLongPressCopyRow(
                      context: context,
                      label: '수신번호',
                      value: ext.accountCode!,
                    ),
                    const SizedBox(height: 6),
                  ],
                  
                  // SIP UserId (길게 누르면 복사)
                  if (ext.sipUserId != null && ext.sipUserId!.isNotEmpty) ...[
                    _buildLongPressCopyRow(
                      context: context,
                      label: 'SIP UserId',
                      value: ext.sipUserId!,
                    ),
                    const SizedBox(height: 6),
                  ],
                  
                  // SIP Secret (길게 누르면 복사)
                  if (ext.sipSecret != null && ext.sipSecret!.isNotEmpty) ...[
                    _buildLongPressCopyRow(
                      context: context,
                      label: 'SIP Secret',
                      value: ext.sipSecret!,
                    ),
                  ],
                ],
              ),
            ),
            
            // 삭제 버튼
            IconButton(
              icon: Icon(
                Icons.delete_outline, 
                size: 20,
                color: isDark ? Colors.red[300] : Colors.red,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Navigator.pop(dialogContext);
                _deleteExtension(context, ext);
              },
              tooltip: '삭제',
            ),
          ],
        ),
      ),
    );
  }

  /// 복사 버튼이 있는 정보 행 빌더
  Widget _buildLongPressCopyRow({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 라벨 (60px로 축소하여 값 표시 공간 확보)
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
          // 값 (더 많은 문자 표시 가능)
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.black87,
                fontFamily: 'monospace',
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          // 복사 버튼 (최소 크기로 더 많은 텍스트 공간 확보)
          IconButton(
            icon: const Icon(Icons.content_copy, size: 14),
            onPressed: () async {
              Clipboard.setData(ClipboardData(text: value));
              await DialogUtils.showCopySuccess(context, label, value);
            },
            tooltip: '복사',
            padding: const EdgeInsets.all(2),
            constraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 28,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _searchMyExtensions(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (kDebugMode) {
      debugPrint('🔍 단말번호 조회 시작');
    }
    
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final authService = context.read<AuthService>();
      final userModel = authService.currentUserModel;
      final userId = authService.currentUser?.uid ?? '';

      if (userModel?.apiBaseUrl == null) {
        setState(() {
          _searchError = 'API 서버를 먼저 설정해주세요.';
          _isSearching = false;
        });
        return;
      }

      // API Service 생성
      final useHttps = (userModel!.apiHttpPort ?? 3500) == 3501;
      
      final apiService = ApiService(
        baseUrl: userModel.getApiUrl(useHttps: useHttps),
        companyId: userModel.companyId,
        appKey: userModel.appKey,
      );

      // 단말번호 조회
      final dataList = await apiService.getExtensions();
      final userEmail = userModel.email ?? '';
      
      // 내 이메일과 일치하는 단말번호 필터링
      final myExtensions = dataList.where((item) {
        final email = item['email']?.toString() ?? '';
        return email.toLowerCase() == userEmail.toLowerCase();
      }).toList();

      if (myExtensions.isEmpty) {
        setState(() {
          _searchError = '내 이메일과 일치하는 단말번호를 찾을 수 없습니다.';
          _isSearching = false;
        });
        
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            icon: Icon(
              Icons.error_outline, 
              color: isDark ? Colors.orange[300] : Colors.orange, 
              size: 48,
            ),
            title: Text(
              '단말번호 없음',
              style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
            ),
            content: Text(
              '내 이메일과 일치하는 단말번호를 찾을 수 없습니다.\n\n관리자에게 단말번호 등록을 요청하세요.',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
        return;
      }

      // maxExtensions 제한 확인
      final dbService = DatabaseService();
      final myExtensionsSnapshot = await dbService.getMyExtensions(userId).first;
      final currentExtensionCount = myExtensionsSnapshot.length;
      final maxExtensions = userModel.maxExtensions;
      
      if (currentExtensionCount >= maxExtensions) {
        setState(() {
          _isSearching = false;
        });
        
        if (!mounted) return;
        
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded, 
                  color: isDark ? Colors.orange[300] : Colors.orange, 
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '등록 한도 초과', 
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.grey[200] : Colors.black87,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '단말번호는 최대 $maxExtensions개까지 등록할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.orange[900]!.withAlpha(77) : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.orange[700]! : Colors.orange[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline, 
                            size: 16, 
                            color: isDark ? Colors.orange[300] : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '현재 등록된 단말번호: $currentExtensionCount개',
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[300] : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '더 많은 단말번호를 등록하려면 기존 단말번호를 삭제하거나 관리자에게 문의하세요.',
                        style: TextStyle(
                          fontSize: 12, 
                          color: isDark ? Colors.grey[400] : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        );
        return;
      }
      
      // 단말번호 선택 다이얼로그 표시
      if (!mounted) return;
      
      await _showExtensionSelectionDialog(context, myExtensions, userId);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 단말번호 조회 실패: $e');
      }
      setState(() {
        _searchError = 'API 조회 실패: $e';
        _isSearching = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _showExtensionSelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> extensions,
    String userId,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('단말번호 선택'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: extensions.length,
              itemBuilder: (context, index) {
                final ext = extensions[index];
                final extension = ext['extension']?.toString() ?? '';
                final name = ext['name']?.toString() ?? '';
                
                return ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: Text(extension),
                  subtitle: Text(name.isNotEmpty ? name : '이름 없음'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _saveExtension(ext, userId);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveExtension(Map<String, dynamic> apiData, String userId) async {
    try {
      final authService = context.read<AuthService>();
      final dbService = DatabaseService();
      
      final extension = apiData['extension']?.toString() ?? '';
      final name = apiData['name']?.toString() ?? '';
      final userEmail = authService.currentUser?.email ?? '';
      final userName = authService.currentUserModel?.phoneNumberName ?? '';
      
      // 1. registered_extensions 컬렉션에 등록
      await dbService.registerExtension(
        extension: extension,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
      );
      
      // 2. my_extensions 컬렉션에 추가
      final myExtension = MyExtensionModel.fromApi(
        userId: userId,
        apiData: apiData,
      );

      await dbService.addMyExtension(myExtension);

      if (kDebugMode) {
        debugPrint('✅ 단말번호 등록 완료: $extension');
      }

      if (mounted && context.mounted) {
        await DialogUtils.showSuccess(context, '단말번호가 등록되었습니다', duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 단말번호 등록 실패: $e');
      }
      if (mounted && context.mounted) {
        await DialogUtils.showError(context, '등록 실패: $e');
      }
    }
  }

  Future<void> _deleteExtension(BuildContext context, MyExtensionModel extension) async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('단말번호 삭제'),
        content: Text('${extension.extension}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = DatabaseService();
        
        // 착신전환 비활성화 시도
        try {
          if (userModel != null &&
              userModel.amiServerId != null && 
              userModel.tenantId != null && 
              extension.extension.isNotEmpty) {
            
            final dcmiws = DCMIWSService();
            await dcmiws.setCallForwardEnabled(
              amiServerId: userModel.amiServerId!,
              tenantId: userModel.tenantId!,
              extensionId: extension.extension,
              enabled: false,
              diversionType: 'CFI',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ 착신전환 비활성화 실패: $e');
          }
        }
        
        // my_extensions 컬렉션에서 삭제
        await dbService.deleteMyExtension(extension.id);
        
        // registered_extensions 컬렉션에서 등록 해제
        await dbService.unregisterExtension(extension.extension);
        
        if (mounted && context.mounted) {
          await DialogUtils.showInfo(context, '단말번호가 삭제되었습니다', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 단말번호 삭제 실패: $e');
        }
        if (mounted && context.mounted) {
          await DialogUtils.showError(context, '삭제 실패: $e');
        }
      }
    }
  }

  Future<void> _deleteAllExtensions(BuildContext context, String userId) async {
    final authService = context.read<AuthService>();
    final userModel = authService.currentUserModel;
    
    // 현재 등록된 단말번호 목록 가져오기
    final snapshot = await DatabaseService().getMyExtensions(userId).first;
    final extensionNumbers = snapshot.map((e) => e.extension).toList();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 삭제'),
        content: Text('모든 단말번호(${extensionNumbers.length}개)를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('전체 삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = DatabaseService();
        
        // 모든 단말번호의 착신전환 비활성화 시도
        if (userModel != null &&
            userModel.amiServerId != null && 
            userModel.tenantId != null) {
          final dcmiws = DCMIWSService();
          
          for (final ext in snapshot) {
            if (ext.extension.isNotEmpty) {
              try {
                await dcmiws.setCallForwardEnabled(
                  amiServerId: userModel.amiServerId!,
                  tenantId: userModel.tenantId!,
                  extensionId: ext.extension,
                  enabled: false,
                  diversionType: 'CFI',
                );
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('❌ 착신전환 비활성화 실패 (${ext.extension}): $e');
                }
              }
            }
          }
        }
        
        // my_extensions 컬렉션에서 전체 삭제
        await dbService.deleteAllMyExtensions(userId);
        
        // registered_extensions에서 각 단말번호 등록 해제
        for (final extension in extensionNumbers) {
          await dbService.unregisterExtension(extension);
        }
        
        if (mounted && context.mounted) {
          await DialogUtils.showInfo(context, '모든 단말번호가 삭제되었습니다', duration: const Duration(seconds: 2));
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 전체 삭제 실패: $e');
        }
        if (mounted && context.mounted) {
          await DialogUtils.showError(context, '삭제 실패: $e');
        }
      }
    }
  }
}
