import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wheel_picker/wheel_picker.dart';

void main() {
  runApp(const DriftSandApp());
}

class DriftSandApp extends StatelessWidget {
  const DriftSandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drift Sand',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const TimerHomePage(),
    );
  }
}

enum TimerStatus { idle, running, paused, finished }

class TimerHomePage extends StatefulWidget {
  const TimerHomePage({super.key});

  @override
  State<TimerHomePage> createState() => _TimerHomePageState();
}

class _TimerHomePageState extends State<TimerHomePage> {
  static const int _tickIntervalMs = 200;
  static const int _maxHours = 24;
  static const int _maxMinutes = 59;
  static const int _maxSeconds = 59;

  TimerStatus _status = TimerStatus.idle;
  int _selectedHours = 0;
  int _selectedMinutes = 25;
  int _selectedSeconds = 0;
  Duration _remaining = const Duration(minutes: 25);
  Duration _activeDuration = const Duration(minutes: 25);
  DateTime? _endTime;
  Timer? _ticker;
  Timer? _boundaryTimer;
  bool _showBoundaryWarning = false;
  int _lastRenderedSeconds = -1;

  late final WheelPickerController _hoursController;
  late final WheelPickerController _minutesController;
  late final WheelPickerController _secondsController;

  bool get _isRunning => _status == TimerStatus.running;
  bool get _isPaused => _status == TimerStatus.paused;
  bool get _isFinished => _status == TimerStatus.finished;

  bool get _canStart {
    if (_status == TimerStatus.idle) {
      return _selectedDuration().inSeconds > 0;
    }
    if (_status == TimerStatus.finished) {
      return _activeDuration.inSeconds > 0;
    }
    return _remaining.inSeconds > 0;
  }

  @override
  void initState() {
    super.initState();
    _hoursController = WheelPickerController(
      itemCount: _maxHours + 1,
      initialIndex: _selectedHours,
    );
    _minutesController = WheelPickerController(
      itemCount: _maxMinutes + 1,
      initialIndex: _selectedMinutes,
    );
    _secondsController = WheelPickerController(
      itemCount: _maxSeconds + 1,
      initialIndex: _selectedSeconds,
    );
  }

  void _start() {
    if (_status == TimerStatus.idle) {
      _remaining = _selectedDuration();
      _activeDuration = _remaining;
      _syncWheelsToDuration(_remaining);
    } else if (_status == TimerStatus.finished) {
      _remaining = _activeDuration;
      _syncWheelsToDuration(_remaining);
    }
    if (_remaining.inMilliseconds <= 0) return;
    _status = TimerStatus.running;
    _endTime = DateTime.now().add(_remaining);
    _lastRenderedSeconds = -1;
    _startTicker();
    setState(() {});
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    _status = TimerStatus.paused;
    _syncRemaining();
    _syncWheelsToDuration(_remaining);
    setState(() {});
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _status = TimerStatus.idle;
    _remaining = _selectedDuration();
    _endTime = null;
    _lastRenderedSeconds = -1;
    setState(() {});
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(milliseconds: _tickIntervalMs),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (_endTime == null) return;
    _syncRemaining();
    final remainingSeconds = _remaining.inSeconds;
    if (remainingSeconds != _lastRenderedSeconds) {
      _lastRenderedSeconds = remainingSeconds;
      _syncWheelsToDuration(_remaining);
      setState(() {});
    }
    if (_remaining.inMilliseconds <= 0) {
      _ticker?.cancel();
      _ticker = null;
      _status = TimerStatus.finished;
      _remaining = Duration.zero;
      _syncWheelsToDuration(_remaining);
      setState(() {});
    }
  }

  void _syncRemaining() {
    final endTime = _endTime;
    if (endTime == null) return;
    final diff = endTime.difference(DateTime.now());
    _remaining = diff.isNegative ? Duration.zero : diff;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Duration _selectedDuration() {
    return Duration(
      hours: _selectedHours,
      minutes: _selectedMinutes,
      seconds: _selectedSeconds,
    );
  }

  void _syncWheelsToDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = (totalSeconds ~/ 3600).clamp(0, _maxHours);
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    _hoursController.setCurrent(hours);
    _minutesController.setCurrent(minutes);
    _secondsController.setCurrent(seconds);
  }

  void _showBoundaryFlash() {
    _boundaryTimer?.cancel();
    _showBoundaryWarning = true;
    _boundaryTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _showBoundaryWarning = false);
    });
  }

  void _setHours(int value) {
    _selectedHours = value;
    if (_selectedHours == _maxHours &&
        (_selectedMinutes != 0 || _selectedSeconds != 0)) {
      _selectedMinutes = 0;
      _selectedSeconds = 0;
      _minutesController.setCurrent(0);
      _secondsController.setCurrent(0);
    }
    if (_status == TimerStatus.idle) {
      _remaining = _selectedDuration();
    }
    setState(() {});
  }

  void _setMinutes(int value) {
    if (_selectedHours == _maxHours && value > 0) {
      _selectedHours = _maxHours - 1;
      _hoursController.setCurrent(_selectedHours);
      _showBoundaryFlash();
    }
    _selectedMinutes = value;
    if (_status == TimerStatus.idle) {
      _remaining = _selectedDuration();
    }
    setState(() {});
  }

  void _setSeconds(int value) {
    if (_selectedHours == _maxHours && value > 0) {
      _selectedHours = _maxHours - 1;
      _hoursController.setCurrent(_selectedHours);
      _showBoundaryFlash();
    }
    _selectedSeconds = value;
    if (_status == TimerStatus.idle) {
      _remaining = _selectedDuration();
    }
    setState(() {});
  }

  Widget _buildWheel({
    required String label,
    required WheelPickerController controller,
    required ValueChanged<int> onChanged,
  }) {
    const textStyle = TextStyle(fontSize: 28, height: 1.2);
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: WheelPicker(
              controller: controller,
              looping: false,
              enableTap: true,
              selectedIndexColor: Colors.brown.shade600,
              onIndexChanged: (index, _) => onChanged(index),
              builder: (context, index) {
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: textStyle,
                  ),
                );
              },
              style: const WheelPickerStyle(
                itemExtent: 38,
                diameterRatio: 1.2,
                surroundingOpacity: 0.35,
                magnification: 1.08,
                squeeze: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _boundaryTimer?.cancel();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingLabel = _formatDuration(_remaining);
    final primaryLabel = _isRunning
        ? 'Pause'
        : _isPaused
        ? 'Resume'
        : _isFinished
        ? 'Restart'
        : 'Start';
    final primaryAction = _isRunning ? _pause : _start;
    // 전체 화면 레이아웃 구조
    return Scaffold(
      appBar: AppBar(title: const Text('Drift Sand')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const SizedBox(height: 24),
            const Spacer(),
            Opacity(
              opacity: _status == TimerStatus.idle ? 1 : 0.6,
              child: IgnorePointer(
                ignoring: _status != TimerStatus.idle,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildWheel(
                          label: '',
                          controller: _hoursController,
                          onChanged: _setHours,
                        ),
                        const SizedBox(width: 8),
                        _buildWheel(
                          label: '',
                          controller: _minutesController,
                          onChanged: _setMinutes,
                        ),
                        const SizedBox(width: 8),
                        _buildWheel(
                          label: '',
                          controller: _secondsController,
                          onChanged: _setSeconds,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_showBoundaryWarning)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '24:00:00 초과 불가 — 23시간대로 조정됨',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isRunning
                        ? _pause
                        : (_canStart ? _start : null),
                    child: Text(primaryLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
