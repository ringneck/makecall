import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 📜 약관 및 정책 섹션
/// 
/// 기능:
/// - 서비스 이용 약관 (외부 링크)
/// - 개인정보 처리방침 (외부 링크)
/// - 오픈소스 라이선스 (Flutter LicenseRegistry)
/// 
/// 독립적인 StatelessWidget으로 구현:
/// - 자체적으로 모든 다이얼로그와 페이지 관리
/// - 외부 URL 열기 (url_launcher)
/// - WebView를 통한 HTML 표시
/// - 부모 위젯과의 결합도 최소화
class TermsAndPoliciesSection extends StatelessWidget {
  const TermsAndPoliciesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.purple[900]!.withValues(alpha: 0.3) : Colors.purple[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.purple[700]! : Colors.purple[100]!),
        ),
        child: ExpansionTile(
          leading: Icon(
            Icons.description, 
            color: isDark ? Colors.purple[300] : Colors.purple,
          ),
          title: Text(
            '약관 및 정책',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            '이용약관, 개인정보처리방침, 라이선스', 
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.black54,
            ),
          ),
          iconColor: isDark ? Colors.purple[300] : Colors.purple,
          collapsedIconColor: isDark ? Colors.purple[300] : Colors.purple,
          children: [
            // 서비스 이용 약관
            ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              leading: Icon(
                Icons.description, 
                size: 20, 
                color: isDark ? Colors.grey[400] : Colors.black54,
              ),
              title: Text(
                '서비스 이용 약관', 
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new, 
                size: 18,
                color: isDark ? Colors.grey[500] : Colors.grey,
              ),
              onTap: () {
                _openExternalUrl('https://app.makecall.io/terms_of_service.html');
              },
            ),
            
            // 개인정보 처리방침
            ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              leading: Icon(
                Icons.privacy_tip, 
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.black54,
              ),
              title: Text(
                '개인정보 처리방침', 
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new, 
                size: 18,
                color: isDark ? Colors.grey[500] : Colors.grey,
              ),
              onTap: () {
                _openExternalUrl('https://app.makecall.io/privacy_policy.html');
              },
            ),
            
            // 오픈소스 라이선스
            ListTile(
              contentPadding: const EdgeInsets.only(left: 56, right: 16),
              leading: Icon(
                Icons.code, 
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.black54,
              ),
              title: Text(
                '오픈소스 라이선스', 
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right, 
                size: 18,
                color: isDark ? Colors.grey[500] : Colors.grey,
              ),
              onTap: () {
                _showLicensePage(context);
              },
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 🔗 외부 URL 열기
  Future<void> _openExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (kDebugMode) {
          debugPrint('❌ URL을 열 수 없습니다: $url');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ URL 열기 오류: $e');
      }
    }
  }

  /// 📄 WebView로 HTML 페이지 표시
  void _showWebViewPage(BuildContext context, String title, String assetPath) async {
    // HTML 파일 내용 로드
    final htmlContent = await rootBundle.loadString(assetPath);
    
    if (!context.mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            backgroundColor: title.contains('서비스') 
                ? const Color(0xFF2196F3) 
                : const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          body: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadHtmlString(htmlContent),
          ),
        ),
      ),
    );
  }

  /// 📋 간단한 텍스트 다이얼로그
  void _showTextDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 📜 오픈소스 라이선스 페이지
  void _showLicensePage(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 라이선스 정보 수집
    final licenseData = <String, List<LicenseEntry>>{};
    await for (final license in LicenseRegistry.licenses) {
      for (final package in license.packages) {
        if (!licenseData.containsKey(package)) {
          licenseData[package] = [];
        }
        licenseData[package]!.add(license);
      }
    }

    // 패키지 이름 정렬
    final sortedPackages = licenseData.keys.toList()..sort();

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          appBar: AppBar(
            title: const Text('오픈소스 라이선스'),
            backgroundColor: isDark ? Colors.grey[850] : const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              // 헤더 정보
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.blue[900]!.withValues(alpha: 0.5), Colors.blue[800]!.withValues(alpha: 0.5)]
                        : [Colors.blue[50]!, Colors.blue[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '총 ${sortedPackages.length}개의 오픈소스 패키지',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue[200] : Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '이 앱은 다음 오픈소스 소프트웨어를 사용합니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 라이선스 목록
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sortedPackages.length,
                  itemBuilder: (context, index) {
                    final package = sortedPackages[index];
                    final licenses = licenseData[package]!;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.blue[900]!.withValues(alpha: 0.5)
                                : Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.code,
                            size: 20,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                        ),
                        title: Text(
                          package,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[200] : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${licenses.length}개 라이선스',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        onTap: () {
                          _showLicenseDetail(context, package, licenses);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 📋 라이선스 상세 정보 다이얼로그
  void _showLicenseDetail(BuildContext context, String package, List<LicenseEntry> licenses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.blue[900]!.withValues(alpha: 0.5), Colors.blue[800]!.withValues(alpha: 0.5)]
                        : [Colors.blue[50]!, Colors.blue[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.code,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        package,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[200] : Colors.blue[900],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // 라이선스 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: licenses.map((license) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[850] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            child: SelectableText(
                              license.paragraphs
                                  .map((p) => p.text)
                                  .join('\n\n'),
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                height: 1.5,
                                color: isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              // 하단 버튼
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[700] : const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
