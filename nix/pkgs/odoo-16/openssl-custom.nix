{ lib, stdenv, fetchurl, perl }:

stdenv.mkDerivation rec {
  pname = "openssl";
  version = "3.4.1";

  src = fetchurl {
    url = "https://github.com/openssl/openssl/releases/download/openssl-${version}/openssl-${version}.tar.gz";
    sha256 = "sha256-ACotazC1i/S+pGxDvdljZar42qbEKHgqpP7uBtoZffM=";
  };

  nativeBuildInputs = [ perl ];

  configureScript = "perl ./Configure";
  configureFlags = [
    "linux-x86_64"
    "shared"
    "--libdir=lib"
  ];

  preConfigure = ''
    export LDFLAGS="-L$out/lib"
    export LD_LIBRARY_PATH="$out/lib:$LD_LIBRARY_PATH"
  '';

  enableParallelBuilding = true;

  postInstall = ''
    mkdir -p $out/{lib,include}
  '';

  meta = with lib; {
    description = "OpenSSL 3.4.1 - CVE-2024-6119 fixed";
    homepage = "https://www.openssl.org";
    license = licenses.asl20;
  };
}