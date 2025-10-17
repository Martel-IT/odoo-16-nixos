#
# See `docs.md` for package documentation.
#
{
  system,
  lib, stdenv, fetchzip, fetchFromGitHub,
  poetry2nix, python310,
  rtlcss, wkhtmltopdf,
  pkgs
}:
let
  # Compila OpenSSL 3.4.1 custom da source
  openssl_custom = import ./openssl-custom.nix { inherit lib stdenv; 
    fetchurl = pkgs.fetchurl;
    perl = pkgs.perl;
  };
  
  python = python310.override {
    packageOverrides = self: super: {
      cffi = super.cffi.overrideAttrs (old: {
        postUnpack = ''
          find . -name "pyproject.toml" -type f -exec sed -i \
            's/license = "MIT"/license = {text = "MIT"}/' {} \;
        '';
      });
    };
  };

  wkhtmltopdf-odoo = wkhtmltopdf;
in 

  poetry2nix.mkPoetryApplication rec {
  pname = "odoo16";
  series = "16.0";
  version = "${series}.20230314";

  src = fetchFromGitHub {
    owner = "Martel-IT";
    repo = "odoo-16-core";
    rev = "odoo-core-20251009";
    sha256 = "sha256-hMLgXQvAyQkX/oM/UmoU/dyTXUGoVe+Lp/25e2fbJSM=";
  };

  projectDir = "${src}/odoo-16-core-1.2";
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  inherit python;

  overrides = poetry2nix.defaultPoetryOverrides.extend (self: super:
    let
      fixLicense = drv: drv.overridePythonAttrs (old: {
        postUnpack = (old.postUnpack or "") + ''
          find . -name "pyproject.toml" -type f -exec sed -i \
            's/^license = "\([^"]*\)"$/license = {text = "\1"}/' {} \;
        '';
      });
    in
    {
      cryptography = super.cryptography.overridePythonAttrs (old: {
        format = "pyproject";
        preferWheels = false;
        
        buildInputs = (old.buildInputs or []) ++ [ openssl_custom ];
        
        OPENSSL_DIR = "${openssl_custom}";
        OPENSSL_LIB_DIR = "${openssl_custom}/lib";
        OPENSSL_INCLUDE_DIR = "${openssl_custom}/include";
        
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ 
          pkgs.rustc 
          pkgs.cargo 
          pkgs.pkg-config
        ];
        
        dontCheckRuntimeDeps = true;
        dontUseSetuptoolsCheck = true;
        checkPhase = "";
      });

      # Fix CVE PyPDF2 - infinite loop vulnerability
      pypdf2 = super.pypdf2.overridePythonAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          # Fix infinite loop in __parse_content_stream
          # https://github.com/py-pdf/pypdf/security/advisories/GHSA-hm9v-vxvr-q428
          sed -i 's/while peek not in (b"\\r", b"\\n"):/while peek not in (b"\\r", b"\\n", b""):/' \
            PyPDF2/generic/_data_structures.py || true
        '';
      });
      
      jinja2 = super.jinja2.overridePythonAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ self.flit-core ];
      });
      
      cffi = fixLicense super.cffi;
      pyparsing = fixLicense super.pyparsing;
      typing-extensions = fixLicense super.typing-extensions;
      
      soupsieve = super.soupsieve.overridePythonAttrs (old: {
        postUnpack = (old.postUnpack or "") + ''
          find . -name "pyproject.toml" -type f -exec sed -i '/Programming Language :: Python :: 3.14/d' {} \;
          if [ -f pyproject.toml ]; then
            sed -i '/Programming Language :: Python :: 3.14/d' pyproject.toml
          fi
        '';
        postPatch = (old.postPatch or "") + ''
          if [ -f pyproject.toml ]; then
            sed -i '/Programming Language :: Python :: 3.14/d' pyproject.toml
          fi
        '';
        preBuild = (old.preBuild or "") + ''
          if [ -f pyproject.toml ]; then
            sed -i '/Programming Language :: Python :: 3.14/d' pyproject.toml
          fi
        '';
      });
      
      urllib3 = super.urllib3.overridePythonAttrs (old: {
        postUnpack = (old.postUnpack or "") + ''
          find . -name "pyproject.toml" -type f -exec sed -i \
            -e 's/^license-files = \[\(.*\)\]$/license-files = {paths = \[\1\]}/' \
            -e '/version = {source = "vcs"}/c\version = "2.5.0"' {} \;
        '';
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ self.hatch-vcs ];
      });
    }
  );

  patches = [
    ./server.py.patch
  ];

  doCheck = false;
  dontStrip = true;

  makeWrapperArgs =
  let
    ps = [rtlcss wkhtmltopdf];
  in [
    "--prefix" "PATH" ":" "${lib.makeBinPath ps}"
  ];

  meta = with lib; {
    description = "Open Source ERP and CRM";
    homepage = "https://www.odoo.com/";
    license = licenses.lgpl3Only;
  };
}# NOTE
# ----
# 1. wkhtmltopdf. See (1) in `wkhtmltopdf.nix` for the version we compile
# as well as
# - https://github.com/c0c0n3/odoo.box/issues/23
# for the issues we're having at the moment. Notice `wkhtmltopdf-bin`
# contains a binary fetched from the interwebs which was compiled for
# Arch Linux and includes the `wkhtmltopdf` patched version of Qt. Not
# optimal, but it works on x86 machines.
#
# 2. Source. Why not fetch from GitHub? Because the tarball consolidates
# all the add-ons in the `odoo/addons` dir whereas the repo has them split
# in two dirs: `repo/addons` and `repo/odoo/addons`. If you run the server
# from the repo you'll have to pass the path to the other addons dir since
# some of the modules the code in `repo/odoo` expects are actually in the
# `repo/addons` dir.
#
# 3. Gevent server. We've got to patch the source to fix an issue with
# the gevent server Odoo uses for long-polling/chat. The problem is that
# the code to spawn the server blindly assumes the command line to start
# Odoo was in the format `python odoo ...`, but this may not be true in
# general since a quite common thing to do is to actually use a shell start
# script. The problem boils down to line 713 in `odoo/service/server.py`
# where `long_polling_spawn` starts the gevent process with this command:
#
#     cmd = [sys.executable, sys.argv[0], 'gevent'] + nargs[1:]
#
# So if you used a start script `my-odoo`, Odoo would try running a
# command like `python my-odoo ...` which would fail unless `my-odoo`
# is Python code. This is exactly the case for our Nix package where
# a shell script called `odoo` nicely sets up the server env before
# actually invoking Python on yet another Nix wrapper script, called
# `.odoo-wrapped`, which is a Python script that sets up the Python
# lib path before finally calling `odoo.cli.main`. Long story short,
# changing the Python line above into the one below makes Odoo start
# cleanly and spawn the gevent process as expected.
#
#     cmd = [sys.argv[0], 'gevent'] + nargs[1:]
#
# See `server.py.patch`.
#
# 4. Broken tests. Some tests are broken, so we've got to skip testing.
#
# 5.Stripping. The Odoo 15 package skips stripping, claiming it takes 5+
# minutes and there are no files to strip. So we do the same.
#