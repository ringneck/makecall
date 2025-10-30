import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/database_service.dart';

class AddContactDialog extends StatefulWidget {
  final String userId;
  final ContactModel? contact; // null이면 추가, 있으면 수정

  const AddContactDialog({
    super.key,
    required this.userId,
    this.contact,
  });

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isFavorite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phoneNumber;
      _emailController.text = widget.contact!.email ?? '';
      _companyController.text = widget.contact!.company ?? '';
      _notesController.text = widget.contact!.notes ?? '';
      _isFavorite = widget.contact!.isFavorite;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.contact != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEdit ? Icons.edit : Icons.person_add,
            color: const Color(0xFF2196F3),
          ),
          const SizedBox(width: 12),
          Text(isEdit ? '연락처 수정' : '연락처 추가'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 이름
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름 *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 전화번호
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호 *',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                  hintText: '010-1234-5678',
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '전화번호를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 이메일
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // 회사
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: '회사',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 메모
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // 즐겨찾기
              SwitchListTile(
                title: const Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text('즐겨찾기에 추가'),
                  ],
                ),
                value: _isFavorite,
                onChanged: (value) {
                  setState(() {
                    _isFavorite = value;
                  });
                },
                activeTrackColor: Colors.amber[200],
                activeThumbColor: Colors.amber,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveContact,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEdit ? '수정' : '추가'),
        ),
      ],
    );
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService();

      if (widget.contact != null) {
        // 수정
        await dbService.updateContact(
          widget.contact!.id,
          {
            'name': _nameController.text.trim(),
            'phoneNumber': _phoneController.text.trim(),
            'email': _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            'company': _companyController.text.trim().isEmpty
                ? null
                : _companyController.text.trim(),
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            'isFavorite': _isFavorite,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        if (context.mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('연락처가 수정되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 추가
        final contact = ContactModel(
          id: '',
          userId: widget.userId,
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          company: _companyController.text.trim().isEmpty
              ? null
              : _companyController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          isFavorite: _isFavorite,
          createdAt: DateTime.now(),
        );

        await dbService.addContact(contact);

        if (context.mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '연락처가 추가되었습니다',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_isFavorite)
                          const Text(
                            '즐겨찾기에 추가됨',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
