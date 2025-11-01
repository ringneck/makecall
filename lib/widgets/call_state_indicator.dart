import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dcmiws_event_provider.dart';

/// 통화 상태 표시 위젯
/// 
/// 특정 단말번호의 실시간 통화 상태를 표시합니다.
class CallStateIndicator extends StatelessWidget {
  final String extension;

  const CallStateIndicator({
    super.key,
    required this.extension,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DCMIWSEventProvider>(
      builder: (context, eventProvider, child) {
        final callState = eventProvider.getCallState(extension);

        // 통화 중이 아니면 표시하지 않음
        if (callState == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: callState.stateColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: callState.stateColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // 애니메이션 아이콘
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (value * 0.2),
                    child: Icon(
                      callState.stateIcon,
                      color: callState.stateColor,
                      size: 32,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              
              // 상태 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      callState.stateKorean,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: callState.stateColor,
                      ),
                    ),
                    if (callState.destinationNumber != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        callState.destinationNumber!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 펄싱 애니메이션 표시기
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 0.5 + (value * 0.5),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: callState.stateColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 모든 통화 상태를 표시하는 리스트 위젯
class CallStateList extends StatelessWidget {
  const CallStateList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DCMIWSEventProvider>(
      builder: (context, eventProvider, child) {
        final callStates = eventProvider.callStates;

        if (callStates.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_in_talk,
                    size: 20,
                    color: Color(0xFF2196F3),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '진행 중인 통화',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${callStates.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...callStates.entries.map((entry) {
              return CallStateIndicator(extension: entry.key);
            }),
          ],
        );
      },
    );
  }
}

/// 최근 이벤트 로그 위젯 (디버깅용)
class RecentEventsLog extends StatelessWidget {
  final int maxEvents;

  const RecentEventsLog({
    super.key,
    this.maxEvents = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DCMIWSEventProvider>(
      builder: (context, eventProvider, child) {
        final events = eventProvider.recentEvents.take(maxEvents).toList();

        if (events.isEmpty) {
          return const Center(
            child: Text(
              '최근 이벤트 없음',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final event = events[index];
            final timeDiff = DateTime.now().difference(event.timestamp);
            
            return ListTile(
              dense: true,
              leading: Icon(
                _getEventIcon(event.eventType),
                size: 20,
                color: _getEventColor(event.eventType),
              ),
              title: Text(
                event.eventType,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: event.description != null
                  ? Text(
                      event.description!,
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              trailing: Text(
                _formatTimeDiff(timeDiff),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'Newchannel':
        return Icons.phone_in_talk;
      case 'Hangup':
        return Icons.call_end;
      case 'DialBegin':
        return Icons.phone_callback;
      case 'DialEnd':
        return Icons.call_made;
      case 'Bridge':
        return Icons.call;
      default:
        return Icons.info_outline;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'Newchannel':
        return Colors.blue;
      case 'Hangup':
        return Colors.red;
      case 'DialBegin':
        return Colors.orange;
      case 'DialEnd':
        return Colors.green;
      case 'Bridge':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeDiff(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}초 전';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}분 전';
    } else {
      return '${duration.inHours}시간 전';
    }
  }
}
