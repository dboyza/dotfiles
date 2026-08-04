{
  buildNpmPackage,
  fetchurl,
  lib,
  nodejs_24,
}:
buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.80.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-wBDbIY1X1WF2VlG/QuwTrcInNmk4gLRs8ZGbm/wmCrM=";
  };

  npmDepsHash = "sha256-LiSUXnICXJIFLim86sRPv0gNMoFbk6qadBEDqvHSr2Y=";
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
    node --input-type=module -e '
      import { readFile, writeFile } from "node:fs/promises";
      const packageJson = JSON.parse(await readFile("package.json", "utf8"));
      delete packageJson.devDependencies;
      await writeFile("package.json", `''${JSON.stringify(packageJson, null, 2)}\n`);
    '

    substituteInPlace npm-shrinkwrap.json \
      --replace-fail \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-agent-core/-/pi-agent-core-0.80.7.tgz",' \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-agent-core/-/pi-agent-core-0.80.7.tgz",
        "integrity": "sha512-EFjyAuoz2kn24sR9Q5A86sZCG6mD+nz58DCsA2I2wxgmS50cF1tSLCBOZaHKI5U9Y3pJs4BefeK3LRkB5TdJag==",' \
      --replace-fail \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-0.80.7.tgz",' \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-0.80.7.tgz",
        "integrity": "sha512-8RLKLwe5TFM9kKFMNu/lTzveduq4GxZbnlG6ba8FAhLeb5wJP4zbj1eBumKBRvggpFQnW5R/Vo2a8zTlHsV9SQ==",' \
      --replace-fail \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-tui/-/pi-tui-0.80.7.tgz",' \
        '"resolved": "https://registry.npmjs.org/@earendil-works/pi-tui/-/pi-tui-0.80.7.tgz",
        "integrity": "sha512-1B2++fLZfgI3XMzW2BTpuDuam2uyHnUUEmsOvi5R0Ne9RAt59WjFV0G8ozX6l1Xafa9P5Y3eT4aDtRr/v/CUTA==",'
  '';

  meta = {
    description = "Minimal terminal coding harness";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
  };
}
