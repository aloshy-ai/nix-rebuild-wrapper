{
  description = "Wrapper module for seamless Nix flake rebuilds";

  inputs = {
    # Only for testing - not required by the module itself
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, ... }@inputs:
    let
      # Core module implementation - platform independent
      makeModule = { platformName, packageOption }:
        { config, lib, pkgs, ... }@moduleArgs:
        with lib;
        let
          cfg = config.system.rebuildWrapper;
          
          # Safely get flake parameter if passed in specialArgs
          selfFlake = moduleArgs.self or null;
          
          # Command name based on platform
          rebuildCommand = 
            if platformName == "nixos" then "nixos-rebuild"
            else if platformName == "darwin" then "darwin-rebuild"
            else if platformName == "nix-on-droid" then "nix-on-droid"
            else throw "Unsupported platform: ${platformName}";
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
            # Add warning if no flake reference provided
            warnings = mkIf (cfg.flake == null && cfg.flakePath == "") [
              "rebuildWrapper: you must set either flake or flakePath for the wrapper to work correctly"
            ];
            
            # Handle different package installation methods
            ${packageOption} = [
              (pkgs.writeShellScriptBin cfg.wrapperName ''
                #!/usr/bin/env bash
                
                # Determine flake path
                FLAKE_PATH="${if cfg.flake != null then toString cfg.flake.outPath else cfg.flakePath}"
                
                if [ -z "$FLAKE_PATH" ]; then
                  echo "Error: No flake path specified. Please set system.rebuildWrapper.flake or system.rebuildWrapper.flakePath." >&2
                  exit 1
                fi
                
                # Execute the rebuild command
                exec /run/current-system/sw/bin/${rebuildCommand} "$@" --flake "$FLAKE_PATH"#${cfg.hostname}
              '')
            ];
          };
        };
    in {
      # Export modules for different platforms with the correct package option
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
        packageOption = "home.packages";
      };
      
      # Doc string to help users
      meta.description = ''
        A module to create wrapper commands for rebuild operations (nixos-rebuild, darwin-rebuild, nix-on-droid)
        that automatically add the --flake flag.
        
        To use this module effectively:
        1. Import it in your configuration
        2. Pass the 'self' flake reference via specialArgs: specialArgs = { self = self; };
        3. Enable the module: system.rebuildWrapper.enable = true;
        
        If you can't pass 'self' via specialArgs, you can manually set the flake path:
        system.rebuildWrapper.flakePath = "/path/to/your/flake";
      '';
    };
}