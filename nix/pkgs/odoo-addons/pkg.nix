#
# See `docs.md` for package documentation.
#
{
    stdenv, fetchFromGitHub, odoo-pkg ? null
}:
let
  vendor = fetchFromGitHub {
    owner = "Martel-IT";
    repo = "odoo-16-addons";
    rev = "odoo.box-vendor-addons-patched-cryptography-latest";
    sha256 = "sha256-u8T7v6HJOhGPsmkwL4W7DRJcCNMQzTklUog3SslTajE=";
  };
in stdenv.mkDerivation rec {
    pname = "odoo-addons";
    version = "1.0.0-odoo-16.0";

    src = vendor;

    installPhase = ''
      mkdir -p $out
      
      cp -rv $src/* $out
      
    '';
}
