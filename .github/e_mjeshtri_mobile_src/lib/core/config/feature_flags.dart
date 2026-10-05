abstract final class FeatureFlags {
  static const providerAppEnabled = true;
  static const adminPanelEnabled = true;
  static const onlinePaymentsEnabled = false;

  // Enable only after the corresponding provider is configured in Supabase
  // and the native deep-link settings are present in Android/iOS projects.
  static const googleAuthEnabled = false;
  static const appleAuthEnabled = false;
}