import 'package:url_launcher/url_launcher.dart';

enum NavigationApp { googleMaps, yandexNavigator }

class NavigationLauncher {
  const NavigationLauncher();

  Uri googleMapsUrl({required double latitude, required double longitude}) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
        'travelmode': 'driving',
      });

  Uri yandexNavigatorUrl({
    required double latitude,
    required double longitude,
  }) => Uri(
    scheme: 'yandexnavi',
    host: 'build_route_on_map',
    queryParameters: {
      'lat_to': latitude.toString(),
      'lon_to': longitude.toString(),
    },
  );

  Future<bool> open(
    NavigationApp app, {
    required double latitude,
    required double longitude,
  }) async {
    final url = switch (app) {
      NavigationApp.googleMaps => googleMapsUrl(
        latitude: latitude,
        longitude: longitude,
      ),
      NavigationApp.yandexNavigator => yandexNavigatorUrl(
        latitude: latitude,
        longitude: longitude,
      ),
    };
    if (app == NavigationApp.yandexNavigator && !await canLaunchUrl(url)) {
      return false;
    }
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
