import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import 'price_models.dart';
import 'pricing_provider.dart';
import 'pricing_repository.dart';

class StorePricesSection extends StatelessWidget {
  final Game game;
  const StorePricesSection({super.key, required this.game});
  @override
  Widget build(BuildContext context) {
    if (game.demo) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      key: ValueKey('prices:${game.key}:${game.title}'),
      create: (context) =>
          PricingProvider(context.read<PricingRepository>(), game),
      child: const _PricesBody(),
    );
  }
}

class _PricesBody extends StatelessWidget {
  const _PricesBody();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<PricingProvider>();
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final listing = p.listing;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: WalletRadius.card,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .5),
          ),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Icon(Icons.storefront_outlined, color: colors.primary),
          title: Text(
            'Stores & prices',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            listing == null || listing.rupeeRate != null
                ? 'PC · Estimated prices in ₹'
                : 'PC · USD prices',
          ),
          onExpansionChanged: (expanded) {
            if (expanded) p.open();
          },
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Rupee amounts are converted estimates, not Indian store prices. Final checkout prices may differ.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            if (p.loading) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(
                semanticsLabel: 'Checking store prices',
              ),
            ],
            if (p.error != null) ...[
              const SizedBox(height: 12),
              Text(p.error!, style: text.bodyMedium),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: p.loading ? null : () => p.load(refresh: true),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ],
            if (p.choosing && !p.loading && p.error == null) ...[
              const SizedBox(height: 14),
              Text(
                p.matches.isEmpty
                    ? 'No matching PC listing found'
                    : 'Choose the correct game & edition',
                style: text.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                p.matches.isEmpty
                    ? 'CheapShark may not cover this game. This does not mean it is unavailable elsewhere.'
                    : 'Prices below will apply only to the listing you select.',
                style: text.bodySmall,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: p.matches.length,
                  itemBuilder: (context, index) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.matches[index].title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => p.select(p.matches[index]),
                  ),
                ),
              ),
            ],
            if (listing != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(listing.match.title, style: text.titleSmall),
              ),
              if (p.outdated)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: colors.tertiary, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Outdated prices · reconnect and refresh before buying',
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              for (final offer in listing.offers)
                _OfferRow(
                  offer,
                  rate: listing.rupeeRate,
                  lowest:
                      !p.outdated && offer.cents == listing.offers.first.cents,
                ),
              if (listing.offers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No store offers reported for this listing. Other stores may still sell it.',
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last checked ${_checked(listing.checkedAt.toLocal())}',
                  style: text.bodySmall,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  listing.rupeeRate == null
                      ? 'Rupee conversion unavailable · showing original USD prices.'
                      : '${listing.rupeeRate!.stale ? 'Outdated exchange rate' : 'Reference exchange rate'} · ${listing.rupeeRate!.date}',
                  style: text.bodySmall,
                ),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                if (p.opened)
                  TextButton.icon(
                    onPressed: p.loading ? null : () => p.load(refresh: true),
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Refresh'),
                  ),
                if (listing != null || p.selected != null)
                  TextButton(
                    onPressed: p.loading ? null : () => p.load(choose: true),
                    child: const Text('Change listing'),
                  ),
                TextButton.icon(
                  onPressed: () =>
                      openExternal(context, 'https://www.cheapshark.com'),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Prices by CheapShark'),
                ),
                if (listing?.rupeeRate != null)
                  TextButton(
                    onPressed: () =>
                        openExternal(context, 'https://frankfurter.dev'),
                    child: const Text('Rates by Frankfurter'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _checked(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _OfferRow extends StatelessWidget {
  final StoreOffer offer;
  final bool lowest;
  final RupeeRate? rate;
  const _OfferRow(this.offer, {required this.lowest, this.rate});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(offer.storeName, style: text.titleSmall),
        if (lowest)
          Padding(
            padding: const EdgeInsets.only(top: WalletSpace.xs),
            child: Text(
              'Lowest among listed stores',
              style: text.labelSmall?.copyWith(color: colors.primary),
            ),
          ),
      ],
    );
    final price = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: WalletSpace.sm,
          runSpacing: WalletSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              rate?.money(offer.cents) ?? StoreOffer.money(offer.cents),
              style: WalletTheme.moneyStyle(context),
            ),
            if (offer.discount != null) ...[
              Text(
                rate?.money(offer.retailCents!) ??
                    StoreOffer.money(offer.retailCents!),
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Text(
                '-${offer.discount}%',
                style: text.labelMedium?.copyWith(color: colors.primary),
              ),
            ],
          ],
        ),
        if (rate != null)
          Text(
            '${StoreOffer.money(offer.cents)} · USD offer',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: WalletRadius.control,
        onTap: () => openExternal(context, offer.url.toString()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WalletSpace.md),
          child: LayoutBuilder(
            builder: (context, box) {
              final sideBySide =
                  box.maxWidth >= 390 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sideBySide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: information),
                        const SizedBox(width: WalletSpace.md),
                        Expanded(child: price),
                        const SizedBox(width: WalletSpace.sm),
                        const Icon(Icons.open_in_new, size: 18),
                      ],
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(child: information),
                        const Icon(Icons.open_in_new, size: 18),
                      ],
                    ),
                    const SizedBox(height: WalletSpace.sm),
                    price,
                  ],
                  const Divider(height: WalletSpace.md),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
