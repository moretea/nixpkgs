{
  dpkg,
  fetchurl,
  stdenv,
}:
stdenv.mkDerivation rec {
  name = "hypercontainer-guest-${version}";
  version = "0.8.1";

  src = fetchurl {
    url = "https://hypercontainer-download.s3-us-west-1.amazonaws.com/0.8/debian/hyperstart_0.8.1-1_amd64.deb";
    sha256 = "07cb9795s2s2bwy5lwmxbcr67cdsykha3v841g4f88r19l7cad25";
  };

  buildInputs = [ dpkg ];

  buildCommand = ''
    dpkg -x ${src} .
    mkdir -p $out
    cp -r var $out
  '';
}
