/// Disabled home-feed account ids consulted by [QuackerTwitterClient.fetch].
///
/// When non-empty, rotation prefers accounts that still participate in For you,
/// so turning an account off on the home feed also stops burning it on Following
/// search requests. Falls back to the full pool if every account is excluded.
class AccountFetchGate {
  static Set<String> disabledIds = {};
}
