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
