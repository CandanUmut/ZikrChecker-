import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:permission_handler/permission_handler.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  bool _locGranted = false;
  bool _sensorAvailable = true;
  bool _checking = true;
  StreamSubscription<QiblahDirection>? _streamSub;
  QiblahDirection? _latestDirection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  Future<void> _init() async {
    setState(() => _checking = true);
    await _requestPermissions();
    try {
      _sensorAvailable = await FlutterQiblah.androidDeviceSensorSupport() ?? true;
    } catch (_) {
      _sensorAvailable = true;
    }
    if (_locGranted) {
      _subscribe();
    }
    setState(() => _checking = false);
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) {
      _locGranted = true;
    } else if (status.isDenied) {
      final res = await Permission.locationWhenInUse.request();
      _locGranted = res.isGranted;
    } else if (status.isPermanentlyDenied) {
      _locGranted = false;
    }
    if (await Permission.sensors.isDenied) {
      await Permission.sensors.request();
    }
  }

  void _subscribe() {
    _streamSub?.cancel();
    _streamSub = FlutterQiblah.qiblahStream.listen((event) {
      setState(() => _latestDirection = event);
    });
  }

  void _openSettings() => openAppSettings();

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_locGranted) {
      return _buildPermissionCard(
        context,
        title: 'Location Required',
        body: 'We need your location to calculate the Qibla direction accurately.',
        actionLabel: 'Grant Permission',
        onPressed: () async {
          await _requestPermissions();
          if (_locGranted) _subscribe();
          else if (await Permission.locationWhenInUse.isPermanentlyDenied) {
            _openSettings();
          }
          setState(() {});
        },
      );
    }
    if (!_sensorAvailable) {
      return _buildInfo(
        context,
        icon: Icons.warning_amber_rounded,
        title: 'Compass Sensor Unavailable',
        msg: 'Your device does not provide a compass sensor.',
      );
    }
    if (_latestDirection == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final dir = _latestDirection!;
    // dir.qiblah = bearing to Qibla from North clockwise
    final qiblaBearingDeg = dir.qiblah;
    final angleRad = qiblaBearingDeg * pi / 180;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 280,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Compass Dial (static)
              _CompassDial(),
              // Rotating Arrow
              Transform.rotate(
                angle: angleRad,
                child: _QiblaArrow(),
              ),
              // Center Label
              Positioned(
                bottom: 12,
                child: Column(
                  children: [
                    Text(
                      'Qibla Direction',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${qiblaBearingDeg.toStringAsFixed(1)}°',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _init,
          icon: const Icon(Icons.refresh),
          label: const Text('Recalibrate'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Rotate your phone until the arrow points directly upward. '
                'Move in a gentle figure‑8 motion if direction seems unstable.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionCard(
      BuildContext context, {
        required String title,
        required String body,
        required String actionLabel,
        required VoidCallback onPressed,
      }) {
    final theme = Theme.of(context);
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.my_location, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(body, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onPressed, child: Text(actionLabel)),
              TextButton(onPressed: _openSettings, child: const Text('Open App Settings')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context,
      {required IconData icon, required String title, required String msg}) {
    final theme = Theme.of(context);
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(msg, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _init, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static compass dial painter with North mark
class _CompassDial extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(260, 260),
      painter: _DialPainter(
        primary: Theme.of(context).colorScheme.primary,
        outline: Theme.of(context).colorScheme.primary.withOpacity(0.6),
        tick: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final Color primary;
  final Color outline;
  final Color tick;

  _DialPainter({required this.primary, required this.outline, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final ringPaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius - 2, bgPaint);
    canvas.drawCircle(center, radius - 2, ringPaint);

    // Minor ticks every 15°
    for (int i = 0; i < 360; i += 15) {
      final rad = i * pi / 180;
      final inner = center + Offset((radius - 14) * cos(rad), (radius - 14) * sin(rad));
      final outer = center + Offset((radius - 6) * cos(rad), (radius - 6) * sin(rad));
      final p = Paint()
        ..color = i % 90 == 0 ? primary : tick
        ..strokeWidth = i % 90 == 0 ? 3 : 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, p);
    }

    // North label
    // Kaaba label (instead of North)
    final kaabaPainter = TextPainter(
      text: TextSpan(
        text: 'Kaaba',
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final kaabaOffset = center - Offset(kaabaPainter.width / 2, radius - 34);
    kaabaPainter.paint(canvas, kaabaOffset);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.outline != outline;
}

/// Rotating Qibla arrow
class _QiblaArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: const Size(200, 200),
      painter: _ArrowPainter(primary),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final path = Path();
    // Arrow points up (0°). Build a stylized pointer.
    final arrowLength = size.height * 0.42;
    final shaftWidth = 8.0;
    final headHeight = 34.0;
    final headWidth = 28.0;

    // Shaft
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center - Offset(0, headHeight / 2),
        width: shaftWidth,
        height: arrowLength - headHeight,
      ),
      const Radius.circular(4),
    ));

    // Head (triangle)
    final headTop = center - Offset(0, arrowLength);
    path.moveTo(headTop.dx, headTop.dy);
    path.lineTo(headTop.dx - headWidth / 2, headTop.dy + headHeight);
    path.lineTo(headTop.dx + headWidth / 2, headTop.dy + headHeight);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadow = Paint()
      ..color = color.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path, shadow);
    canvas.drawPath(path, paint);

    // Center circle
    final centerCircle = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 10, centerCircle);
    canvas.drawCircle(
        center,
        10,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
