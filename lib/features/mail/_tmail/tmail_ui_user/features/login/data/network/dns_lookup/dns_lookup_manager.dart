// Stub: tmail's DNS-based JMAP autoconfig isn't used in our setup
// (we hit Supabase edge functions, not arbitrary JMAP servers). Replaced
// with a no-op manager so login_datasource_impl compiles.

class DnsLookupManager {
  DnsLookupManager();
  Future<String?> lookupSrvJmap(String _) async => null;
  Future<String?> lookupTxtAutoconfig(String _) async => null;
  Future<String?> lookupJmapUrl(String _) async => null;
  Future<String?> lookupSrvJmapUrl(String _) async => null;
}
