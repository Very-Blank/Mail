{
  description = "Dev flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixnvim = {
      url = "github:Very-Blank/NixNvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nmux = {
      url = "github:Very-Blank/Nmux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, ...} @ inputs: let
    system = "x86_64-linux";
  in {
    devShells."${system}".default = let
      pkgs = import nixpkgs {inherit system;};

      tmux = inputs.nmux.mkPackage {
        system = system;

        extraModule = {...}: {
          config.nmux = {
            name = "Mail";
            shell = "${pkgs.lib.getExe pkgs.zsh}";
            extraConfig = ''
              set-hook -g session-created 'send-keys "nvim" enter ; new-window ; select-window -t 0'
            '';
          };
        };
      };
    in
      pkgs.mkShell
      {
        packages = [
          pkgs.zig_0_17

          (
            inputs.nixnvim.mkPackage {
              system = system;
              extraModule = {...}: {
                config = {
                  vim = {
                    languages = {
                      zig = {
                        enable = true;
                        lsp.enable = true;
                        treesitter.enable = true;
                      };
                    };

                    lsp.servers.zls = pkgs.lib.mkForce {
                      filetypes = ["zig"];
                      cmd = pkgs.lib.mkForce [
                        "${pkgs.lib.getExe pkgs.zigscient}"
                      ];
                    };
                  };
                };
              };
            }
          )
        ];

        shellHook = ''
          ${pkgs.lib.getExe' tmux "tmux"}
          exit
        '';
      };
  };
}
