import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings.dart';

/// Small pieces of the reader: the status line, the night-theme schedule, the warm-light filter and the
/// page-turn animation.

const _audio = MethodChannel('lantern/audio');

/// Whether the night theme is wanted now, or null when the user switches themes by hand.
bool? nightWanted(Settings s, DateTime now, Brightness platform) {
  switch (s.autoNight) {
    case 'system':
      return platform == Brightness.dark;
    case 'schedule':
      final m = now.hour * 60 + now.minute, from = s.nightFrom, to = s.nightTo;
      return from <= to ? (m >= from && m < to) : (m >= from || m < to);
    default:
      return null;
  }
}

String fmtClockMinutes(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Roughly how long the rest of a chapter takes to read, from [chars] still to read (about 1,000 characters
/// a minute), e.g. "6 min left in chapter".
String timeLeftLabel(int chars) {
  if (chars <= 0) return 'End of chapter';
  final m = (chars / 1000).ceil();
  return m < 60 ? '$m min left in chapter' : '${(m / 60).toStringAsFixed(1)} h left in chapter';
}

/// Takes blue and some green out of the page for evening reading. [w] is 0..1.
ColorFilter warmFilter(double w) => ColorFilter.matrix(<double>[
  1, 0, 0, 0, 0, //
  0, 1 - 0.18 * w, 0, 0, 0,
  0, 0, 1 - 0.55 * w, 0, 0,
  0, 0, 0, 1, 0,
]);

/// Clock and battery for the bottom of the page, refreshed every half minute.
class ClockBattery extends StatefulWidget {
  final TextStyle style;
  const ClockBattery({super.key, required this.style});
  @override
  State<ClockBattery> createState() => _ClockBatteryState();
}

class _ClockBatteryState extends State<ClockBattery> {
  Timer? _t;
  int? _level;
  bool _charging = false;

  @override
  void initState() {
    super.initState();
    _battery();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      _battery();
      if (mounted) setState(() {});
    });
  }

  Future<void> _battery() async {
    if (!Platform.isAndroid) return;
    try {
      final r = await _audio.invokeMapMethod<String, Object?>('batteryLevel');
      if (!mounted || r == null) return;
      setState(() {
        _level = (r['level'] as num?)?.toInt();
        _charging = r['charging'] == true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(now, alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat);
    final l = _level;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: widget.style),
        if (l != null) ...[
          const SizedBox(width: 10),
          Icon(
            _charging
                ? Icons.battery_charging_full
                : l > 85
                ? Icons.battery_full
                : l > 60
                ? Icons.battery_5_bar
                : l > 35
                ? Icons.battery_3_bar
                : l > 15
                ? Icons.battery_2_bar
                : Icons.battery_alert,
            size: (widget.style.fontSize ?? 12) + 2,
            color: widget.style.color,
          ),
          Text('$l%', style: widget.style),
        ],
      ],
    );
  }
}

/// "Turn" page animation: the next page swings in from the right, hinged at the left edge like a page
/// being laid down, while the page under it stays still and dims.
class PageTurn extends StatelessWidget {
  final PageController controller;
  final int index;
  final double width;
  final Color background;
  final Widget child;
  const PageTurn({
    super.key,
    required this.controller,
    required this.index,
    required this.width,
    required this.background,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final page = ColoredBox(color: background, child: child);
    return AnimatedBuilder(
      animation: controller,
      child: page,
      builder: (context, w) {
        var at = index.toDouble();
        if (controller.hasClients && controller.position.haveDimensions) at = controller.page ?? at;
        final d = index - at;
        if (d == 0 || d.abs() >= 1) return w!;
        if (d < 0) {
          // The page underneath: keep it in place and darken it as the new one covers it.
          return Transform.translate(
            offset: Offset(-d * width, 0),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                w!,
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Colors.black.withValues(alpha: (-d) * 0.28)),
                  ),
                ),
              ],
            ),
          );
        }
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0011)
            ..translateByDouble(-d * width, 0, 0, 1)
            ..rotateY(-d * math.pi / 2),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.18 * d),
                  Colors.transparent,
                ],
                stops: const [0, 0.25],
              ),
            ),
            child: w,
          ),
        );
      },
    );
  }
}
