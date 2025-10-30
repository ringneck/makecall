enum CallType { incoming, outgoing, missed }
enum CallMethod { local, localApp, extension }

class CallHistoryModel {
  final String id;
  final String userId;
  final String phoneNumber;
  final String? contactName;
  final CallType callType;
  final CallMethod callMethod;
  final DateTime callTime;
  final int? duration; // in seconds
  final String? mainNumberUsed;
  final String? extensionUsed;
  
  CallHistoryModel({
    required this.id,
    required this.userId,
    required this.phoneNumber,
    this.contactName,
    required this.callType,
    required this.callMethod,
    required this.callTime,
    this.duration,
    this.mainNumberUsed,
    this.extensionUsed,
  });
  
  factory CallHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CallHistoryModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      contactName: map['contactName'] as String?,
      callType: CallType.values.firstWhere(
        (e) => e.toString() == 'CallType.${map['callType']}',
        orElse: () => CallType.outgoing,
      ),
      callMethod: CallMethod.values.firstWhere(
        (e) => e.toString() == 'CallMethod.${map['callMethod']}',
        orElse: () => CallMethod.local,
      ),
      callTime: DateTime.parse(map['callTime'] as String? ?? DateTime.now().toIso8601String()),
      duration: map['duration'] as int?,
      mainNumberUsed: map['mainNumberUsed'] as String?,
      extensionUsed: map['extensionUsed'] as String?,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phoneNumber': phoneNumber,
      'contactName': contactName,
      'callType': callType.toString().split('.').last,
      'callMethod': callMethod.toString().split('.').last,
      'callTime': callTime.toIso8601String(),
      'duration': duration,
      'mainNumberUsed': mainNumberUsed,
      'extensionUsed': extensionUsed,
    };
  }
  
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
