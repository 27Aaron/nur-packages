{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  version = "2026.08.01";
  releaseUrl = "https://github.com/P3TERX/GeoLite.mmdb/releases/download/${version}";

  databases = {
    asn = fetchurl {
      url = "${releaseUrl}/GeoLite2-ASN.mmdb";
      hash = "sha256-3c7BRePD6gY4nYhyNY2mU/kIbe3rvX0Ptcdb4nbZRB4=";
    };
    city = fetchurl {
      url = "${releaseUrl}/GeoLite2-City.mmdb";
      hash = "sha256-bmaEyrBOu6EMHqn0pEMXXKD/CA4lXoT57wNQUXWCZX4=";
    };
    country = fetchurl {
      url = "${releaseUrl}/GeoLite2-Country.mmdb";
      hash = "sha256-0Y8TkBT/Md0LAF4WoVWEnA0mtZxl2ceRaKeA2igYk2Q=";
    };
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

    passthru = databases;

    meta = {
      description = "MaxMind GeoLite2 ASN, City, and Country databases";
      homepage = "https://github.com/P3TERX/GeoLite.mmdb";
      license = lib.licenses.cc-by-sa-40;
      platforms = lib.platforms.all;
    };
  }
