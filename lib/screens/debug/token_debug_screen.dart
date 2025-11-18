import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firebase_auth_token_helper.dart';

/// 🔍 디버깅용 - ID Token 확인 화면
/// 
/// 개발 중 ID Token을 확인하고 테스트하기 위한 화면입니다.
/// ⚠️ 프로덕션 빌드에서는 제거하는 것을 권장합니다.
class TokenDebugScreen extends StatefulWidget {
  const TokenDebugScreen({super.key});

  @override
  State<TokenDebugScreen> createState() => _TokenDebugScreenState();
}

class _TokenDebugScreenState extends State<TokenDebugScreen> {
  String? _idToken;
  String? _uid;
  String? _email;
  bool _isLoading = false;
  Map<String, dynamic>? _cacheInfo;

  @override
  void initState() {
    super.initState();
    _loadTokenInfo();
  }

  Future<void> _loadTokenInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        _uid = user.uid;
        _email = user.email;
        
        final tokenHelper = FirebaseAuthTokenHelper();
        _idToken = await tokenHelper.getIdToken();
        _cacheInfo = tokenHelper.getCacheInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('토큰 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshToken() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tokenHelper = FirebaseAuthTokenHelper();
      _idToken = await tokenHelper.refreshToken();
      _cacheInfo = tokenHelper.getCacheInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 토큰 갱신 완료')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('토큰 갱신 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📋 클립보드에 복사됨')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 ID Token 디버깅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshToken,
            tooltip: '토큰 갱신',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(
                  child: Text(
                    '로그인이 필요합니다',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 사용자 정보
                      _buildSection(
                        title: '👤 사용자 정보',
                        children: [
                          _buildInfoRow('UID', _uid ?? '-'),
                          _buildInfoRow('Email', _email ?? '-'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 캐시 정보
                      if (_cacheInfo != null) ...[
                        _buildSection(
                          title: '💾 캐시 정보',
                          children: [
                            _buildInfoRow(
                              '캐시 상태',
                              _cacheInfo!['hasCachedToken'] == true
                                  ? '✅ 활성'
                                  : '❌ 비활성',
                            ),
                            _buildInfoRow(
                              '유효성',
                              _cacheInfo!['isValid'] == true
                                  ? '✅ 유효'
                                  : '❌ 만료',
                            ),
                            _buildInfoRow(
                              '남은 시간',
                              _cacheInfo!['remainingMinutes'] != null
                                  ? '${_cacheInfo!['remainingMinutes']}분'
                                  : '-',
                            ),
                            _buildInfoRow(
                              '만료 시간',
                              _cacheInfo!['expiryTime'] ?? '-',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ID Token
                      _buildSection(
                        title: '🔐 ID Token',
                        children: [
                          if (_idToken != null) ...[
                            Container(
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Token (앞 50자)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 20),
                                        onPressed: () =>
                                            _copyToClipboard(_idToken!),
                                        tooltip: '전체 토큰 복사',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    _idToken!.length > 50
                                        ? '${_idToken!.substring(0, 50)}...'
                                        : _idToken!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '토큰 길이: ${_idToken!.length} 자',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _copyToClipboard(_idToken!),
                              icon: const Icon(Icons.copy),
                              label: const Text('전체 토큰 복사'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '💡 복사 후 jwt.io에서 디코딩 가능',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ] else ...[
                            const Text('토큰을 가져올 수 없습니다'),
                          ],
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 경고 메시지
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '⚠️ 이 화면은 개발/디버깅 전용입니다.\n프로덕션 빌드에서는 제거하세요.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
