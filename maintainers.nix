{ ... }:
let
  maintainers = import ./lib/maintainers.nix { outputStructured = true; };
in with maintainers;
let
  delegateTo = path: import path { inherit maintainers; };
in [
  {
    description = "Maintainers";
    paths = [ "maintainers.nix" ];
    maintainers = [ eelco ];
  }

  {
    description = "Standard environment";
    paths = [ "pkgs/stdenv/**" ];
    maintainers = [ eelco ];
  }

  {
    description = "Ruby modules";
    paths = [ "pkgs/development/ruby-modules/**" ];
    delegate = delegateTo pkgs/development/ruby-modules/maintainers.nix;
    maintainers = [ zimbatm ];
  }

  {
    description = "Package maintainers";
    paths = [ "pkgs/**/*" ];
    script = "./find-pkg-maintainers";
    maintainers = [];
  }
]
