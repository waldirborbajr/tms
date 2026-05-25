package main

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
)

// ====================== CLI Commands ======================

type ListCmd struct{}

func (c ListCmd) Run() error {
	fmt.Print(renderSessionList())
	return nil
}

// -----

type VersionCmd struct{}

func (c VersionCmd) Run() error {
	fmt.Print(renderVersion())
	return nil
}

// -----

type ConfigCmd struct{}

func (c ConfigCmd) Run() error {
	fmt.Print(renderConfig())
	return nil
}

// -----

type NewCmd struct {
	Name string `arg:"" optional:"" help:"Session name"`
}

func (c NewCmd) Run() error {
	name := c.Name
	cfg := GetConfig()
	if name == "" {
		name = cfg.DefaultSession
	}

	if err := CreateSession(name); err != nil {
		TmuxDisplay("Failed to create session")
		return err
	}

	if cfg.AutoSwitch {
		if err := SwitchSession(name); err != nil {
			TmuxDisplay(fmt.Sprintf("Created session '%s' but failed to switch: %v", name, err))
			return err
		}
	}

	TmuxDisplay("Created session: " + name)
	return nil
}

// -----

type SwitchCmd struct {
	Name string `arg:"" optional:"" help:"Session name"`
}

func (c SwitchCmd) Run() error {
	if c.Name == "" {
		fmt.Println("Usage: tms switch <name>")
		return nil
	}

	if err := SwitchSession(c.Name); err != nil {
		TmuxDisplay(fmt.Sprintf("Session '%s' not found", c.Name))
	} else {
		TmuxDisplay(fmt.Sprintf("Switched to: %s", c.Name))
	}
	return nil
}

// -----

type KillCmd struct {
	Name string `arg:"" optional:"" help:"Session name"`
}

func (c KillCmd) Run() error {
	if c.Name == "" {
		// Interactive kill mode
		p := tea.NewProgram(NewKillModel())
		if _, err := p.Run(); err != nil {
			fmt.Printf("Error: %v\n", err)
		}
		return nil
	}

	if err := KillSession(c.Name); err != nil {
		TmuxDisplay(fmt.Sprintf("Failed to kill '%s'", c.Name))
	} else {
		TmuxDisplay(fmt.Sprintf("Killed session: %s", c.Name))
	}
	return nil
}

// -----

type RenameCmd struct {
	Old string `arg:"" name:"old"`
	New string `arg:"" name:"new"`
}

func (c RenameCmd) Run() error {
	if err := RenameSession(c.Old, c.New); err != nil {
		TmuxDisplay("Failed to rename session")
	} else {
		TmuxDisplay(fmt.Sprintf("Renamed: %s → %s", c.Old, c.New))
	}
	return nil
}
