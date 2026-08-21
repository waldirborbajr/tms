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

	if name == "" {
		TmuxDisplay("No session name provided and default is empty")
		return fmt.Errorf("session name required")
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
		// Interactive switch mode
		p := tea.NewProgram(NewSwitchModel())
		if _, err := p.Run(); err != nil {
			fmt.Printf("Error: %v\n", err)
		}
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

// -----

type SaveCmd struct {
	Name string `arg:"" help:"Saved session name"`
	Dir  string `arg:"" optional:"" help:"Optional directory to restore into"`
}

func (c SaveCmd) Run() error {
	cfg := GetConfig()
	dir := c.Dir
	if dir == "" {
		dir = cfg.DefaultDirectory
	}

	if err := SaveSession(c.Name, dir); err != nil {
		TmuxDisplay("Failed to save session")
		return err
	}

	TmuxDisplay(fmt.Sprintf("Saved session definition: %s", c.Name))
	return nil
}

// -----

type RestoreCmd struct {
	Name string `arg:"" help:"Saved session name"`
}

func (c RestoreCmd) Run() error {
	if err := RestoreSession(c.Name); err != nil {
		TmuxDisplay("Failed to restore session")
		return err
	}

	TmuxDisplay(fmt.Sprintf("Restored session: %s", c.Name))
	return nil
}

// -----

type SavedCmd struct{}

func (c SavedCmd) Run() error {
	saved, err := ListSavedSessions()
	if err != nil {
		return err
	}

	if len(saved) == 0 {
		fmt.Print("No saved sessions found.\n")
		return nil
	}

	for _, name := range saved {
		fmt.Println(name)
	}
	return nil
}

// ========== IMPORTAÇÃO E EXPORTAÇÃO (Prioridade 4) ==========

// ImportSessionCmd importa uma sessão de tmuxinator/tmuxp
type ImportSessionCmd struct {
	Path    string `arg:"" help:"Caminho do arquivo a importar"`
	Format  string `help:"Formato: tmuxinator ou tmuxp" enum:"auto,tmuxinator,tmuxp" default:"auto"`
}

func (i *ImportSessionCmd) Run() error {
	format := i.Format
	if format == "auto" {
		if strings.HasSuffix(i.Path, ".json") {
			format = "tmuxp"
		} else {
			format = "tmuxinator"
		}
	}

	switch format {
	case "tmuxinator":
		return ImportTmuxinator(i.Path)
	case "tmuxp":
		return ImportTmuxp(i.Path)
	default:
		return fmt.Errorf("formato não suportado: %s", format)
	}
}

// ExportSessionCmd exporta uma sessão para tmuxinator/tmuxp
type ExportSessionCmd struct {
	Name    string `arg:"" help:"Nome da sessão a exportar"`
	Format  string `help:"Formato: tmuxinator ou tmuxp" enum:"tmuxinator,tmuxp" default:"tmuxinator"`
	Output  string `help:"Caminho de saída (opcional)"`
}

func (e *ExportSessionCmd) Run() error {
	output := e.Output
	if output == "" {
		ext := ".tmuxinator.yml"
		if e.Format == "tmuxp" {
			ext = ".tmuxp.json"
		}
		output = e.Name + ext
	}

	switch e.Format {
	case "tmuxinator":
		return ExportTmuxinator(e.Name, output)
	case "tmuxp":
		return ExportTmuxp(e.Name, output)
	default:
		return fmt.Errorf("formato não suportado: %s", e.Format)
	}
}

// ListImportableCmd lista arquivos importáveis
type ListImportableCmd struct{}

func (l *ListImportableCmd) Run() error {
	files, err := ListImportable()
	if err != nil {
		return err
	}
	if len(files) == 0 {
		fmt.Println("Nenhum arquivo importável encontrado.")
		return nil
	}
	fmt.Println("📋 Arquivos encontrados:")
	for _, f := range files {
		fmt.Printf("  %s\n", f)
	}
	return nil
}
