class ExtensionDetails {
  final int id;
  final String name;
  final int extension;
  final String domain;
  final String password;
  final String proxy;
  final int port;
  final String? protocol;

  ExtensionDetails({
    required this.id,
    required this.name,
    required this.extension,
    required this.domain,
    required this.password,
    required this.proxy,
    required this.port,
    this.protocol,
  });

  factory ExtensionDetails.fromJson(Map<String, dynamic> json) {
    return ExtensionDetails(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      extension: json['extension'] ?? 0,
      domain: json['domain'] ?? '',
      password: json['password'] ?? '',
      proxy: json['proxy'] ?? '',
      port: json['port'] ?? 0,
      protocol: json['protocol'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'extension': extension,
      'domain': domain,
      'password': password,
      'proxy': proxy,
      'port': port,
      'protocol': protocol,
    };
  }

  @override
  String toString() {
    return 'ExtensionDetails(id: $id, name: $name, extension: $extension, domain: $domain, proxy: $proxy, port: $port, protocol: $protocol)';
  }
}
