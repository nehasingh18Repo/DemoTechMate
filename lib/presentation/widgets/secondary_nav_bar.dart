import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';

class SecondaryNavBar extends StatelessWidget {
  const SecondaryNavBar({
    super.key,
    required this.flags,
    this.onRefresh,
    this.onSearch,
  });

  final FeatureFlags flags;
  final VoidCallback? onRefresh;
  final VoidCallback? onSearch;

  static const _allItems = <_SecondaryNavItem>[
    _SecondaryNavItem(Icons.map_outlined, 'Map', 'map'),
    _SecondaryNavItem(Icons.filter_list, 'Filter Jobs', 'filterJobs'),
    _SecondaryNavItem(Icons.note_add_outlined, 'ALT Job', 'altJob'),
    _SecondaryNavItem(Icons.person_search, 'Self Assign', 'selfAssign'),
    _SecondaryNavItem(Icons.refresh, 'Refresh', 'refresh'),
    _SecondaryNavItem(Icons.search, 'Search', 'search'),
    // EOD has no feature flag — always visible.
    _SecondaryNavItem(Icons.access_time, 'EOD', null),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _allItems
        .where((item) => item.featureKey == null || flags.isEnabled(item.featureKey!))
        .toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: () {
              if (item.label == 'Refresh') {
                onRefresh?.call();
              } else if (item.label == 'Search') {
                onSearch?.call();
              }
            },
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 20, color: AppColors.navLabel),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8, color: AppColors.navLabel),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SecondaryNavItem {
  const _SecondaryNavItem(this.icon, this.label, this.featureKey);

  final IconData icon;
  final String label;
  final String? featureKey;
}
