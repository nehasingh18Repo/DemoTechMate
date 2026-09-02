import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brightspeed_fiber_app/core/config/app_config.dart';
import 'package:brightspeed_fiber_app/core/location/location_service.dart';
import 'package:brightspeed_fiber_app/core/location/location_tracking_service.dart';
import 'package:brightspeed_fiber_app/core/network/api_client.dart';
import 'package:brightspeed_fiber_app/core/network/auth_token_holder.dart';
import 'package:brightspeed_fiber_app/core/network/connectivity_status_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/fcm_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_inbox_service.dart';
import 'package:brightspeed_fiber_app/core/sync/jobs_sync_service.dart';
import 'package:brightspeed_fiber_app/data/datasources/auth_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/auth_remote_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/dashboard_remote_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/fcm_remote_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/feature_flag_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/feature_flag_remote_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/jobs_remote_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/jobs_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/location_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/location_remote_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/notification_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/repositories/auth_repository_impl.dart';
import 'package:brightspeed_fiber_app/data/repositories/dashboard_repository_impl.dart';
import 'package:brightspeed_fiber_app/data/repositories/jobs_repository_impl.dart';
import 'package:brightspeed_fiber_app/data/repositories/location_repository_impl.dart';
import 'package:brightspeed_fiber_app/data/repositories/notification_repository_impl.dart';
import 'package:brightspeed_fiber_app/domain/repositories/auth_repository.dart';
import 'package:brightspeed_fiber_app/domain/repositories/dashboard_repository.dart';
import 'package:brightspeed_fiber_app/domain/repositories/jobs_repository.dart';
import 'package:brightspeed_fiber_app/domain/repositories/location_repository.dart';
import 'package:brightspeed_fiber_app/domain/repositories/notification_repository.dart';
import 'package:brightspeed_fiber_app/domain/usecases/auth_usecases.dart';
import 'package:brightspeed_fiber_app/domain/usecases/get_dashboard_summary_usecase.dart';
import 'package:brightspeed_fiber_app/domain/usecases/jobs_usecases.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/dashboard/cubit/dashboard_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/feature_flags/cubit/feature_flag_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/inventory/cubit/inventory_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/cubit/jobs_cubit.dart';

class AppDependencies {
  AppDependencies._({
    required this.authRepository,
    required this.dashboardRepository,
    required this.jobsRepository,
    required this.notificationRepository,
    required this.locationRepository,
    required this.notificationInboxService,
    required this.fcmService,
    required this.connectivityStatusService,
    required this.jobsSyncService,
    required this.locationService,
    required this.locationTrackingService,
    required this.locationRemoteDataSource,
    required this.featureFlagLocalDataSource,
    required this.featureFlagRemoteDataSource,
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCachedSessionUseCase,
    required this.getDashboardSummaryUseCase,
    required this.getUserJobsUseCase,
    required this.refreshJobStatusOnResumeUseCase,
    required this.updateJobStatusUseCase,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final JobsRepository jobsRepository;
  final NotificationRepository notificationRepository;
  final LocationRepository locationRepository;
  final NotificationInboxService notificationInboxService;
  final FcmService fcmService;
  final ConnectivityStatusService connectivityStatusService;
  final JobsSyncService jobsSyncService;
  final LocationService locationService;
  final LocationTrackingService locationTrackingService;
  final LocationRemoteDataSource locationRemoteDataSource;
  final FeatureFlagLocalDataSource featureFlagLocalDataSource;
  final FeatureFlagRemoteDataSource featureFlagRemoteDataSource;
  final LoginUseCase loginUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCachedSessionUseCase getCachedSessionUseCase;
  final GetDashboardSummaryUseCase getDashboardSummaryUseCase;
  final GetUserJobsUseCase getUserJobsUseCase;
  final RefreshJobStatusOnResumeUseCase refreshJobStatusOnResumeUseCase;
  final UpdateJobStatusUseCase updateJobStatusUseCase;

  static Future<AppDependencies> create() async {
    final tokenHolder = AuthTokenHolder();
    final sharedPreferences = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();

    final apiClient = ApiClient(tokenHolder: tokenHolder);
    final featureFlagApiClient = ApiClient(
      tokenHolder: tokenHolder,
      baseUrl: AppConfig.featureFlagApiBaseUrl,
    );
    final authLocalDataSource = AuthLocalDataSource(
      secureStorage: secureStorage,
      sharedPreferences: sharedPreferences,
      tokenHolder: tokenHolder,
    );

    final authRemoteDataSource = AuthRemoteDataSource(apiClient);
    final dashboardRemoteDataSource = DashboardRemoteDataSource(apiClient);
    final jobsRemoteDataSource = JobsRemoteDataSource(apiClient);
    final jobsLocalDataSource = JobsLocalDataSource();
    const featureFlagLocalDataSource = FeatureFlagLocalDataSource();
    final featureFlagRemoteDataSource =
        FeatureFlagRemoteDataSource(featureFlagApiClient);
    final fcmRemoteDataSource = FcmRemoteDataSource(apiClient);
    final notificationLocalDataSource = NotificationLocalDataSource();
    final notificationRepository =
        NotificationRepositoryImpl(notificationLocalDataSource);
    final notificationInboxService = NotificationInboxService(
      repository: notificationRepository,
      apiClient: apiClient,
    );
    final fcmService = FcmService(
      remoteDataSource: fcmRemoteDataSource,
      inboxService: notificationInboxService,
    );
    const locationService = LocationService();
    final locationRemoteDataSource = LocationRemoteDataSource(apiClient);
    final locationLocalDataSource = LocationLocalDataSource();
    final locationRepository = LocationRepositoryImpl(
      locationService: locationService,
      remoteDataSource: locationRemoteDataSource,
      localDataSource: locationLocalDataSource,
    );
    final connectivityStatusService = ConnectivityStatusService();
    await connectivityStatusService.start();
    final jobsSyncService = JobsSyncService(
      localDataSource: jobsLocalDataSource,
      remoteDataSource: jobsRemoteDataSource,
      connectivityStatusService: connectivityStatusService,
    );
    final locationTrackingService = LocationTrackingService(
      locationRepository: locationRepository,
      jobsSyncService: jobsSyncService,
    );

    final authRepository = AuthRepositoryImpl(
      remoteDataSource: authRemoteDataSource,
      localDataSource: authLocalDataSource,
    );
    final dashboardRepository =
        DashboardRepositoryImpl(dashboardRemoteDataSource);
    final jobsRepository = JobsRepositoryImpl(
      remoteDataSource: jobsRemoteDataSource,
      localDataSource: jobsLocalDataSource,
    );

    return AppDependencies._(
      authRepository: authRepository,
      dashboardRepository: dashboardRepository,
      jobsRepository: jobsRepository,
      notificationRepository: notificationRepository,
      locationRepository: locationRepository,
      notificationInboxService: notificationInboxService,
      fcmService: fcmService,
      connectivityStatusService: connectivityStatusService,
      jobsSyncService: jobsSyncService,
      locationService: locationService,
      locationTrackingService: locationTrackingService,
      locationRemoteDataSource: locationRemoteDataSource,
      featureFlagLocalDataSource: featureFlagLocalDataSource,
      featureFlagRemoteDataSource: featureFlagRemoteDataSource,
      loginUseCase: LoginUseCase(authRepository),
      logoutUseCase: LogoutUseCase(authRepository),
      getCachedSessionUseCase: GetCachedSessionUseCase(authRepository),
      getDashboardSummaryUseCase:
          GetDashboardSummaryUseCase(dashboardRepository),
      getUserJobsUseCase: GetUserJobsUseCase(jobsRepository),
      refreshJobStatusOnResumeUseCase:
          RefreshJobStatusOnResumeUseCase(jobsRepository),
      updateJobStatusUseCase: UpdateJobStatusUseCase(jobsRepository),
    );
  }

  List<SingleChildWidget> providers() {
    return [
      Provider<AuthRepository>.value(value: authRepository),
      Provider<DashboardRepository>.value(value: dashboardRepository),
      Provider<JobsRepository>.value(value: jobsRepository),
      Provider<NotificationRepository>.value(value: notificationRepository),
      Provider<LocationRepository>.value(value: locationRepository),
      Provider<NotificationInboxService>.value(value: notificationInboxService),
      Provider<FcmService>.value(value: fcmService),
      ChangeNotifierProvider<ConnectivityStatusService>.value(
        value: connectivityStatusService,
      ),
      ChangeNotifierProvider<JobsSyncService>.value(
        value: jobsSyncService,
      ),
      Provider<LocationService>.value(value: locationService),
      Provider<LocationTrackingService>.value(value: locationTrackingService),
      BlocProvider(
        create: (_) => FeatureFlagCubit(
          localDataSource: featureFlagLocalDataSource,
          remoteDataSource: featureFlagRemoteDataSource,
        ),
      ),
      BlocProvider(
        create: (context) => AuthCubit(
          loginUseCase: loginUseCase,
          logoutUseCase: logoutUseCase,
          getCachedSessionUseCase: getCachedSessionUseCase,
          fcmService: fcmService,
          locationTrackingService: locationTrackingService,
          jobsSyncService: jobsSyncService,
          featureFlagCubit: context.read<FeatureFlagCubit>(),
        )..checkSession(),
      ),
      BlocProvider(
        create: (_) => DashboardCubit(getDashboardSummaryUseCase),
      ),
      BlocProvider(
        create: (_) => JobsCubit(
          getUserJobsUseCase: getUserJobsUseCase,
          refreshJobStatusOnResumeUseCase: refreshJobStatusOnResumeUseCase,
          updateJobStatusUseCase: updateJobStatusUseCase,
          jobsSyncService: jobsSyncService,
        ),
      ),
      BlocProvider(
        create: (_) => InventoryCubit(
          locationTrackingService: locationTrackingService,
        ),
      ),
    ];
  }
}
