import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../brew_controller.dart';
import 'style.dart';

class BasicScale extends StatelessWidget {
  final BrewController controller;
  const BasicScale({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final grams = c.currentGrams;
    final overloaded = !c.demo && c.scale?.reading?.overloaded == true;
    final timer = c.scaleTimer;
    final elapsed = timer.elapsed;
    final tenths = elapsed.inMilliseconds ~/ 100 % 10;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 608),
        child: SingleChildScrollView(
          key: const Key('basic-scale'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.liveWeight,
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text.rich(
                          TextSpan(
                            text:
                                overloaded
                                    ? context.l10n.overCapacity
                                    : grams?.toStringAsFixed(1) ?? '0.0',
                            children:
                                overloaded
                                    ? null
                                    : const [
                                      TextSpan(
                                        text: ' g',
                                        style: TextStyle(
                                          fontSize: 24,
                                          letterSpacing: 0,
                                          color: copper,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                          ),
                          key: const Key('basic-scale-weight'),
                          style: const TextStyle(
                            fontSize: 64,
                            letterSpacing: -1.5,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: context.l10n.flowPrefix,
                        children: [
                          TextSpan(
                            text: c.scaleFlow.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const TextSpan(text: ' g/s'),
                        ],
                      ),
                      key: const Key('basic-scale-flow'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (grams == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          c.scale?.connected == true
                              ? context.l10n.waitingScaleReading
                              : context.l10n.connectScalePeriod,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('basic-scale-tare'),
                      onPressed: c.canTare ? c.tare : null,
                      style: secondaryButtonStyle().copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 20),
                      label: Text(
                        c.taring
                            ? context.l10n.checkingZero
                            : context.l10n.tareButton,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.timer,
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            context.l10n.autoDetectPour,
                            textAlign: TextAlign.end,
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 42,
                          height: 36,
                          child: FittedBox(
                            child: Switch(
                              key: const Key('scale-auto-start'),
                              value: c.scaleAutoStart,
                              onChanged: c.setScaleAutoStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          text: clockText(elapsed.inMilliseconds / 1000),
                          children: [
                            TextSpan(
                              text: '.$tenths',
                              style: const TextStyle(
                                fontSize: 28,
                                color: muted,
                                letterSpacing: -.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        key: const Key('manual-timer-value'),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.scaleAutoStart
                          ? (timer.running
                              ? context.l10n.timerRunning
                              : elapsed > Duration.zero
                              ? context.l10n.resumeTimerHint
                              : context.l10n.pourFromZero)
                          : context.l10n.manualTimerHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('manual-timer-reset'),
                            onPressed:
                                elapsed > Duration.zero || timer.running
                                    ? c.resetScaleTimer
                                    : null,
                            style: secondaryButtonStyle(),
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 18,
                            ),
                            label: Text(context.l10n.reset),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('manual-timer-toggle'),
                            onPressed: c.toggleScaleTimer,
                            icon: Icon(
                              timer.running
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            label: Text(
                              timer.running
                                  ? context.l10n.pause
                                  : elapsed > Duration.zero
                                  ? context.l10n.resume
                                  : context.l10n.start,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (c.notice != null || c.scale?.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    c.notice ?? c.scale!.error!,
                    style: const TextStyle(color: copper, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
