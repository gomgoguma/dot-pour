import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../brew_controller.dart';
import 'style.dart';

class WeighingPanel extends StatelessWidget {
  final BrewController controller;
  const WeighingPanel({super.key, required this.controller});

  Future<void> _editDose(BuildContext context) async {
    final c = controller;
    final form = GlobalKey<FormState>();
    double? dose;
    final selected = await showDialog<double>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(context.l10n.enterDose),
            content: Form(
              key: form,
              child: TextFormField(
                key: const Key('manual-dose-field'),
                initialValue: number(c.setupDose ?? c.brew.dose),
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.dose,
                  suffixText: 'g',
                ),
                validator: (value) => c.validateDose(parseNumber(value ?? '')),
                onSaved: (value) => dose = parseNumber(value ?? ''),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final state = form.currentState!;
                  if (!state.validate()) return;
                  state.save();
                  Navigator.pop(dialogContext, dose);
                },
                child: Text(context.l10n.applyDose),
              ),
            ],
          ),
    );
    if (context.mounted && selected != null) c.setDose(selected);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final isWeighing = c.isDoseWeighing;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final grams = c.setupDose;
    final suggested = c.suggestedDose;
    final busy = c.starting || c.taring;
    final connected = c.scale?.connected == true;
    final overloaded = !c.demo && c.scale?.reading?.overloaded == true;
    final status =
        busy
            ? context.l10n.checkingZeroShort
            : !connected && !c.demo
            ? context.l10n.connectScale
            : overloaded
            ? context.l10n.overloadedScale
            : c.currentGrams == null
            ? context.l10n.waitingReading
            : c.addingEquipment
            ? context.l10n.checkingEquipment
            : isWeighing && grams == null
            ? context.l10n.setupEquipmentAgain
            : null;
    final ready = status == null && c.equipmentReady && suggested == null;
    return SurfaceCard(
      key: const Key('weighing-panel'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isWeighing
                      ? context.l10n.weighCoffee
                      : context.l10n.equipmentSetup,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: const Key('manual-dose'),
                onPressed: busy ? null : () => _editDose(context),
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text(
                  context.l10n.enterDose,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (isWeighing) ...[
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  key: const Key('weighing-reading-group'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _illustration(context, true),
                    const SizedBox(width: 16),
                    Text.rich(
                      TextSpan(
                        text:
                            overloaded
                                ? context.l10n.overCapacity
                                : grams?.toStringAsFixed(1) ?? '—',
                        children:
                            overloaded || grams == null
                                ? null
                                : const [
                                  TextSpan(
                                    text: ' g',
                                    style: TextStyle(
                                      fontSize: 26,
                                      letterSpacing: 0,
                                      color: copper,
                                    ),
                                  ),
                                ],
                      ),
                      key: const Key('live-weight'),
                      semanticsLabel:
                          grams == null ? context.l10n.doseRequired : null,
                      style: const TextStyle(
                        fontSize: 56,
                        height: 1.1,
                        letterSpacing: -1.5,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status ??
                        (c.confirmedDose != null
                            ? context.l10n.doseConfirmed
                            : (grams ?? 0) > 0
                            ? context.l10n.checkCoffeeWeight
                            : context.l10n.addCoffee),
                    key: const Key('weighing-instruction'),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const Key('dose-step-equipment'),
                  onPressed: c.canChangeScale ? c.returnToEquipment : null,
                  style: TextButton.styleFrom(
                    foregroundColor: muted,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 14),
                  label: Text(
                    context.l10n.resetEquipment,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _illustration(context, false, size: compact ? 48 : 60),
                  SizedBox(width: compact ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status ??
                              (c.preparingAgain
                                  ? context.l10n.setUpAgain
                                  : context.l10n.placeServerDripper),
                          key: const Key('weighing-instruction'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          c.preparingAgain
                              ? context.l10n.removeCoffee
                              : ready
                              ? context.l10n.readyToWeigh
                              : context.l10n.addCoffeeNext,
                          key: ready ? const Key('equipment-ready-hint') : null,
                          style: TextStyle(
                            color: ready ? copperText : muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (suggested != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: softCopper,
                border: Border.all(color: copper.withValues(alpha: .25)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.didAddCoffee,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextButton(
                      key: const Key('apply-suggested-dose'),
                      onPressed: busy ? null : () => c.setDose(suggested),
                      style: TextButton.styleFrom(foregroundColor: copperText),
                      child: Text(
                        context.l10n.useDetectedDose(number(suggested)),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isWeighing) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('dose-step-beans'),
              onPressed:
                  c.canEnterDoseWeighing
                      ? () {
                        FocusScope.of(context).unfocus();
                        c.enterDoseWeighing();
                      }
                      : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: ready ? softCopper : mint,
                foregroundColor: ready ? copperText : ink,
                side: BorderSide(
                  color: ready ? copper.withValues(alpha: .45) : controlLine,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.startWeighing,
                    style: TextStyle(fontSize: 13),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
          if (c.demo) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.demoWeight,
              style: TextStyle(color: muted, fontSize: 12),
            ),
            Slider(
              key: const Key('demo-dose'),
              value: c.demoWeight.clamp(0, 100),
              max: 100,
              divisions: 200,
              onChanged: busy ? null : c.setDemoWeight,
            ),
          ],
        ],
      ),
    );
  }

  Widget _illustration(
    BuildContext context,
    bool isWeighing, {
    double size = 60,
  }) => Image.asset(
    isWeighing
        ? 'assets/illustrations/coffee-beans.png'
        : 'assets/illustrations/pour-over-setup.png',
    key: const Key('setup-illustration'),
    width: size,
    height: size,
    cacheHeight: 264,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel:
        isWeighing
            ? context.l10n.coffeeBeans
            : context.l10n.equipmentIllustration,
  );
}
