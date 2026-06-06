import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class ApprovedCelebration extends StatefulWidget {
  final int approvedCount;
  final VoidCallback onTap;
  final Color color;

  const ApprovedCelebration({
    Key? key,
    required this.approvedCount,
    required this.onTap,
    this.color = Colors.green,
  }) : super(key: key);

  @override
  State<ApprovedCelebration> createState() => _ApprovedCelebrationState();
}

class _ApprovedCelebrationState extends State<ApprovedCelebration>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _bgPulseController;
  late AnimationController _scaleController;
  late AnimationController _textGlowController;
  late ConfettiController _confettiController;

  int _previousCount = 0;
  bool _isFirstBuild = true;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _bgPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));

    _previousCount = widget.approvedCount;

    // Trigger initial celebration after first frame if count > 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.approvedCount > 0) {
          _triggerCelebration();
        }
        _isFirstBuild = false; // mark that initial frame has passed
      }
    });
  }

  @override
  void didUpdateWidget(ApprovedCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger celebration when count increases (and not the initial frame)
    if (!_isFirstBuild && widget.approvedCount > oldWidget.approvedCount) {
      _triggerCelebration();
    }

    _previousCount = oldWidget.approvedCount;
  }

  void _triggerCelebration() {
    // Reset and play the scale animation
    _scaleController
      ..reset()
      ..forward();

    // Reset and play text glow
    _textGlowController
      ..reset()
      ..forward();

    // Play confetti
    _confettiController.play();

    // Stop confetti after the duration
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _confettiController.stop();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _bgPulseController.dispose();
    _scaleController.dispose();
    _textGlowController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.approvedCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _glowController,
          _bgPulseController,
          _scaleController,
          _textGlowController,
        ]),
        builder: (context, _) {
          final double glowValue = 0.95 + 0.05 * (1 - _glowController.value);
          final bgOpacity = 0.1 + 0.1 * _bgPulseController.value;

          // Scale animation value with elastic curve
          final scaleValue =
              1.0 + 0.2 * Curves.elasticOut.transform(_scaleController.value);

          // Text glow intensity
          final textGlowIntensity = _textGlowController.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft background pulse
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withOpacity(bgOpacity),
                      Colors.white.withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

              // Subtle confetti
              Align(
                alignment: Alignment.center,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.02,
                  numberOfParticles: 12,
                  maxBlastForce: 6,
                  minBlastForce: 2,
                  gravity: 0.08,
                  colors: [
                    widget.color,
                    Colors.white,
                    Colors.lightGreenAccent,
                  ],
                ),
              ),

              // Main content with scale animation
              Transform.scale(
                scale: scaleValue,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: glowValue,
                      child: Icon(
                        Icons.verified_rounded,
                        color: widget.color,
                        size: 40,
                        shadows: [
                          Shadow(
                            blurRadius: 15,
                            color: widget.color.withOpacity(0.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: ShaderMask(
                        key: ValueKey(widget.approvedCount),
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: [
                              Colors.white,
                              widget.color,
                              Colors.white,
                            ],
                            stops: [0.2, 0.5 + textGlowIntensity * 0.3, 0.8],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          '${widget.approvedCount} Approved',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                blurRadius: 6 + textGlowIntensity * 4,
                                color: widget.color
                                    .withOpacity(0.4 + textGlowIntensity * 0.3),
                              ),
                              Shadow(
                                blurRadius: 2,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
