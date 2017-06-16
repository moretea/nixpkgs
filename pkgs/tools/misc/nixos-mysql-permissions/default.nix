{ stdenv, bundlerEnv, ruby } :
let
  env = bundlerEnv {
    name = "nixos-mysql-permissions-env";
    inherit ruby;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };

in
stdenv.mkDerivation {
  name = "nixos-mysql-permissions";
  buildInputs = [ env.wrappedRuby ];
  buildCommand = ''
    mkdir -p $out/bin
    cp ${./nixos-mysql-permissions.rb} $out/bin/nixos-mysql-permissions
    chmod +x $out/bin/nixos-mysql-permissions
    patchShebangs $out/bin/nixos-mysql-permissions
  '';
}
