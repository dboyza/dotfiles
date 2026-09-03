{
  bubblewrap,
  fetchurl,
  installShellFiles,
  lib,
  makeBinaryWrapper,
  ripgrep,
  stdenv,
}:
let
  version = "0.153.0";

  releases = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      codexHash = "sha256-jN7NC46+I/IOs3MBD9kelReXfoQLaJQe9qZGtAnLMuE=";
      codeModeHostHash = "sha256-hf2wRhY26dWAb6IAtPAApc0odFbzZvavR5ekwy1dUOk=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      codexHash = "sha256-ZoMJx9fMHr7l+bRIVzn5L9VVawgFvZ9Jo0eTArX2itw=";
      codeModeHostHash = "sha256-yYSVZkPTkgeiMmGASzqJP4WjpSuSgJS43xMZBcQnL/w=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      codexHash = "sha256-zCwMNl1NUcGBY7upPM5bkig2kAyoZ/W8+JsOcUqVKlM=";
      codeModeHostHash = "sha256-Jp1gBvtVyV+HZFT8A+03VcNnwcN2t3qYXQApOVpadzY=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      codexHash = "sha256-NagsFT2DlZ3gnCy4SscLpp0FeIrusI1Klcpo45+GaA4=";
      codeModeHostHash = "sha256-K4F6SV41pTMz6Us1r57YeeGA+bKP1X7xWs6ahXuobyw=";
    };
  };

  release =
    releases.${stdenv.hostPlatform.system}
      or (throw "Unsupported Codex platform: ${stdenv.hostPlatform.system}");
  releaseBase = "https://github.com/openai/codex/releases/download/rust-v${version}";

  codexArchive = fetchurl {
    url = "${releaseBase}/codex-${release.target}.tar.gz";
    hash = release.codexHash;
  };

  codeModeHostArchive = fetchurl {
    url = "${releaseBase}/codex-code-mode-host-${release.target}.tar.gz";
    hash = release.codeModeHostHash;
  };
in
stdenv.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    tar -xzf ${codexArchive} -C "$out/bin"
    tar -xzf ${codeModeHostArchive} -C "$out/bin"
    mv "$out/bin/codex-${release.target}" "$out/bin/codex"
    mv "$out/bin/codex-code-mode-host-${release.target}" "$out/bin/codex-code-mode-host"
    chmod +x "$out/bin/codex" "$out/bin/codex-code-mode-host"

    runHook postInstall
  '';

  postInstall = ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  postFixup = ''
    wrapProgram "$out/bin/codex" --prefix PATH : ${
      lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ])
    }
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/codex" --version | grep -F "codex-cli ${version}"
  '';

  meta = {
    description = "OpenAI coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = builtins.attrNames releases;
  };
}
