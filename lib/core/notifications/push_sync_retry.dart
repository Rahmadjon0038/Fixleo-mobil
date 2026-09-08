import 'dart:async';

/// Coalesces concurrent registration attempts and retries temporary failures.
/// Reset invalidates pending work on logout/account replacement.
class PushSyncRetry {
  PushSyncRetry(this.attempt);
  final Future<bool> Function() attempt;
  static const delays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
  ];
  Timer? _timer;
  Future<void>? _running;
  int _generation = 0;
  int _retries = 0;

  Future<void> sync() {
    if (_running != null) return _running!;
    _timer?.cancel();
    _timer = null;
    final generation = _generation;
    final completer = Completer<void>();
    _running = completer.future;
    unawaited(_run(generation, completer));
    return completer.future;
  }

  Future<void> _run(int generation, Completer<void> completer) async {
    var success = false;
    try {
      success = await attempt();
    } on Object {
      // A failed SDK/network call must not crash startup or resume.
    } finally {
      if (generation == _generation) {
        _running = null;
        if (success) {
          _retries = 0;
        } else if (_retries < delays.length) {
          _timer = Timer(delays[_retries++], () => unawaited(sync()));
        }
      }
      completer.complete();
    }
  }

  void reset() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _running = null;
    _retries = 0;
  }
}
