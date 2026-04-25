// Stub for super_dns_client. tmail uses it for autoconfig DNS lookup
// against arbitrary JMAP servers. We hit our own edge functions, so the
// auto-discovery flow never runs. Class shapes are minimal — just enough
// to satisfy imports.

class SrvRecord {
  final String target;
  final int port;
  final int priority;
  const SrvRecord({required this.target, this.port = 0, this.priority = 0});
}

class SuperDnsClient {
  SuperDnsClient();
  Future<List<SrvRecord>> lookupSrv(String _) async => const [];
  Future<List<String>> lookupTxt(String _) async => const [];
}
