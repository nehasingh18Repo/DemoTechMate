import 'package:flutter/material.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';
import 'package:brightspeed_fiber_app/core/widgets/techx_logo.dart'
    show AuthHeader, TechMateLogo;
import 'package:brightspeed_fiber_app/presentation/widgets/connectivity_status.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.role,
    this.onLogout,
    this.isJobsTab = true,
  });

  final String role;
  final VoidCallback? onLogout;
  final bool isJobsTab;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.black,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.brandGradient,
        ),
      ),
      automaticallyImplyLeading: false,
      title: const Align(
        alignment: Alignment.centerLeft,
        child: TechMateLogo(fontSize: 22),
      ),
      actions: [
        HomeHeaderActions(
          onLogout: onLogout,
          isJobsTab: isJobsTab,
        ),
      ],
    );
  }
}

/// Soft light-yellow gradient header used on the home / Job Card screen.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.isJobsTab,
    this.onLogout,
  });

  final bool isJobsTab;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const TechMateLogo(fontSize: 22),
            const Spacer(),
            HomeHeaderActions(
              onLogout: onLogout,
              isJobsTab: isJobsTab,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeHeaderActions extends StatelessWidget {
  const HomeHeaderActions({
    super.key,
    this.onLogout,
    this.isJobsTab = true,
  });

  final VoidCallback? onLogout;
  final bool isJobsTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            isJobsTab ? 'TechMate' : 'TechMate Manager',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const ConnectivityStatusChip(),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade400,
            child: const Icon(Icons.person, size: 18, color: Colors.white),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              onLogout?.call();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AuthAlternativeSignIn extends StatelessWidget {
  const AuthAlternativeSignIn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '- OR -',
          style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Text('Sign in with', style: TextStyle(color: AppColors.blue)),
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade200,
          child: const Icon(Icons.cloud, color: AppColors.blue, size: 28),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class AuthProfileIcon extends StatelessWidget {
  const AuthProfileIcon({super.key, this.icon = Icons.person});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.blue,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}

class AuthScreenBody extends StatelessWidget {
  const AuthScreenBody({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softCream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const AuthHeader(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
