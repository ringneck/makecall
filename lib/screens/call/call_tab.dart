import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/contact_model.dart';
import '../../models/call_history_model.dart';
import 'dialpad_screen.dart';
import '../../widgets/call_method_dialog.dart';

class CallTab extends StatefulWidget {
  const CallTab({super.key});

  @override
  State<CallTab> createState() => _CallTabState();
}

class _CallTabState extends State<CallTab> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _searchController = TextEditingController();

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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('즐겨찾기가 없습니다', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final contact = favorites[index];
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              title: Text(contact.name),
              subtitle: Text(contact.phoneNumber),
              trailing: IconButton(
                icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
                onPressed: () => _showCallMethodDialog(contact.phoneNumber),
              ),
              onTap: () => _showCallMethodDialog(contact.phoneNumber),
            );
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
              subtitle: Text(
                '${_formatDateTime(call.callTime)}${call.duration != null ? ' · ${call.formattedDuration}' : ''}',
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '연락처 검색',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ContactModel>>(
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
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contacts, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('연락처가 없습니다', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(contact.name),
                    subtitle: Text(contact.phoneNumber),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            contact.isFavorite
                                ? Icons.star
                                : Icons.star_border,
                            color: contact.isFavorite
                                ? Colors.amber
                                : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(contact),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Color(0xFF2196F3)),
                          onPressed: () => _showCallMethodDialog(contact.phoneNumber),
                        ),
                      ],
                    ),
                    onTap: () => _showCallMethodDialog(contact.phoneNumber),
                  );
                },
              );
            },
          ),
        ),
      ],
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }
}
