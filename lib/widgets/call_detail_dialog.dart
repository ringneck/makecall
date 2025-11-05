import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 통화 상세 내역 다이얼로그
class CallDetailDialog extends StatefulWidget {
  final String linkedid;

  const CallDetailDialog({
    super.key,
    required this.linkedid,
  });

  @override
  State<CallDetailDialog> createState() => _CallDetailDialogState();
}

class _CallDetailDialogState extends State<CallDetailDialog> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _cdrData;
  String? _serverUrl; // ProfileDrawer 서버 설정

  @override
  void initState() {
    super.initState();
    _loadServerSettings();
  }

  /// ProfileDrawer 서버 설정 로드
  Future<void> _loadServerSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = '로그인 정보가 없습니다';
          _isLoading = false;
        });
        return;
      }

      // users 컬렉션에서 API 서버 설정 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final apiBaseUrl = userData?['apiBaseUrl'] as String?;
        final apiHttpsPort = userData?['apiHttpsPort'] as int? ?? 3501;
        final useHttps = apiHttpsPort == 3501;
        
        if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
          // CDR API 서버 URL 구성 (http/https + apiBaseUrl)
          final protocol = useHttps ? 'https' : 'http';
          _serverUrl = '$protocol://$apiBaseUrl';
          
          // 서버 설정 로드 완료 → CDR 조회 시작
          _fetchCallDetail();
        } else {
          setState(() {
            _error = 'API 서버 설정이 없습니다\nProfileDrawer > 기본설정에서 API 서버 주소를 설정해주세요';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = '사용자 정보를 찾을 수 없습니다';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '서버 설정을 불러오는데 실패했습니다\n$e';
        _isLoading = false;
      });
    }
  }

  /// CDR API 호출
  Future<void> _fetchCallDetail() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      setState(() {
        _error = '서버 URL이 설정되지 않았습니다';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // ProfileDrawer 서버 설정 사용
      final apiUrl = '$_serverUrl/api/v2/cdr?search=${widget.linkedid}&search_fields=linkedid';
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          // 필요시 인증 헤더 추가
          // 'Authorization': 'Bearer YOUR_TOKEN',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _cdrData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'API 오류: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '통화 상세 정보를 불러오는데 실패했습니다\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2196F3),
                    Color(0xFF1976D2),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '통화 상세 내역',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 내용
            Expanded(
              child: _buildContent(),
            ),

            // 하단 버튼
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_error != null)
                    TextButton.icon(
                      onPressed: _loadServerSettings,
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 시도'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2196F3),
                      ),
                    ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('닫기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '통화 상세 정보를 불러오는 중...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cdrData == null || _cdrData!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '통화 상세 정보가 없습니다',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'Linked ID',
            value: widget.linkedid,
            icon: Icons.link,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          ..._buildCDRFields(),
        ],
      ),
    );
  }

  List<Widget> _buildCDRFields() {
    final List<Widget> fields = [];
    
    // CDR 데이터 파싱 (실제 API 응답 구조에 맞게 수정 필요)
    final cdrList = _cdrData!['data'] ?? _cdrData!['results'] ?? [];
    
    if (cdrList is List && cdrList.isNotEmpty) {
      for (var i = 0; i < cdrList.length; i++) {
        final cdr = cdrList[i];
        
        fields.add(
          _buildSectionHeader('통화 정보 ${i + 1}'),
        );
        
        // 주요 필드 매핑
        final fieldMappings = {
          'calldate': {'label': '통화 시간', 'icon': Icons.access_time, 'color': Colors.green},
          'clid': {'label': '발신자 ID', 'icon': Icons.person, 'color': Colors.blue},
          'src': {'label': '발신 번호', 'icon': Icons.call_made, 'color': Colors.orange},
          'dst': {'label': '수신 번호', 'icon': Icons.call_received, 'color': Colors.purple},
          'dcontext': {'label': '컨텍스트', 'icon': Icons.code, 'color': Colors.cyan},
          'channel': {'label': '채널', 'icon': Icons.phone_in_talk, 'color': Colors.indigo},
          'dstchannel': {'label': '대상 채널', 'icon': Icons.phone_forwarded, 'color': Colors.teal},
          'lastapp': {'label': '마지막 앱', 'icon': Icons.apps, 'color': Colors.deepOrange},
          'lastdata': {'label': '마지막 데이터', 'icon': Icons.data_usage, 'color': Colors.brown},
          'duration': {'label': '총 시간', 'icon': Icons.timer, 'color': Colors.red},
          'billsec': {'label': '통화 시간', 'icon': Icons.timer_outlined, 'color': Colors.pink},
          'disposition': {'label': '통화 상태', 'icon': Icons.info, 'color': Colors.amber},
          'amaflags': {'label': 'AMA 플래그', 'icon': Icons.flag, 'color': Colors.lightBlue},
          'accountcode': {'label': '계정 코드', 'icon': Icons.account_box, 'color': Colors.deepPurple},
          'uniqueid': {'label': 'Unique ID', 'icon': Icons.fingerprint, 'color': Colors.grey},
          'userfield': {'label': '사용자 필드', 'icon': Icons.person_outline, 'color': Colors.blueGrey},
        };

        fieldMappings.forEach((key, value) {
          if (cdr[key] != null && cdr[key].toString().isNotEmpty) {
            fields.add(
              _buildInfoCard(
                title: value['label'] as String,
                value: cdr[key].toString(),
                icon: value['icon'] as IconData,
                color: value['color'] as Color,
              ),
            );
            fields.add(const SizedBox(height: 8));
          }
        });
        
        // 나머지 필드들 (매핑되지 않은 필드)
        cdr.forEach((key, value) {
          if (!fieldMappings.containsKey(key) && value != null && value.toString().isNotEmpty) {
            fields.add(
              _buildInfoCard(
                title: key,
                value: value.toString(),
                icon: Icons.label,
                color: Colors.grey,
              ),
            );
            fields.add(const SizedBox(height: 8));
          }
        });
        
        if (i < cdrList.length - 1) {
          fields.add(const Divider(height: 32, thickness: 2));
        }
      }
    } else {
      // 단일 객체인 경우
      _cdrData!.forEach((key, value) {
        if (key != 'success' && key != 'message' && value != null) {
          fields.add(
            _buildInfoCard(
              title: key,
              value: value.toString(),
              icon: Icons.label,
              color: Colors.grey,
            ),
          );
          fields.add(const SizedBox(height: 8));
        }
      });
    }

    return fields;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1976D2),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
