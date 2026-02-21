import 'dart:async';
import 'dart:ui';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8FBFA6)),
        useMaterial3: true,
        fontFamily: 'NotoSans',
        fontFamilyFallback: const ['NotoSansKR', 'NotoSansJP'],
        textTheme: ThemeData.light().textTheme.copyWith(
          titleLarge: const TextStyle(fontWeight: FontWeight.w600),
          titleMedium: const TextStyle(fontWeight: FontWeight.w600),
          titleSmall: const TextStyle(fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5B4634),
          ),
          iconTheme: IconThemeData(color: Color(0xFF5B4634)),
        ),
      ),
      home: const TimerHomePage(),
    );
  }
}

enum TimerStatus { idle, running, paused, finished }

class _GlassPalette {
  static const Color seed = Color(0xFF8FBFA6);
  static const List<Color> backgroundGradient = [
    Color(0xFFF6ECD9),
    Color(0xFFEAD9BF),
    Color(0xFFF4E7CF),
  ];
  static const Color panelBase = Color(0xFFEAF6EF);
  static const Color panelBorder = Color(0xFFCFE6D6);
  static const Color buttonText = Color(0xFF5B4634);
  static const Color buttonDisabledText = Color(0x995B4634);
}

class TimerHomePage extends StatefulWidget {
  const TimerHomePage({super.key});

  @override
  State<TimerHomePage> createState() => _TimerHomePageState();
}

class _TimerHomePageState extends State<TimerHomePage>
    with SingleTickerProviderStateMixin {
  static const int _tickIntervalMs = 200;
  static const int _maxHours = 24;
  static const int _maxMinutes = 59;
  static const int _maxSeconds = 59;

  TimerStatus _status = TimerStatus.idle;
  int _selectedHours = 0;
  int _selectedMinutes = 0;
  int _selectedSeconds = 0;
  Duration _remaining = Duration.zero;
  Duration _activeDuration = Duration.zero;
  DateTime? _endTime;
  Timer? _ticker;
  Timer? _boundaryTimer;
  bool _showBoundaryWarning = false;
  int _lastRenderedSeconds = -1;
  AnimationController? _repaintController;
  bool? _showControls = true;
  bool? _soundOn = true;

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
    _ensureRepaintController();
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

  void _ensureRepaintController() {
    _repaintController ??= AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  void _start() {
    _ensureRepaintController();
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
    _repaintController?.repeat();
    _startTicker();
    setState(() {});
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    _status = TimerStatus.paused;
    _syncRemaining();
    _syncWheelsToDuration(_remaining);
    _repaintController?.stop();
    setState(() {});
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    _status = TimerStatus.idle;
    _selectedHours = 0;
    _selectedMinutes = 0;
    _selectedSeconds = 0;
    _remaining = Duration.zero;
    _activeDuration = Duration.zero;
    _hoursController.setCurrent(0);
    _minutesController.setCurrent(0);
    _secondsController.setCurrent(0);
    _endTime = null;
    _lastRenderedSeconds = -1;
    _repaintController?.stop();
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
      _repaintController?.stop();
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
    required double wheelHeight,
    required double itemExtent,
    required double fontSize,
  }) {
    final textStyle = TextStyle(fontSize: fontSize, height: 1.2);
    return Expanded(
      child: Column(
        children: [
          if (label.isNotEmpty)
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (label.isNotEmpty) const SizedBox(height: 8),
          SizedBox(
            height: wheelHeight,
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
              style: WheelPickerStyle(
                itemExtent: itemExtent,
                diameterRatio: 1.2,
                surroundingOpacity: 1.0,
                magnification: 1.0,
                squeeze: 1.0,
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
    _repaintController?.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingLabel = _formatDuration(_remaining);
    final primaryLabel = _isRunning
        ? 'pause'
        : _isPaused
        ? 'resume'
        : _isFinished
        ? 'restart'
        : 'start';
    final primaryAction = _isRunning ? _pause : _start;
    const isLiquidGlass = true;
    // 전체 화면 레이아웃 구조
    return Scaffold(
      appBar: _HeaderBottomEdge(
        child: AppBar(
          title: const Text('Drift Sand'),
          backgroundColor: isLiquidGlass
              ? Colors.transparent
              : Colors.brown.shade100,
          surfaceTintColor: isLiquidGlass
              ? Colors.transparent
              : Colors.brown.shade100,
          elevation: isLiquidGlass ? 0 : null,
          flexibleSpace: isLiquidGlass
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: _GlassPalette.backgroundGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
              : null,
        ),
      ),
      extendBodyBehindAppBar: false,
      bottomNavigationBar: SafeArea(
        child: _GlassWrapper(
          enabled: isLiquidGlass,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            decoration: BoxDecoration(
              color: isLiquidGlass
                  ? Colors.white.withOpacity(0.12)
                  : Colors.brown.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLiquidGlass
                    ? Colors.white.withOpacity(0.35)
                    : Colors.brown.shade200,
              ),
            ),
            child: Text(
              'Ad Banner Placeholder',
              style: TextStyle(
                fontSize: 12,
                color: isLiquidGlass ? Colors.black87 : Colors.brown,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isLiquidGlass
              ? const LinearGradient(
                  colors: _GlassPalette.backgroundGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = (constraints.maxHeight / 720).clamp(1.0, 1.1);
              final gap = 20 * scale;
              final topGap = 0.0;
              final wheelHeight = 72 * scale * 1.3;
              final itemExtent = 38 * scale * 1.3;
              final fontSize = 22 * scale * 1.3;
              final maxHourglass = constraints.maxHeight * 0.6;
              final hourglassSize = (320 * scale * 1.3).clamp(
                260.0,
                maxHourglass,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Container(
                              margin: const EdgeInsets.only(
                                top: 8,
                                bottom: 10,
                              ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MiniIconButton(
                                      icon: (_showControls ?? true)
                                          ? Icons.arrow_drop_down_rounded
                                          : Icons.arrow_drop_up_rounded,
                                      onTap: () => setState(
                                        () => _showControls = !(
                                          _showControls ?? true),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  _MiniIconButton(
                                    icon: (_soundOn ?? true)
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                    onTap: () =>
                                        setState(
                                          () =>
                                              _soundOn = !(_soundOn ?? true),
                                        ),
                                  ),
                                    const SizedBox(width: 6),
                                    _MiniIconButton(
                                      icon: Icons.settings_rounded,
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: gap * 0.6),
                          Stack(
                            children: [
                              _GlassWrapper(
                                enabled: false,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: isLiquidGlass
                                        ? Colors.white.withOpacity(0.06)
                                        : null,
                                  ),
                                  child: SizedBox(
                                    height: hourglassSize,
                                    width: hourglassSize,
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: AnimatedBuilder(
                                        animation:
                                            _repaintController ??
                                            const AlwaysStoppedAnimation(0),
                                        builder: (context, _) {
                                          final selected = _selectedDuration();
                                          final idleEmpty =
                                              _status == TimerStatus.idle &&
                                              selected.inMilliseconds == 0;
                                          final forceIdleFull = idleEmpty;
                                          final displayDuration =
                                              _status == TimerStatus.idle
                                              ? (idleEmpty
                                                    ? const Duration(seconds: 1)
                                                    : selected)
                                              : _activeDuration;
                                          final displayRemaining =
                                              _status == TimerStatus.idle
                                              ? (idleEmpty
                                                    ? const Duration(seconds: 1)
                                                    : selected)
                                              : _remaining;
                                          final displayEndTime =
                                              _status == TimerStatus.running
                                              ? _endTime
                                              : null;
                                          return CustomPaint(
                                            painter: HourglassPainter(
                                              status: _status,
                                              activeDuration: displayDuration,
                                              remaining: displayRemaining,
                                              endTime: displayEndTime,
                                              forceIdleFull: forceIdleFull,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: gap),
                          if (_showControls ?? true)
                            Opacity(
                              opacity: _status == TimerStatus.idle ? 1 : 0.6,
                              child: IgnorePointer(
                                ignoring: _status != TimerStatus.idle,
                                child: CustomPaint(
                                  painter: _WheelBoxOutlinePainter(),
                                  child: _GlassWrapper(
                                    enabled: isLiquidGlass,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            _buildWheel(
                                              label: '',
                                              controller: _hoursController,
                                              onChanged: _setHours,
                                              wheelHeight: wheelHeight,
                                              itemExtent: itemExtent,
                                              fontSize: fontSize,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildWheel(
                                              label: '',
                                              controller: _minutesController,
                                              onChanged: _setMinutes,
                                              wheelHeight: wheelHeight,
                                              itemExtent: itemExtent,
                                              fontSize: fontSize,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildWheel(
                                              label: '',
                                              controller: _secondsController,
                                              onChanged: _setSeconds,
                                              wheelHeight: wheelHeight,
                                              itemExtent: itemExtent,
                                              fontSize: fontSize,
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
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: gap),
                          if (_showControls ?? true)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: _GlassButton(
                                    enabled: isLiquidGlass,
                                    filled: true,
                                    onPressed: _isRunning
                                        ? _pause
                                        : (_canStart ? _start : null),
                                    child: Text(primaryLabel),
                                  ),
                                ),
                                if (_status != TimerStatus.idle &&
                                    _status != TimerStatus.running) ...[
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 140,
                                    child: _GlassButton(
                                      enabled: isLiquidGlass,
                                      filled: false,
                                      onPressed: _reset,
                                      child: const Text('reset'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GlassWrapper extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _GlassWrapper({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return _GlassPanel(child: child);
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  final Color? fillColor;
  final Color? borderColor;

  const _GlassPanel({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.all(12),
    this.fillColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (fillColor ?? _GlassPalette.panelBase).withOpacity(0.14),
            borderRadius: borderRadius,
            border: Border.all(
              color: (borderColor ?? _GlassPalette.panelBorder).withOpacity(
                0.65,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  final bool enabled;
  final bool filled;
  final VoidCallback? onPressed;
  final Widget child;
  final Color? textColor;
  final Color? disabledTextColor;

  const _GlassButton({
    required this.enabled,
    required this.filled,
    required this.onPressed,
    required this.child,
    this.textColor,
    this.disabledTextColor,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.filled
          ? FilledButton(onPressed: widget.onPressed, child: widget.child)
          : OutlinedButton(onPressed: widget.onPressed, child: widget.child);
    }
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _pressed ? 0.96 : 1.0,
        child: Stack(
          children: [
            CustomPaint(
              painter: _ButtonOutlinePainter(),
              child: _GlassPanel(
                borderRadius: BorderRadius.circular(999),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: widget.onPressed == null
                          ? (widget.disabledTextColor ??
                                _GlassPalette.buttonDisabledText)
                          : (widget.textColor ?? _GlassPalette.buttonText),
                      fontWeight: FontWeight.w600,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _pressed ? 0.55 : 0.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.12),
                          const Color(0xFFF4D7AE).withOpacity(0.35),
                          const Color(0xFFF0CFA3).withOpacity(0.20),
                          Colors.black.withOpacity(0.10),
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(999));
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final inner = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 3);
    canvas.drawRRect(rrect, shadow);
    canvas.drawRRect(rrect, inner);
  }

  @override
  bool shouldRepaint(covariant _ButtonOutlinePainter oldDelegate) => false;
}

class _WheelBoxOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final inner = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 3);
    canvas.drawRRect(rrect, shadow);
    canvas.drawRRect(rrect, inner);
  }

  @override
  bool shouldRepaint(covariant _WheelBoxOutlinePainter oldDelegate) => false;
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
          ),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF5B4634)),
      ),
    );
  }
}

class _HeaderBottomEdge extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;

  const _HeaderBottomEdge({required this.child});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: 4,
            child: CustomPaint(painter: _HeaderBottomEdgePainter()),
          ),
        ),
      ],
    );
  }
}

class _HeaderBottomEdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final inner = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 3);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), shadow);
    canvas.drawLine(Offset(0, y), Offset(size.width, y), inner);
  }

  @override
  bool shouldRepaint(covariant _HeaderBottomEdgePainter oldDelegate) => false;
}

class HourglassPainter extends CustomPainter {
  final TimerStatus status;
  final Duration activeDuration;
  final Duration remaining;
  final DateTime? endTime;
  final bool forceIdleFull;

  HourglassPainter({
    required this.status,
    required this.activeDuration,
    required this.remaining,
    required this.endTime,
    this.forceIdleFull = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glassStroke = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final glassInnerStroke = Paint()
      ..color = Colors.white.withOpacity(0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final glassFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Color(0x66FFFFFF), Color(0x22FFFFFF), Color(0x10FFFFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);

    final glassShadow = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);

    final glassBodyEdgeShadow = Paint()
      ..color = Colors.black.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    final innerShadow = Paint()
      ..color = Colors.black.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 5);

    final baseGrainDark = Paint()
      ..color = const Color(0xFF8A5A33).withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    final baseGrainLight = Paint()
      ..color = const Color(0xFFC99B6B).withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final baseInnerShadow = Paint()
      ..color = const Color(0xFF6A3F20).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 3.2);

    final sandFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFF7E7C4).withOpacity(0.68),
          const Color(0xFFE8C98B).withOpacity(0.72),
          const Color(0xFFCE9F58).withOpacity(0.76),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Offset.zero & size);
    final sandHighlight = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final sandShadow = Paint()
      ..color = const Color(0xFFB7893D).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    final sandGrainLight = Paint()
      ..color = const Color(0xFFF6E6C3).withOpacity(0.35)
      ..style = PaintingStyle.fill;
    final sandGrainDark = Paint()
      ..color = const Color(0xFFC18B3C).withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final hasActive = activeDuration.inMilliseconds > 0;
    final hasRemaining = remaining.inMilliseconds > 0;
    final showIdleSand = status == TimerStatus.idle && !hasActive;
    final drawUpper =
        (hasActive && hasRemaining) || showIdleSand || forceIdleFull;
    final drawLower =
        !forceIdleFull &&
        status != TimerStatus.idle &&
        hasActive &&
        (hasRemaining || status == TimerStatus.finished);

    final progress = forceIdleFull ? 1.0 : (showIdleSand ? 1.0 : _progress());
    final upperFill = progress.clamp(0.0, 1.0);
    final lowerFill = (1 - progress).clamp(0.0, 1.0);

    final centerX = size.width / 2;
    final left = size.width * 0.10;
    final right = size.width * 0.90;
    final top = size.height * 0.06;
    final bottom = size.height * 0.94;
    final midY = size.height * 0.5;
    final neckY = midY;
    final topInset = size.width * 0.01;
    final neckInset = size.width * 0.08;
    final cornerRadius = (size.width * 0.06).clamp(6.0, 18.0);
    final innerInset = size.width * 0.03;
    final neckNarrowExtra = neckInset * 1.1;
    final innerNeckInset = (neckInset + innerInset - neckNarrowExtra).clamp(
      size.width * 0.01,
      neckInset + innerInset,
    );
    final capHeight = size.height * 0.055;
    final capWidthInset = size.width * 0.001;

    Path roundedTrapezoid({
      required double topY,
      required double bottomY,
      required double topInset,
      required double bottomInset,
      required double radius,
    }) {
      final topLeft = left + topInset;
      final topRight = right - topInset;
      final bottomLeft = left + bottomInset;
      final bottomRight = right - bottomInset;
      final maxR = [
        radius,
        (topRight - topLeft) / 2,
        (bottomRight - bottomLeft) / 2,
        (bottomY - topY) / 2,
      ].reduce((a, b) => a < b ? a : b);

      final r = maxR;
      final path = Path()
        ..moveTo(topLeft + r, topY)
        ..lineTo(topRight - r, topY)
        ..quadraticBezierTo(topRight, topY, topRight, topY + r)
        ..lineTo(bottomRight, bottomY - r)
        ..quadraticBezierTo(bottomRight, bottomY, bottomRight - r, bottomY)
        ..lineTo(bottomLeft + r, bottomY)
        ..quadraticBezierTo(bottomLeft, bottomY, bottomLeft, bottomY - r)
        ..lineTo(topLeft, topY + r)
        ..quadraticBezierTo(topLeft, topY, topLeft + r, topY)
        ..close();
      return path;
    }

    Path hourglassOutlinePath({
      required double topInsetValue,
      required double neckInsetValue,
    }) {
      final topLeft = left + topInsetValue;
      final topRight = right - topInsetValue;
      final neckLeft = centerX - neckInsetValue;
      final neckRight = centerX + neckInsetValue;
      final bottomLeft = left + topInsetValue;
      final bottomRight = right - topInsetValue;

      final upperH = midY - top;
      final lowerH = bottom - midY;

      final r = cornerRadius;
      return Path()
        ..moveTo(topLeft + r, top)
        ..lineTo(topRight - r, top)
        ..quadraticBezierTo(topRight, top, topRight, top + r)
        ..cubicTo(
          topRight,
          top + upperH * 0.35,
          neckRight,
          midY - upperH * 0.15,
          neckRight,
          midY,
        )
        ..cubicTo(
          neckRight,
          midY + lowerH * 0.15,
          bottomRight,
          bottom - lowerH * 0.35,
          bottomRight,
          bottom - r,
        )
        ..quadraticBezierTo(bottomRight, bottom, bottomRight - r, bottom)
        ..lineTo(bottomLeft + r, bottom)
        ..quadraticBezierTo(bottomLeft, bottom, bottomLeft, bottom - r)
        ..cubicTo(
          bottomLeft,
          bottom - lowerH * 0.35,
          neckLeft,
          midY + lowerH * 0.15,
          neckLeft,
          midY,
        )
        ..cubicTo(
          neckLeft,
          midY - upperH * 0.15,
          topLeft,
          top + upperH * 0.35,
          topLeft,
          top + r,
        )
        ..quadraticBezierTo(topLeft, top, topLeft + r, top)
        ..close();
    }

    final outlinePath = hourglassOutlinePath(
      topInsetValue: topInset,
      neckInsetValue: neckInset,
    );
    final innerOutlinePath = hourglassOutlinePath(
      topInsetValue: topInset + innerInset,
      neckInsetValue: innerNeckInset,
    );

    final topCap = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left + capWidthInset,
        top - capHeight,
        (right - left) - capWidthInset * 2,
        capHeight,
      ),
      Radius.circular(capHeight * 0.55),
    );
    final bottomCap = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left + capWidthInset,
        bottom,
        (right - left) - capWidthInset * 2,
        capHeight,
      ),
      Radius.circular(capHeight * 0.55),
    );

    canvas.save();
    canvas.drawPath(outlinePath, glassShadow);
    canvas.drawPath(outlinePath, glassFill);
    canvas.drawPath(outlinePath, innerShadow);
    canvas.clipPath(outlinePath);

    canvas.save();
    canvas.clipPath(innerOutlinePath);

    if (drawUpper) {
      final upperHeight = (midY - top) * upperFill;
      final upperTop = midY - upperHeight;
      final upperSide = roundedTrapezoid(
        topY: upperTop,
        bottomY: midY,
        topInset: topInset + innerInset + size.width * (1 - upperFill) * 0.12,
        bottomInset: innerNeckInset,
        radius: cornerRadius,
      );
      canvas.drawPath(upperSide, sandFill);
      canvas.drawPath(upperSide, sandShadow);
      _drawSandGrains(canvas, upperSide, sandGrainLight, sandGrainDark);
      final upperHighlight = upperSide.shift(
        Offset(size.width * 0.005, size.height * 0.004),
      );
      canvas.drawPath(upperHighlight, sandHighlight);
    }

    if (drawLower) {
      final lowerHeight = (bottom - midY) * lowerFill;
      final lowerTop = bottom - lowerHeight;
      final lowerSide = roundedTrapezoid(
        topY: lowerTop,
        bottomY: bottom,
        topInset: innerNeckInset,
        bottomInset: topInset + innerInset,
        radius: cornerRadius,
      );
      canvas.drawPath(lowerSide, sandFill);
      canvas.drawPath(lowerSide, sandShadow);
      _drawSandGrains(canvas, lowerSide, sandGrainLight, sandGrainDark);
      final lowerHighlight = lowerSide.shift(
        Offset(size.width * 0.004, size.height * 0.003),
      );
      canvas.drawPath(lowerHighlight, sandHighlight);
    }
    canvas.restore();

    canvas.save();
    final bodyTop = topCap.outerRect.bottom + 1;
    final bodyBottom = bottomCap.outerRect.top - 1;
    if (bodyBottom > bodyTop) {
      canvas.clipRect(
        Rect.fromLTWH(0, bodyTop, size.width, bodyBottom - bodyTop),
      );
      canvas.drawPath(outlinePath, glassBodyEdgeShadow);
    }
    canvas.restore();

    if (status == TimerStatus.running && hasRemaining) {
      final streamBottom = midY + (bottom - midY) * 0.65;
      _drawSandStream(
        canvas,
        centerX,
        neckY,
        streamBottom,
        innerNeckInset * 1.2,
        sandFill,
      );
    }

    canvas.restore();

    final baseRect = bottomCap.outerRect;
    final baseFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [Color(0xFFC69562), Color(0xFFA86E41), Color(0xFF91592E)],
        stops: [0.0, 0.55, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(baseRect);

    void drawWoodCap(RRect cap) {
      final rect = cap.outerRect;
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          colors: [Color(0xFFD7BD9B), Color(0xFFBF9872), Color(0xFFA67D59)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);

      canvas.drawRRect(cap, fill);
      canvas.drawRRect(cap, baseInnerShadow);

      canvas.save();
      canvas.clipRRect(cap);
      final grainTop = rect.top + rect.height * 0.22;
      final grainBottom = rect.bottom - rect.height * 0.18;
      final grainStep = (rect.height * 0.12).clamp(2.5, 5.5);
      final grainWidth = rect.width * 0.08;
      for (double y = grainTop; y < grainBottom; y += grainStep) {
        final phase = (y * 0.23) % 1.0;
        final amplitude = grainWidth * (0.35 + phase * 0.35);
        final cx = rect.center.dx;
        final path = Path()
          ..moveTo(rect.left - 8, y)
          ..quadraticBezierTo(cx - amplitude, y - grainStep * 0.4, cx, y)
          ..quadraticBezierTo(
            cx + amplitude,
            y + grainStep * 0.4,
            rect.right + 8,
            y,
          );
        canvas.drawPath(path, phase > 0.5 ? baseGrainDark : baseGrainLight);
      }
      canvas.restore();
    }

    drawWoodCap(bottomCap);
    drawWoodCap(topCap);

    // Remove outer white glass outline.

    // Removed top cap glass inner highlight for wood finish.

    final highlight = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    // Intentionally no vertical highlight line.
  }

  double _progress() {
    if (activeDuration.inMilliseconds == 0) return 0;
    if (status == TimerStatus.running && endTime != null) {
      final remainingMs = endTime!.difference(DateTime.now()).inMilliseconds;
      final ratio = remainingMs / activeDuration.inMilliseconds;
      return ratio.clamp(0, 1);
    }
    return (remaining.inMilliseconds / activeDuration.inMilliseconds).clamp(
      0,
      1,
    );
  }

  void _drawSandStream(
    Canvas canvas,
    double centerX,
    double neckY,
    double streamBottom,
    double streamWidth,
    Paint paint,
  ) {
    final streamTop = neckY;
    if (streamBottom <= streamTop) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final phase = (now % 2000) / 2000;
    const streamCount = 4;
    const dotCount = 10;
    final half = streamWidth / 2;
    for (int s = 0; s < streamCount; s++) {
      final tStream = s / (streamCount - 1);
      final x = centerX - half + streamWidth * tStream;
      final phaseOffset = (phase + s * 0.12) % 1.0;
      for (int i = 0; i < dotCount; i++) {
        final t = (i / dotCount + phaseOffset) % 1.0;
        final y = streamTop + (streamBottom - streamTop) * t;
        final radius = 0.7 + (i % 2) * 0.2;
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  void _drawSandGrains(
    Canvas canvas,
    Path sandPath,
    Paint lightPaint,
    Paint darkPaint,
  ) {
    final bounds = sandPath.getBounds();
    final step = (bounds.width * 0.045).clamp(4.0, 9.0);
    const seed = 1337;
    canvas.save();
    canvas.clipPath(sandPath);
    for (double y = bounds.top + step; y < bounds.bottom; y += step) {
      for (double x = bounds.left + step; x < bounds.right; x += step) {
        final h1 = _hash2d(x.toInt(), y.toInt(), seed);
        if (h1 < 0.5) {
          final h2 = _hash2d(x.toInt() + 17, y.toInt() + 29, seed);
          final dx = (h2 - 0.5) * step * 0.6;
          final h3 = _hash2d(x.toInt() + 53, y.toInt() + 71, seed);
          final dy = (h3 - 0.5) * step * 0.6;
          final radius = (0.6 + h1 * 1.1).clamp(0.6, 1.8);
          final paint = h2 > 0.5 ? lightPaint : darkPaint;
          canvas.drawCircle(Offset(x + dx, y + dy), radius, paint);
        }
      }
    }
    canvas.restore();
  }

  double _hash2d(int x, int y, int seed) {
    var n = x * 374761393 + y * 668265263 + seed * 1442695041;
    n = (n ^ (n >> 13)) * 1274126177;
    n = n ^ (n >> 16);
    return (n & 0x7fffffff) / 0x7fffffff;
  }

  @override
  bool shouldRepaint(covariant HourglassPainter oldDelegate) {
    return oldDelegate.status != status ||
        oldDelegate.remaining != remaining ||
        oldDelegate.activeDuration != activeDuration ||
        oldDelegate.endTime != endTime;
  }
}
