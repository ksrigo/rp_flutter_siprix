class ExtensionDetails {
  final String name;
  final int extension;
  final String domain;
  final String password;
  final String proxy;
  final int port;

  ExtensionDetails({
    required this.name,
    required this.extension,
    required this.domain,
    required this.password,
    required this.proxy,
    required this.port,
  });

  factory ExtensionDetails.fromJson(Map<String, dynamic> json) {
    return ExtensionDetails(
      name: json['name'] ?? '',
      extension: json['extension'] ?? 0,
      domain: json['domain'] ?? '',
      password: json['password'] ?? '',
      proxy: json['proxy'] ?? '',
      port: json['port'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'extension': extension,
      'domain': domain,
      'password': password,
      'proxy': proxy,
      'port': port
    };
  }

  @override
  String toString() {
    return 'ExtensionDetails(name: $name, extension: $extension, domain: $domain, proxy: $proxy, port: $port)';
  }
}
