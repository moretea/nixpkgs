import ./make-test.nix ({ pkgs, ...} : {
  name = "mysql-permissions";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ moretea ];
  };

  nodes = let
    schema = pkgs.writeText "schema.sql" ''
      CREATE USER "dbuser";
    '';
  in {
    with_privs = { pkgs, config, ... }: {
      services.mysql.enable = true;
      services.mysql.package = pkgs.mysql;
      services.mysql.initialDatabases = [ { name ="testdb"; inherit schema;  } ];

      services.mysql.users = {
        "dbuser" = {
          user.privs.drop = true;
          user.privs.create = true;
        };
      };
    };

    no_privs = { pkgs, config, ... }: {
      services.mysql.initialDatabases = [ { name ="testdb"; inherit schema;} ];
      services.mysql.enable = true;
      services.mysql.package = pkgs.mysql;
    };
  };

  testScript = ''
    startAll;

    $with_privs->waitForUnit("mysql");
    $with_privs->sleep(10); # Hopefully this is long enough!!
    $with_privs->succeed("echo 'use testdb; create table test (t int);' | mysql -u dbuser -N");

    $no_privs->waitForUnit("mysql");
    $no_privs->sleep(10); # Hopefully this is long enough!!
    $no_privs->fail("echo 'use testdb; create table test (t int);' | mysql -u dbuser -N");
  '';
})
