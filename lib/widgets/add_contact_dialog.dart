import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import '../models/contact_model.dart';
import '../services/database_service.dart';

class AddContactDialog extends StatefulWidget {
  final String userId;
  final ContactModel? contact; // null이면 추가, 있으면 수정
  final String? initialPhoneNumber; // 초기 전화번호 (최근통화에서 추가시)

  const AddContactDialog({
    super.key,
    required this.userId,
    this.contact,
    this.initialPhoneNumber,
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
      // 수정 모드
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phoneNumber;
      _emailController.text = widget.contact!.email ?? '';
      _companyController.text = widget.contact!.company ?? '';
      _notesController.text = widget.contact!.notes ?? '';
      _isFavorite = widget.contact!.isFavorite;
    } else if (widget.initialPhoneNumber != null) {
      // 최근통화에서 추가 - 전화번호 미리 채우기
      _phoneController.text = widget.initialPhoneNumber!;
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
      final phoneNumber = _phoneController.text.trim();

      // 🔍 고급 개발자 패턴: 전화번호 중복 체크 (추가/수정 모두)
      final duplicateCheck = await dbService.checkPhoneNumberDuplicate(
        widget.userId,
        phoneNumber,
        excludeContactId: widget.contact?.id, // 수정 시 자기 자신 제외
      );

      if (duplicateCheck['isDuplicate'] == true) {
        final existingContact = duplicateCheck['existingContact'] as ContactModel?;
        
        if (context.mounted) {
          setState(() => _isLoading = false);
          
          // 🎨 사용자 친화적 중복 알림 다이얼로그
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
              title: const Text('중복된 전화번호'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이 전화번호는 이미 등록되어 있습니다:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                existingContact?.name ?? '이름 없음',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              existingContact?.phoneNumber ?? '',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        if (existingContact?.company != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.business, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                existingContact!.company!,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '다른 전화번호를 입력해주세요.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (widget.contact != null) {
        // 수정
        await dbService.updateContact(
          widget.contact!.id,
          {
            'name': _nameController.text.trim(),
            'phoneNumber': phoneNumber,
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

        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true);
          // Navigator.pop 후 약간의 딜레이를 주어 안전하게 새 다이얼로그 표시
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (context.mounted) {
            await DialogUtils.showSuccess(context, '연락처가 수정되었습니다', duration: const Duration(seconds: 1));
          }
        }
      } else {
        // 추가
        final contact = ContactModel(
          id: '',
          userId: widget.userId,
          name: _nameController.text.trim(),
          phoneNumber: phoneNumber,
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

        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context, true);
          // Navigator.pop 후 약간의 딜레이를 주어 안전하게 새 다이얼로그 표시
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (context.mounted) {
            await DialogUtils.showSuccess(
              context,
              _isFavorite
                  ? '연락처가 추가되었습니다\n즐겨찾기에 추가됨'
                  : '연락처가 추가되었습니다',
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        await DialogUtils.showError(
          context,
          '오류 발생: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
