import 'package:flutter/material.dart';

import '../brew_controller.dart';
import '../brew_session.dart';
import '../espresso_session.dart';
import '../espresso_vessel.dart';
import '../l10n/language.dart';
import 'brew_chart.dart';
import 'brew_timer.dart';
import 'style.dart';

class EspressoPanel extends StatelessWidget {
  final BrewController controller;
  const EspressoPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final shot = c.espresso;
    final s = context.l10n;
    final preparing = shot.phase == EspressoPhase.setup;
    final now = DateTime.now();
    final seconds = shot.secondsAt(now);
    final height = MediaQuery.sizeOf(context).height;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 608),
        child: ListView(
          key: const Key('espresso-panel'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            if (preparing)
              _DoseCard(controller: c)
            else ...[
              _ShotMetrics(
                shot: shot,
                seconds: seconds,
                flow: shot.flowAt(now),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(
                      s.brewFlow,
                      trailing: const Icon(
                        Icons.show_chart_rounded,
                        color: copper,
                        size: 21,
                      ),
                    ),
                    BrewChart(
                      points: shot.points,
                      target: 0,
                      seconds: seconds,
                      height:
                          height < 780
                              ? 104
                              : height < 820
                              ? 128
                              : 154,
                      showFlow: true,
                    ),
                  ],
                ),
              ),
            ],
            if (c.espressoNotice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  c.espressoNotice!,
                  style: const TextStyle(color: copperText),
                ),
              ),
            if (c.demo && (preparing || shot.active)) ...[
              const SizedBox(height: 10),
              if (preparing)
                TextField(
                  key: const Key('espresso-demo-weight'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: s.demoWeight,
                    suffixText: 'g',
                  ),
                  onChanged: (value) {
                    final weight = parseNumber(value);
                    if (weight.isFinite &&
                        weight >= 0 &&
                        weight <= c.scale!.info.capacityGrams) {
                      c.setDemoWeight(weight);
                    }
                  },
                )
              else
                TextButton(
                  onPressed: c.toggleEspressoDemoPour,
                  child: Text(c.espressoDemoPour ? s.stopPour : s.autoPour),
                ),
            ],
            if (preparing && !c.espressoNeedsDose) ...[
              const SizedBox(height: 12),
              _ShotCupCard(controller: c),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShotCupCard extends StatelessWidget {
  final BrewController controller;
  const _ShotCupCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = context.l10n;
    final reading = c.espressoReadingAvailable;
    final ready = reading && c.espressoCupReady;
    final title =
        c.taring
            ? s.checkingZeroShort
            : !reading
            ? s.connectScale
            : ready
            ? s.espressoCupReady
            : c.espressoWaitingForCup
            ? s.espressoPlaceCup
            : s.espressoClearScale;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                ready
                    ? Icons.check_circle_outline_rounded
                    : Icons.coffee_outlined,
                color: ready ? muted : copperText,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const Key('espresso-cup-instruction'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reading && !c.taring) ...[
                      const SizedBox(height: 4),
                      Text(
                        ready
                            ? s.espressoCupHint
                            : c.espressoWaitingForCup
                            ? s.espressoCupBeforeStart
                            : s.espressoRemoveDoseVessel,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (reading && !c.taring && c.espressoNeedsEmptyConfirmation) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('espresso-confirm-empty-scale'),
              onPressed:
                  c.canPrepareEspresso ? c.confirmEspressoEmptyScale : null,
              child: Text(s.espressoScaleIsEmpty),
            ),
          ],
        ],
      ),
    );
  }
}

class EspressoActions extends StatelessWidget {
  final BrewController controller;
  const EspressoActions({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final shot = c.espresso;
    final s = context.l10n;
    if (shot.phase == EspressoPhase.setup) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('espresso-manual-start'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
              onPressed:
                  c.canStartEspresso
                      ? () => c.startEspresso(automatic: false)
                      : null,
              child: Text(s.espressoManualStart, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const Key('espresso-auto-start'),
              onPressed:
                  c.canStartEspresso
                      ? () => c.startEspresso(automatic: true)
                      : null,
              child: Text(
                c.taring ? s.checkingZero : s.espressoArm,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    final armed = shot.phase == EspressoPhase.armed;
    final label =
        armed
            ? s.cancel
            : shot.active
            ? s.finishBrew
            : s.newBrew;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('espresso-finish'),
        onPressed: shot.active ? c.finishEspresso : c.resetEspresso,
        icon: Icon(
          shot.active ? Icons.stop_rounded : Icons.restart_alt_rounded,
          size: 18,
        ),
        label: Text(label),
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  final BrewController controller;
  const _DoseCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final s = context.l10n;
    final dose = c.espresso.dose;
    final candidate = c.espressoNetDose;
    final valid = candidate != null && EspressoSession.validDose(candidate);
    final editing = c.espressoNeedsDose;
    final liveDose = editing && valid ? candidate : null;
    final vessel = c.espressoVessel;
    final instruction =
        c.espressoZeroedForDose
            ? (vessel == null ? s.espressoPlaceBeans : s.espressoPlaceLoaded)
            : (vessel == null ? s.espressoTareDirect : s.espressoTareEmpty);
    final accessoryStyle = TextButton.styleFrom(
      foregroundColor: muted,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      textStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.dose,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              key: const Key('espresso-dose-reading-group'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/illustrations/coffee-beans.png',
                  width: 48,
                  height: 48,
                  cacheHeight: 264,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 12),
                Text.rich(
                  TextSpan(
                    text: (editing ? liveDose ?? 0 : dose!).toStringAsFixed(1),
                    children: const [
                      TextSpan(
                        text: ' g',
                        style: TextStyle(
                          fontSize: 22,
                          color: copper,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  key: const Key('espresso-dose'),
                  style: const TextStyle(
                    fontSize: 48,
                    height: 1.1,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              key: Key(editing ? 'espresso-manual-dose' : 'espresso-edit-dose'),
              style: OutlinedButton.styleFrom(
                foregroundColor: muted,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: const StadiumBorder(),
              ),
              onPressed:
                  !c.canPrepareEspresso
                      ? null
                      : editing
                      ? () => _enterDose(context)
                      : () => c.editEspressoDose(true),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: Text(
                editing ? s.espressoEnterDoseShort : s.espressoChangeDose,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (editing) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('espresso-vessel-${vessel?.id ?? ""}'),
              value: vessel?.id ?? '',
              isExpanded: true,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: ink, fontSize: 13),
              decoration: InputDecoration(
                labelText: s.espressoWeighWith,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(
                    s.espressoDirectWeigh,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final entry in c.espressoVessels)
                  DropdownMenuItem(
                    value: entry.id,
                    child: Text(
                      '${entry.name} · ${entry.grams.toStringAsFixed(1)} g',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged:
                  c.canPrepareEspresso
                      ? (id) => c.selectEspressoVessel(
                        c.espressoVessels.where((v) => v.id == id).firstOrNull,
                      )
                      : null,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const Key('espresso-vessels'),
                style: accessoryStyle,
                onPressed:
                    c.canPrepareEspresso ? () => _manageVessels(context) : null,
                icon: const Icon(Icons.inventory_2_outlined, size: 14),
                label: Text(s.espressoManageVesselsShort),
              ),
            ),
            if (liveDose == null) ...[
              Text(
                c.taring
                    ? s.checkingZero
                    : !c.espressoReadingAvailable
                    ? s.connectScale
                    : instruction,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
              if (!c.espressoZeroedForDose) ...[
                const SizedBox(height: 7),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    key: const Key('espresso-dose-tare'),
                    onPressed:
                        c.canTare && c.espressoReadingAvailable
                            ? c.tareEspressoDose
                            : null,
                    child: const Text('TARE'),
                  ),
                ),
              ],
            ] else
              FilledButton(
                key: const Key('espresso-use-dose'),
                onPressed:
                    c.canPrepareEspresso
                        ? () => c.setEspressoDose(liveDose, measured: true)
                        : null,
                child: Text(s.espressoUseDose, textAlign: TextAlign.center),
              ),
            if (dose != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('espresso-cancel-dose'),
                  style: accessoryStyle,
                  onPressed:
                      c.canPrepareEspresso
                          ? () => c.editEspressoDose(false)
                          : null,
                  child: Text(s.cancel),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _enterDose(BuildContext context) async {
    final c = controller;
    final s = context.l10n;
    final form = GlobalKey<FormState>();
    double dose = 0;
    final applied = await showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(s.enterDose),
            content: Form(
              key: form,
              child: TextFormField(
                key: const Key('espresso-manual-dose-field'),
                autofocus: true,
                initialValue: c.espresso.dose?.toStringAsFixed(1) ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(suffixText: 'g'),
                validator: (value) {
                  dose = parseNumber(value ?? '');
                  return EspressoSession.validDose(dose) ? null : s.doseRange;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, dose);
                  }
                },
                child: Text(s.applyDose),
              ),
            ],
          ),
    );
    if (applied != null) c.setEspressoDose(applied);
  }

  Future<void> _manageVessels(BuildContext context) async {
    final c = controller;
    c.clearEspressoWeighing();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: paper,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _Vessels(controller: c),
    );
    if (context.mounted) c.clearEspressoWeighing();
  }
}

class _ShotMetrics extends StatelessWidget {
  final EspressoSession shot;
  final double seconds, flow;
  const _ShotMetrics({
    required this.shot,
    required this.seconds,
    required this.flow,
  });

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final ratio = shot.ratio;
    final phase = switch (shot.phase) {
      EspressoPhase.setup => BrewPhase.setup,
      EspressoPhase.armed => BrewPhase.ready,
      EspressoPhase.brewing => BrewPhase.pouring,
      EspressoPhase.finished => BrewPhase.finished,
      EspressoPhase.interrupted => BrewPhase.interrupted,
    };
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s.espressoYield,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (shot.holding)
                Tooltip(
                  message: s.waitingStableWeight,
                  child: Icon(
                    Icons.circle,
                    size: 7,
                    color: const Color(0xffbc8638),
                    semanticLabel: s.waitingStableWeight,
                  ),
                ),
              if (shot.dose case final dose?)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Text(
                    s.doseChip(number(dose)),
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: shot.yieldGrams.toStringAsFixed(1),
                children: const [
                  TextSpan(
                    text: ' g',
                    style: TextStyle(
                      fontSize: 24,
                      color: copper,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 56,
                height: 1.1,
                letterSpacing: -1.5,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: s.flowPrefix,
              children: [
                TextSpan(
                  text: flow.toStringAsFixed(1),
                  style: const TextStyle(
                    color: espressoFlowBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' g/s'),
              ],
            ),
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: BrewTimer(
                  seconds: seconds,
                  phase: phase,
                  reached: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      s.brewRatio,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        ratio == null ? '—' : '1:${ratio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Vessels extends StatefulWidget {
  final BrewController controller;
  const _Vessels({required this.controller});

  @override
  State<_Vessels> createState() => _VesselsState();
}

class _VesselsState extends State<_Vessels> {
  static const _input = InputDecoration(
    fillColor: mint,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
  final _name = TextEditingController();
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveOrRemove([EspressoVessel? remove]) async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final c = widget.controller;
    final saved =
        remove == null
            ? await c.registerEspressoVessel(_name.text)
            : await c.removeEspressoVessel(remove);
    if (!mounted) return;
    setState(() {
      _failed = !saved;
      _saving = false;
      if (saved && remove == null) _name.clear();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final s = context.l10n;
      final weight = c.espressoRegistrationWeight;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionLabel(s.espressoVessels),
                for (final entry in c.espressoVessels)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.name),
                    subtitle: Text('${entry.grams.toStringAsFixed(1)} g'),
                    trailing: IconButton(
                      tooltip: s.delete,
                      onPressed: _saving ? null : () => _saveOrRemove(entry),
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ),
                if (c.espressoVessels.isNotEmpty) const Divider(height: 24),
                SectionLabel(s.espressoRegister),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('espresso-vessel-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 40,
                  decoration: _input.copyWith(
                    labelText: s.espressoVesselName,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Text(
                  !c.espressoReadingAvailable
                      ? s.connectScale
                      : c.espressoZeroedForDose
                      ? s.espressoPlaceEmpty
                      : s.espressoTareEmpty,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                if (c.demo) ...[
                  const SizedBox(height: 6),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _input.copyWith(
                      labelText: s.demoWeight,
                      suffixText: 'g',
                    ),
                    onChanged: (value) {
                      final grams = parseNumber(value);
                      if (grams.isFinite &&
                          grams >= 0 &&
                          grams <= c.scale!.info.capacityGrams) {
                        c.setDemoWeight(grams);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      key: const Key('espresso-register-tare'),
                      onPressed:
                          !_saving && c.canTare && c.espressoReadingAvailable
                              ? c.tareEspressoDose
                              : null,
                      child: const Text('TARE'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const Key('espresso-register-save'),
                        onPressed:
                            !_saving &&
                                    weight != null &&
                                    _name.text.trim().isNotEmpty
                                ? () => _saveOrRemove()
                                : null,
                        child: Text(
                          weight == null
                              ? s.save
                              : s.espressoSaveVessel(weight.toStringAsFixed(1)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      s.saveRetry,
                      style: const TextStyle(color: copperText),
                    ),
                  ),
                if (c.espressoNotice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      c.espressoNotice!,
                      style: const TextStyle(color: copperText),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
