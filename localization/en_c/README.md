# en_c - Globally Neutral Computer English Locale Module

## Purpose

This module provides a globally neutral computer English localization configuration based on the C.UTF-8 locale. It is designed to offer maximum universal compatibility across different systems and regions while maintaining a clean, standardized English computing environment.

## Key Features

- **Universal Compatibility**: Uses C.UTF-8 locale throughout for maximum system compatibility
- **Neutral Configuration**: Avoids region-specific formatting and conventions
- **UTF-8 Character Set**: Consistent UTF-8 encoding for all locale categories
- **UTC Timezone**: Defaults to UTC for globally neutral time handling

## Module Structure

The module defines two main configuration areas:

### Time Configuration
- `time.offsetHardwareClock`: Boolean option to offset hardware clock to local timezone (default: false)
- Sets timezone to UTC for global neutrality

### Internationalization Configuration
- `i18n.defaultLocaleShortlist`: Enum option for default locale (only C.UTF-8 available)
- `i18n.defaultCharsetShortlist`: Enum option for default charset (only UTF-8 available)
- Configures all LC_* categories to use C.UTF-8
- Sets all charset configurations to UTF-8

## Implementation in Flakes

To use this module in your NixOS flake configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-common.url = "github:thecloudexplorers/nixos-common";
  };

  outputs = { self, nixpkgs, nixos-common }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-common.nixosModules.localization-en_c
        # Your other configuration modules
      ];
    };
  };
}
```

## Use Cases

This module is ideal for:
- Server environments requiring neutral localization
- Development environments with international teams
- Systems that need maximum locale compatibility
- Containerized applications requiring standardized environments
- Any scenario where region-specific locale settings would be inappropriate

## Locale Categories

All locale categories are set to C.UTF-8:
- `LC_ADDRESS`: Address formatting
- `LC_COLLATE`: String collation and sorting
- `LC_CTYPE`: Character classification and case conversion
- `LC_IDENTIFICATION`: Locale identification
- `LC_MEASUREMENT`: Measurement units
- `LC_MESSAGES`: System messages language
- `LC_MONETARY`: Monetary formatting
- `LC_NAME`: Personal name formatting
- `LC_NUMERIC`: Numeric formatting
- `LC_PAPER`: Paper size
- `LC_TELEPHONE`: Telephone number formatting
- `LC_TIME`: Time and date formatting