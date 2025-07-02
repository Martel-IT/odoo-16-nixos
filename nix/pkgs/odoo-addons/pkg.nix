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
    rev = "odoo.box-vendor-addons-2-jul-2025";
    sha256 = "sha256-btuRMzrsokgOmRS3UK3baDjCj8IqBLOrFRpyj2S7HR0=";
  };
in stdenv.mkDerivation rec {
    pname = "odoo-addons";
    version = "1.0.0-odoo-16.0";

    src = vendor;

    installPhase = ''
      # Creiamo la directory di output
      mkdir -p $out
      
      # Copiamo solo gli addons del fornitore
      cp -rv $src/* $out
      
      echo "Installed vendor addons only, no core addons linked"
    '';
}
