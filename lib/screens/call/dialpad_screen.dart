import 'package:flutter/material.dart';
import '../../widgets/call_method_dialog.dart';

class DialpadScreen extends StatefulWidget {
  const DialpadScreen({super.key});

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> {
  String _phoneNumber = '';

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
    // 화면 크기에 따른 반응형 크기 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final keyPadSize = (screenWidth - 80) / 3; // 3열 그리드
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: isSmallScreen ? 16 : 24),
            // 전화번호 표시
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 24, 
                vertical: isSmallScreen ? 8 : 16
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _phoneNumber.isEmpty ? '전화번호 입력' : _phoneNumber,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 24 : 32,
                        fontWeight: FontWeight.w400,
                        color: _phoneNumber.isEmpty ? Colors.grey : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_phoneNumber.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.backspace),
                      onPressed: _onBackspace,
                    ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            // 키패드
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 사용 가능한 높이에 맞춰 키 크기 계산
                  final availableHeight = constraints.maxHeight - 24;
                  final calculatedSize = availableHeight / 4;
                  final actualKeySize = calculatedSize < keyPadSize ? calculatedSize : keyPadSize;
                  
                  return Center(
                    child: SizedBox(
                      width: actualKeySize * 3 + 48,
                      child: GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildKey('1', '', actualKeySize),
                          _buildKey('2', 'ABC', actualKeySize),
                          _buildKey('3', 'DEF', actualKeySize),
                          _buildKey('4', 'GHI', actualKeySize),
                          _buildKey('5', 'JKL', actualKeySize),
                          _buildKey('6', 'MNO', actualKeySize),
                          _buildKey('7', 'PQRS', actualKeySize),
                          _buildKey('8', 'TUV', actualKeySize),
                          _buildKey('9', 'WXYZ', actualKeySize),
                          _buildKey('*', '', actualKeySize),
                          _buildKey('0', '+', actualKeySize),
                          _buildKey('#', '', actualKeySize),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // 통화 버튼
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
              child: SizedBox(
                width: isSmallScreen ? 64 : 72,
                height: isSmallScreen ? 64 : 72,
                child: FloatingActionButton(
                  onPressed: _onCall,
                  backgroundColor: const Color(0xFF4CAF50),
                  elevation: 4,
                  child: CustomPaint(
                    size: Size(isSmallScreen ? 32 : 36, isSmallScreen ? 32 : 36),
                    painter: PhoneIconPainter(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String number, String letters, double size) {
    final fontSize = size * 0.35;
    final letterSize = size * 0.12;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPressed(number),
        borderRadius: BorderRadius.circular(size / 2),
        splashColor: const Color(0xFF2196F3).withAlpha(51),
        highlightColor: const Color(0xFF2196F3).withAlpha(26),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.withAlpha(77),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  number,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w400,
                    color: Colors.black87,
                  ),
                ),
                if (letters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      letters,
                      style: TextStyle(
                        fontSize: letterSize,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 커스텀 전화 아이콘 페인터 (SVG 스타일)
class PhoneIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // 전화기 수화기 모양 그리기
    final w = size.width;
    final h = size.height;
    
    // 수화기 하단 부분
    path.moveTo(w * 0.25, h * 0.75);
    path.cubicTo(
      w * 0.15, h * 0.85,
      w * 0.1, h * 0.9,
      w * 0.15, h * 0.95,
    );
    path.lineTo(w * 0.2, h * 0.92);
    path.cubicTo(
      w * 0.25, h * 0.88,
      w * 0.3, h * 0.8,
      w * 0.35, h * 0.7,
    );
    
    // 중간 연결 부분
    path.lineTo(w * 0.65, h * 0.35);
    
    // 수화기 상단 부분
    path.cubicTo(
      w * 0.7, h * 0.25,
      w * 0.75, h * 0.2,
      w * 0.8, h * 0.15,
    );
    path.lineTo(w * 0.85, h * 0.1);
    path.cubicTo(
      w * 0.9, h * 0.05,
      w * 0.85, h * 0.0,
      w * 0.75, h * 0.1,
    );
    path.lineTo(w * 0.7, h * 0.15);
    path.cubicTo(
      w * 0.65, h * 0.2,
      w * 0.6, h * 0.28,
      w * 0.55, h * 0.38,
    );
    
    // 연결 부분
    path.lineTo(w * 0.25, h * 0.72);
    path.close();
    
    canvas.drawPath(path, paint);
    
    // 강조 효과를 위한 외곽선
    final outlinePaint = Paint()
      ..color = Colors.white.withAlpha(128)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
