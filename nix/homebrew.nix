# Declare install-only macOS command-line packages and the terminal font.
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
    "jq"
    "kubernetes-cli"
    "lazygit"
    "make"
    "mas"
    "neovim"
    "node"
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
    "font-hack-nerd-font"
  ];
}
