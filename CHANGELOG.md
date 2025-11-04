# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Enhanced debugging logs for extension initialization process
- Comprehensive error handling for extension initialization failures

### Changed
- **CRITICAL**: Reversed initialization order - extensions now load BEFORE settings check
- Optimized `_initializeExtensions()` method with advanced programming patterns
- Simplified settings guidance dialog UI
- Updated extension drawer to work seamlessly with auto-initialization

### Fixed
- **MAJOR BUG**: "No extension number selected" error after login
  - Root cause: Extensions were only initialized after settings check completed
  - Solution: Extensions now initialize immediately after login, regardless of settings status
- Compilation errors in dialog code (undefined variables)
- Unused variable warning for `categoryIcon`

### Removed
- Redundant individual setting requirement checks in dialog
- Unused code in settings guidance display

## [1.2.0] - 2024-11-04

### Added
- Auto-initialization of extension numbers immediately after login
- Advanced programming patterns implementation:
  - Early Return Pattern for cleaner code flow
  - Idempotent Operations to prevent duplicate work
  - Fail Silent Pattern for non-critical errors
  - Deduplication Pattern to prevent redundant execution
- Detailed logging for initialization process

### Changed
- Extension initialization priority: Now executes FIRST before any other initialization
- Dialog UI simplified for better user experience
- Code cleaning: Removed unused functions and redundant code

### Fixed
- Click-to-call functionality now works immediately after login without requiring ExtensionDrawer interaction
- All compilation errors resolved (`flutter analyze` passes with 0 errors)

## [1.1.0] - 2024-10-31

### Added
- Profile image upload functionality
- Firebase Storage integration
- Camera and gallery permissions for iOS/Android
- Upload timeout and error handling (30 seconds)
- Firebase Storage security rules setup script
- Progress logging for uploads

### Fixed
- iOS hang issue when selecting photos
- Android permission issues (CAMERA, READ_MEDIA_IMAGES)
- iOS Privacy settings descriptions
- Upload error handling improvements

## [1.0.0] - 2024-10-31

### Added
- Company information management
- maxExtensions (extension number storage limit)
- Manual refresh button for user data
- Timestamp display for last update
- App icon update (latest iOS/Android guidelines)

### Changed
- Improved permission handling for iOS/Android contacts
- Updated app icons for all platforms

### Fixed
- Contact permission optimization

## [0.9.0] - Initial Release

### Added
- Firebase-based authentication (email/password)
- Call management (call history, phonebook integration)
- Extension number management
- User profile management
- Multi-platform support (Android, iOS, macOS, Web)
- Material Design 3 UI
- API integration with PBX systems
- Offline support with Hive
- Real-time data sync with Firestore
- 4-tab structure (Home, Call, Phonebook, Profile)
- Click-to-call functionality
- Device contact integration
- Call history tracking

### Platform Support
- Android 5.0+ (API Level 21+)
- iOS 15.0+
- macOS 12.0+ (Apple Silicon & Intel)
- Web (Chrome, Firefox, Safari, Edge)

### Technical Stack
- Flutter 3.35.4
- Dart 3.9.2
- Firebase (Auth, Firestore, Messaging, Storage)
- Provider for state management
- Hive for local storage
