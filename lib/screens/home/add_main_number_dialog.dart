import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/main_number_model.dart';

class AddMainNumberDialog extends StatefulWidget {
  final String userId;
  final MainNumberModel? mainNumber;

  const AddMainNumberDialog({
    super.key,
    required this.userId,
    this.mainNumber,
  });

  @override
  State<AddMainNumberDialog> createState() => _AddMainNumberDialogState();
}

class _AddMainNumberDialogState extends State<AddMainNumberDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.mainNumber?.name ?? '');
    _numberController = TextEditingController(text: widget.mainNumber?.number ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.mainNumber == null) {
        // 새로운 대표번호 추가
        final newMainNumber = MainNumberModel(
          id: '',
          userId: widget.userId,
          name: _nameController.text.trim(),
          number: _numberController.text.trim(),
          order: 0,
          createdAt: DateTime.now(),
        );
        await _databaseService.addMainNumber(newMainNumber);
      } else {
        // 기존 대표번호 수정
        await _databaseService.updateMainNumber(
          widget.mainNumber!.id,
          {
            'name': _nameController.text.trim(),
            'number': _numberController.text.trim(),
          },
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mainNumber == null
                  ? '대표번호가 추가되었습니다'
                  : '대표번호가 수정되었습니다',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mainNumber == null ? '대표번호 추가' : '대표번호 수정'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '대표번호 이름',
                hintText: '예: 회사명',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '대표번호 이름을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '대표번호',
                hintText: '예: 02-1234-5678',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '대표번호를 입력해주세요';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.mainNumber == null ? '추가' : '수정'),
        ),
      ],
    );
  }
}
