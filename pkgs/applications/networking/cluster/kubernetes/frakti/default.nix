{ lib, stdenv, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  name = "frakti-${version}";
  version = "0.2";
  rev = "refs/tags/v0.2";

  goPackagePath = "k8s.io/frakti";

  src = fetchFromGitHub {
    inherit rev;
    name = "kubernetes-frakti-${version}";
    owner = "kubernetes";
    repo = "frakti";
    sha256 = "0c3bl9ar1wzx4h7p726vykfg0gcy71w6dfn8sq82h8cv1rvnfja6";
  };

  goDeps = null;

  meta = {
    maintainer = with lib.maintainers; [ moretea ];
  };
}
