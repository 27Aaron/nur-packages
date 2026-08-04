{
  lib,
  sources,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "geolite2";
  inherit (sources.geolite2-asn) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm444 ${sources.geolite2-asn.src} $out/GeoLite2-ASN.mmdb
    install -Dm444 ${sources.geolite2-city.src} $out/GeoLite2-City.mmdb
    install -Dm444 ${sources.geolite2-country.src} $out/GeoLite2-Country.mmdb

    runHook postInstall
  '';

  passthru = {
    asn = sources.geolite2-asn.src;
    city = sources.geolite2-city.src;
    country = sources.geolite2-country.src;
  };

  meta = {
    description = "MaxMind GeoLite2 ASN, City, and Country databases";
    homepage = "https://github.com/P3TERX/GeoLite.mmdb";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.all;
  };
}
