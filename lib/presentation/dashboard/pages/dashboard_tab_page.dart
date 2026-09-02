import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/utils/responsive.dart';
import 'package:brightspeed_fiber_app/core/widgets/loading_view.dart';
import 'package:brightspeed_fiber_app/core/widgets/state_views.dart';
import 'package:brightspeed_fiber_app/presentation/dashboard/cubit/dashboard_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/dashboard/cubit/dashboard_state.dart';
import 'package:brightspeed_fiber_app/presentation/dashboard/widgets/dashboard_summary_section.dart';

class DashboardTabPage extends StatelessWidget {
  const DashboardTabPage({super.key});

  Future<void> _onRefresh(BuildContext context) async {
    await context.read<DashboardCubit>().loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _onRefresh(context),
      child: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.loading ||
              state.status == DashboardStatus.initial) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                LoadingView(message: 'Loading dashboard...'),
              ],
            );
          }

          if (state.status == DashboardStatus.failure) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: ErrorView(
                    message:
                        state.errorMessage ?? 'Failed to load dashboard.',
                    onRetry: () =>
                        context.read<DashboardCubit>().loadSummary(),
                  ),
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: Responsive.pagePadding(context),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: DashboardSummarySection(
                    summary: state.summary!,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
