/// Whether the device is permanently in native-host mode.
abstract interface class PermanentHostModeChecking {
  Future<bool> isPermanentHostModeEnabled();
}

final class MemoryPermanentHostModeChecker implements PermanentHostModeChecking {
  MemoryPermanentHostModeChecker({this.enabled = false});

  bool enabled;

  @override
  Future<bool> isPermanentHostModeEnabled() async => enabled;
}
