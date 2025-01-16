{
  description = "A flake for working with Fusion 360";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = { self, nixpkgs }:
	  let
	  	system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = 
      pkgs.mkShell {
        buildInputs = with pkgs; [
          python312Full
          python312Packages.edalize
	        vscodium
	        ghdl
	        yosys-ghdl
        ];

      shellHook = ''
        echo "Entering dust_cpu Development Environment..."
        codium ./
        '';
      };
    };
  }
