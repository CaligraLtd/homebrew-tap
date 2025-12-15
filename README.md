# Caligra Workbench Homebrew Tap

A custom Homebrew tap for Caligra Workbench, providing casks for Linux applications.

## Installation

First, tap this repository:

```bash
brew tap CaligraLtd/caligra-tap
```

## Available Casks

```bash
brew install --cask google-chrome-linux

## the following casks originate from https://github.com/ublue-os/homebrew-experimental-tap & https://github.com/ublue-os/homebrew-tap
brew install --cask 1password-gui-linux
brew install --cask cursor-linux
brew install --cask framework-tool-linux
brew install --cask visual-studio-code-linux
```

## Development

To test casks locally before pushing:

```bash
brew install --cask ./Casks/cask-name.rb
```

To audit a cask:

```bash
brew audit --strict --online --cask cask-name
```

## Contributing

Contributions are welcome! Please ensure formulas follow Homebrew style guidelines.
