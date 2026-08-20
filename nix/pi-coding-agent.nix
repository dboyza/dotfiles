{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_24,
}:
let
  metadata = builtins.fromJSON (builtins.readFile ./pi-coding-agent.json);
  integrityPatches = lib.concatMapStringsSep "\n" (dependency: ''
    substituteInPlace npm-shrinkwrap.json \
      --replace-fail \
        '"resolved": "${dependency.resolved}",' \
        '"resolved": "${dependency.resolved}",
        "integrity": "${dependency.integrity}",'
  '') metadata.missingIntegrities;
in
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit (metadata) version;

  src = fetchurl {
    url = metadata.tarball;
    hash = metadata.sourceHash;
  };

  npmDepsHash = metadata.npmDepsHash;
  npmDepsFetcherVersion = 2;
  nodejs = nodejs_24;
  dontNpmBuild = true;
  npmFlags = [
    "--ignore-scripts"
    "--omit=dev"
  ];

  # Pi's published shrinkwrap omits integrity values for first-party packages.
  # Nix requires them to fetch dependencies reproducibly.
  postPatch = ''
    grep -q '^[[:space:]]*"devDependencies": {' package.json
    sed -i '/^[[:space:]]*"devDependencies": {$/,/^[[:space:]]*},$/d' package.json
    ! grep -q '^[[:space:]]*"devDependencies": {' package.json

    ${integrityPatches}
  '';

  meta = {
    description = "Minimal terminal coding harness";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
