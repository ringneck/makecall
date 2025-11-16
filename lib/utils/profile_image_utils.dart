import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:croppy/croppy.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../services/auth_service.dart';
import 'dialog_utils.dart';

/// 프로필 이미지 관리 유틸리티
/// 
/// profile_tab.dart와 profile_drawer.dart에서 공통으로 사용하는
/// 프로필 이미지 관련 기능을 통합 관리합니다.
/// 
/// 주요 기능:
/// - 프로필 사진 옵션 표시 (촬영/갤러리/삭제)
/// - 이미지 선택 + 크롭 + 업로드
/// - 프로필 사진 삭제 (확인 다이얼로그 포함)
class ProfileImageUtils {
  /// 프로필 사진 옵션 Bottom Sheet 표시
  /// 
  /// [useModernUI]: true = profile_tab 스타일 (handle bar, 제목 포함)
  ///                false = profile_drawer 스타일 (기본 UI)
  static void showImageOptions(
    BuildContext context,
    AuthService authService, {
    bool useModernUI = true,
  }) {
    final hasProfileImage = authService.currentUserModel?.profileImageUrl != null;
    
    showModalBottomSheet(
      context: context,
      shape: useModernUI
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            )
          : null,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modern UI: Handle bar + 제목
            if (useModernUI) ...[
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '프로필 사진',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // 갤러리에서 선택
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: useModernUI ? const Color(0xFF2196F3) : null,
              ),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                pickAndUploadImage(
                  context,
                  ImageSource.gallery,
                  authService,
                );
              },
            ),
            
            // 사진 촬영
            ListTile(
              leading: Icon(
                useModernUI ? Icons.camera_alt : Icons.photo_camera,
                color: useModernUI ? const Color(0xFF2196F3) : null,
              ),
              title: Text(useModernUI ? '사진 촬영' : '카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                pickAndUploadImage(
                  context,
                  ImageSource.camera,
                  authService,
                );
              },
            ),
            
            // 프로필 사진 삭제
            if (hasProfileImage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  '프로필 사진 삭제',
                  style: TextStyle(
                    color: useModernUI ? null : Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  deleteProfileImage(context, authService);
                },
              ),
            
            if (useModernUI) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 이미지 선택 + 크롭 + 업로드 (통합 함수)
  /// 
  /// [useIOSOptimization]: iOS 최적화 적용 여부 (기본: true)
  /// [useModernLoadingUI]: 로딩 UI 스타일 (기본: true)
  static Future<void> pickAndUploadImage(
    BuildContext context,
    ImageSource source,
    AuthService authService, {
    bool useIOSOptimization = true,
    bool useModernLoadingUI = true,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🖼️ [ProfileImageUtils] Starting image picker with source: $source');
      }

      final picker = ImagePicker();

      // iOS hang 방지: UI 스레드가 완전히 정리되도록 지연
      if (useIOSOptimization) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 이미지 선택
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (pickedFile == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [ProfileImageUtils] Image picker cancelled by user');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ [ProfileImageUtils] Image picked: ${pickedFile.path}');
      }

      // 마운트 확인
      if (!context.mounted) return;

      if (kDebugMode) {
        debugPrint('🖼️ [ProfileImageUtils] Showing croppy image cropper...');
        debugPrint('🖼️ [ProfileImageUtils] Platform: ${Theme.of(context).platform}');
      }

      final imageFile = File(pickedFile.path);

      // 플랫폼에 맞는 크롭 UI 표시
      final CropImageResult? croppedImage;

      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // iOS: Cupertino 스타일 (iOS Photos 앱 느낌)
        if (kDebugMode) {
          debugPrint('🍎 [ProfileImageUtils] Using Cupertino cropper for iOS');
        }
        croppedImage = await showCupertinoImageCropper(
          context,
          imageProvider: FileImage(imageFile),
          allowedAspectRatios: [
            const CropAspectRatio(width: 1, height: 1), // 정사각형만 허용
          ],
        );
      } else {
        // Android/Web/기타: Material 스타일 (Google Photos 느낌)
        if (kDebugMode) {
          debugPrint('🤖 [ProfileImageUtils] Using Material cropper');
        }
        croppedImage = await showMaterialImageCropper(
          context,
          imageProvider: FileImage(imageFile),
          allowedAspectRatios: [
            const CropAspectRatio(width: 1, height: 1), // 정사각형만 허용
          ],
        );
      }

      if (kDebugMode) {
        debugPrint('🖼️ [ProfileImageUtils] Crop result: ${croppedImage != null ? "success" : "cancelled"}');
      }

      if (croppedImage == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [ProfileImageUtils] Image cropper cancelled by user');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ [ProfileImageUtils] Image cropped successfully');
      }

      // 크롭된 이미지를 Uint8List로 변환
      final byteData = await croppedImage.uiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        if (kDebugMode) {
          debugPrint('❌ [ProfileImageUtils] Failed to convert cropped image to bytes');
        }
        return;
      }

      final croppedBytes = byteData.buffer.asUint8List();

      // 마운트 확인
      if (!context.mounted) return;

      // 로딩 다이얼로그 표시
      _showLoadingDialog(context, useModernUI: useModernLoadingUI);

      // 크롭된 이미지를 임시 파일로 저장
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(croppedBytes);

      if (kDebugMode) {
        debugPrint('📤 [ProfileImageUtils] Uploading image to Firebase Storage...');
      }

      // Firebase Storage에 업로드
      await authService.uploadProfileImage(tempFile);

      if (kDebugMode) {
        debugPrint('✅ [ProfileImageUtils] Image upload completed successfully');
      }

      if (!context.mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      // 성공 메시지
      await DialogUtils.showSuccess(
        context,
        '프로필 사진이 업데이트되었습니다',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ProfileImageUtils] Image upload error: $e');
      }

      if (!context.mounted) return;

      // 로딩 다이얼로그가 열려있으면 닫기
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

      await DialogUtils.showError(
        context,
        '이미지 업로드 실패: ${e.toString()}',
      );
    }
  }

  /// 프로필 사진 삭제 (확인 다이얼로그 포함)
  /// 
  /// ✅ CRITICAL: 항상 확인 다이얼로그를 표시하여 실수로 인한 삭제 방지
  static Future<void> deleteProfileImage(
    BuildContext context,
    AuthService authService,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔒 확인 다이얼로그 (필수!)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          '프로필 사진 삭제',
          style: TextStyle(
            color: isDark ? Colors.grey[200] : Colors.black87,
          ),
        ),
        content: Text(
          '프로필 사진을 삭제하시겠습니까?',
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    // 사용자가 취소한 경우
    if (confirmed != true) return;

    try {
      // 로딩 다이얼로그 표시
      if (context.mounted) {
        _showLoadingDialog(context, message: '프로필 사진 삭제 중...', useModernUI: false);
      }

      // Firebase Storage에서 삭제
      await authService.deleteProfileImage();

      if (kDebugMode) {
        debugPrint('✅ [ProfileImageUtils] Profile image deleted successfully');
      }

      if (!context.mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      // 성공 메시지
      await DialogUtils.showSuccess(
        context,
        '프로필 사진이 삭제되었습니다',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ProfileImageUtils] Delete profile image error: $e');
      }

      if (!context.mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.pop(context);

      await DialogUtils.showError(
        context,
        '프로필 사진 삭제 실패: ${e.toString()}',
      );
    }
  }

  /// 로딩 다이얼로그 표시 (내부 헬퍼 함수)
  static void _showLoadingDialog(
    BuildContext context, {
    String message = '프로필 사진 업로드 중...',
    bool useModernUI = true,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        if (useModernUI) {
          // Modern UI: Card + 메시지
          return PopScope(
            canPop: false, // 백버튼으로 닫기 방지
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(message),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // Simple UI: CircularProgressIndicator만
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
