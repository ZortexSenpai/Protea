import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

/// Waveform bars; [progress] (0..1) tints the played part.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.values,
    this.progress = 0,
    this.height = 28,
    this.activeColor,
    this.inactiveColor,
  });

  /// Normalized amplitudes 0..1.
  final List<double> values;
  final double progress;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size(max(values.length * 3.0, 60), height),
      painter: _WaveformPainter(
        values: values,
        progress: progress,
        activeColor: activeColor ?? colorScheme.primary,
        inactiveColor:
            inactiveColor ?? colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.values,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> values;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final barWidth = size.width / values.length;
    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = barWidth * 0.6
      ..strokeCap = StrokeCap.round;
    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = barWidth * 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < values.length; i++) {
      final x = i * barWidth + barWidth / 2;
      final amplitude = values[i].clamp(0.05, 1.0);
      final barHeight = amplitude * size.height;
      final paint = (i + 1) / values.length <= progress
          ? activePaint
          : inactivePaint;
      canvas.drawLine(
        Offset(x, (size.height - barHeight) / 2),
        Offset(x, (size.height + barHeight) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor;
}

/// Formats a duration as m:ss.
String formatAudioDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Playback bubble for `m.audio` events (voice messages per MSC3245 or
/// plain audio files): play/pause, waveform and progress.
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({super.key, required this.event});

  final Event event;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  static AudioPlayer? _player;
  static String? _playingEventId;
  static final _stateNotifier = ValueNotifier(0);

  bool _loading = false;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  bool get _isActive => _playingEventId == widget.event.eventId;

  @override
  void initState() {
    super.initState();
    _stateNotifier.addListener(_onGlobalStateChanged);
  }

  @override
  void dispose() {
    _stateNotifier.removeListener(_onGlobalStateChanged);
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  void _onGlobalStateChanged() {
    if (mounted) setState(() {});
  }

  /// Amplitudes from the MSC3245 waveform (0..1024), normalized to 0..1.
  List<double> get _waveform {
    final audio = widget.event.content.tryGetMap<String, Object?>(
      'org.matrix.msc1767.audio',
    );
    final raw = audio?.tryGetList<int>('waveform');
    if (raw == null || raw.isEmpty) {
      return List.filled(30, 0.4);
    }
    final maxValue = raw.reduce(max).clamp(1, 1 << 30);
    return [for (final value in raw) value / maxValue];
  }

  Duration get _duration {
    final audio = widget.event.content.tryGetMap<String, Object?>(
      'org.matrix.msc1767.audio',
    );
    final ms =
        audio?.tryGet<int>('duration') ??
        widget.event.infoMap.tryGet<int>('duration');
    return Duration(milliseconds: ms ?? 0);
  }

  Future<void> _togglePlay() async {
    if (_isActive && _player != null) {
      if (_player!.playing) {
        await _player!.pause();
      } else {
        await _player!.play();
      }
      _stateNotifier.value++;
      return;
    }
    setState(() => _loading = true);
    try {
      // Stop whatever else is playing.
      await _player?.stop();
      await _player?.dispose();
      _player = null;

      final file = await widget.event.downloadAndDecryptAttachment();
      final dir = await getTemporaryDirectory();
      final extension = file.name.contains('.')
          ? file.name.split('.').last
          : 'm4a';
      final tempFile = File(
        '${dir.path}/voice_${widget.event.eventId.hashCode}.$extension',
      );
      await tempFile.writeAsBytes(file.bytes);

      final player = AudioPlayer();
      _player = player;
      _playingEventId = widget.event.eventId;
      await player.setFilePath(tempFile.path);
      _positionSubscription?.cancel();
      _positionSubscription = player.positionStream.listen((position) {
        if (mounted && _isActive) setState(() => _position = position);
      });
      _playerStateSubscription?.cancel();
      _playerStateSubscription = player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          player.pause();
          player.seek(Duration.zero);
        }
        _stateNotifier.value++;
      });
      await player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _stateNotifier.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _isActive && (_player?.playing ?? false);
    final duration = _duration;
    final position = _isActive ? _position : Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _loading
            ? const SizedBox(
                width: 36,
                height: 36,
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton.filledTonal(
                iconSize: 20,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlay,
              ),
        const SizedBox(width: 8),
        Waveform(values: _waveform, progress: progress),
        const SizedBox(width: 8),
        Text(
          _isActive && duration.inMilliseconds > 0
              ? formatAudioDuration(position)
              : formatAudioDuration(duration),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
