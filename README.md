# TMS — Tmux Session Manager

A clean, fast, and modern tmux session manager written in Go.

[![Go Version](https://img.shields.io/badge/Go-1.19+-00ADD8?style=flat&logo=go)](https://golang.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Go Report Card](https://goreportcard.com/badge/github.com/waldirborbajr/tms)](https://goreportcard.com/report/github.com/waldirborbajr/tms)

## About

`tms` helps you create, switch, kill, rename, and manage tmux sessions with both a beautiful **TUI** (interactive menu) and a powerful **CLI**.

## Features

- ✨ **Interactive TUI** — Launch with no arguments for an intuitive menu (powered by Bubble Tea)
- 🎯 **CLI commands** — Full support for scripting and keybindings via Kong
- 📋 **Session management** — Create, switch, kill, rename, and list sessions
- 🗂️ **Session persistence** — Save and restore named session definitions
- ⚙️ **Configuration** — Persistent settings via `~/.config/tms/config.toml`
- 🚀 **Auto-switch** — Optionally switch to new sessions immediately
- 🎨 **Theming** — Customizable color schemes
- ⚡ **Fast & lightweight** — Single optimized Go binary, no runtime dependencies
- 🔍 **Interactive Search** — Press `/` in TUI to filter sessions/commands (NEW!)
- ⚡ **Smart Caching** — Session list caching for faster operations (NEW!)
- 🔄 **Import/Export** — Compatible with tmuxinator and tmuxp formats (NEW!)
- 🛡️ **Robust Parsing** — JSON-based tmux output parsing (NEW!)

## Installation

### From source (recommended)

    git clone https://github.com/waldirborbajr/tms.git
    cd tms
    just build          # Compile optimized binary
    just release-local  # Install to $GOPATH/bin

Or directly:

    go install github.com/waldirborbajr/tms@latest

### Requirements

- Go 1.19+
- tmux 2.1+

## Usage

### Interactive Mode (TUI)

    tms

Launch with no arguments to open the interactive menu. Navigate with arrow keys or vim keys (`j`/`k`), select with Enter, quit with `q`.

#### Interactive Search (TUI)

When in the TUI menu, press `/` to activate search/filter mode:

- Type to filter menu items
- `Enter` to select the highlighted item
- `Esc` to cancel and return to the full menu
- Arrow keys or `j`/`k` to navigate through filtered results

This is especially useful when you have many sessions or options.

### CLI Mode

    # Create a new session
    tms new [name]

    # Create and switch (respects auto_switch config)
    tms new work

    # Switch to existing session (launch interactive picker if no name given)
    tms switch [name]
    tms s [name]           # alias

    # Kill one or more sessions (interactive multi-select if no name given)
    tms kill [name]
    tms k [name]           # alias

    # Rename a session
    tms rename <old> <new>
    tms r <old> <new>      # alias

    # Save a session definition for restore
    tms save <name> [directory]

    # Restore a saved session definition
    tms restore <name>

    # List saved session definitions
    tms saved

    # List all active sessions
    tms list

    # Import session from tmuxinator/tmuxp (NEW!)
    tms import <file> [--format tmuxinator|tmuxp]

    # Export session to tmuxinator/tmuxp (NEW!)
    tms export <name> [--format tmuxinator|tmuxp] [--output <file>]

    # List importable files found (NEW!)
    tms list-importable

    # Show version info
    tms version

    # Show current configuration
    tms config

## Import/Export (NEW!)

`tms` can import and export session definitions from/to other popular tmux session managers:

### Import from tmuxinator

    tms import ~/.tmuxinator/project.yml
    tms import project.tmuxinator.yml --format tmuxinator

### Import from tmuxp

    tms import project.tmuxp.json
    tms import project.tmuxp.json --format tmuxp

### Export to tmuxinator

    tms export work --format tmuxinator
    tms export work --format tmuxinator --output ~/.tmuxinator/work.yml

### Export to tmuxp

    tms export work --format tmuxp
    tms export work --format tmuxp --output work.json

### List importable files

    tms list-importable

This will search for:
- `*.tmuxinator.yml`, `*.tmuxinator.yaml` in current directory and `~/.tmuxinator/`
- `*.tmuxp.json` in current directory and `~/.tmuxp/`

## Configuration

Configuration is stored at `~/.config/tms/config.toml`. Create it with:

    default_session = "main"
    default_directory = ""  # Optional: start sessions in this directory
    auto_switch = true      # Switch to new sessions immediately
    theme = "default"       # Built-in theme (extensible)

On first run, `tms` creates a default config file with these settings.

## tmux Keybindings

Add these to your `~/.tmux.conf` to integrate `tms`:

    # Open tms menu
    bind-key t run-shell "tms"

    # Create new session
    bind-key c run-shell "tms new"

    # Switch to session (interactive)
    bind-key s run-shell "tms switch"

    # Kill sessions (interactive multi-select)
    bind-key k run-shell "tms kill"

    # List sessions
    bind-key l run-shell "tms list"

    # Rename current session (requires manual input)
    bind-key r command-prompt -I "#S" -p "Rename: " \
      "run-shell 'tms rename \"#S\" \"%%\"'"

    # Import session (NEW!)
    bind-key I run-shell "tms import"

    # Export session (NEW!)
    bind-key E run-shell "tms export"

Then reload tmux:

    tmux source-file ~/.tmux.conf

## Building

### Quick Build

    just build          # Optimized binary (stripped, fast)
    just b              # Shorthand

### Build Variants

    just build-debug    # With debug symbols (larger)
    just build-static   # Fully static binary (no libc)
    just build-cross    # Multi-platform (Linux/macOS/Windows)

### Version Management

    just version-show            # Display current version
    just version-bump patch      # 1.2.3 → 1.2.4
    just version-bump minor      # 1.2.3 → 1.3.0
    just version-bump major      # 1.2.3 → 2.0.0

The version is embedded at build time via `-ldflags`.

## Development

### Project Structure

    tms/
    ├── main.go                 # Entry point, CLI setup
    ├── cli.go                  # Kong CLI definitions
    ├── commands.go             # CLI command implementations
    ├── config.go               # Configuration loading
    ├── tmux.go                 # Tmux command wrappers (with cache)
    ├── display.go              # Shared display renderers
    ├── menu_model.go           # Main menu (with filter support)
    ├── filter_model.go         # Interactive search/filter (NEW!)
    ├── cache.go                # Session caching (NEW!)
    ├── import_export.go        # tmuxinator/tmuxp integration (NEW!)
    ├── input_model.go          # Text input model
    ├── switch_model.go         # Session picker model
    ├── kill_model.go           # Multi-select kill model
    ├── information_model.go    # Read-only display model
    ├── styles.go               # Lipgloss style definitions
    ├── session.go              # Session definitions
    ├── justfile                # Build recipes
    └── VERSION                 # Current version

### Testing

    just test            # Run tests
    just test-coverage   # With coverage report

### Code Quality

    just fmt             # Format code
    just vet             # Run go vet
    just lint            # Run golangci-lint
    just check           # All checks (fmt-check, vet, lint, test)
    just pre-commit      # Pre-commit validation

### Git Workflow

    just pre-commit      # Before committing
    git add .
    git commit -m "feat: description"

## Architecture

### CLI vs TUI

- **CLI mode**: Direct commands, used in scripts and tmux keybindings
- **TUI mode**: Interactive menu, launched with `tms` or when interactive input is needed

Both share the same underlying tmux operations and configuration layer.

### Caching (NEW!)

`tms` uses a smart caching system for session lists:

- Sessions are cached for **2 seconds** (configurable)
- Cache is automatically invalidated after operations like `new`, `kill`, `rename`
- Reduces tmux calls in scripts and keybindings for faster response

### Error Handling

Errors are surfaced via:

- **TUI**: `TmuxDisplay()` messages shown in tmux status line
- **CLI**: Standard error output and exit codes
- **Startup**: `stderr` with fallback to defaults

### Models (Bubble Tea)

Each interactive screen is a model:

- `MenuModel` — Main menu (with filter integration)
- `FilterModel` — Interactive search/filter (NEW!)
- `InputModel` — Text input for session names
- `SwitchModel` — Interactive session picker
- `KillModel` — Multi-select kill interface
- `InformationModel` — Read-only display (version, config, list)

## Dependencies

- `github.com/charmbracelet/bubbletea` — TUI framework
- `github.com/charmbracelet/lipgloss` — Terminal styling
- `github.com/alecthomas/kong` — CLI argument parsing
- `github.com/BurntSushi/toml` — Configuration file parsing

All dependencies are vendored and managed by `go mod`.

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create a feature branch** (`git checkout -b feature/my-feature`)
3. **Make changes** following the code style
4. **Run `just check`** to validate code quality
5. **Write or update tests** as needed
6. **Submit a Pull Request** with a clear description

### Code Style

- Follow Go conventions and `gofmt`
- Receiver names match type initials: `k` for `KillModel`, `s` for `SwitchModel`, `t` for `TextInputModel`
- Keep error handling explicit; avoid silent failures
- Surgical changes only; don't refactor unrelated code

### Testing

Tests should verify:

- Model `Update()` logic with various `tea.KeyMsg` inputs
- Config loading and defaults
- Tmux command wrappers and error cases
- Cache invalidation logic (NEW!)
- Import/export functionality (NEW!)

## Changelog

### v1.1.0 (2026-08-21)

**New Features:**
- 🔍 Interactive search/filter in TUI (`/` key)
- ⚡ Smart session caching (TTL: 2s)
- 🔄 Import from tmuxinator and tmuxp
- 🔄 Export to tmuxinator and tmuxp
- 🛡️ JSON-based robust tmux parsing
- 📋 New commands: `import`, `export`, `list-importable`

**Improvements:**
- Better error handling in tmux operations
- Faster session listing in scripts

## License

MIT — See `LICENSE` file

## Credits

Built with:

- [Bubble Tea](https://github.com/charmbracelet/bubbletea) for TUI magic
- [Lipgloss](https://github.com/charmbracelet/lipgloss) for beautiful styling
- [Kong](https://github.com/alecthomas/kong) for effortless CLI parsing

Made with ❤️ for the terminal.

---

**Questions?** Open an issue or discussion on GitHub.
