{ bundlerEnv
, fetchFromGitHub
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
    rev = "2078268d4dd8b6c2759cae4cb70b7e203f2d2d8b";
    hash = "sha256-1U3efaY4imed8GtU69bTcRVHzvvl1/49YErRzoUipTg=";
  };
  env = bundlerEnv {
    name = "${pname}-gems";
    inherit ruby;
    gemfile = "${src}/Gemfile";
    lockfile = "${src}/Gemfile.lock";
    gemset = "${src}/gemset.nix";
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
