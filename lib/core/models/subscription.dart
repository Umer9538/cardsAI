import 'package:flutter/foundation.dart';

/// How often a plan bills.
enum BillingPeriod {
  monthly('/Month', Duration(days: 30)),
  annual('/Year', Duration(days: 365));

  const BillingPeriod(this.suffix, this.length);

  /// The suffix the price is drawn with — see `PlanPrice`, which renders it at
  /// a smaller size via a character-level style run.
  final String suffix;

  /// Nominal term. Real renewal dates come from the store; this is what the
  /// development stub uses to produce a plausible one.
  final Duration length;
}

/// A purchasable plan.
///
/// Prices are hardcoded to the artboard for now. With real in-app purchases
/// they must come from the store instead — StoreKit and Play Billing both
/// return localised, currency-correct prices, and showing a hardcoded "$4.99"
/// to someone paying in rupees is both wrong and a review rejection.
@immutable
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.period,
    required this.features,
    this.currencySymbol = r'$',
  });

  /// Also the store product id, once there is one.
  final String id;
  final String name;
  final double price;
  final String currencySymbol;
  final BillingPeriod period;
  final List<String> features;

  /// "$4.99" — trailing zeros kept, as prices are always written.
  String get priceLabel => '$currencySymbol${price.toStringAsFixed(2)}';

  String get periodLabel => period.suffix;

  static const List<SubscriptionPlan> catalogue = [
    SubscriptionPlan(
      id: 'monthly',
      name: 'Monthly Plan',
      price: 4.99,
      period: BillingPeriod.monthly,
      // Every line is something the app does today. The previous list
      // promised weekly AI progress reports and exclusive diet programs,
      // neither of which exists — selling a feature that is not there is an
      // Apple 2.3.1 rejection and, worse, a refund request.
      features: [
        '300 AI meal scans a month',
        'Meal plans built around your taste',
        'No ads, anywhere',
        'Photo, barcode and text logging',
        'Full macro and fibre breakdown',
      ],
    ),
    SubscriptionPlan(
      id: 'annual',
      name: 'Annual Plan',
      price: 29.99,
      period: BillingPeriod.annual,
      features: [
        '300 AI meal scans a month',
        'Meal plans built around your taste',
        'No ads, anywhere',
        'Photo, barcode and text logging',
        'Two months free vs monthly',
      ],
    ),
  ];

  static SubscriptionPlan? byId(String? id) {
    for (final plan in catalogue) {
      if (plan.id == id) return plan;
    }
    return null;
  }
}

enum SubscriptionStatus { none, active, expired, cancelled }

/// What the signed-in account is entitled to.
@immutable
class Subscription {
  const Subscription({
    this.status = SubscriptionStatus.none,
    this.planId,
    this.startedAt,
    this.renewsAt,
  });

  final SubscriptionStatus status;
  final String? planId;
  final DateTime? startedAt;

  /// Next billing date, or the date access ends when [cancelled].
  final DateTime? renewsAt;

  static const Subscription free = Subscription();

  SubscriptionPlan? get plan => SubscriptionPlan.byId(planId);

  /// Whether premium features are unlocked right now.
  ///
  /// A cancelled subscription stays entitled until its paid term runs out —
  /// cutting access at the moment of cancellation would be taking money for
  /// nothing.
  bool get isActive {
    if (status == SubscriptionStatus.active) return true;
    if (status == SubscriptionStatus.cancelled && renewsAt != null) {
      return renewsAt!.isAfter(DateTime.now());
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'planId': planId,
        'startedAt': startedAt?.toIso8601String(),
        'renewsAt': renewsAt?.toIso8601String(),
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        status: SubscriptionStatus.values
                .where((s) => s.name == json['status'])
                .firstOrNull ??
            SubscriptionStatus.none,
        planId: json['planId'] as String?,
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
        renewsAt: DateTime.tryParse(json['renewsAt'] as String? ?? ''),
      );

  @override
  bool operator ==(Object other) =>
      other is Subscription &&
      other.status == status &&
      other.planId == planId &&
      other.renewsAt == renewsAt;

  @override
  int get hashCode => Object.hash(status, planId, renewsAt);
}
