import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/mobile_contacts_service.dart';
import '../../models/contact_model.dart';
import '../../models/call_history_model.dart';
import 'dialpad_screen.dart';
import '../../widgets/call_method_dialog.dart';
import '../../widgets/add_contact_dialog.dart';

class CallTab extends StatefulWidget {
  const CallTab({super.key});

  @override
  State<CallTab> createState() => _CallTabState();
}

class _CallTabState extends State<CallTab> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final MobileContactsService _mobileContactsService = MobileContactsService();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoadingDeviceContacts = false;
  bool _showDeviceContacts = false;
  List<ContactModel> _deviceContacts = [];

  @override
  void initState() {
    super.initState();
    // 기본 화면을 키패드(인덱스 3)로 설정
    _tabController = TabController(length: 4, vsync: this, initialIndex: 3);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통화'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '즐겨찾기'),
            Tab(text: '최근통화'),
            Tab(text: '연락처'),
            Tab(text: '키패드'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFavoritesTab(),
          _buildCallHistoryTab(),
          _buildContactsTab(),
          const DialpadScreen(),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';

    return StreamBuilder<List<ContactModel>>(
      stream: _databaseService.getFavoriteContacts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final favorites = snapshot.data ?? [];

        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  '즐겨찾기가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '연락처에서 별 아이콘을 눌러 즐겨찾기에 추가하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final contact = favorites[index];
            return _buildContactListTile(contact);
          },
        );
      },
    );
  }

  Widget _buildCallHistoryTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';

    return StreamBuilder<List<CallHistoryModel>>(
      stream: _databaseService.getUserCallHistory(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final callHistory = snapshot.data ?? [];

        if (callHistory.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('통화 기록이 없습니다', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: callHistory.length,
          itemBuilder: (context, index) {
            final call = callHistory[index];
            return ListTile(
              leading: Icon(
                _getCallTypeIcon(call.callType),
                color: _getCallTypeColor(call.callType),
              ),
              title: Text(call.contactName ?? call.phoneNumber),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatDateTime(call.callTime)}${call.duration != null ? ' · ${call.formattedDuration}' : ''}',
                  ),
                  if (call.extensionUsed != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_android,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '단말번호: ${call.extensionUsed}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
                onPressed: () => _showCallMethodDialog(call.phoneNumber),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContactsTab() {
    final userId = context.watch<AuthService>().currentUser?.uid ?? '';

    return Column(
      children: [
        // 상단 컨트롤 바
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              // 장치 연락처 토글 버튼
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoadingDeviceContacts ? null : _toggleDeviceContacts,
                  icon: _isLoadingDeviceContacts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_showDeviceContacts ? Icons.cloud_done : Icons.smartphone),
                  label: Text(
                    _showDeviceContacts ? '저장된 연락처' : '장치 연락처',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showDeviceContacts
                        ? const Color(0xFF2196F3)
                        : Colors.white,
                    foregroundColor: _showDeviceContacts
                        ? Colors.white
                        : const Color(0xFF2196F3),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 연락처 추가 버튼
              ElevatedButton.icon(
                onPressed: () => _showAddContactDialog(userId),
                icon: const Icon(Icons.person_add, size: 20),
                label: const Text('추가', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        // 검색바
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '연락처 검색',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),

        // 연락처 목록
        Expanded(
          child: _showDeviceContacts
              ? _buildDeviceContactsList()
              : _buildSavedContactsList(userId),
        ),
      ],
    );
  }

  Widget _buildSavedContactsList(String userId) {
    return StreamBuilder<List<ContactModel>>(
      stream: _databaseService.getUserContacts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var contacts = snapshot.data ?? [];

        // 검색 필터링
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          contacts = contacts.where((contact) {
            return contact.name.toLowerCase().contains(query) ||
                contact.phoneNumber.contains(query);
          }).toList();
        }

        if (contacts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.contacts, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty
                      ? '검색 결과가 없습니다'
                      : '저장된 연락처가 없습니다',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '우측 상단 추가 버튼을 눌러 연락처를 추가하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return _buildContactListTile(contact, showActions: true);
          },
        );
      },
    );
  }

  Widget _buildDeviceContactsList() {
    if (_deviceContacts.isEmpty) {
      return const Center(
        child: Text('장치 연락처를 불러오는 중...'),
      );
    }

    var contacts = _deviceContacts;

    // 검색 필터링
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      contacts = contacts.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
            contact.phoneNumber.contains(query);
      }).toList();
    }

    if (contacts.isEmpty) {
      return const Center(
        child: Text('검색 결과가 없습니다'),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactListTile(contact, isDeviceContact: true);
      },
    );
  }

  Widget _buildContactListTile(
    ContactModel contact, {
    bool showActions = false,
    bool isDeviceContact = false,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: contact.isFavorite
            ? Colors.amber[100]
            : const Color(0xFF2196F3).withAlpha(51),
        child: Icon(
          contact.isFavorite ? Icons.star : Icons.person,
          color: contact.isFavorite ? Colors.amber[700] : const Color(0xFF2196F3),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              contact.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (isDeviceContact)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                '장치',
                style: TextStyle(fontSize: 10, color: Colors.blue),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contact.phoneNumber),
          if (contact.company != null)
            Text(
              contact.company!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showActions) ...[
            // 즐겨찾기 토글
            IconButton(
              icon: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite ? Colors.amber : Colors.grey,
              ),
              onPressed: () => _toggleFavorite(contact),
              tooltip: contact.isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
            ),
            // 수정 버튼
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () => _showEditContactDialog(contact),
              tooltip: '수정',
            ),
          ],
          if (isDeviceContact)
            // 장치 연락처에서 즐겨찾기 추가 버튼
            IconButton(
              icon: const Icon(Icons.star_border, color: Colors.amber),
              onPressed: () => _addDeviceContactToFavorites(contact),
              tooltip: '즐겨찾기에 추가',
            ),
          // 전화 버튼
          IconButton(
            icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
            onPressed: () => _showCallMethodDialog(contact.phoneNumber),
            tooltip: '전화 걸기',
          ),
        ],
      ),
      onTap: () => _showCallMethodDialog(contact.phoneNumber),
    );
  }

  IconData _getCallTypeIcon(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  Color _getCallTypeColor(CallType type) {
    switch (type) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  void _showCallMethodDialog(String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => CallMethodDialog(phoneNumber: phoneNumber),
    );
  }

  Future<void> _toggleFavorite(ContactModel contact) async {
    try {
      await _databaseService.updateContact(
        contact.id,
        {'isFavorite': !contact.isFavorite},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  contact.isFavorite ? Icons.star_border : Icons.star,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  contact.isFavorite
                      ? '즐겨찾기에서 제거되었습니다'
                      : '즐겨찾기에 추가되었습니다',
                ),
              ],
            ),
            backgroundColor: contact.isFavorite ? Colors.grey[700] : Colors.amber[700],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  Future<void> _toggleDeviceContacts() async {
    if (_showDeviceContacts) {
      setState(() {
        _showDeviceContacts = false;
        _deviceContacts = [];
      });
      return;
    }

    setState(() => _isLoadingDeviceContacts = true);

    try {
      final userId = context.read<AuthService>().currentUser?.uid ?? '';
      final contacts = await _mobileContactsService.getDeviceContacts(userId);

      setState(() {
        _deviceContacts = contacts;
        _showDeviceContacts = true;
        _isLoadingDeviceContacts = false;
      });

      if (contacts.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('장치 연락처를 불러올 수 없습니다. 권한을 확인해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingDeviceContacts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddContactDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(userId: userId),
    );
  }

  void _showEditContactDialog(ContactModel contact) {
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(
        userId: contact.userId,
        contact: contact,
      ),
    );
  }

  Future<void> _addDeviceContactToFavorites(ContactModel contact) async {
    try {
      final userId = context.read<AuthService>().currentUser?.uid ?? '';
      
      // Firestore에 저장
      final newContact = contact.copyWith(
        userId: userId,
        isFavorite: true,
        isDeviceContact: false, // 이제 저장된 연락처
      );

      await _databaseService.addContact(newContact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${contact.name}을(를) 즐겨찾기에 추가했습니다'),
                ),
              ],
            ),
            backgroundColor: Colors.amber[700],
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '보기',
              textColor: Colors.white,
              onPressed: () {
                _tabController.animateTo(0); // 즐겨찾기 탭으로 이동
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
