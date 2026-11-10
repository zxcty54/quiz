/// Premium digital study features are temporarily free in the Google Play
/// release. No payment, subscription, or manual UPI flow is enabled here.
class PremiumService {
  PremiumService._();

  static const bool isFreeRelease = true;

  static Future<bool> isPremiumActive() async => true;

  /// Expiry date for screens that still gate content on a premium window (the
  /// sectional exam screen on `main` does). While the Play release is free the
  /// window never lapses, so nothing locks and the paywall cannot dead-end.
  /// Without this shim those screens fail to compile against the free-release
  /// service: `fetchPremiumUntil` was part of the removed manual UPI flow.
  static Future<DateTime?> fetchPremiumUntil() async =>
      isFreeRelease ? DateTime(2099, 12, 31) : null;

  /// Owner mode belonged to the removed manual approval flow. It stays disabled
  /// so no device gains privileged entitlement outside Google Play Billing.
  static Future<bool> isOwnerMode() async => false;
}
