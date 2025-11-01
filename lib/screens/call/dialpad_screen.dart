import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../widgets/call_method_dialog.dart';

class DialpadScreen extends StatefulWidget {
  const DialpadScreen({super.key});

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> {
  String _phoneNumber = '';

  // 플랫폼 감지
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  void _onKeyPressed(String key) {
    setState(() {
      _phoneNumber += key;
    });
  }

  void _onBackspace() {
    if (_phoneNumber.isNotEmpty) {
      setState(() {
        _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      });
    }
  }

  void _onCall() {
    if (_phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 입력해주세요')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(phoneNumber: _phoneNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              // 랜드스케이프 모드: 가로 레이아웃
              return _buildLandscapeLayout();
            } else {
              // 포트레이트 모드: 세로 레이아웃
              return _buildPortraitLayout();
            }
          },
        ),
      ),
    );
  }

  // 세로 모드 레이아웃
  Widget _buildPortraitLayout() {
    final bool isIOS = _isIOS;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 사용 가능한 높이 계산
        final availableHeight = constraints.maxHeight;
        
        // iOS 스타일: 더 많은 여백, 더 큰 버튼
        final phoneNumberHeight = isIOS ? 100.0 : 80.0;
        final callButtonHeight = isIOS ? 120.0 : 100.0;
        final keypadPadding = isIOS ? 24.0 : 20.0;
        final keySpacing = isIOS ? 16.0 : 12.0;
        
        return Column(
          children: [
            // 전화번호 표시 영역
            SizedBox(
              height: phoneNumberHeight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: keypadPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _phoneNumber.isEmpty ? '' : _phoneNumber,
                        style: TextStyle(
                          fontSize: isIOS ? 36 : 32,
                          fontWeight: FontWeight.w300,
                          letterSpacing: isIOS ? 0.5 : 1,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_phoneNumber.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.backspace_outlined,
                          color: isIOS ? Colors.grey[600] : Colors.grey[700],
                        ),
                        iconSize: isIOS ? 26 : 28,
                        onPressed: _onBackspace,
                      ),
                  ],
                ),
              ),
            ),

            // 키패드 영역 (Expanded로 남은 공간 채우기)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isIOS ? 350 : 400,
                    maxHeight: availableHeight - phoneNumberHeight - callButtonHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: keypadPadding,
                      vertical: isIOS ? 12 : 10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildKeypadRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                        SizedBox(height: keySpacing),
                        _buildKeypadRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                        SizedBox(height: keySpacing),
                        _buildKeypadRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                        SizedBox(height: keySpacing),
                        _buildKeypadRow(['*', '0', '#'], ['', '+', '']),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 통화 버튼 영역
            SizedBox(
              height: callButtonHeight,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isIOS ? 32 : 16,
                    top: isIOS ? 16 : 16,
                  ),
                  child: _buildCallButton(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 가로 모드 레이아웃
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // 왼쪽: 전화번호 표시 및 통화 버튼
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 전화번호 표시
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _phoneNumber.isEmpty ? '' : _phoneNumber,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_phoneNumber.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.backspace_outlined, color: Colors.grey[600]),
                        iconSize: 24,
                        onPressed: _onBackspace,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 통화 버튼
              _buildCallButton(),
            ],
          ),
        ),

        // 오른쪽: 키패드
        Expanded(
          flex: 3,
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildKeypadRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                      const SizedBox(height: 8),
                      _buildKeypadRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                      const SizedBox(height: 8),
                      _buildKeypadRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                      const SizedBox(height: 8),
                      _buildKeypadRow(['*', '0', '#'], ['', '+', '']),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers, List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildKey(numbers[index], letters[index]),
          ),
        );
      }),
    );
  }

  Widget _buildKey(String number, String letters) {
    // Android/iOS 네이티브 스타일 구분
    final bool isAndroidStyle = _isAndroid || kIsWeb; // Web은 Android 스타일 사용
    final bool isIOS = _isIOS;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 랜드스케이프 모드에서는 더 작은 크기 사용
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
        
        // iOS: 더 큰 버튼 크기
        double size;
        if (isLandscape) {
          size = constraints.maxWidth.clamp(50.0, 70.0);
        } else if (isIOS) {
          // iOS: 최대 75px로 제한하여 화면에 맞춤
          size = constraints.maxWidth.clamp(60.0, 75.0);
        } else {
          size = constraints.maxWidth;
        }
        
        return SizedBox(
          width: size,
          height: size,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onKeyPressed(number),
              customBorder: const CircleBorder(),
              splashColor: isAndroidStyle 
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.blue.withOpacity(0.1),
              highlightColor: isAndroidStyle
                  ? Colors.grey.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.05),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Android: 테두리 없음, iOS: 얇은 테두리
                  border: isAndroidStyle
                      ? null
                      : Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                  // iOS 스타일 배경
                  color: isIOS ? Colors.grey.withOpacity(0.08) : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 숫자
                      Text(
                        number,
                        style: TextStyle(
                          fontSize: isLandscape 
                              ? 24 
                              : (isIOS ? 38 : (isAndroidStyle ? 32 : 36)),
                          fontWeight: isIOS 
                              ? FontWeight.w200 
                              : (isAndroidStyle ? FontWeight.w300 : FontWeight.w200),
                          color: Colors.black87,
                          height: 1.0,
                        ),
                      ),
                      // 문자
                      if (letters.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: isIOS ? 3 : 2),
                          child: Text(
                            letters,
                            style: TextStyle(
                              fontSize: isLandscape 
                                  ? 8 
                                  : (isIOS ? 10 : (isAndroidStyle ? 10 : 9)),
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                              letterSpacing: isIOS ? 1.0 : (isAndroidStyle ? 1.2 : 0.8),
                              height: 1.0,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallButton() {
    final bool isAndroidStyle = _isAndroid || kIsWeb;
    final bool isIOS = _isIOS;
    
    // iOS: 더 큰 버튼
    final buttonSize = isIOS ? 72.0 : 64.0;
    final iconSize = isIOS ? 34.0 : (isAndroidStyle ? 32.0 : 30.0);
    
    return Material(
      elevation: isAndroidStyle ? 4 : 1,
      shape: const CircleBorder(),
      color: isAndroidStyle ? const Color(0xFF4CAF50) : const Color(0xFF34C759),
      child: InkWell(
        onTap: _onCall,
        customBorder: const CircleBorder(),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.phone,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}
