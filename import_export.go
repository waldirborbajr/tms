package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
)

// Estruturas para tmuxinator
type TmuxinatorConfig struct {
	Name     string            `toml:"name"`
	Root     string            `toml:"root"`
	Windows  []TmuxinatorWindow `toml:"windows"`
	Options  map[string]string `toml:"options"`
	Pre      string            `toml:"pre"`
	PreWindow string           `toml:"pre_window"`
}

type TmuxinatorWindow struct {
	Name     string   `toml:"name"`
	Panes    []string `toml:"panes"`
	Layout   string   `toml:"layout,omitempty"`
	Commands []string `toml:"commands,omitempty"`
}

// Estruturas para tmuxp
type TmuxpConfig struct {
	Name          string                 `json:"session_name"`
	StartDirectory string                `json:"start_directory"`
	Windows       []TmuxpWindow          `json:"windows"`
	GlobalOptions map[string]interface{} `json:"global_options"`
}

type TmuxpWindow struct {
	Name     string   `json:"window_name"`
	Panes    []string `json:"panes"`
	Layout   string   `json:"layout,omitempty"`
	Commands []string `json:"commands,omitempty"`
	Options  map[string]interface{} `json:"options,omitempty"`
}

// Importar do tmuxinator
func ImportTmuxinator(path string) error {
	var config TmuxinatorConfig

	if _, err := toml.DecodeFile(path, &config); err != nil {
		return fmt.Errorf("erro ao ler tmuxinator config: %w", err)
	}

	if config.Name == "" {
		return fmt.Errorf("nome da sessão não encontrado no arquivo")
	}

	sessionsDir := getSessionsDir()
	if err := os.MkdirAll(sessionsDir, 0755); err != nil {
		return fmt.Errorf("erro ao criar diretório: %w", err)
	}

	session := SessionDefinition{
		Name:        config.Name,
		Directory:   config.Root,
		Windows:     []WindowDefinition{},
		PreCommands: []string{},
	}

	if config.Pre != "" {
		session.PreCommands = append(session.PreCommands, config.Pre)
	}
	if config.PreWindow != "" {
		session.PreCommands = append(session.PreCommands, config.PreWindow)
	}

	for _, win := range config.Windows {
		window := WindowDefinition{
			Name:      win.Name,
			Layout:    win.Layout,
			Panes:     []PaneDefinition{},
			Commands:  win.Commands,
		}

		for _, paneCmd := range win.Panes {
			window.Panes = append(window.Panes, PaneDefinition{
				Command: paneCmd,
			})
		}

		if len(window.Panes) == 0 {
			window.Panes = append(window.Panes, PaneDefinition{
				Command: "bash",
			})
		}

		session.Windows = append(session.Windows, window)
	}

	sessionFile := filepath.Join(sessionsDir, config.Name+".toml")
	if err := saveSessionDefinition(sessionFile, session); err != nil {
		return fmt.Errorf("erro ao salvar sessão: %w", err)
	}

	fmt.Printf("✅ Sessão '%s' importada do tmuxinator com sucesso!\n", config.Name)
	return nil
}

// Importar do tmuxp
func ImportTmuxp(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("erro ao ler arquivo: %w", err)
	}

	var config TmuxpConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return fmt.Errorf("erro ao parsear JSON: %w", err)
	}

	if config.Name == "" {
		return fmt.Errorf("nome da sessão não encontrado")
	}

	sessionsDir := getSessionsDir()
	if err := os.MkdirAll(sessionsDir, 0755); err != nil {
		return fmt.Errorf("erro ao criar diretório: %w", err)
	}

	session := SessionDefinition{
		Name:      config.Name,
		Directory: config.StartDirectory,
		Windows:   []WindowDefinition{},
	}

	for _, win := range config.Windows {
		window := WindowDefinition{
			Name:   win.Name,
			Layout: win.Layout,
			Panes:  []PaneDefinition{},
		}

		for _, paneCmd := range win.Panes {
			window.Panes = append(window.Panes, PaneDefinition{
				Command: paneCmd,
			})
		}

		if len(window.Panes) == 0 {
			window.Panes = append(window.Panes, PaneDefinition{
				Command: "bash",
			})
		}

		session.Windows = append(session.Windows, window)
	}

	sessionFile := filepath.Join(sessionsDir, config.Name+".toml")
	if err := saveSessionDefinition(sessionFile, session); err != nil {
		return fmt.Errorf("erro ao salvar sessão: %w", err)
	}

	fmt.Printf("✅ Sessão '%s' importada do tmuxp com sucesso!\n", config.Name)
	return nil
}

// Exportar para tmuxinator
func ExportTmuxinator(name string, outputPath string) error {
	session, err := loadSessionDefinition(name)
	if err != nil {
		return fmt.Errorf("erro ao carregar sessão: %w", err)
	}

	config := TmuxinatorConfig{
		Name: session.Name,
		Root: session.Directory,
	}

	for _, win := range session.Windows {
		window := TmuxinatorWindow{
			Name:  win.Name,
			Layout: win.Layout,
		}

		if len(win.Panes) > 0 {
			window.Panes = make([]string, len(win.Panes))
			for i, pane := range win.Panes {
				window.Panes[i] = pane.Command
			}
		} else {
			window.Panes = []string{"bash"}
		}

		config.Windows = append(config.Windows, window)
	}

	f, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("erro ao criar arquivo: %w", err)
	}
	defer f.Close()

	encoder := toml.NewEncoder(f)
	if err := encoder.Encode(config); err != nil {
		return fmt.Errorf("erro ao codificar TOML: %w", err)
	}

	fmt.Printf("✅ Sessão '%s' exportada para tmuxinator: %s\n", name, outputPath)
	return nil
}

// Exportar para tmuxp
func ExportTmuxp(name string, outputPath string) error {
	session, err := loadSessionDefinition(name)
	if err != nil {
		return fmt.Errorf("erro ao carregar sessão: %w", err)
	}

	config := TmuxpConfig{
		Name:           session.Name,
		StartDirectory: session.Directory,
	}

	for _, win := range session.Windows {
		window := TmuxpWindow{
			Name:  win.Name,
			Layout: win.Layout,
		}

		if len(win.Panes) > 0 {
			window.Panes = make([]string, len(win.Panes))
			for i, pane := range win.Panes {
				window.Panes[i] = pane.Command
			}
		} else {
			window.Panes = []string{"bash"}
		}

		config.Windows = append(config.Windows, window)
	}

	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("erro ao codificar JSON: %w", err)
	}

	if err := os.WriteFile(outputPath, data, 0644); err != nil {
		return fmt.Errorf("erro ao escrever arquivo: %w", err)
	}

	fmt.Printf("✅ Sessão '%s' exportada para tmuxp: %s\n", name, outputPath)
	return nil
}

// Listar arquivos importáveis
func ListImportable() ([]string, error) {
	patterns := []string{
		"*.tmuxinator.yml",
		"*.tmuxinator.yaml",
		"*.tmuxp.json",
		".tmuxinator.yml",
		".tmuxinator.yaml",
		".tmuxp.json",
	}

	var found []string
	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err == nil {
			found = append(found, matches...)
		}
	}

	home, err := os.UserHomeDir()
	if err == nil {
		tmuxinatorDir := filepath.Join(home, ".tmuxinator")
		if files, err := os.ReadDir(tmuxinatorDir); err == nil {
			for _, file := range files {
				if strings.HasSuffix(file.Name(), ".yml") || strings.HasSuffix(file.Name(), ".yaml") {
					found = append(found, filepath.Join(tmuxinatorDir, file.Name()))
				}
			}
		}
	}

	if err == nil {
		tmuxpDir := filepath.Join(home, ".tmuxp")
		if files, err := os.ReadDir(tmuxpDir); err == nil {
			for _, file := range files {
				if strings.HasSuffix(file.Name(), ".json") {
					found = append(found, filepath.Join(tmuxpDir, file.Name()))
				}
			}
		}
	}

	return found, nil
}
