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
  final String? linkedid; // 통화 상세 조회용 linkedid
  
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
    this.linkedid,
  });
  
  factory CallHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    // Firebase 필드명 변환: callerNumber -> phoneNumber, callerName -> contactName
    // timestamp 필드를 callTime으로 변환 (서버 타임스킬프 지원)
    final phoneNumber = map['callerNumber'] as String? ?? map['phoneNumber'] as String? ?? '';
    final contactName = map['callerName'] as String? ?? map['contactName'] as String?;
    
    // timestamp 처리: Firestore의 serverTimestamp 또는 ISO8601 문자열
    DateTime callTime;
    if (map['timestamp'] != null) {
      final timestamp = map['timestamp'];
      if (timestamp is String) {
        callTime = DateTime.parse(timestamp);
      } else {
        // Firestore Timestamp 객체인 경우 (toDate 메서드 호출)
        try {
          callTime = (timestamp as dynamic).toDate() as DateTime;
        } catch (e) {
          callTime = DateTime.now();
        }
      }
    } else if (map['callTime'] != null) {
      callTime = DateTime.parse(map['callTime'] as String);
    } else {
      callTime = DateTime.now();
    }
    
    // callType 처리: Firebase의 'incoming', 'outgoing', 'missed' 문자열
    CallType callType;
    if (map['callType'] == 'incoming') {
      callType = CallType.incoming;
    } else if (map['callType'] == 'outgoing') {
      callType = CallType.outgoing;
    } else if (map['callType'] == 'missed') {
      callType = CallType.missed;
    } else {
      callType = CallType.outgoing;
    }
    
    return CallHistoryModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      phoneNumber: phoneNumber,
      contactName: contactName,
      callType: callType,
      callMethod: CallMethod.values.firstWhere(
        (e) => e.toString() == 'CallMethod.${map['callMethod']}',
        orElse: () => CallMethod.local,
      ),
      callTime: callTime,
      duration: map['duration'] as int?,
      mainNumberUsed: map['mainNumberUsed'] as String?,
      extensionUsed: map['extensionUsed'] as String?,
      linkedid: map['linkedid'] as String?,
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
      if (linkedid != null) 'linkedid': linkedid,
    };
  }
  
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
