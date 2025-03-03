# nix-rebuild-wrapper

[![FlakeHub](https://img.shields.io/badge/FlakeHub-nix--rebuild--wrapper-blue)](https://flakehub.com/flake/aloshy-ai/nix-rebuild-wrapper)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/aloshy-ai/nix-rebuild-wrapper)](https://github.com/aloshy-ai/nix-rebuild-wrapper/releases)
[![GitHub license](https://img.shields.io/github/license/aloshy-ai/nix-rebuild-wrapper)](https://github.com/aloshy-ai/nix-rebuild-wrapper/blob/main/LICENSE)
[![CI](https://github.com/aloshy-ai/nix-rebuild-wrapper/actions/workflows/ci.yml/badge.svg)](https://github.com/aloshy-ai/nix-rebuild-wrapper/actions/workflows/ci.yml)

A cross-platform Nix module that creates wrapper commands for `nixos-rebuild`, `darwin-rebuild`, and `nix-on-droid` with automatic flake path detection, eliminating the need to repeatedly specify `--flake` flags.

## Problem

When using Nix flakes, you need to specify the `--flake` flag with every rebuild command:

```bash
# Traditional approach requires the full path and hostname each time
nixos-rebuild switch --flake /path/to/config#hostname
darwin-rebuild switch --flake /path/to/config#hostname
nix-on-droid switch --flake /path/to/config#hostname
```

This becomes tedious, especially when you frequently update your configuration.

## Solution

This module creates a wrapper command that automatically adds the `--flake` flag with the correct path and hostname:

```bash
# After installing this module, you can simply run:
nixos-rebuild switch
darwin-rebuild switch
nix-on-droid switch
```

The module handles all the complexities of path resolution, hostname, and platform detection for you.

## Features

- **Cross-platform support**: Works on NixOS, nix-darwin, and nix-on-droid
- **Automatic platform detection**: Creates the appropriate wrapper for your system
- **Nixpkgs version agnostic**: Works with any nixpkgs version
- **Flexible configuration**: Customize wrapper name, command path, and more
- **Self-reference support**: Automatically detects and uses the current flake

## Installation

1. Add to your flake inputs:

```nix
{
  inputs = {
    # Your other inputs...
    rebuild-wrapper.url = "github:aloshy-ai/nix-rebuild-wrapper";
    # For a specific version:
    # rebuild-wrapper.url = "github:aloshy-ai/nix-rebuild-wrapper/v0.1.0";
    # Or via FlakeHub:
    # rebuild-wrapper.url = "flakehub:aloshy-ai/nix-rebuild-wrapper/0.1.0";
  };
}
```

2. Import the module and enable the wrapper:

```nix
# NixOS configuration
{
  imports = [ rebuild-wrapper.nixosModules.default ];
  
  # Pass the flake reference in specialArgs
  specialArgs.hostFlake = self;
  
  # Enable and configure
  system.rebuildWrapper = {
    enable = true;
    hostname = "default";  # The hostname in your flake configuration
  };
}
```

```nix
# nix-darwin configuration
{
  imports = [ rebuild-wrapper.darwinModules.default ];
  
  # Pass the flake reference in specialArgs
  specialArgs.hostFlake = self;
  
  # Enable and configure
  system.rebuildWrapper = {
    enable = true;
    hostname = "default";  # The hostname in your flake configuration
  };
}
```

```nix
# nix-on-droid configuration
{
  imports = [ rebuild-wrapper.nixOnDroidModules.default ];
  
  # Pass the flake reference in specialArgs
  specialArgs.hostFlake = self;
  
  # Enable and configure
  system.rebuildWrapper = {
    enable = true;
    hostname = "default";  # The hostname in your flake configuration
  };
}
```

## Configuration Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `enable` | Enable the wrapper | `false` | `true` |
| `flake` | Reference to the flake | `hostFlake` | `self` |
| `flakePath` | Path to the flake if reference not available | `flake.outPath` | `"/home/user/config"` |
| `hostname` | Hostname/identifier for the configuration | `"default"` | `"laptop"` |
| `wrapperName` | Name for the wrapper command | Platform specific | `"rebuild"` |
| `commandPath` | Path to the rebuild command | Auto-detected | `"/run/current-system/sw/bin/nixos-rebuild"` |

## Advanced Usage

### Custom command name

```nix
system.rebuildWrapper = {
  enable = true;
  wrapperName = "rebuild";  # Create a custom command name
};
```

### Multiple configurations

```nix
system.rebuildWrapper = {
  enable = true;
  hostname = "laptop";  # Specific configuration name
};
```

### Custom command path

```nix
system.rebuildWrapper = {
  enable = true;
  commandPath = "/path/to/custom/nixos-rebuild";
};
```

## How it works

The module:

1. Detects your platform (NixOS, nix-darwin, or nix-on-droid)
2. Identifies the appropriate rebuild command
3. Creates a wrapper script that automatically adds the `--flake` argument
4. Adds the wrapper to your system packages

## Compatibility

- **NixOS**: All versions with flakes support
- **nix-darwin**: All versions with flakes support
- **nix-on-droid**: All versions with flakes support

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
