import 'package:flutter/foundation.dart';
import '../models/my_extension_model.dart';

/// 선택된 단말번호를 전역적으로 관리하는 Provider
class SelectedExtensionProvider extends ChangeNotifier {
  MyExtensionModel? _selectedExtension;

  MyExtensionModel? get selectedExtension => _selectedExtension;

  /// 선택된 단말번호 설정
  void setSelectedExtension(MyExtensionModel? extension) {
    _selectedExtension = extension;
    if (kDebugMode) {
      debugPrint('✅ [STEP 2] Selected extension updated:');
      debugPrint('   - Extension: ${extension?.extension}');
      debugPrint('   - Name: ${extension?.name}');
      debugPrint('   - Extension ID: ${extension?.extensionId}');
      debugPrint('   - Model ID: ${extension?.id}');
    }
    notifyListeners();
  }

  /// 선택 초기화
  void clearSelection() {
    _selectedExtension = null;
    notifyListeners();
  }
}
