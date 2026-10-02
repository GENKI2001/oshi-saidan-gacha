// No ads on the web.
class Ads {
  static final instance = Ads._();
  Ads._();

  bool get enabled => false;
  bool get ready => false;
  Future<void> start() async {}

  /// Calls [onEarned] once the reward is earned; returns false if no ad could be shown.
  Future<bool> show(void Function() onEarned) async => false;
}
