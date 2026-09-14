import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../data/subscription_repository.dart';
import '../domain/subscription.dart';
import '../domain/subscription_plan.dart';

/// docs/04-development-phases.md Phase 2 item 1. Settings -> Subscription
/// was a "coming soon" placeholder since Phase 1 item 10 specifically
/// because this feature didn't exist yet — see SettingsScreen's own doc
/// comment.
///
/// Only drives the `provider: "stripe"` purchase path (SubscriptionRepository's
/// own doc comment) — no native-store UI here. When the backend is
/// configured with a real Stripe account, `purchase()` returns a
/// `checkout_url` instead of an already-active subscription; this screen
/// opens that in the device browser and relies on the user pulling to
/// refresh afterwards, since there's no deep-link handler wired up yet to
/// notice a completed payment automatically (flagged, not silently assumed
/// — see StripePaymentGateway's own doc comment on the backend).
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _loading = true;
  String? _error;
  List<SubscriptionPlan> _plans = [];
  Subscription? _current;
  int? _purchasingPlanId;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(subscriptionRepositoryProvider);
      final results = await Future.wait([repo.getPlans(), repo.getCurrent()]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<SubscriptionPlan>;
        _current = results[1] as Subscription?;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _purchase(SubscriptionPlan plan) async {
    setState(() => _purchasingPlanId = plan.id);
    try {
      final result = await ref
          .read(subscriptionRepositoryProvider)
          .purchase(plan.id);

      if (!mounted) return;

      if (result.isActiveImmediately) {
        setState(() {
          _current = result.subscription;
          _purchasingPlanId = null;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("You're now Premium!")));
        return;
      }

      setState(() => _purchasingPlanId = null);
      final url = result.checkoutUrl;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete your payment in the browser, then pull down here to refresh.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _purchasingPlanId = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text(
          'This ends your Premium access immediately, not at the end of the '
          'current billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      final subscription = await ref
          .read(subscriptionRepositoryProvider)
          .cancel();
      if (!mounted) return;
      setState(() {
        _current = subscription;
        _cancelling = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ],
      );
    }

    final current = _current;
    if (current != null && current.isActive) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.plan.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${current.plan.formattedPrice} / ${current.plan.billingIntervalLabel}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Renews ${_formatDate(current.endsAt)}'),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(
                    onPressed: _cancelling ? null : _cancel,
                    child: _cancelling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cancel subscription'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_plans.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: Text('No plans are available right now.')),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _plans.length,
      itemBuilder: (context, index) {
        final plan = _plans[index];
        final purchasing = _purchasingPlanId == plan.id;

        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('${plan.formattedPrice} / ${plan.billingIntervalLabel}'),
                const SizedBox(height: AppSpacing.md),
                ..._entitlementLines(plan).map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: purchasing ? null : () => _purchase(plan),
                  child: purchasing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Subscribe'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _entitlementLines(SubscriptionPlan plan) {
    final lines = <String>[];
    if (plan.entitlementBool('unlimited_likes')) lines.add('Unlimited likes');
    if (plan.entitlementBool('advanced_filters')) {
      lines.add('Advanced filters');
    }
    if (plan.entitlementBool('unmatched_messaging')) {
      lines.add("Message people you haven't matched with");
    }
    final boosts = plan.entitlements['boosts_per_month'];
    if (boosts is int && boosts > 0) {
      lines.add('$boosts profile boost${boosts == 1 ? '' : 's'} / month');
    }
    return lines;
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
