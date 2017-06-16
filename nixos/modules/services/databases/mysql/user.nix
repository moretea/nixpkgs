{ lib }:

with lib;
{
  options = {
    user = {
      privs = {
        drop = mkOption {
          type = types.bool;
          default = false;
          description = "Grant DROP on all tables in all databases";
        };
        create = mkOption {
          type = types.bool;
          default = false;
          description = "Grant CREATE on all databases";
        };
      };
    };

    dbs = mkOption {
      type = types.attrsOf (types.submodule (import ./database-permissions.nix { inherit lib; }));
      default = {};
      description = "Per database permissions";
    };
  };
}
