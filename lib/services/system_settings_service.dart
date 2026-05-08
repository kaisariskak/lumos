import 'package:flutter/services.dart';

class SystemSettingsService {
  SystemSettingsService._();

  static const _channel = MethodChannel('ibadat/system_settings');

  static Future<void> openAddGoogleAccount() {
    return _channel.invokeMethod<void>('addGoogleAccount');
  }
}
