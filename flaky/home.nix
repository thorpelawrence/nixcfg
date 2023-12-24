
{ pkgs, ... }: {
  home.stateVersion = "23.11";
  programs.neovim = {
    enable = true;
    vimAlias = true;
    defaultEditor = true;
    plugins = with pkgs; [
      vimPlugins.vim-nix
      vimPlugins.vim-commentary
    ];
    extraConfig = ''
      set list
      set lcs+=space:·
    '';
  };
  programs.fish = {
    enable = true;
  };
}
