import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'audio_player_dialog.dart';

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
  String? _companyId;  // API 인증 - Company ID
  String? _appKey;     // API 인증 - App-Key

  @override
  void initState() {
    super.initState();
    
    // 🔍 디버그: linkedid 확인
    if (kDebugMode) {
      debugPrint('');
      debugPrint('📱 CallDetailDialog 초기화');
      debugPrint('  - Linkedid: ${widget.linkedid}');
      debugPrint('  - Linkedid 길이: ${widget.linkedid.length}');
      debugPrint('  - Linkedid null 체크: ${widget.linkedid.isEmpty ? "비어있음" : "값 존재"}');
    }
    
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
        debugPrint('❌ CDR API: 로그인 정보 없음');
        setState(() {
          _error = '로그인 정보가 없습니다';
          _isLoading = false;
        });
        return;
      }

      debugPrint('');
      debugPrint('='*60);
      debugPrint('🔍 CallDetailDialog 서버 설정 로드');
      debugPrint('='*60);
      debugPrint('👤 User ID: $userId');
      debugPrint('📂 Collection: users/$userId');
      debugPrint('');

      // users 컬렉션에서 API 서버 설정 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final apiBaseUrl = userData?['apiBaseUrl'] as String?;
        final apiHttpPort = userData?['apiHttpPort'] as int? ?? 3500; // 기본값: 3500 (http)
        final apiHttpsPort = userData?['apiHttpsPort'] as int? ?? 3501;
        
        // SSL 사용 여부 판단: apiHttpPort가 3501이면 HTTPS, 3500이면 HTTP
        final useHttps = apiHttpPort == 3501;
        final port = useHttps ? apiHttpsPort : apiHttpPort;
        
        final companyId = userData?['companyId'] as String?;
        final appKey = userData?['appKey'] as String?;
        
        debugPrint('📋 Firestore에서 로드한 설정:');
        debugPrint('  ├─ apiBaseUrl: ${apiBaseUrl ?? "(null)"}');
        debugPrint('  ├─ apiHttpPort: $apiHttpPort');
        debugPrint('  ├─ apiHttpsPort: $apiHttpsPort');
        debugPrint('  ├─ useHttps: $useHttps (${useHttps ? "HTTPS" : "HTTP"})');
        debugPrint('  ├─ 사용할 포트: $port');
        debugPrint('  ├─ companyId: ${companyId ?? "(null)"}');
        debugPrint('  └─ appKey: ${appKey ?? "(null)"}');
        debugPrint('');
        
        if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
          // CDR API 서버 URL 구성 (http/https + apiBaseUrl + port)
          final protocol = useHttps ? 'https' : 'http';
          _serverUrl = '$protocol://$apiBaseUrl:$port';
          _companyId = companyId;
          _appKey = appKey;
          
          debugPrint('✅ 서버 URL 구성 완료:');
          debugPrint('  └─ $_serverUrl');
          debugPrint('');
          debugPrint('🔐 인증 정보 상태:');
          if (_companyId == null || _companyId!.isEmpty) {
            debugPrint('  ├─ Company-Id: ❌ 설정되지 않음');
          } else {
            debugPrint('  ├─ Company-Id: ✅ $_companyId');
          }
          if (_appKey == null || _appKey!.isEmpty) {
            debugPrint('  └─ App-Key: ❌ 설정되지 않음');
          } else {
            debugPrint('  └─ App-Key: ✅ $_appKey');
          }
          debugPrint('='*60);
          debugPrint('');
          
          // 서버 설정 로드 완료 → CDR 조회 시작
          _fetchCallDetail();
        } else {
          debugPrint('❌ CDR API: API 서버 주소가 설정되지 않음');
          setState(() {
            _error = 'API 서버 설정이 없습니다\nProfileDrawer > 기본설정에서 API 서버 주소를 설정해주세요';
            _isLoading = false;
          });
        }
      } else {
        debugPrint('❌ CDR API: 사용자 문서를 찾을 수 없음');
        setState(() {
          _error = '사용자 정보를 찾을 수 없습니다';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ CDR API: 서버 설정 로드 실패 - $e');
      setState(() {
        _error = '서버 설정을 불러오는데 실패했습니다\n$e';
        _isLoading = false;
      });
    }
  }

  /// CDR API 호출
  Future<void> _fetchCallDetail() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      debugPrint('❌ CDR API: 서버 URL이 null 또는 빈 문자열');
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
      
      // 인증 헤더 구성
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      // companyId와 appKey 추가 (설정되어 있는 경우)
      if (_companyId != null && _companyId!.isNotEmpty) {
        headers['Company-Id'] = _companyId!;
      }
      if (_appKey != null && _appKey!.isNotEmpty) {
        headers['App-Key'] = _appKey!;
      }
      
      debugPrint('');
      debugPrint('='*60);
      debugPrint('🌐 CDR API 요청');
      debugPrint('='*60);
      debugPrint('📍 URL: $apiUrl');
      debugPrint('🔗 Linkedid: ${widget.linkedid}');
      debugPrint('');
      debugPrint('📋 요청 헤더 (Request Headers):');
      debugPrint('  ├─ Content-Type: application/json');
      if (_companyId != null && _companyId!.isNotEmpty) {
        debugPrint('  ├─ Company-Id: $_companyId');
      } else {
        debugPrint('  ├─ Company-Id: (없음)');
      }
      if (_appKey != null && _appKey!.isNotEmpty) {
        debugPrint('  └─ App-Key: $_appKey');
      } else {
        debugPrint('  └─ App-Key: (없음)');
      }
      debugPrint('');
      debugPrint('⏱️ Timeout: 10초');
      debugPrint('='*60);
      
      final startTime = DateTime.now();
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      final duration = DateTime.now().difference(startTime);
      
      debugPrint('📡 CDR API: 응답 수신');
      debugPrint('  - Status Code: ${response.statusCode}');
      debugPrint('  - Response Time: ${duration.inMilliseconds}ms');
      debugPrint('  - Content-Type: ${response.headers['content-type']}');
      debugPrint('  - Body Length: ${response.body.length} bytes');

      if (response.statusCode == 200) {
        debugPrint('✅ CDR API: 성공 (200 OK)');
        
        final data = json.decode(response.body);
        debugPrint('📦 CDR API: JSON 파싱 완료');
        
        // 응답 데이터 구조 로깅
        if (data is Map) {
          debugPrint('  - Response Type: Map');
          debugPrint('  - Keys: ${data.keys.join(', ')}');
          
          // data.result 또는 data 또는 results 배열 확인
          final cdrList = (data['data'] is Map)
              ? (data['data']['result'] ?? data['data']['results'])
              : (data['data'] ?? data['results']);
          
          debugPrint('  - cdrList type: ${cdrList.runtimeType}');
          debugPrint('  - cdrList is List: ${cdrList is List}');
          debugPrint('  - cdrList is null: ${cdrList == null}');
          
          if (cdrList is List) {
            debugPrint('  - CDR Records: ${cdrList.length}개');
            if (cdrList.isNotEmpty) {
              debugPrint('  - First Record Keys: ${(cdrList[0] as Map).keys.join(', ')}');
              debugPrint('  - First Record Sample: ${cdrList[0]}');
            } else {
              debugPrint('  - ⚠️ CDR List is empty!');
            }
          } else {
            debugPrint('  - ⚠️ No CDR list found in response!');
            debugPrint('  - Full Response: $data');
          }
        } else if (data is List) {
          debugPrint('  - Response Type: List');
          debugPrint('  - CDR Records: ${data.length}개');
        }
        
        setState(() {
          _cdrData = data;
          _isLoading = false;
        });
        
        debugPrint('✅ CDR API: UI 업데이트 완료');
      } else {
        debugPrint('❌ CDR API: 오류 응답');
        debugPrint('  - Status Code: ${response.statusCode}');
        debugPrint('  - Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        
        setState(() {
          _error = 'API 오류: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } on TimeoutException catch (e) {
      debugPrint('⏱️ CDR API: 타임아웃 (10초 초과)');
      debugPrint('  - Error: $e');
      setState(() {
        _error = '요청 시간 초과 (10초)\n서버가 응답하지 않습니다';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ CDR API: 예외 발생');
      debugPrint('  - Error Type: ${e.runtimeType}');
      debugPrint('  - Error Message: $e');
      
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

    // CDR 데이터 존재 확인
    if (_cdrData == null) {
      if (kDebugMode) {
        debugPrint('⚠️ _cdrData is null');
      }
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
              '통화 상세 정보가 없습니다\n(_cdrData is null)',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // CDR 리스트 추출
    final cdrList = (_cdrData!['data'] is Map)
        ? (_cdrData!['data']['result'] ?? _cdrData!['data']['results'] ?? [])
        : (_cdrData!['data'] ?? _cdrData!['results'] ?? []);
    
    if (kDebugMode) {
      debugPrint('🔍 _buildContent - CDR 데이터 체크');
      debugPrint('  - _cdrData is null: ${_cdrData == null}');
      debugPrint('  - _cdrData keys: ${_cdrData?.keys.join(', ')}');
      debugPrint('  - cdrList type: ${cdrList.runtimeType}');
      debugPrint('  - cdrList is List: ${cdrList is List}');
      if (cdrList is List) {
        debugPrint('  - cdrList.length: ${cdrList.length}');
      }
    }
    
    if (cdrList is! List || cdrList.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ CDR list is empty or not a list');
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '통화 상세 데이터가 없습니다\n(CDR list: ${cdrList is List ? '${cdrList.length}개' : 'not a list'})',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
    
    // CDR 데이터 파싱 (data.result 또는 data 또는 results 배열)
    final cdrList = (_cdrData!['data'] is Map)
        ? (_cdrData!['data']['result'] ?? _cdrData!['data']['results'] ?? [])
        : (_cdrData!['data'] ?? _cdrData!['results'] ?? []);
    
    if (cdrList is List && cdrList.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('📊 CDR 상세: ${cdrList.length}개 레코드 표시');
      }
      
      for (var i = 0; i < cdrList.length; i++) {
        final cdr = cdrList[i] as Map<String, dynamic>;
        
        // 통화 정보 헤더
        fields.add(_buildSectionHeader('통화 #${i + 1}'));
        fields.add(const SizedBox(height: 12));
        
        // 📞 기본 정보 섹션
        fields.add(_buildGroupHeader('기본 정보', Icons.info_outline, const Color(0xFF2196F3)));
        if (cdr['calldate'] != null) {
          fields.add(_buildCompactInfoRow('통화 시간', cdr['calldate'].toString(), Icons.access_time));
        }
        if (cdr['src'] != null) {
          fields.add(_buildCompactInfoRow('발신 번호', cdr['src'].toString(), Icons.call_made));
        }
        if (cdr['dst'] != null) {
          fields.add(_buildCompactInfoRow('수신 번호', cdr['dst'].toString(), Icons.call_received));
        }
        if (cdr['clid'] != null) {
          fields.add(_buildCompactInfoRow('발신자 ID', cdr['clid'].toString(), Icons.person));
        }
        fields.add(const SizedBox(height: 16));
        
        // ⏱️ 통화 시간 섹션
        fields.add(_buildGroupHeader('통화 시간', Icons.timer, const Color(0xFF4CAF50)));
        if (cdr['duration'] != null) {
          final duration = _formatDuration(cdr['duration']);
          fields.add(_buildCompactInfoRow('총 시간', duration, Icons.timelapse));
        }
        if (cdr['billsec'] != null) {
          final billsec = _formatDuration(cdr['billsec']);
          fields.add(_buildCompactInfoRow('통화 시간', billsec, Icons.timer_outlined));
        }
        if (cdr['disposition'] != null) {
          final dispositionText = _getDispositionText(cdr['disposition'].toString());
          fields.add(_buildCompactInfoRow('통화 상태', dispositionText, Icons.info));
        }
        fields.add(const SizedBox(height: 16));
        
        // 📡 채널 정보 섹션
        fields.add(_buildGroupHeader('채널 정보', Icons.phone_in_talk, const Color(0xFFFF9800)));
        if (cdr['channel'] != null) {
          fields.add(_buildCompactInfoRow('발신 채널', cdr['channel'].toString(), Icons.phone_forwarded));
        }
        if (cdr['dstchannel'] != null) {
          fields.add(_buildCompactInfoRow('수신 채널', cdr['dstchannel'].toString(), Icons.phone_callback));
        }
        if (cdr['lastapp'] != null) {
          fields.add(_buildCompactInfoRow('마지막 앱', cdr['lastapp'].toString(), Icons.apps));
        }
        if (cdr['lastdata'] != null) {
          fields.add(_buildCompactInfoRow('마지막 데이터', cdr['lastdata'].toString(), Icons.data_usage));
        }
        fields.add(const SizedBox(height: 16));
        
        // 🔑 시스템 ID 섹션
        fields.add(_buildGroupHeader('시스템 정보', Icons.fingerprint, const Color(0xFF9C27B0)));
        if (cdr['uniqueid'] != null) {
          fields.add(_buildCompactInfoRow('Unique ID', cdr['uniqueid'].toString(), Icons.fingerprint));
        }
        if (cdr['linkedid'] != null) {
          fields.add(_buildCompactInfoRow('Linked ID', cdr['linkedid'].toString(), Icons.link));
        }
        if (cdr['accountcode'] != null) {
          fields.add(_buildCompactInfoRow('계정 코드', cdr['accountcode'].toString(), Icons.account_box));
        }
        if (cdr['dcontext'] != null) {
          fields.add(_buildCompactInfoRow('컨텍스트', cdr['dcontext'].toString(), Icons.code));
        }
        fields.add(const SizedBox(height: 16));
        
        // 🎵 녹음 파일 섹션 (billsec >= 5초이고 recording_url이 존재하는 경우)
        final billsec = cdr['billsec'];
        final recordingUrl = cdr['recording_url'] as String?;
        
        if (billsec != null && 
            (billsec is int && billsec >= 5 || 
             billsec is String && (int.tryParse(billsec) ?? 0) >= 5) &&
            recordingUrl != null && 
            recordingUrl.isNotEmpty) {
          fields.add(_buildGroupHeader('녹음 파일', Icons.mic, const Color(0xFF9C27B0)));
          fields.add(const SizedBox(height: 8));
          fields.add(_buildRecordingButton(recordingUrl, cdr));
          fields.add(const SizedBox(height: 16));
        }
        
        // 구분선 (마지막 항목 제외)
        if (i < cdrList.length - 1) {
          fields.add(const Divider(height: 32, thickness: 2));
          fields.add(const SizedBox(height: 16));
        }
      }
    } else {
      fields.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              '통화 상세 데이터가 없습니다',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ),
      );
    }
    
    return fields;
  }
  
  /// 그룹 헤더 (섹션 구분)
  Widget _buildGroupHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 간결한 정보 행 (라벨 + 값)
  Widget _buildCompactInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 시간 포맷팅 (초 → MM:SS)
  String _formatDuration(dynamic seconds) {
    try {
      int sec = 0;
      if (seconds is int) {
        sec = seconds;
      } else if (seconds is String) {
        sec = int.tryParse(seconds) ?? 0;
      }
      
      final minutes = sec ~/ 60;
      final remainingSeconds = sec % 60;
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } catch (e) {
      return seconds.toString();
    }
  }
  
  /// Disposition 텍스트 변환
  String _getDispositionText(String disposition) {
    switch (disposition.toUpperCase()) {
      case 'ANSWERED':
        return '✅ 응답됨';
      case 'NO ANSWER':
        return '❌ 무응답';
      case 'BUSY':
        return '📵 통화중';
      case 'FAILED':
        return '⚠️ 실패';
      case 'CONGESTION':
        return '🚫 혼잡';
      default:
        return disposition;
    }
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
  
  /// 녹음 파일 재생 버튼
  Widget _buildRecordingButton(String recordingUrl, Map<String, dynamic> cdr) {
    final billsec = cdr['billsec'];
    String billsecText = '통화 시간: ';
    
    if (billsec is int) {
      billsecText += _formatDuration(billsec);
    } else if (billsec is String) {
      billsecText += _formatDuration(billsec);
    } else {
      billsecText += '알 수 없음';
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (kDebugMode) {
              debugPrint('🎵 녹음 파일 재생 시작');
              debugPrint('  - URL: $recordingUrl');
              debugPrint('  - billsec: $billsec');
            }
            
            // 발신/수신 번호 확인
            final src = cdr['src']?.toString() ?? '';
            final dst = cdr['dst']?.toString() ?? '';
            final title = src.isNotEmpty ? '$src → $dst' : '녹음 파일';
            
            showDialog(
              context: context,
              builder: (context) => AudioPlayerDialog(
                audioUrl: recordingUrl,
                title: title,
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9C27B0),
                  Color(0xFF7B1FA2),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '녹음 파일 재생',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        billsecText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
