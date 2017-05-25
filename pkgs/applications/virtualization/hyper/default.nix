{
  autoconf,
  automake,
  devicemapper,
  fetchgit,
  gcc,
  git,
  go,
  lib,
  libvirt,
  pkgconfig,
  stdenv,
}:
let
  libs = [devicemapper libvirt];
  makePaths = opt: postfix: libs: lib.concatStringsSep " " (map (lib: "${opt} ${lib}/${postfix}") libs);
in
stdenv.mkDerivation rec {
  name = "hypercontainer-${version}";
  version = "git-${rev}";
  rev = "13bde1a6bb75a6f4de971516ac7cfb61c3b789e8";

#  metadata = {
#    description = "HyperContainer is a hypervisor-agnostic technology that allows you to run Docker images on plain hypervisors";
#  };

  goPackagePath = "github.com/hyperhq/hyperd";

  src = fetchgit {
    url = "https://github.com/hyperhq/hyperd";
    leaveDotGit = true;
    inherit rev;
    sha256 = "10hmsgvib72bhfbc9d5z8frsjzvb7c97xb5knh0wgq21g65zx9lr";
  };

  CPPFLAGS    = makePaths "-I" "include" libs;
  LDFLAGS     = makePaths "-L" "lib" libs;
  CGO_CFLAGS  = CPPFLAGS;
  CGO_LDFLAGS = LDFLAGS;

  buildInputs = [ git autoconf automake go pkgconfig gcc libvirt ];

  buildCommand = ''
    export GOPATH=`pwd`
    mkdir -p src/${goPackagePath}
    cd src/${goPackagePath}
    cp -r ${src}/{.git,*} .
    ./autogen.sh
    # remove broken check...
    ./configure --without-xen --without-btrfs --with-libvirt
    make
    mkdir -p $out/bin
    cp ./hyperd $out/bin
    cp ./hyperctl $out/bin
  '';
}
