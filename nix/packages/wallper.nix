{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wallper";
  version = "1.11.1";

  src = fetchurl {
    url = "https://github.com/alxndlk/wallper-app/releases/download/${finalAttrs.version}/Wallper.zip";
    hash = "sha256-Urdafbz8PQ8n2M+Wzqfx8ixbCiqWy/mRbQcdBsJW6DI=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Preserve the vendor-signed application bundle without binary rewriting.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R Wallper.app "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Live wallpapers for macOS";
    homepage = "https://www.wallper.app/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
  };
})
