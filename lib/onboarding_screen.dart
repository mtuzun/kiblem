import 'package:flutter/material.dart';

import 'main.dart'
    show
        qiblaButtonKey,
        prayerListKey,
        dailyAyahKey,
        zikirButtonKey,
        settingsButtonKey;

class _CoachStep {
  final GlobalKey key;
  final IconData icon;
  final String title;
  final String description;
  final bool isDoubleTap;

  const _CoachStep({
    required this.key,
    required this.icon,
    required this.title,
    required this.description,
    this.isDoubleTap = false,
  });
}

final List<_CoachStep> _coachSteps = [
  _CoachStep(
    key: qiblaButtonKey,
    icon: Icons.explore,
    title: "Kıble Yönü",
    description: "Buraya dokunarak pusula ile Kâbe yönünü anında görebilirsin.",
  ),
  _CoachStep(
    key: prayerListKey,
    icon: Icons.access_time_filled,
    title: "Namaz Vakitleri",
    description: "Şehrine göre hesaplanan namaz vakitleri burada listelenir.",
  ),
  _CoachStep(
    key: dailyAyahKey,
    icon: Icons.menu_book,
    title: "Günün Ayeti",
    description: "Her gün burada yeni bir ayet gösterilir. Ayete çift dokunarak mealini açabilir ve sesli okunuşunu dinleyebilirsin.",
    isDoubleTap: true,
  ),
  _CoachStep(
    key: zikirButtonKey,
    icon: Icons.timer,
    title: "Zikirmatik",
    description: "Buraya dokunarak zikir sayacını açabilirsin.",
  ),
  _CoachStep(
    key: settingsButtonKey,
    icon: Icons.settings,
    title: "Ayarlar",
    description: "Buradan ezandan istediğin kadar önce (en fazla 15 dakika) hatırlatma bildirimini açabilirsin.",
  ),
];

class CoachMarkOverlay extends StatefulWidget {
  final VoidCallback onFinished;

  const CoachMarkOverlay({super.key, required this.onFinished});

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  Rect? _targetRect;

  late final AnimationController _enterController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureStep());
  }

  @override
  void dispose() {
    _enterController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _measureStep() async {
    final step = _coachSteps[_stepIndex];
    final ctx = step.key.currentContext;
    if (ctx == null) {
      _goNext(skipCurrent: true);
      return;
    }

    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      alignment: 0.5,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final freshCtx = step.key.currentContext;
    final renderBox = freshCtx?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      _goNext(skipCurrent: true);
      return;
    }

    final topLeft = renderBox.localToGlobal(Offset.zero);
    setState(() {
      _targetRect = topLeft & renderBox.size;
    });

    _enterController.forward(from: 0);
    _pulseController
      ..stop()
      ..reset()
      ..repeat();
  }

  void _goNext({bool skipCurrent = false}) {
    if (_stepIndex >= _coachSteps.length - 1) {
      widget.onFinished();
      return;
    }
    setState(() {
      _stepIndex++;
      _targetRect = null;
    });
    _pulseController.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureStep());
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final step = _coachSteps[_stepIndex];
    final rect = _targetRect;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(rect),
              ),
              if (rect != null) ...[
                _buildTapIndicator(rect, step),
                _buildCaptionCard(context, screenSize, rect, step),
              ],
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 12,
                child: TextButton(
                  onPressed: widget.onFinished,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text("Geç", style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTapIndicator(Rect rect, _CoachStep step) {
    final center = rect.center;
    return AnimatedBuilder(
      animation: Listenable.merge([_enterController, _pulseController]),
      builder: (context, child) {
        final enter = CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic).value;
        final pulse = _pulseController.value;
        // Hand slides in from bottom-right of the target, then taps in place.
        final startOffset = center + const Offset(55, 55);
        final handPos = Offset.lerp(startOffset, center, enter)!;

        // A single tap has one impact moment; a double-tap has two, close together.
        final tapMoments = step.isDoubleTap ? const [0.12, 0.30] : const [0.15];

        double handScale = 1.0;
        final ripples = <Widget>[];
        if (enter >= 1.0) {
          for (final moment in tapMoments) {
            final localT = pulse - moment;
            if (localT < 0) continue;

            if (localT < 0.08) {
              final bounce = 1.0 - (localT / 0.08);
              final scale = 1.0 - (bounce * 0.25);
              if (scale < handScale) handScale = scale;
            }

            final rippleT = (localT / 0.45).clamp(0.0, 1.0);
            if (rippleT > 0 && rippleT < 1) {
              ripples.add(
                Positioned(
                  left: center.dx - 30 * rippleT,
                  top: center.dy - 30 * rippleT,
                  child: Opacity(
                    opacity: (1 - rippleT).clamp(0.0, 1.0),
                    child: Container(
                      width: 60 * rippleT,
                      height: 60 * rippleT,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        }

        return IgnorePointer(
          child: Stack(
            children: [
              ...ripples,
              Positioned(
                left: handPos.dx - 16,
                top: handPos.dy - 16,
                child: Opacity(
                  opacity: enter,
                  child: Transform.scale(
                    scale: enter < 1.0 ? 1.0 : handScale,
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 34,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaptionCard(BuildContext context, Size screenSize, Rect rect, _CoachStep step) {
    final showBelow = rect.center.dy < screenSize.height / 2;
    const cardMargin = 20.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      left: cardMargin,
      right: cardMargin,
      top: showBelow ? rect.bottom + 24 : null,
      bottom: showBelow ? null : screenSize.height - rect.top + 24,
      child: FadeTransition(
        opacity: _enterController,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(step.icon, color: const Color(0xFF3E8E7E), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F3A34)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                step.description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3A), height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_coachSteps.length, (i) {
                      final active = i == _stepIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 5),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF3E8E7E) : const Color(0xFFD5E4DF),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  ElevatedButton(
                    onPressed: () => _goNext(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E8E7E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: Text(_stepIndex == _coachSteps.length - 1 ? "Anladım" : "İleri"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  static const double _padding = 10;

  _SpotlightPainter(this.targetRect);

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final fullRect = Offset.zero & size;

    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, scrimPaint);

    if (targetRect != null) {
      final holeRRect = RRect.fromRectAndRadius(
        targetRect!.inflate(_padding),
        const Radius.circular(18),
      );
      canvas.drawRRect(holeRRect, Paint()..blendMode = BlendMode.clear);
      canvas.restore();

      canvas.drawRRect(
        holeRRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    } else {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}
