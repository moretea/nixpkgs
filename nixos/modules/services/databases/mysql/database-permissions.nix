{ lib }:

with lib;
{
  options = {
    privs = {
      select = mkOption {
        type = types.bool;
        default = false;
        description = "Grant SELECT on all tables in this database";
      };

      insert = mkOption {
        type = types.bool;
        default = false;
        description = "Grant INSERT on all tables in this database";
      };
    };
  };
}
