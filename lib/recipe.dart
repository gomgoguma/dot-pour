import 'dart:math' as math;

enum PourUnit { grams, percent }

class BrewPoint {
  final double seconds;
  final double grams;
  final double flow;
  const BrewPoint(this.seconds, this.grams, this.flow);
  List<num> toJson() => [seconds, grams, flow];
  factory BrewPoint.fromJson(List<dynamic> value) {
    if (value.length != 3) throw const FormatException('Invalid point');
    final point = BrewPoint(
      (value[0] as num).toDouble(),
      (value[1] as num).toDouble(),
      (value[2] as num).toDouble(),
    );
    if (![point.seconds, point.grams, point.flow].every((n) => n.isFinite) ||
        point.seconds < 0 ||
        point.grams < 0 ||
        point.flow < 0) {
      throw const FormatException('Invalid point values');
    }
    return point;
  }
}

class PourStep {
  final double start;
  final double duration;

  /// Additional water in this step, not the cumulative target.
  final double amount;
  const PourStep({
    required this.start,
    required this.duration,
    required this.amount,
  });
  double get end => start + duration;
  Map<String, dynamic> toJson() => {
    'start': start,
    'duration': duration,
    'amount': amount,
  };
  factory PourStep.fromJson(Map<String, dynamic> data) => PourStep(
    start: (data['start'] as num).toDouble(),
    duration: (data['duration'] as num).toDouble(),
    amount: (data['amount'] as num).toDouble(),
  );
}

class BrewRecipe {
  final String id;
  final String name;
  final double dose;
  final double ratio;
  final PourUnit unit;
  final List<PourStep> steps;
  final List<BrewPoint> trace;
  final double duration;
  final DateTime createdAt;
  final bool isDemo;

  BrewRecipe({
    required this.id,
    required this.name,
    required this.dose,
    required this.ratio,
    required this.unit,
    required List<PourStep> steps,
    List<BrewPoint> trace = const [],
    required this.duration,
    required this.createdAt,
    this.isDemo = false,
  }) : steps = List.unmodifiable(steps),
       trace = List.unmodifiable(trace);

  double get target => dose * ratio;
  bool get recorded => trace.isNotEmpty;
  double gramsFor(PourStep step) =>
      unit == PourUnit.percent ? target * step.amount / 100 : step.amount;
  double get plannedGrams => steps.fold(0, (sum, step) => sum + gramsFor(step));
  double cumulativeAt(int index) =>
      steps.take(index + 1).fold(0, (sum, step) => sum + gramsFor(step));

  List<BrewPoint> get curve {
    if (recorded) return trace;
    final points = <BrewPoint>[const BrewPoint(0, 0, 0)];
    double mass = 0;
    for (final step in steps) {
      points.add(BrewPoint(step.start, mass, 0));
      mass += gramsFor(step);
      points.add(BrewPoint(step.end, mass, gramsFor(step) / step.duration));
    }
    points.add(BrewPoint(duration, mass, 0));
    return points;
  }

  double expectedGrams(double seconds) => interpolate(curve, seconds);
  static double interpolate(List<BrewPoint> points, double seconds) {
    if (points.isEmpty || seconds < points.first.seconds) return 0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (seconds <= b.seconds) {
        if (b.seconds == a.seconds) return b.grams;
        return a.grams +
            (b.grams - a.grams) *
                (seconds - a.seconds) /
                (b.seconds - a.seconds);
      }
    }
    return points.last.grams;
  }

  /// Changing the dose scales water amounts while retaining pour timings.
  BrewRecipe scaled(double dose, double ratio) {
    final factor = dose * ratio / target;
    return BrewRecipe(
      id: id,
      name: name,
      dose: dose,
      ratio: ratio,
      unit: unit,
      steps:
          steps
              .map(
                (s) => PourStep(
                  start: s.start,
                  duration: s.duration,
                  amount: unit == PourUnit.grams ? s.amount * factor : s.amount,
                ),
              )
              .toList(),
      trace:
          trace
              .map(
                (p) => BrewPoint(p.seconds, p.grams * factor, p.flow * factor),
              )
              .toList(),
      duration: duration,
      createdAt: createdAt,
      isDemo: isDemo,
    );
  }

  String? validate() {
    if (name.trim().isEmpty || name.length > 60) {
      return '레시피 이름을 1~60자로 입력해 주세요.';
    }
    if (!dose.isFinite ||
        dose < 0.1 ||
        dose > 100 ||
        !ratio.isFinite ||
        ratio < 1 ||
        ratio > 30 ||
        target > 1200) {
      return '원두량과 비율을 확인해 주세요. 목표는 1,200g 이하여야 합니다.';
    }
    if (!duration.isFinite || duration <= 0) return '총 추출시간을 입력해 주세요.';
    if (steps.isEmpty && !recorded) return '붓기 단계를 하나 이상 추가해 주세요.';
    if (!recorded && steps.first.start != 0) return '첫 붓기는 0초부터 시작해 주세요.';
    double previousEnd = 0;
    for (final step in steps) {
      if (![step.start, step.duration, step.amount].every((n) => n.isFinite) ||
          step.start < previousEnd - 0.001 ||
          step.duration <= 0 ||
          step.amount <= 0) {
        return '차수의 시작 시간·붓는 시간·물량을 확인해 주세요. 시간은 겹칠 수 없습니다.';
      }
      previousEnd = step.end;
    }
    if (duration < previousEnd) return '총 추출시간은 마지막 붓기 종료 이후여야 합니다.';
    if (!recorded &&
        (plannedGrams - target).abs() > math.max(0.2, target * 0.001)) {
      return unit == PourUnit.percent
          ? '차수별 비율의 합계를 100%로 맞춰 주세요.'
          : '차수별 물량의 합계를 목표 물량과 맞춰 주세요.';
    }
    double previousTime = -1;
    for (final point in trace) {
      if (![point.seconds, point.grams, point.flow].every((n) => n.isFinite) ||
          point.seconds < previousTime ||
          point.seconds < 0 ||
          point.grams < 0 ||
          point.flow < 0 ||
          point.seconds > duration + 0.1) {
        return '추출 기록의 시간 또는 무게가 올바르지 않습니다.';
      }
      previousTime = point.seconds;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dose': dose,
    'ratio': ratio,
    'unit': unit.name,
    'steps': steps.map((s) => s.toJson()).toList(),
    'trace': trace.map((p) => p.toJson()).toList(),
    'duration': duration,
    'createdAt': createdAt.toIso8601String(),
    'isDemo': isDemo,
  };

  factory BrewRecipe.fromJson(Map<String, dynamic> data) {
    final recipe = BrewRecipe(
      id: data['id'] as String,
      name: data['name'] as String,
      dose: (data['dose'] as num).toDouble(),
      ratio: (data['ratio'] as num).toDouble(),
      unit: PourUnit.values.byName(data['unit'] as String),
      steps:
          (data['steps'] as List)
              .map((s) => PourStep.fromJson(Map<String, dynamic>.from(s)))
              .toList(),
      trace:
          (data['trace'] as List? ?? [])
              .map((p) => BrewPoint.fromJson(p as List))
              .toList(),
      duration: (data['duration'] as num).toDouble(),
      createdAt: DateTime.parse(data['createdAt'] as String),
      isDemo: data['isDemo'] == true,
    );
    final error = recipe.validate();
    if (error != null) throw FormatException(error);
    return recipe;
  }

  /// Segment a recorded curve into pours. Two seconds without positive mass
  /// increase separates pours; the original trace remains the replay authority.
  static List<PourStep> inferPours(List<BrewPoint> points) {
    final result = <PourStep>[];
    BrewPoint? begin, lastIncrease;
    void flush() {
      if (begin != null &&
          lastIncrease != null &&
          lastIncrease!.grams - begin!.grams >= 0.5) {
        result.add(
          PourStep(
            start: begin!.seconds,
            duration: math.max(0.1, lastIncrease!.seconds - begin!.seconds),
            amount: lastIncrease!.grams - begin!.grams,
          ),
        );
      }
      begin = null;
      lastIncrease = null;
    }

    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final dt = b.seconds - a.seconds;
      if (dt > 0 &&
          b.grams - a.grams >= 0.1 &&
          (b.grams - a.grams) / dt >= 0.5) {
        if (lastIncrease != null && a.seconds - lastIncrease!.seconds >= 2) {
          flush();
        }
        begin ??= a;
        lastIncrease = b;
      } else if (lastIncrease != null &&
          b.seconds - lastIncrease!.seconds >= 2) {
        flush();
      }
    }
    flush();
    return result;
  }
}

class PourGuide {
  final BrewRecipe recipe;
  final double seconds;
  final double water;
  PourGuide(this.recipe, this.seconds, this.water);
  double get expected => recipe.expectedGrams(seconds);
  double get difference => water - expected;
  int get stepIndex {
    for (var i = 0; i < recipe.steps.length; i++) {
      if (water < recipe.cumulativeAt(i) - 0.5) return i;
    }
    return recipe.steps.length;
  }

  bool get poursDone => stepIndex >= recipe.steps.length;
  PourStep? get step => poursDone ? null : recipe.steps[stepIndex];
  bool get waiting => step != null && seconds < step!.start;
  double get stepTarget =>
      poursDone ? recipe.plannedGrams : recipe.cumulativeAt(stepIndex);
  double get targetFlow =>
      step == null ? 0 : recipe.gramsFor(step!) / step!.duration;
}
