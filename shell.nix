# based on https://github.com/crystal-lang/crystal/blob/master/shell.nix
#
# You can choose which llvm version use and, on Linux, choose to use musl.
#
# $ nix-shell --pure
# $ nix-shell --pure --arg llvm 10
# $ nix-shell --pure --arg llvm 10 --arg musl true
# $ nix-shell --pure --arg llvm 9
# $ nix-shell --pure --arg llvm 9 --argstr system i686-linux
# ...
# $ nix-shell --pure --arg llvm 6
#
# Futhermore you can add choose to install further software to test the bot against 
# an actual syncplay server
#
# $ nix-shell --pure --arg testing true
#
# If needed, you can use https://app.cachix.org/cache/crystal-ci to avoid building
# packages that are not available in Nix directly. This is mostly useful for musl.
#
# $ nix-env -iA cachix -f https://cachix.org/api/v1/install
# $ cachix use crystal-ci
# $ nix-shell --pure --arg musl true
#

{llvm ? 10, musl ? false, system ? builtins.currentSystem, testing ? false}:

let
  nixpkgs = import (builtins.fetchTarball {
    name = "nixpkgs-unstable";
    url = "https://github.com/NixOS/nixpkgs/archive/0fe6b1ccde4f80ff7a3c969dffb57a811932dc38.tar.gz";
    sha256 = "17r3m8acpsi1awnll09yqgsyfd12rqf04v5i1ip91rgmf9z9zghn";
  }) {
    inherit system;
  };

  pkgs = if musl then nixpkgs.pkgsMusl else nixpkgs;

  genericBinary = { url, sha256 }:
    pkgs.stdenv.mkDerivation rec {
      name = "crystal-binary";
      src = builtins.fetchTarball { inherit url sha256; };

      buildCommand = ''
        mkdir -p $out

        # Darwin packages use embedded/bin/crystal
        if [ -f "${src}/embedded/bin/crystal" ]; then
          cp -R ${src}/embedded/* $out/
          cp -R ${src}/src $out/
        fi

        # Linux packages use lib/crystal/bin/crystal
        if [ -f "${src}/lib/crystal/bin/crystal" ]; then
          cp -R ${src}/lib/crystal/* $out 
          cp -R ${src}/share/crystal/src $out
        fi
      '';
    };

  # Hashes obtained using `nix-prefetch-url --unpack <url>`
  latestCrystalBinary = genericBinary ({
    x86_64-darwin = {
      url = "https://github.com/crystal-lang/crystal/releases/download/1.0.0/crystal-1.0.0-1-darwin-x86_64.tar.gz";
      sha256 = "sha256:1ff05f7v31r7xw4xk1a5zns77k3hrgdb9cn15w2zsps83iqlq81i";
    };

    x86_64-linux = {
      url = "https://github.com/crystal-lang/crystal/releases/download/1.0.0/crystal-1.0.0-1-linux-x86_64.tar.gz";
      sha256 = "sha256:13940gjs1zl29wrhngzylhckxgzb8xh16bniqik5lslp6qpljqy4";
    };

    i686-linux = {
      url = "https://github.com/crystal-lang/crystal/releases/download/1.0.0/crystal-1.0.0-1-linux-i686.tar.gz";
      sha256 = "sha256:18xg2nxg68cx0ngidpzy68wa5zqmcz0xfm0im5sg8j8bnj8ccg35";
    };
  }.${pkgs.stdenv.system});

  pkgconfig = pkgs.pkgconfig;

  llvm_suite = ({
    llvm_10 = {
      llvm = pkgs.llvm_10;
      extra = [ pkgs.lld_10 pkgs.lldb_10 ];
    };
    llvm_9 = {
      llvm = pkgs.llvm_9;
      extra = [ ]; # lldb it fails to compile on Darwin
    };
    llvm_8 = {
      llvm = pkgs.llvm_8;
      extra = [ ]; # lldb it fails to compile on Darwin
    };
    llvm_7 = {
      llvm = pkgs.llvm;
      extra = [ pkgs.lldb ];
    };
    llvm_6 = {
      llvm = pkgs.llvm_6;
      extra = [ ]; # lldb it fails to compile on Darwin
    };
  }."llvm_${toString llvm}");

  libatomic_ops = builtins.fetchurl {
    url = "https://github.com/ivmai/libatomic_ops/releases/download/v7.6.10/libatomic_ops-7.6.10.tar.gz";
    sha256 = "1bwry043f62pc4mgdd37zx3fif19qyrs8f5bw7qxlmkzh5hdyzjq";
  };

  boehmgc = pkgs.stdenv.mkDerivation rec {
    pname = "boehm-gc";
    version = "8.0.4";

    src = builtins.fetchTarball {
      url = "https://github.com/ivmai/bdwgc/releases/download/v${version}/gc-${version}.tar.gz";
      sha256 = "16ic5dwfw51r5lcl88vx3qrkg3g2iynblazkri3sl9brnqiyzjk7";
    };

    patches = [
      (pkgs.fetchpatch {
        url = "https://github.com/ivmai/bdwgc/commit/5668de71107022a316ee967162bc16c10754b9ce.patch";
        sha256 = "02f0rlxl4fsqk1xiq0pabkhwydnmyiqdik2llygkc6ixhxbii8xw";
      })
    ];

    postUnpack = ''
      mkdir $sourceRoot/libatomic_ops
      tar -xzf ${libatomic_ops} -C $sourceRoot/libatomic_ops --strip-components 1
    '';

    configureFlags = [
      "--disable-debug"
      "--disable-dependency-tracking"
      "--disable-shared"
      "--enable-large-config"
    ];

    enableParallelBuilding = true;
  };

  stdLibDeps = with pkgs; [
      boehmgc gmp libevent libiconv libxml2 libyaml openssl pcre zlib
    ] ++ lib.optionals stdenv.isDarwin [ libiconv ];

  tools = with pkgs; [ pkgs.hostname pkgs.git llvm_suite.extra ] ++ lib.optionals testing [ syncplay openssl ];
  libraries = with pkgs; lib.strings.concatStringsSep ":" (lib.lists.forEach stdLibDeps (x: "${x}/lib/"));
in

pkgs.stdenv.mkDerivation rec {
  name = "crystal-dev";

  buildInputs = tools ++ stdLibDeps ++ [
    latestCrystalBinary
    pkgconfig
    llvm_suite.llvm
  ];

  LLVM_CONFIG = "${llvm_suite.llvm}/bin/llvm-config";
  CRYSTAL_LIBRARY_PATH = "${libraries}:${latestCrystalBinary}/lib";
  CRYSTAL_PATH = "lib:${latestCrystalBinary}/src";

  # ld: warning: object file (.../src/ext/libcrystal.a(sigfault.o)) was built for newer OSX version (10.14) than being linked (10.12)
  MACOSX_DEPLOYMENT_TARGET = "10.11";
}
