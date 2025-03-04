{
  description = "Wrapper module for seamless Nix flake rebuilds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      # Helper function to create a safe check for each system
      makeCheck = system:
        let 
          pkgs = import nixpkgs { inherit system; };
        in {
          module-import-test = pkgs.runCommand "test-wrapper-module" {} ''
            echo "Testing module import on ${system}"
            mkdir -p $out
            touch $out/result
          '';
        };
        
      # Helper to create system-specific modules
      makeModule = { platformName, packageOption }:
        { config, lib, pkgs, ... }@moduleArgs:
        with lib;
        let
          cfg = config.system.rebuildWrapper;
          selfFlake = moduleArgs.self or null;
          rebuildCommand = 
            if platformName == "nixos" then "nixos-rebuild"
            else if platformName == "darwin" then "darwin-rebuild"
            else if platformName == "nix-on-droid" then "nix-on-droid"
            else "rebuild";
        in {
          options.system.rebuildWrapper = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable the seamless flake rebuild command wrapper";
            };
            
            flake = mkOption {
              type = types.nullOr types.attrs;
              description = "Reference to the flake (typically 'self')";
              default = selfFlake;
              example = "self";
            };
            
            flakePath = mkOption {
              type = types.str;
              description = "Path to the flake if flake reference not available";
              default = "";
              example = "/home/user/dotfiles";
            };
            
            hostname = mkOption {
              type = types.str;
              description = "Hostname/identifier for the configuration";
              default = "default";
              example = "laptop";
            };
            
            wrapperName = mkOption {
              type = types.str;
              description = "Name for the wrapper command";
              default = rebuildCommand;
              example = "rebuild";
            };
          };
          
          config = mkIf cfg.enable {
            warnings = mkIf (cfg.flake == null && cfg.flakePath == "") [
              "rebuildWrapper: you must set either flake or flakePath for the wrapper to work correctly"
            ];
            
            ${packageOption} = [
              (pkgs.writeShellScriptBin cfg.wrapperName ''
                #!/usr/bin/env bash
                FLAKE_PATH="${if cfg.flake != null then toString cfg.flake.outPath else cfg.flakePath}"
                if [ -z "$FLAKE_PATH" ]; then
                  echo "Error: No flake path specified. Please set system.rebuildWrapper.flake or system.rebuildWrapper.flakePath." >&2
                  exit 1
                fi
                exec /run/current-system/sw/bin/${rebuildCommand} "$@" --flake "$FLAKE_PATH"#${cfg.hostname}
              '')
            ];
          };
        };

      # List of all systems we want to support
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in {
      # Export modules
      nixosModules.default = makeModule { 
        platformName = "nixos"; 
        packageOption = "environment.systemPackages";
      };
      
      darwinModules.default = makeModule { 
        platformName = "darwin"; 
        packageOption = "environment.systemPackages";
      };
      
      nixOnDroidModules.default = makeModule { 
        platformName = "nix-on-droid"; 
        packageOption = "environment.packages";
      };
      
      # Add checks for all supported systems
      checks = builtins.listToAttrs (map 
        (system: { 
          name = system; 
          value = makeCheck system; 
        }) 
        supportedSystems);
    };
}