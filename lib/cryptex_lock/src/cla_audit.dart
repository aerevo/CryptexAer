
class ClaAudit {
  static final List<String> _logs = [];

  static void log(String event) {
    _logs.add('[${DateTime.now().toIso8601String()}] $event');
  }

  static List<String> get logs => List.unmodifiable(_logs);
}
