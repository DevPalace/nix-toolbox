{ pkgs, ... }:
{
  copyToRoot = [ pkgs.dockerTools.caCertificates ];

  # compatibility
  # - openssl
  env.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
  # - Haskell x509-system
  env.SYSTEM_CERTIFICATE_PATH = "/etc/ssl/certs/ca-bundle.crt";
}
