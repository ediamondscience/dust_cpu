{
  description = "A flake for working with Fusion 360";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = { self, nixpkgs }:
	let pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
    in {
      devShells.${pkgs.system}.default = 
      pkgs.mkShell {
        buildInputs = with pkgs; [
          python312Full
          python312Packages.edalize
	  vscode-fhs
	  ghdl
	  yosys-ghdl
        ];

      shellHook = ''
        echo "Entering dust_cpu Development Environment..."
        code ./
        '';
      };
    };
  }
