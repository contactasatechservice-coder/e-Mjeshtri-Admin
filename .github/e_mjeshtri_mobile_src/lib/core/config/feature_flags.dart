abstract final class FeatureFlags {
  static const providerAppEnabled = false;
  static const adminPanelEnabled = false;
  static const onlinePaymentsEnabled = false;

  // Enable only after the corresponding provider is configured in Supabase
  // and the native deep-link settings are present in Android/iOS projects.
  static const googleAuthEnabled = false;
  static const appleAuthEnabled = false;
}