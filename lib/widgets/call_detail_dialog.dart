import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'audio_player_dialog.dart';
import 'package:flutter_app/utils/platform_user_agent.dart';
// 조건부 import: 웹에서만 dart:html, 모바일에서는 빈 구현
import 'download_helper_web.dart' if (dart.library.io) 'download_helper_mobile.dart';

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
  
  // 🔽 접기/펼치기 상태
  bool _isChannelInfoExpanded = false;  // 채널 정보 초기값: 접힘
  bool _isSystemInfoExpanded = false;   // 시스템 정보 초기값: 접힘

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
        
        // 🎵 녹음 파일 섹션 (최상단 배치 - billsec >= 5초이고 recording_url이 존재하는 경우)
        final billsec = cdr['billsec'];
        final recordingUrl = cdr['recording_url'] as String?;
        
        if (billsec != null && 
            (billsec is int && billsec >= 5 || 
             billsec is String && (int.tryParse(billsec) ?? 0) >= 5) &&
            recordingUrl != null && 
            recordingUrl.isNotEmpty) {
          fields.add(_buildCompactRecordingButton(recordingUrl, cdr));
          fields.add(const SizedBox(height: 16));
        }
        
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
        
        // 📡 채널 정보 섹션 (접기/펼치기)
        fields.add(_buildExpandableGroupHeader(
          title: '채널 정보',
          icon: Icons.phone_in_talk,
          color: const Color(0xFFFF9800),
          isExpanded: _isChannelInfoExpanded,
          onTap: () {
            setState(() {
              _isChannelInfoExpanded = !_isChannelInfoExpanded;
            });
          },
        ));
        if (_isChannelInfoExpanded) {
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
        }
        fields.add(const SizedBox(height: 16));
        
        // 🔑 시스템 정보 섹션 (접기/펼치기)
        fields.add(_buildExpandableGroupHeader(
          title: '시스템 정보',
          icon: Icons.fingerprint,
          color: const Color(0xFF9C27B0),
          isExpanded: _isSystemInfoExpanded,
          onTap: () {
            setState(() {
              _isSystemInfoExpanded = !_isSystemInfoExpanded;
            });
          },
        ));
        if (_isSystemInfoExpanded) {
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
        }
        fields.add(const SizedBox(height: 16));
        
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
  
  /// 접기/펼치기 가능한 그룹 헤더
  Widget _buildExpandableGroupHeader({
    required String title,
    required IconData icon,
    required Color color,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 24,
              color: color,
            ),
          ],
        ),
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
  
  /// 디바이스에 따라 녹음 파일 확장자 변환
  /// - Chrome/Edge: WAV 그대로 사용
  /// - iOS/Safari/기타: MP3로 변환
  String _convertRecordingUrlForDevice(String url) {
    // 웹 환경에서 User-Agent 확인
    if (kIsWeb) {
      // User-Agent를 통해 브라우저 감지
      final userAgent = PlatformUserAgent.getUserAgent().toLowerCase();
      
      // Chrome 또는 Edge인 경우 WAV 그대로 사용
      final isChrome = userAgent.contains('chrome') && !userAgent.contains('edg');
      final isEdge = userAgent.contains('edg');
      
      if (isChrome || isEdge) {
        // Chrome/Edge: WAV 파일 그대로 사용
        if (kDebugMode) {
          debugPrint('🎵 브라우저: ${isChrome ? "Chrome" : "Edge"} - WAV 파일 사용');
        }
        return url;
      }
      
      // iOS, Safari, Firefox 등 기타 브라우저: MP3로 변환
      if (url.toLowerCase().endsWith('.wav')) {
        final mp3Url = url.substring(0, url.length - 4) + '.mp3';
        if (kDebugMode) {
          debugPrint('🎵 브라우저: 기타 (iOS/Safari/Firefox) - MP3로 변환');
          debugPrint('   원본: $url');
          debugPrint('   변환: $mp3Url');
        }
        return mp3Url;
      }
    } else {
      // 모바일 플랫폼 (iOS/Android): 항상 MP3 사용
      if (url.toLowerCase().endsWith('.wav')) {
        final mp3Url = url.substring(0, url.length - 4) + '.mp3';
        if (kDebugMode) {
          debugPrint('🎵 모바일 플랫폼: MP3로 변환');
          debugPrint('   원본: $url');
          debugPrint('   변환: $mp3Url');
        }
        return mp3Url;
      }
    }
    
    // 변환 불필요한 경우 원본 반환
    return url;
  }
  
  /// 녹음 파일 다운로드 (모든 플랫폼 지원: Web, iOS, Android)
  Future<void> _downloadRecordingFile(String recordingUrl, String filename) async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('='*60);
        debugPrint('📥 녹음 파일 다운로드 시작');
        debugPrint('='*60);
        debugPrint('  - 플랫폼: ${kIsWeb ? "Web" : "Mobile (iOS/Android)"}');
        debugPrint('  - 원본 URL: $recordingUrl');
        debugPrint('  - 파일명: $filename');
      }

      // 변환된 URL 사용 (플랫폼별 최적화)
      var convertedUrl = _convertRecordingUrlForDevice(recordingUrl);
      
      // 🔧 iOS/Android 기기에서 localhost/127.0.0.1 URL 처리
      if (!kIsWeb) {
        final uri = Uri.parse(convertedUrl);
        if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
          if (kDebugMode) {
            debugPrint('⚠️ localhost URL 감지!');
            debugPrint('  - 현재 호스트: ${uri.host}');
            debugPrint('');
            debugPrint('❌ iOS/Android 기기는 localhost에 접근할 수 없습니다.');
            debugPrint('');
            debugPrint('💡 해결 방법:');
            debugPrint('  1. 서버를 컴퓨터의 실제 IP 주소로 접근하세요');
            debugPrint('  2. 예: http://192.168.1.100:${uri.port}${uri.path}');
            debugPrint('  3. 또는 공인 도메인을 사용하세요');
            debugPrint('');
            debugPrint('🔍 현재 설정된 서버 URL: $_serverUrl');
            debugPrint('='*60);
          }
          
          throw Exception(
            'localhost 접근 불가\n\n'
            'iOS/Android 기기는 localhost(${uri.host})에 접근할 수 없습니다.\n\n'
            '해결 방법:\n'
            '1. 프로필 설정에서 서버 주소를 변경하세요\n'
            '2. localhost 대신 컴퓨터의 실제 IP를 사용하세요\n'
            '   예: 192.168.1.100 (Wi-Fi 설정에서 확인)\n\n'
            '현재 서버 URL: $_serverUrl'
          );
        }
        
        if (kDebugMode) {
          debugPrint('  - 변환된 URL: $convertedUrl');
          debugPrint('  - 호스트: ${uri.host}');
          debugPrint('  - 포트: ${uri.port}');
          debugPrint('  - 경로: ${uri.path}');
          debugPrint('='*60);
          debugPrint('');
        }
      }
      
      if (kIsWeb) {
        // 웹 플랫폼: 즉시 다운로드
        await downloadFile(convertedUrl, filename);
        
        if (mounted) {
          await DialogUtils.showSuccess(
            context,
            '다운로드 시작\n\n$filename',
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // 모바일 플랫폼 (iOS/Android): Share Sheet로 저장/공유
        if (mounted) {
          // 다운로드 진행 중 표시
          await DialogUtils.showInfo(
            context,
            '파일 다운로드 중...',
            duration: const Duration(seconds: 2),
          );
        }
        
        // 비동기 다운로드 및 공유
        await downloadFile(convertedUrl, filename);
        
        if (mounted) {
          await DialogUtils.showSuccess(
            context,
            '파일 공유\n\n$filename',
            duration: const Duration(seconds: 3),
          );
        }
      }
      
      if (kDebugMode) {
        debugPrint('✅ 녹음 파일 다운로드 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('='*60);
        debugPrint('❌ 녹음 파일 다운로드 오류');
        debugPrint('='*60);
        debugPrint('오류 내용: $e');
        debugPrint('스택 추적: ${StackTrace.current}');
        debugPrint('='*60);
        debugPrint('');
      }
      
      if (mounted) {
        // 에러 메시지에서 상세 정보 추출
        final errorMessage = e.toString();
        String displayMessage;
        
        if (errorMessage.contains('localhost 접근 불가')) {
          displayMessage = 'localhost는 모바일 기기에서\n접근할 수 없습니다.\n\n'
              '프로필 설정에서 서버 주소를\n'
              '실제 IP로 변경하세요.\n'
              '(예: 192.168.1.100)';
        } else if (errorMessage.contains('TimeoutException') || errorMessage.contains('시간 초과')) {
          displayMessage = '다운로드 시간 초과.\n서버 응답이 없습니다.';
        } else if (errorMessage.contains('SocketException') || errorMessage.contains('연결 실패')) {
          displayMessage = '서버 연결 실패.\n서버 주소와 네트워크를 확인하세요.';
        } else if (errorMessage.contains('HTTP')) {
          displayMessage = '서버 오류.\n잠시 후 다시 시도하세요.';
        } else if (errorMessage.contains('FileSystemException')) {
          displayMessage = '파일 저장 실패.\n저장 공간을 확인하세요.';
        } else {
          displayMessage = kIsWeb 
              ? '다운로드 실패.\n잠시 후 다시 시도해주세요.'
              : '다운로드 실패.\n서버 연결을 확인해주세요.';
        }
        
        await DialogUtils.showError(
          context,
          '파일 다운로드 실패\n\n$displayMessage${kDebugMode ? "\n\n상세: ${errorMessage.length > 100 ? errorMessage.substring(0, 100) + "..." : errorMessage}" : ""}',
          duration: const Duration(seconds: 5),
        );
      }
    }
  }

  /// 간단하고 깔끔한 녹음 파일 재생/다운로드 버튼 (개선형)
  Widget _buildCompactRecordingButton(String recordingUrl, Map<String, dynamic> cdr) {
    final billsec = cdr['billsec'];
    String durationText = '';
    
    if (billsec is int) {
      durationText = _formatDuration(billsec);
    } else if (billsec is String) {
      durationText = _formatDuration(billsec);
    }
    
    // 발신/수신 번호로 파일명 생성
    final src = cdr['src']?.toString() ?? '';
    final dst = cdr['dst']?.toString() ?? '';
    final calldate = cdr['calldate']?.toString() ?? '';
    final title = src.isNotEmpty ? '$src → $dst' : '녹음 파일';
    
    // 파일명 생성 (예: recording_01012345678_20240108_143022.wav)
    String filename = 'recording';
    if (src.isNotEmpty && dst.isNotEmpty) {
      filename += '_${src}_to_$dst';
    }
    if (calldate.isNotEmpty) {
      // calldate format: 2024-01-08 14:30:22
      final dateStr = calldate.replaceAll(RegExp(r'[:\s-]'), '');
      filename += '_$dateStr';
    }
    filename += '.wav';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF9C27B0).withValues(alpha: 0.1),
              const Color(0xFF7B1FA2).withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (아이콘 + 제목 + 시간)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.graphic_eq,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎵 통화 녹음',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                      if (durationText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              durationText,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 버튼 그룹 (재생 + 다운로드)
            Row(
              children: [
                // 재생 버튼
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final convertedUrl = _convertRecordingUrlForDevice(recordingUrl);
                        
                        if (kDebugMode) {
                          debugPrint('🎵 녹음 파일 재생 시작');
                          debugPrint('  - 원본 URL: $recordingUrl');
                          debugPrint('  - 변환 URL: $convertedUrl');
                          debugPrint('  - billsec: $billsec');
                        }
                        
                        showDialog(
                          context: context,
                          builder: (context) => AudioPlayerDialog(
                            audioUrl: convertedUrl,
                            title: title,
                            billsec: billsec,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '재생',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 다운로드 버튼
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _downloadRecordingFile(recordingUrl, filename);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF9C27B0),
                            width: 1.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download,
                              color: Color(0xFF9C27B0),
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              '다운로드',
                              style: TextStyle(
                                color: Color(0xFF9C27B0),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
