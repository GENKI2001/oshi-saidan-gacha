// Rewarded ads (AdMob). Only iOS has them for now; the web build gets a stub.
export 'ads_stub.dart' if (dart.library.io) 'ads_mobile.dart';
