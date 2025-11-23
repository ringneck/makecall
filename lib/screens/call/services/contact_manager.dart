import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/database_service.dart';
import '../../../services/mobile_contacts_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/contact_model.dart';
import '../../../utils/dialog_utils.dart';
import 'permission_handler.dart';

/// ContactManager Service
/// 연락처 상태 관리 및 즐겨찾기 토글 처리
class ContactManager {
  final DatabaseService databaseService;
  final MobileContactsService mobileContactsService;
  final PermissionHandler permissionHandler;
  final VoidCallback onStateChanged;
  
  bool _isLoadingDeviceContacts = false;
  bool _showDeviceContacts = false;
  List<ContactModel> _deviceContacts = [];
  bool _isTogglingFavorite = false;
  
  ContactManager({
    required this.databaseService,
    required this.mobileContactsService,
    required this.permissionHandler,
    required this.onStateChanged,
  });
  
  bool get isLoadingDeviceContacts => _isLoadingDeviceContacts;
  bool get showDeviceContacts => _showDeviceContacts;
  List<ContactModel> get deviceContacts => _deviceContacts;
  
  /// 장치 연락처 토글 (불러오기/숨기기)
  Future<void> toggleDeviceContacts(
    BuildContext context,
    AuthService authService,
  ) async {
    if (_showDeviceContacts) {
      _showDeviceContacts = false;
      _deviceContacts = [];
      onStateChanged();
      return;
    }

    _isLoadingDeviceContacts = true;
    onStateChanged();

    try {
      if (!context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        return;
      }
      
      _isLoadingDeviceContacts = false;
      onStateChanged();
      
      final hasPermission = await permissionHandler.checkAndRequestPermission(context);
      
      if (!hasPermission) return;
      
      _isLoadingDeviceContacts = true;
      onStateChanged();

      if (!context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        return;
      }
      
      final userId = authService.currentUser?.uid ?? '';
      final contacts = await mobileContactsService.getDeviceContacts(userId);

      if (!context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        return;
      }
      
      _deviceContacts = contacts;
      _showDeviceContacts = true;
      _isLoadingDeviceContacts = false;
      onStateChanged();

      if (contacts.isEmpty) {
        await DialogUtils.showWarning(
          context,
          '장치에 저장된 연락처가 없습니다.',
          duration: const Duration(seconds: 1),
        );
      } else {
        await DialogUtils.showSuccess(
          context,
          '${contacts.length}개의 연락처를 불러왔습니다.',
          duration: const Duration(seconds: 1),
        );
      }
      
    } catch (e) {
      if (context.mounted) {
        _isLoadingDeviceContacts = false;
        onStateChanged();
        
        await DialogUtils.showError(
          context,
          '연락처 불러오기 실패: ${e.toString().split(':').last.trim()}',
        );
      }
    }
  }
  
  /// 즐겨찾기 토글
  Future<void> toggleFavorite(
    BuildContext context,
    ContactModel contact,
  ) async {
    if (_isTogglingFavorite) return;
    
    _isTogglingFavorite = true;
    
    try {
      final newFavoriteStatus = !contact.isFavorite;
      
      if (contact.id.isEmpty) {
        final userId = _getUserId(context);
        if (userId == null || userId.isEmpty) {
          throw Exception('사용자 ID를 찾을 수 없습니다');
        }
        
        final existingContact = await databaseService.findContactByPhone(
          userId, 
          contact.phoneNumber,
        );
        
        if (existingContact != null) {
          await databaseService.updateContactAndWaitForSync(
            existingContact.id,
            {'isFavorite': newFavoriteStatus},
          );
          
          if (_showDeviceContacts && _deviceContacts.isNotEmpty) {
            final index = _deviceContacts.indexWhere((c) => 
              c.phoneNumber == contact.phoneNumber);
            if (index != -1) {
              _deviceContacts[index] = ContactModel(
                id: existingContact.id,
                name: _deviceContacts[index].name,
                phoneNumber: _deviceContacts[index].phoneNumber,
                isFavorite: newFavoriteStatus,
                userId: _deviceContacts[index].userId,
                createdAt: _deviceContacts[index].createdAt,
                updatedAt: DateTime.now(),
              );
              onStateChanged();
            }
          }
          return;
        }
        
        final newContact = contact.copyWith(
          userId: userId,
          isFavorite: newFavoriteStatus,
          isDeviceContact: false,
        );
        
        final docId = await databaseService.addContact(newContact);
        await databaseService.waitForContactAdded(userId, docId);
        
        if (_showDeviceContacts && _deviceContacts.isNotEmpty) {
          final index = _deviceContacts.indexWhere((c) => 
            c.phoneNumber == contact.phoneNumber);
          if (index != -1) {
            _deviceContacts[index] = ContactModel(
              id: docId,
              name: _deviceContacts[index].name,
              phoneNumber: _deviceContacts[index].phoneNumber,
              isFavorite: newFavoriteStatus,
              userId: userId,
              createdAt: _deviceContacts[index].createdAt,
              updatedAt: DateTime.now(),
            );
            onStateChanged();
          }
        }
        return;
      }
      
      await databaseService.updateContactAndWaitForSync(
        contact.id,
        {'isFavorite': newFavoriteStatus},
      );

      if (_showDeviceContacts && _deviceContacts.isNotEmpty) {
        final index = _deviceContacts.indexWhere((c) => c.id == contact.id);
        if (index != -1) {
          _deviceContacts[index] = ContactModel(
            id: _deviceContacts[index].id,
            name: _deviceContacts[index].name,
            phoneNumber: _deviceContacts[index].phoneNumber,
            isFavorite: newFavoriteStatus,
            userId: _deviceContacts[index].userId,
            createdAt: _deviceContacts[index].createdAt,
            updatedAt: DateTime.now(),
          );
          onStateChanged();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('즐겨찾기 변경 실패'),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('❌ 즐겨찾기 변경 실패: $e');
      }
    } finally {
      _isTogglingFavorite = false;
    }
  }
  
  String? _getUserId(BuildContext context) {
    try {
      return context.read<AuthService>().currentUser?.uid;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 사용자 ID 가져오기 실패: $e');
      }
      return null;
    }
  }
  
  void resetState() {
    _isLoadingDeviceContacts = false;
    _showDeviceContacts = false;
    _deviceContacts = [];
    onStateChanged();
  }
}
