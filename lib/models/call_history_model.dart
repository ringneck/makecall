import 'package:flutter/material.dart';

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
  final String? receiverNumber; // 수신번호 (착신 통화 시 받은 번호)
  final String? linkedid; // 통화 상세 조회용 linkedid
  final String? status; // 통화 상태 (confirmed, device_answered, rejected, missed 등)
  final bool? callForwardEnabled; // 착신전환 활성화 여부 (클릭투콜 발신 시점)
  final String? callForwardDestination; // 착신전환 목적지 번호 (클릭투콜 발신 시점)
  final int? billsec; // 통화 시간 (초) - CDR API의 billsec
  final String? recordingUrl; // 녹음 파일 URL - CDR API의 recording_url
  
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
    this.receiverNumber,
    this.linkedid,
    this.status,
    this.callForwardEnabled,
    this.callForwardDestination,
    this.billsec,
    this.recordingUrl,
  });
  
  factory CallHistoryModel.fromMap(Map<String, dynamic> map, String id) {
    // Firebase 필드명 변환: callerNumber -> phoneNumber, callerName -> contactName
    // timestamp 필드를 callTime으로 변환 (서버 타임스킬프 지원)
    final phoneNumber = map['callerNumber'] as String? ?? map['phoneNumber'] as String? ?? '';
    final contactName = map['callerName'] as String? ?? map['contactName'] as String?;
    
    // 🔧 FIX: createdAt 우선 사용 (정확한 클라이언트 시간)
    // timestamp는 serverTimestamp()로 인한 추정값 문제가 있음
    DateTime callTime;
    if (map['createdAt'] != null) {
      // 우선순위 1: createdAt (DateTime.now()로 저장된 정확한 시간)
      final createdAt = map['createdAt'];
      if (createdAt is String) {
        callTime = DateTime.parse(createdAt);
      } else {
        // Firestore Timestamp 객체인 경우
        try {
          callTime = (createdAt as dynamic).toDate() as DateTime;
        } catch (e) {
          callTime = DateTime.now();
        }
      }
    } else if (map['timestamp'] != null) {
      // 우선순위 2: timestamp (서버 타임스탬프, fallback)
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
      // 우선순위 3: callTime (레거시 지원)
      callTime = DateTime.parse(map['callTime'] as String);
    } else {
      // 마지막 fallback
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
      receiverNumber: map['receiverNumber'] as String?,
      linkedid: map['linkedid'] as String?,
      status: map['status'] as String?,
      callForwardEnabled: map['callForwardEnabled'] as bool?,
      callForwardDestination: map['callForwardDestination'] as String?,
      billsec: map['billsec'] as int?,
      recordingUrl: map['recordingUrl'] as String?,
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
      if (receiverNumber != null) 'receiverNumber': receiverNumber,
      if (linkedid != null) 'linkedid': linkedid,
      if (status != null) 'status': status,
      if (callForwardEnabled != null) 'callForwardEnabled': callForwardEnabled,
      if (callForwardDestination != null) 'callForwardDestination': callForwardDestination,
      if (billsec != null) 'billsec': billsec,
      if (recordingUrl != null) 'recordingUrl': recordingUrl,
    };
  }
  
  /// 수신 방식 텍스트 반환
  String get statusText {
    if (callType != CallType.incoming) return '';
    
    switch (status) {
      case 'device_answered':
        return '단말수신';
      case 'confirmed':
        return '알림확인';
      case 'rejected':
        return '거절';
      case 'missed':
        return '부재중';
      default:
        return '';
    }
  }
  
  /// 수신 방식 색상 반환
  Color? get statusColor {
    if (callType != CallType.incoming) return null;
    
    switch (status) {
      case 'device_answered':
        return const Color(0xFF4CAF50); // 초록색 - 단말 수신
      case 'confirmed':
        return const Color(0xFF2196F3); // 파란색 - 알림 확인
      case 'rejected':
        return const Color(0xFFF44336); // 빨간색 - 거절
      case 'missed':
        return const Color(0xFFFF9800); // 주황색 - 부재중
      default:
        return null;
    }
  }
  
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// 녹음 파일 재생 가능 여부 (billsec >= 5초이고 recordingUrl 존재)
  bool get hasRecording {
    return billsec != null && billsec! >= 5 && recordingUrl != null && recordingUrl!.isNotEmpty;
  }
}
