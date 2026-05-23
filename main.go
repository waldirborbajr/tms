package main

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/alecthomas/kong"
)

// ==================== Build Information ====================
// These are set at build time via ldflags
var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildTime = "unknown"
)

func main() {
	LoadConfig()

	// If arguments provided, run CLI mode
	if len(os.Args) > 1 {
		runCLI()
		return
	}

	// Otherwise, run interactive TUI mode
	runInteractive()
}

// runCLI executes CLI commands
func runCLI() {
	var cli CLI
	ctx := kong.Parse(&cli,
		kong.Name("tms"),
		kong.Description("Simple Tmux Session Manager"),
		kong.UsageOnError(),
		kong.ConfigureHelp(kong.HelpOptions{Compact: true}),
	)

	if err := ctx.Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}

// runInteractive starts the TUI interactive menu
func runInteractive() {
	p := tea.NewProgram(NewMenuModel())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
	}
}
