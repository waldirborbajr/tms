package main

// ====================== CLI Structure ======================
// This file defines the CLI command hierarchy for the application.
// Uses github.com/alecthomas/kong for argument parsing.

type CLI struct {
	New     NewCmd     `cmd:"" help:"Create a new session"`
	Switch  SwitchCmd  `cmd:"" aliases:"s" help:"Switch to a session"`
	Kill    KillCmd    `cmd:"" aliases:"k" help:"Kill a session"`
	Rename  RenameCmd  `cmd:"" aliases:"r" help:"Rename a session"`
	List    ListCmd    `cmd:"" help:"List active sessions"`
	Version VersionCmd `cmd:"" help:"Show version"`
	Config  ConfigCmd  `cmd:"" help:"Show current configuration"`
}
