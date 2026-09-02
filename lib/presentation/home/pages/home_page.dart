import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/location/location_tracking_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_coordinator.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_inbox_service.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/auth/pages/login_page.dart';
import 'package:brightspeed_fiber_app/presentation/dashboard/cubit/dashboard_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/dashboard/pages/dashboard_tab_page.dart';
import 'package:brightspeed_fiber_app/presentation/feature_flags/cubit/feature_flag_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/feature_flags/cubit/feature_flag_state.dart';
import 'package:brightspeed_fiber_app/presentation/inventory/cubit/inventory_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/inventory/pages/inventory_tab_page.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/cubit/jobs_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/cubit/jobs_state.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/pages/jobs_tab_page.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/app_header.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/connectivity_status.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/primary_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const routeName = '/home';

  static const tabDashboard = 'dashboard';
  static const tabJobs = 'jobs';

  static const jobsNavJob = 'job';
  static const jobsNavInventory = 'myInventory';

  static const dashboardNav = [
    NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    NavItem(icon: Icons.groups_outlined, label: 'Team'),
    NavItem(icon: Icons.scoreboard_outlined, label: 'Scorecard'),
    NavItem(icon: Icons.gps_fixed, label: 'GPS View'),
    NavItem(icon: Icons.border_outer, label: 'Boundary'),
    NavItem(icon: Icons.more_horiz, label: 'More'),
  ];

  static const jobsNavEntries = <_JobsNavEntry>[
    _JobsNavEntry(
      id: 'job',
      featureKey: 'job',
      item: NavItem(icon: Icons.checklist, label: 'Job'),
    ),
    _JobsNavEntry(
      id: 'circuitView',
      featureKey: 'circuitView',
      item: NavItem(icon: Icons.memory, label: 'Circuit View'),
    ),
    _JobsNavEntry(
      id: 'myInventory',
      featureKey: 'myInventory',
      item: NavItem(icon: Icons.local_shipping_outlined, label: 'My Invent...'),
    ),
    _JobsNavEntry(
      id: 'timesheet',
      featureKey: 'timesheet',
      item: NavItem(icon: Icons.laptop, label: 'Timesheet'),
    ),
    _JobsNavEntry(
      id: 'hotReads',
      featureKey: 'hotReads',
      item: NavItem(icon: Icons.menu_book_outlined, label: 'Hot Reads'),
    ),
    // MORE has no feature flag — always visible.
    _JobsNavEntry(
      id: 'more',
      featureKey: null,
      item: NavItem(icon: Icons.grid_view, label: 'MORE'),
    ),
  ];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Jobs tab is the default (matches original default for technicians).
  String _mainTab = HomePage.tabJobs;
  int _dashboardSubTab = 0;
  String _jobsSubTab = HomePage.jobsNavJob;
  int _lastHandledOpenJobsSignal = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _lastHandledOpenJobsSignal = NotificationCoordinator.openJobsSignal.value;
    NotificationCoordinator.openJobsSignal.addListener(_onOpenJobsConfirmed);
    NotificationCoordinator.pendingDialog.addListener(_onNotificationDialogPending);
    NotificationCoordinator.pendingHighPriorityList
        .addListener(_onNotificationDialogPending);
    if (NotificationCoordinator.openJobsSignal.value >
        _lastHandledOpenJobsSignal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onOpenJobsConfirmed();
      });
    }
    if (NotificationCoordinator.pendingDialog.value != null ||
        (NotificationCoordinator.pendingHighPriorityList.value?.isNotEmpty ??
            false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onNotificationDialogPending();
      });
    }
    // Manual app open: show unread high-priority notifications received
    // while the app was in the background (no tray tap required).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<NotificationInboxService>().presentUnreadHighPriorityOnManualOpen();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<LocationTrackingService>().checkGpsAndNotify());
    });
  }

  @override
  void dispose() {
    NotificationCoordinator.openJobsSignal.removeListener(_onOpenJobsConfirmed);
    NotificationCoordinator.pendingDialog
        .removeListener(_onNotificationDialogPending);
    NotificationCoordinator.pendingHighPriorityList
        .removeListener(_onNotificationDialogPending);
    super.dispose();
  }

  /// When notification dialog is about to show, jump to Jobs tab immediately
  /// so the user does not sit on a blank/loading screen.
  void _onNotificationDialogPending() {
    if (!mounted) {
      return;
    }
    final hasSingle = NotificationCoordinator.pendingDialog.value != null;
    final hasList =
        NotificationCoordinator.pendingHighPriorityList.value?.isNotEmpty ??
            false;
    if (!hasSingle && !hasList) {
      return;
    }
    final flags = context.read<FeatureFlagCubit>().state.flags;
    if (!flags.jobsTab) {
      return;
    }
    setState(() {
      _mainTab = HomePage.tabJobs;
      _jobsSubTab = _resolveJobsSubTab(flags, preferred: HomePage.jobsNavJob);
    });
  }

  /// OK on notification dialog → Job Card instantly + fast silent refresh.
  void _onOpenJobsConfirmed() {
    if (!mounted) {
      return;
    }
    final signal = NotificationCoordinator.openJobsSignal.value;
    if (signal <= _lastHandledOpenJobsSignal) {
      return;
    }
    _lastHandledOpenJobsSignal = signal;

    final flags = context.read<FeatureFlagCubit>().state.flags;
    if (!flags.jobsTab) {
      return;
    }

    // Switch to Job Card immediately (no waiting).
    setState(() {
      _mainTab = HomePage.tabJobs;
      _jobsSubTab = _resolveJobsSubTab(flags, preferred: HomePage.jobsNavJob);
    });

    // Soft refresh keeps cards on screen; updates as soon as API returns.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _reloadJobsFast();
    });
  }

  void _reloadJobsFast() {
    final session = context.read<AuthCubit>().state.session;
    if (session == null) {
      return;
    }
    // Existing Job Card API: GET /api/jobs/user/{id} (silent = no full reload UI)
    context.read<JobsCubit>().loadJobs(
          session.userId,
          refresh: true,
          silent: true,
          forceRemoteFetch: true,
        );
  }

  void _loadData() {
    final session = context.read<AuthCubit>().state.session;
    if (session == null) {
      return;
    }
    context.read<FeatureFlagCubit>().load(userId: session.userId);
    context.read<DashboardCubit>().loadSummary();
    context.read<JobsCubit>().loadJobs(
          session.userId,
          refresh: true,
          forceRemoteFetch: true,
        );
  }

  void _onJobsNavSelected(String id) {
    setState(() => _jobsSubTab = id);
    if (id == HomePage.jobsNavInventory) {
      _openInventoryWithLocation();
    }
  }

  void _openInventoryWithLocation() {
    final session = context.read<AuthCubit>().state.session;
    if (session == null) {
      return;
    }
    context.read<InventoryCubit>().captureAndSendLocation(session.userId);
  }

  Future<void> _logout() async {
    await context.read<AuthCubit>().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      LoginPage.routeName,
      (_) => false,
    );
  }

  List<_JobsNavEntry> _visibleJobsNav(FeatureFlags flags) {
    return HomePage.jobsNavEntries
        .where(
          (entry) =>
              entry.featureKey == null || flags.isEnabled(entry.featureKey!),
        )
        .toList();
  }

  String _resolveJobsSubTab(FeatureFlags flags, {String? preferred}) {
    final visible = _visibleJobsNav(flags);
    if (visible.isEmpty) {
      return HomePage.jobsNavJob;
    }
    if (preferred != null && visible.any((e) => e.id == preferred)) {
      return preferred;
    }
    if (visible.any((e) => e.id == _jobsSubTab)) {
      return _jobsSubTab;
    }
    return visible.first.id;
  }

  String _resolveMainTab(FeatureFlags flags) {
    final dashboardEnabled = flags.dashboardTab;
    final jobsEnabled = flags.jobsTab;
    if (_mainTab == HomePage.tabJobs && jobsEnabled) {
      return HomePage.tabJobs;
    }
    if (_mainTab == HomePage.tabDashboard && dashboardEnabled) {
      return HomePage.tabDashboard;
    }
    if (jobsEnabled) {
      return HomePage.tabJobs;
    }
    if (dashboardEnabled) {
      return HomePage.tabDashboard;
    }
    return HomePage.tabJobs;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureFlagCubit, FeatureFlagState>(
      builder: (context, flagState) {
        final flags = flagState.flags;
        final mainTab = _resolveMainTab(flags);
        final jobsSubTab = _resolveJobsSubTab(flags);
        final isJobsTab = mainTab == HomePage.tabJobs;
        final visibleJobsNav = _visibleJobsNav(flags);
        final navItems = isJobsTab
            ? visibleJobsNav.map((e) => e.item).toList()
            : HomePage.dashboardNav;
        final jobsNavIndex = visibleJobsNav.indexWhere((e) => e.id == jobsSubTab);
        final selectedNavIndex =
            isJobsTab ? (jobsNavIndex < 0 ? 0 : jobsNavIndex) : _dashboardSubTab;

        // Keep local state in sync with resolved (flag-safe) values.
        if (mainTab != _mainTab || jobsSubTab != _jobsSubTab) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _mainTab = mainTab;
              _jobsSubTab = jobsSubTab;
            });
          });
        }

        final bottomItems = <_BottomTabItem>[
          if (flags.dashboardTab)
            const _BottomTabItem(
              id: HomePage.tabDashboard,
              item: BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
            ),
          if (flags.jobsTab)
            const _BottomTabItem(
              id: HomePage.tabJobs,
              item: BottomNavigationBarItem(
                icon: Icon(Icons.checklist),
                activeIcon: Icon(Icons.checklist_rtl),
                label: 'Jobs',
              ),
            ),
        ];

        final bottomIndex = bottomItems.indexWhere((e) => e.id == mainTab);
        final safeBottomIndex = bottomIndex < 0 ? 0 : bottomIndex;
        final showBottomNav = bottomItems.length >= 2;

        return BlocListener<JobsCubit, JobsState>(
          listenWhen: (previous, current) =>
              previous.statusUpdateMessage != current.statusUpdateMessage ||
              previous.errorMessage != current.errorMessage,
          listener: (context, state) {
            if (state.statusUpdateMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.statusUpdateMessage!)),
              );
              if (state.statusUpdateMessage == 'Job updates synced successfully') {
                _loadData();
              }
            } else if (state.errorMessage != null &&
                state.status == JobsStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.softCream,
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.pageGradient,
              ),
              child: Column(
                children: [
                  HomeHeader(
                    isJobsTab: isJobsTab,
                    onLogout: _logout,
                  ),
                  if (navItems.isNotEmpty)
                    PrimaryNavBar(
                      items: navItems,
                      selectedIndex: selectedNavIndex < 0
                          ? 0
                          : selectedNavIndex.clamp(0, navItems.length - 1),
                      onSelected: (index) {
                        if (isJobsTab) {
                          if (index < 0 || index >= visibleJobsNav.length) {
                            return;
                          }
                          _onJobsNavSelected(visibleJobsNav[index].id);
                        } else {
                          setState(() => _dashboardSubTab = index);
                        }
                      },
                    ),
                  Expanded(
                    child: _buildBody(
                      isJobsTab: isJobsTab,
                      jobsSubTab: jobsSubTab,
                      navItems: navItems,
                      flags: flags,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Online/offline box sits directly above the tab bar. Without
                // a tab bar below it, it owns the bottom inset itself.
                if (showBottomNav)
                  const ConnectivityStatusBanner()
                else
                  const SafeArea(
                    top: false,
                    child: ConnectivityStatusBanner(),
                  ),
                if (showBottomNav)
                  BottomNavigationBar(
                    currentIndex: safeBottomIndex,
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: Colors.white,
                    selectedItemColor: Colors.black,
                    unselectedItemColor: Colors.grey.shade600,
                    selectedFontSize: 12,
                    unselectedFontSize: 12,
                    onTap: (index) {
                      if (index < 0 || index >= bottomItems.length) {
                        return;
                      }
                      setState(() => _mainTab = bottomItems[index].id);
                    },
                    items: bottomItems.map((e) => e.item).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required bool isJobsTab,
    required String jobsSubTab,
    required List<NavItem> navItems,
    required FeatureFlags flags,
  }) {
    if (!flags.dashboardTab && !flags.jobsTab) {
      return const Center(
        child: Text('No tabs enabled in feature flags.'),
      );
    }

    if (!isJobsTab) {
      if (_dashboardSubTab == 0) {
        return const DashboardTabPage();
      }
      if (_dashboardSubTab >= 0 && _dashboardSubTab < navItems.length) {
        return _placeholder(navItems[_dashboardSubTab].label);
      }
      return const SizedBox.shrink();
    }

    switch (jobsSubTab) {
      case HomePage.jobsNavJob:
        return const JobsTabPage();
      case HomePage.jobsNavInventory:
        return const InventoryTabPage();
      default:
        final match = HomePage.jobsNavEntries.where((e) => e.id == jobsSubTab);
        final label = match.isEmpty ? 'Feature' : match.first.item.label;
        return _placeholder(label);
    }
  }

  Widget _placeholder(String label) {
    return Center(
      child: Text(
        '$label — coming soon',
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}

class _JobsNavEntry {
  const _JobsNavEntry({
    required this.id,
    required this.item,
    required this.featureKey,
  });

  final String id;
  final NavItem item;
  final String? featureKey;
}

class _BottomTabItem {
  const _BottomTabItem({required this.id, required this.item});

  final String id;
  final BottomNavigationBarItem item;
}
