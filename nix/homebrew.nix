# macOS user tools. Nix retains configuration and activation dependencies.
{
  taps = [
    {
      name = "hashicorp/tap";
      trusted = true;
    }
  ];
  brews = [
    "bat"
    "bind"
    "btop"
    "curl"
    "direnv"
    "fzf"
    "gh"
    "git"
    "git-lfs"
    "gnupg"
    "herdr"
    "jq"
    "kubernetes-cli"
    "lazygit"
    "make"
    "mas"
    "neovim"
    "node"
    "opencode"
    "pi-coding-agent"
    "pre-commit"
    "python@3.14"
    "ripgrep"
    "shellcheck"
    "shfmt"
    "socat"
    "starship"
    "tmux"
    "tree"
    "unzip"
    "uv"
    "wget"
    "zoxide"
    "zsh"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "hashicorp/tap/terraform"
  ];
  casks = [
    "claude-code"
    "codex"
    "font-hack-nerd-font"
  ];
}
