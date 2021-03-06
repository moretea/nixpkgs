{ fetchurl, stdenv, perl, lib, openldap, pam, db, cyrus_sasl, libcap,
expat, libxml2, libtool, openssl}:
stdenv.mkDerivation rec {
  name = "squid-3.5.15";
  src = fetchurl {
    url = "http://www.squid-cache.org/Versions/v3/3.5/${name}.tar.bz2";
    sha256 = "1cgy6ffyarqd35plqmqi3mrsp0941c6n55pr3zavp07ksj46wgzm";
  };
  buildInputs = [perl openldap pam db cyrus_sasl libcap expat libxml2
    libtool openssl];
  configureFlags = [
    "--enable-ipv6"
    "--disable-strict-error-checking"
    "--disable-arch-native"
    "--with-openssl"
    "--enable-ssl-crtd"
  ];

  meta = {
    description = "a caching proxy for the Web supporting HTTP, HTTPS, FTP, and more";
    homepage = "http://www.squid-cache.org";
    license = stdenv.lib.licenses.gpl2;
  };
}
