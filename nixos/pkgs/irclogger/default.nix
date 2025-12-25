{ bundlerEnv
, fetchFromGitHub
, gcc13Stdenv
, lib
, makeWrapper
, ruby
, stdenvNoCC
, util-linux
}:

let
  pname = "irclogger";
  src = fetchFromGitHub {
    owner = "whitequark";
    repo = pname;
    rev = "e1d01e00302e55445f5d3fbc5296d8292caa26cf";
    hash = "sha256-lKRF9mtjVn1AbbWVzvc9a19/bz/9l6lIenznbtVNFDw=";
  };
  env = bundlerEnv {
    name = "${pname}-gems";
    gemfile = "${src}/Gemfile";
    lockfile = "${src}/Gemfile.lock";
    gemset = "${src}/gemset.nix";

    # Overriding ruby stdenv propagates to gems. `mysql2` has issues building with newer compiler versions.
    ruby = (ruby.override { stdenv = gcc13Stdenv; });
  };
in
stdenvNoCC.mkDerivation {
  pname = "irclogger";
  version = "1.0.0";

  inherit src;

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    ruby
  ];

  installPhase = ''
    mkdir -p $out/{bin,opt/irclogger}

    cp -r {bin,lib,public,views} $out/opt/irclogger/

    for bin in $out/opt/irclogger/bin/*; do
      BINNAME=$(basename -- "$bin")
      makeWrapper "$bin" "$out/bin/''${BINNAME%%.*}" \
        --set GEM_PATH ${env}/${ruby.gemPath} \
        --prefix PATH : ${lib.makeBinPath [
          util-linux # for `cal`
        ]}
    done
  '';
}
