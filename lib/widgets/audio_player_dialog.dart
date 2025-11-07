import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

/// 간단하고 안정적인 오디오 플레이어 다이얼로그
class AudioPlayerDialog extends StatefulWidget {
  final String audioUrl;
  final String title;

  const AudioPlayerDialog({
    super.key,
    required this.audioUrl,
    this.title = '녹음 파일',
  });

  @override
  State<AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<AudioPlayerDialog> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _error;
  Completer<void>? _durationCompleter;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
    _loadAudio();
  }

  void _setupAudioPlayer() {
    // 플레이어 상태 리스너
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Duration 리스너
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
        
        // Duration이 설정되면 Completer 완료
        if (_durationCompleter != null && !_durationCompleter!.isCompleted) {
          _durationCompleter!.complete();
        }
      }
    });

    // Position 리스너
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // 재생 완료 리스너
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      if (kDebugMode) {
        debugPrint('🎵 오디오 로딩 시작: ${widget.audioUrl}');
      }

      // Duration Completer 생성
      _durationCompleter = Completer<void>();

      // 오디오 소스 설정
      await _audioPlayer.setSourceUrl(widget.audioUrl);

      // Duration을 가져오기 위해 잠깐 재생했다가 즉시 일시정지
      await _audioPlayer.play(UrlSource(widget.audioUrl));
      
      // ⚠️ Duration이 실제로 설정될 때까지 기다림 (onDurationChanged 리스너가 완료 신호)
      // 최대 10초 타임아웃 (네트워크 느린 경우 대비)
      bool durationLoaded = true;
      try {
        await _durationCompleter!.future.timeout(
          const Duration(seconds: 10),
        );
      } catch (e) {
        durationLoaded = false;
        if (kDebugMode) {
          debugPrint('⚠️ Duration 로딩 타임아웃 (10초)');
          debugPrint('   → 재생 시작하면 duration이 자동으로 설정됩니다');
        }
      }
      
      // ⚠️ 확실하게 pause 호출 (타임아웃 후에도)
      try {
        await _audioPlayer.pause();
        if (kDebugMode) {
          debugPrint('✅ 오디오 일시정지 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Pause 실패 (무시): $e');
        }
      }
      
      // Duration 로드 실패 시에도 seek는 시도 (에러 무시)
      try {
        await _audioPlayer.seek(Duration.zero);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Seek 실패 (무시): $e');
        }
      }

      if (kDebugMode) {
        if (durationLoaded) {
          debugPrint('✅ 오디오 로딩 완료');
          debugPrint('   Duration: ${_duration.inSeconds}초');
        } else {
          debugPrint('⚠️ 오디오 로딩 완료 (Duration 대기 중)');
          debugPrint('   → 재생 시작 후 duration이 업데이트됩니다');
        }
      }

      // Duration 로드 실패 시 로딩 상태 해제 (onDurationChanged에서 처리 안 되므로)
      if (!durationLoaded && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 오디오 로드 오류: $e');
        debugPrint('   URL: ${widget.audioUrl}');
      }

      setState(() {
        _error = '오디오 파일을 로드할 수 없습니다';
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      // 로딩 중이거나 에러 상태면 재생하지 않음
      if (_isLoading || _error != null) {
        if (kDebugMode) {
          debugPrint('⚠️ 재생 건너뛰기: 오디오 준비되지 않음 (로딩 또는 에러)');
        }
        return;
      }
      
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // Duration이 0이면 처음 재생 (play 사용), 아니면 resume
        if (_duration.inMilliseconds == 0) {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 재생/일시정지 오류: $e');
      }
    }
  }

  Future<void> _seekTo(double seconds) async {
    try {
      // 오디오가 로드되지 않았거나 duration이 0이면 seek 하지 않음
      if (_duration.inMilliseconds == 0 || _isLoading || _error != null) {
        if (kDebugMode) {
          debugPrint('⚠️ Seek 건너뛰기: 오디오 준비되지 않음');
          debugPrint('   - Duration: ${_duration.inMilliseconds}ms');
          debugPrint('   - Loading: $_isLoading');
          debugPrint('   - Error: $_error');
          debugPrint('   - 요청된 위치: ${seconds}초');
        }
        return;
      }
      
      // Seek 범위를 duration 내로 제한
      final seekDuration = Duration(seconds: seconds.toInt());
      if (seekDuration > _duration) {
        await _audioPlayer.seek(_duration);
      } else if (seekDuration < Duration.zero) {
        await _audioPlayer.seek(Duration.zero);
      } else {
        await _audioPlayer.seek(seekDuration);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Seek 오류: $e');
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  double _getProgress() {
    if (_duration.inMilliseconds == 0) return 0.0;
    final progress = _position.inMilliseconds / _duration.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3c72),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF1e3c72)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 콘텐츠
            if (_isLoading)
              _buildLoading()
            else if (_error != null)
              _buildError()
            else
              _buildPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('로딩 중...', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _loadAudio,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3c72),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(widget.audioUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('다운로드'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    return Column(
      children: [
        // 오디오 아이콘
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1e3c72).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPlaying ? Icons.volume_up : Icons.headphones,
            size: 40,
            color: const Color(0xFF1e3c72),
          ),
        ),

        const SizedBox(height: 24),

        // 시간 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_position),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3c72),
              ),
            ),
            Text(
              _formatDuration(_duration),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 프로그레스 바 (LinearProgressIndicator 사용)
        Column(
          children: [
            LinearProgressIndicator(
              value: _getProgress(),
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1e3c72)),
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            // Slider (조작용)
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: const Color(0xFF1e3c72),
                overlayColor: const Color(0xFF1e3c72).withOpacity(0.2),
              ),
              child: Slider(
                value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()),
                min: 0.0,
                max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                onChanged: (_isLoading || _error != null || _duration.inSeconds == 0) 
                    ? null  // 로딩 중, 에러, 또는 duration이 0이면 비활성화
                    : _seekTo,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 재생 컨트롤
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 10초 뒤로
            IconButton(
              icon: const Icon(Icons.replay_10),
              iconSize: 32,
              color: (_isLoading || _error != null)
                  ? Colors.grey
                  : const Color(0xFF1e3c72),
              onPressed: (_isLoading || _error != null)
                  ? null
                  : () {
                      final newPosition = _position - const Duration(seconds: 10);
                      _seekTo(newPosition.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()));
                    },
            ),

            const SizedBox(width: 16),

            // 재생/일시정지 버튼
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: (_isLoading || _error != null)
                    ? Colors.grey
                    : const Color(0xFF1e3c72),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                iconSize: 36,
                onPressed: (_isLoading || _error != null)
                    ? null
                    : _togglePlayPause,
              ),
            ),

            const SizedBox(width: 16),

            // 10초 앞으로
            IconButton(
              icon: const Icon(Icons.forward_10),
              iconSize: 32,
              color: (_isLoading || _error != null)
                  ? Colors.grey
                  : const Color(0xFF1e3c72),
              onPressed: (_isLoading || _error != null)
                  ? null
                  : () {
                      final newPosition = _position + const Duration(seconds: 10);
                      _seekTo(newPosition.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()));
                    },
            ),
          ],
        ),
      ],
    );
  }
}
