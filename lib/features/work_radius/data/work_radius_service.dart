import 'package:fixleo/core/network/api_client.dart';
import 'package:fixleo/features/work_radius/data/work_radius_model.dart';

/// Talks to the Work-radii endpoints (see `api/WorkRadius.md`).
///
/// The public list ([getOptions]) powers the master "Ish hududi" radius picker
/// so the app only ever offers radii the backend actually allows. The admin
/// methods ([add] / [remove]) require an admin token (see [AuthSession]).
class WorkRadiusService {
  WorkRadiusService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// `GET /work-radiuses` — public. Allowed radii, ascending by km.
  Future<List<WorkRadius>> getOptions() async {
    final data = await _client.get('/work-radiuses');
    return (data as List<dynamic>)
        .map((e) => WorkRadius.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /admin/work-radiuses` — admin. Same list, for the admin panel.
  Future<List<WorkRadius>> getOptionsAdmin() async {
    final data = await _client.get('/admin/work-radiuses');
    return (data as List<dynamic>)
        .map((e) => WorkRadius.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /admin/work-radiuses` — admin. Adds a new (unique) radius.
  Future<WorkRadius> add(int km) async {
    final data = await _client.post('/admin/work-radiuses', body: {'km': km});
    return WorkRadius.fromJson(data as Map<String, dynamic>);
  }

  /// `DELETE /admin/work-radiuses/:id` — admin.
  Future<void> remove(int id) => _client.delete('/admin/work-radiuses/$id');
}
