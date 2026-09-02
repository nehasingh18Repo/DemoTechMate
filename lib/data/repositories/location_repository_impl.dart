import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:brightspeed_fiber_app/core/error/exceptions.dart';
import 'package:brightspeed_fiber_app/core/error/failures.dart';
import 'package:brightspeed_fiber_app/core/location/device_location.dart';
import 'package:brightspeed_fiber_app/core/location/location_service.dart';
import 'package:brightspeed_fiber_app/core/utils/result.dart';
import 'package:brightspeed_fiber_app/data/datasources/location_local_datasource.dart';
import 'package:brightspeed_fiber_app/data/datasources/location_remote_datasource.dart';
import 'package:brightspeed_fiber_app/domain/entities/pending_location.dart';
import 'package:brightspeed_fiber_app/domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl({
    required LocationService locationService,
    required LocationRemoteDataSource remoteDataSource,
    required LocationLocalDataSource localDataSource,
    Connectivity? connectivity,
  })  : _locationService = locationService,
        _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _connectivity = connectivity ?? Connectivity();

  final LocationService _locationService;
  final LocationRemoteDataSource _remoteDataSource;
  final LocationLocalDataSource _localDataSource;
  final Connectivity _connectivity;

  @override
  Future<Result<DeviceLocation>> getCurrentLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      return Success(location);
    } on LocationException catch (error) {
      return ErrorResult(LocationFailure(error.message));
    } catch (error) {
      return ErrorResult(LocationFailure('Unable to get location: $error'));
    }
  }

  @override
  Future<Result<String>> syncLocation({
    required int userId,
    required DeviceLocation location,
  }) async {
    try {
      final response = await _remoteDataSource.sendUserLocation(
        userId: userId,
        location: location,
      );
      return Success(_responseText(response, 'Location synced'));
    } on ServerException catch (error) {
      return ErrorResult(ServerFailure(error.message));
    } catch (error) {
      return ErrorResult(ServerFailure('Location sync failed: $error'));
    }
  }

  @override
  Future<Result<PendingLocation>> enqueueOfflineLocation({
    required int userId,
    required DeviceLocation location,
  }) async {
    try {
      final pending = await _localDataSource.enqueue(
        userId: userId,
        location: location,
      );
      return Success(pending);
    } catch (error) {
      return ErrorResult(CacheFailure('Unable to queue offline location: $error'));
    }
  }

  @override
  Future<Result<List<PendingLocation>>> getPendingLocations(int userId) async {
    try {
      final list = await _localDataSource.getPending(userId);
      return Success(list);
    } catch (error) {
      return ErrorResult(CacheFailure('Unable to read pending locations: $error'));
    }
  }

  @override
  Future<Result<void>> deletePendingLocation(int id) async {
    try {
      await _localDataSource.deleteById(id);
      return const Success(null);
    } catch (error) {
      return ErrorResult(CacheFailure('Unable to delete pending location: $error'));
    }
  }

  @override
  Future<Result<void>> clearPendingLocations(int userId) async {
    try {
      await _localDataSource.clearForUser(userId);
      return const Success(null);
    } catch (error) {
      return ErrorResult(CacheFailure('Unable to clear pending locations: $error'));
    }
  }

  @override
  Future<Result<String>> syncPendingLocationsBatch({
    required int userId,
    required List<PendingLocation> locations,
  }) async {
    if (locations.isEmpty) {
      return const Success('No queued locations');
    }
    try {
      final response = await _remoteDataSource.sendUserLocationsBatch(
        userId: userId,
        locations: locations,
      );
      return Success(
        _responseText(
          response,
          '${locations.length} locations synced',
        ),
      );
    } on ServerException catch (error) {
      return ErrorResult(ServerFailure(error.message));
    } catch (error) {
      return ErrorResult(ServerFailure('Batch location sync failed: $error'));
    }
  }

  static String _responseText(dynamic response, String fallback) {
    if (response is Map) {
      final text =
          response['message'] ?? response['status'] ?? response['result'];
      if (text != null && text.toString().trim().isNotEmpty) {
        return text.toString();
      }
    }
    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }
    return fallback;
  }

  @override
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty) {
        return false;
      }
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // If connectivity check fails, attempt online path and let API decide.
      return true;
    }
  }
}
