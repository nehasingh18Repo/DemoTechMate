import 'package:flutter/services.dart';

class AndroidDeviceId {
  static const MethodChannel _channel =
      MethodChannel('device_info');

  static Future<String?> getAndroidId() async {
    try {
      final androidId =
          await _channel.invokeMethod<String>('getAndroidId');

      return androidId;
    } on PlatformException catch (e) {
      print('Failed to get Android ID: ${e.message}');
      return null;
    }
  }
}