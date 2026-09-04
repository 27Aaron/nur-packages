{
  fetchurl,
  lib,
  stdenvNoCC,
  versionData ? builtins.fromJSON (builtins.readFile ./hashes.json),
}:
let
  inherit (versionData) version;
  mkDatabase =
    name: hash:
    fetchurl {
      url = "https://github.com/P3TERX/GeoLite.mmdb/releases/download/${version}/GeoLite2-${name}.mmdb";
      inherit hash;
    };
  databases = {
    asn = mkDatabase "ASN" versionData.hashes.asn;
    city = mkDatabase "City" versionData.hashes.city;
    country = mkDatabase "Country" versionData.hashes.country;
  };
in
stdenvNoCC.mkDerivation {
  pname = "geolite2";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm444 ${databases.asn} $out/GeoLite2-ASN.mmdb
    install -Dm444 ${databases.city} $out/GeoLite2-City.mmdb
    install -Dm444 ${databases.country} $out/GeoLite2-Country.mmdb

    runHook postInstall
  '';

  passthru = {
    inherit (databases) asn city country;
    cachePaths = builtins.attrValues databases;
  };

  meta = {
    description = "MaxMind GeoLite2 ASN, City, and Country databases";
    homepage = "https://github.com/P3TERX/GeoLite.mmdb";
    changelog = "https://github.com/P3TERX/GeoLite.mmdb/releases/tag/${version}";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.all;
  };
}
