import '../models/user_profile.dart';

/// What a plan is for, as the app reads it off the profile.
///
/// Derived from two onboarding answers — the direction the target moves
/// ([WeightGoal]) and what brought the person here ([Motivation]) — and never
/// asked again. The Worker makes the same derivation from the same two stored
/// fields (`purposeFor` in `workers/src/planPrompt.ts`) and that is the copy
/// that steers the model; this one exists so the local planner and the quiz's
/// build step can show the same word the plan will come back carrying.
/// **The two tables must agree.** A chip that says "Weight loss" while the
/// server wrote a bulk is the plan contradicting itself.
///
/// Muscle wins whatever the goal: someone cutting while training still needs
/// the protein spread and the post-training meal. No goal means no purpose,
/// not "maintenance" — the target is then the default, neither a deficit nor
/// a surplus, and a plan that claimed a purpose over it would be claiming
/// something the numbers do not do.
enum PlanPurpose {
  muscle('Building muscle'),
  loss('Weight loss'),
  gain('Weight gain'),
  eatBetter('Eating better'),
  maintenance('Maintenance');

  const PlanPurpose(this.label);

  /// The short form: the first "Built for you" chip, and what the Worker
  /// returns as `purpose`.
  final String label;

  /// The purpose for [profile], or null when it has no goal.
  static PlanPurpose? of(UserProfile? profile) =>
      from(goal: profile?.goal, motivation: profile?.motivation);

  static PlanPurpose? from({WeightGoal? goal, Motivation? motivation}) {
    if (motivation == Motivation.muscle) return PlanPurpose.muscle;
    return switch (goal) {
      null => null,
      WeightGoal.lose => PlanPurpose.loss,
      WeightGoal.gain => PlanPurpose.gain,
      WeightGoal.maintain => switch (motivation) {
          Motivation.healthier || Motivation.understand => PlanPurpose.eatBetter,
          _ => PlanPurpose.maintenance,
        },
    };
  }
}
