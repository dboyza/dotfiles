{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_24,
}:
buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.82.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-qcnX+GGnUIr15RbUk6A+rB/vNvi1b7DSBNpkOVDl2wg=";
  };

  npmDepsHash = "sha256-a2U+yvWtuMiK9FkQPmy0f1TTuBTwkTrmoNvybNNv2Q8=";
  npmDepsFetcherVersion = 2;
  nodejs = nodejs_24;
  dontNpmBuild = true;
  npmFlags = [
    "--ignore-scripts"
    "--omit=dev"
  ];

  # npm 11 omitted these integrity values from Pi's published shrinkwrap.
  # Nix requires them to fetch dependencies reproducibly.
  postPatch = ''
    grep -q '^[[:space:]]*"devDependencies": {' package.json
    sed -i '/^[[:space:]]*"devDependencies": {$/,/^[[:space:]]*},$/d' package.json
    ! grep -q '^[[:space:]]*"devDependencies": {' package.json

    substituteInPlace npm-shrinkwrap.json \
      --replace-fail \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-agent-core/-/pi-agent-core-0.82.0.tgz",' \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-agent-core/-/pi-agent-core-0.82.0.tgz",
        "integrity": "sha512-bnS9DpOKK5T/F/gQkaOnYdMsuuciWiScfAHHWC+k5OQ0HxjSqMFQvp8keurULLoT4+v8NHv4V14pNvd4hsfC0Q==",' \
      --replace-fail \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-0.82.0.tgz",' \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-0.82.0.tgz",
        "integrity": "sha512-8MvW9+zno13sXDuT2kFMnWeTNUufUhPeZDRVO+igGoBRCDWgn7Xh2FkRQI1mRuet6QhF4ENQuLYdIAOyG6BhNw==",' \
      --replace-fail \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-tui/-/pi-tui-0.82.0.tgz",' \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-tui/-/pi-tui-0.82.0.tgz",
        "integrity": "sha512-9IDjQOXne7t9l2s2YcjnIBxsVNVPE7qScVSB3YmFlXsBW4pfo2gOElTxggV84KrRiGqABnlFPBWbf0k54hszHQ==",'
  '';

  meta = {
    description = "Minimal terminal coding harness";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
