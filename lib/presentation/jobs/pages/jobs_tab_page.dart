import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:brightspeed_fiber_app/core/utils/responsive.dart';
import 'package:brightspeed_fiber_app/core/widgets/loading_view.dart';
import 'package:brightspeed_fiber_app/core/widgets/state_views.dart';
import 'package:brightspeed_fiber_app/domain/entities/feature_flags.dart';
import 'package:brightspeed_fiber_app/domain/entities/job.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/feature_flags/cubit/feature_flag_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/feature_flags/cubit/feature_flag_state.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/cubit/jobs_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/cubit/jobs_state.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/job_card_widget.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/job_status_picker_sheet.dart';
import 'package:brightspeed_fiber_app/presentation/widgets/secondary_nav_bar.dart';

class JobsTabPage extends StatefulWidget {
  const JobsTabPage({super.key});

  @override
  State<JobsTabPage> createState() => _JobsTabPageState();
}

class _JobsTabPageState extends State<JobsTabPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      context.read<JobsCubit>().loadMore();
    }
  }

  Future<void> _onRefresh() async {
    final userId = context.read<AuthCubit>().state.session?.userId;
    if (userId != null) {
      await context.read<JobsCubit>().loadJobs(
            userId,
            refresh: true,
            forceRemoteFetch: true,
          );
    }
  }

  Future<void> _onStatusTap(Job job) async {
    final selected = await showJobStatusPicker(
      context,
      currentStatus: job.status,
    );
    if (selected == null) {
      return;
    }
    if (selected == job.status) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already selected this status'),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    await context.read<JobsCubit>().updateStatus(
          job: job,
          displayStatus: selected,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeatureFlagCubit, FeatureFlagState>(
      builder: (context, flagState) {
        final flags = flagState.flags;
        final showSearch = _showSearch && flags.search;

        return Column(
          children: [
            SecondaryNavBar(
              flags: flags,
              onRefresh: flags.refresh ? _onRefresh : null,
              onSearch: flags.search
                  ? () => setState(() => _showSearch = !_showSearch)
                  : null,
            ),
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search jobs locally...',
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              context.read<JobsCubit>().updateSearch('');
                              setState(() {});
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    context.read<JobsCubit>().updateSearch(value);
                    setState(() {});
                  },
                ),
              ),
            Expanded(child: _buildJobsList(flags)),
          ],
        );
      },
    );
  }

  Widget _buildJobsList(FeatureFlags flags) {
    return BlocBuilder<JobsCubit, JobsState>(
      builder: (context, jobsState) {
        if ((jobsState.status == JobsStatus.loading ||
                jobsState.status == JobsStatus.initial) &&
            jobsState.visibleJobs.isEmpty) {
          return const LoadingView(message: 'Loading jobs...');
        }

        if (jobsState.status == JobsStatus.failure) {
          return ErrorView(
            message: jobsState.errorMessage ?? 'Failed to load jobs.',
            onRetry: _onRefresh,
          );
        }

        if (jobsState.visibleJobs.isEmpty) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyView(
                  title: 'No jobs found',
                  subtitle: 'Try adjusting your search or pull to refresh.',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: jobsState.visibleJobs.length +
                (jobsState.hasMore || jobsState.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= jobsState.visibleJobs.length) {
                return jobsState.isLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox(height: 24);
              }

              final job = jobsState.visibleJobs[index];
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.contentMaxWidth(context),
                  ),
                  child: JobCardWidget(
                    job: job,
                    flags: flags,
                    onStatusTap: () => _onStatusTap(job),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
