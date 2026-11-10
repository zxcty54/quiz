/// Premium digital study features are temporarily free in the Google Play
/// release. No payment, subscription, or manual UPI flow is enabled here.
class PremiumService {
  PremiumService._();

  static const bool isFreeRelease = true;

  static Future<bool> isPremiumActive() async => true;
}
