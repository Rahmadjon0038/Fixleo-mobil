import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fixleo/app/locale/app_locale.dart';
import 'package:fixleo/core/location/device_location_service.dart';

void showDeviceLocationFailure(
  BuildContext context,
  DeviceLocationException error,
  DeviceLocationService service,
) {
  final lang = LocaleController.language.value;
  final message = switch (error.failure) {
    DeviceLocationFailure.serviceDisabled => tr(
      lang,
      'Telefon lokatsiyasi o‘chirilgan',
      'Геолокация на телефоне выключена',
      'Location services are turned off',
    ),
    DeviceLocationFailure.permissionDenied => tr(
      lang,
      'Joylashuvga ruxsat berilmadi',
      'Доступ к геолокации не разрешён',
      'Location permission was not granted',
    ),
    DeviceLocationFailure.permissionDeniedForever => tr(
      lang,
      'Lokatsiya ruxsati bloklangan. Sozlamalardan yoqing',
      'Доступ к геолокации заблокирован. Разрешите его в настройках',
      'Location permission is blocked. Enable it in Settings',
    ),
    DeviceLocationFailure.timeout => tr(
      lang,
      'Joylashuvni aniqlash vaqti tugadi. Qayta urinib ko‘ring',
      'Не удалось вовремя определить местоположение. Попробуйте снова',
      'Location lookup timed out. Try again',
    ),
    DeviceLocationFailure.unavailable => tr(
      lang,
      'Joylashuvni aniqlab bo‘lmadi',
      'Не удалось определить местоположение',
      'Could not determine your location',
    ),
  };
  final opensSettings =
      error.failure == DeviceLocationFailure.serviceDisabled ||
      error.failure == DeviceLocationFailure.permissionDeniedForever;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: opensSettings
            ? SnackBarAction(
                label: tr(lang, 'Sozlamalar', 'Настройки', 'Settings'),
                onPressed: () {
                  if (error.failure == DeviceLocationFailure.serviceDisabled) {
                    unawaited(service.openLocationSettings());
                  } else {
                    unawaited(service.openAppSettings());
                  }
                },
              )
            : null,
      ),
    );
}
