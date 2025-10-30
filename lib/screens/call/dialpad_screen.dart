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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // 전화번호 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _phoneNumber.isEmpty ? '전화번호 입력' : _phoneNumber,
                      style: TextStyle(
                        fontSize: 32,
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
            const SizedBox(height: 32),
            // 키패드
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildKey('1', ''),
                    _buildKey('2', 'ABC'),
                    _buildKey('3', 'DEF'),
                    _buildKey('4', 'GHI'),
                    _buildKey('5', 'JKL'),
                    _buildKey('6', 'MNO'),
                    _buildKey('7', 'PQRS'),
                    _buildKey('8', 'TUV'),
                    _buildKey('9', 'WXYZ'),
                    _buildKey('*', ''),
                    _buildKey('0', '+'),
                    _buildKey('#', ''),
                  ],
                ),
              ),
            ),
            // 통화 버튼
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: FloatingActionButton.large(
                onPressed: _onCall,
                backgroundColor: const Color(0xFF4CAF50),
                child: const Icon(Icons.phone, size: 32, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String number, String letters) {
    return InkWell(
      onTap: () => _onKeyPressed(number),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withAlpha(77)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
