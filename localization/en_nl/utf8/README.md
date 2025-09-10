# en_c - Globally Neutral Computer English Locale Module

## Purpose

This module provides an English localization configuration for the Netherlands locale, based on the UTF-8 charset.

## Key Features

- **Universal Compatibility**: Uses UTF-8 locale throughout for maximum system compatibility
- **Minimal Local Configuration**: Sets minimal region-specific formatting and conventions
- **UTF-8 Character Set**: Consistent UTF-8 encoding for all locale categories
- **Amsterdam Timezone**: Defaults to Amsterdam timezone for locally specific time handling

## Module Structure

The module defines two main configuration areas:

### Time Configuration
- `time.offsetHardwareClock`: Boolean option to offset hardware clock to local timezone (default: false)
- Sets timezone to Amsterdam by default

### Internationalization Configuration
- `i18n.defaultLocaleShortlist`: Enum option for default locale
- `i18n.defaultCharsetShortlist`: Enum option for default charset
- Configures all LC_* categories to use en_IE.UTF-8 or nl_NL.UTF8
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
        nixos-common.nixosModules.localization-en_nl_utf8
        # Your other configuration modules
      ];
    };
  };
}
```

## Use Cases

This module is ideal for:
- Desktop environments requiring some localization, but retain UTF8 charsets
- Development environments with international teams, based in the Netherlands
- Systems that need minimal locale compatibility, with some internationalization
- Containerized applications requiring standardized environments, with locale NL
- Any scenario where more region-specific locale settings would be complicated

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
- `LC_PAPER`: Paper size for printing
- `LC_TELEPHONE`: Telephone number formatting
- `LC_TIME`: Time and date formatting