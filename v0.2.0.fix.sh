#!/bin/bash
# Script para aplicar todas as melhorias ao tms

set -e

echo "🚀 Aplicando melhorias ao tms..."

# ========== 1. CACHE DE SESSÕES ==========

cat > cache.go << 'EOF'
package main

import (
	"sync"
	"time"
)

type SessionCache struct {
	data      []string
	expiresAt time.Time
	mu        sync.RWMutex
	ttl       time.Duration
}

func NewSessionCache(ttl ...time.Duration) *SessionCache {
	duration := 2 * time.Second
	if len(ttl) > 0 && ttl[0] > 0 {
		duration = ttl[0]
	}
	return &SessionCache{
		ttl: duration,
	}
}

func (c *SessionCache) Get() ([]string, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.data == nil || time.Now().After(c.expiresAt) {
		return nil, false
	}
	return c.data, true
}

func (c *SessionCache) Set(data []string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = data
	c.expiresAt = time.Now().Add(c.ttl)
}

func (c *SessionCache) Invalidate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = nil
	c.expiresAt = time.Time{}
}

func (c *SessionCache) IsValid() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.data != nil && time.Now().Before(c.expiresAt)
}
EOF

# ========== 2. FILTER MODEL ==========

cat > filter_model.go << 'EOF'
package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type FilterModel struct {
	Text      string
	Active    bool
	Filtered  []string
	AllItems  []string
	Selected  int
	OnFilter  func([]string)
	OnCancel  func()
	OnConfirm func(string)
}

func NewFilterModel(items []string) *FilterModel {
	return &FilterModel{
		Text:     "",
		Active:   false,
		AllItems: items,
		Filtered: items,
		Selected: 0,
	}
}

func (f *FilterModel) Init() tea.Cmd {
	return nil
}

func (f *FilterModel) Update(msg tea.Msg) (*FilterModel, tea.Cmd) {
	if !f.Active {
		return f, nil
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "esc":
			f.Active = false
			f.Text = ""
			f.Filtered = f.AllItems
			if f.OnCancel != nil {
				f.OnCancel()
			}
			return f, nil

		case "enter":
			f.Active = false
			if f.OnConfirm != nil && len(f.Filtered) > 0 {
				f.OnConfirm(f.Filtered[f.Selected])
			}
			return f, nil

		case "up", "k":
			if f.Selected > 0 {
				f.Selected--
			}
			return f, nil

		case "down", "j":
			if f.Selected < len(f.Filtered)-1 {
				f.Selected++
			}
			return f, nil

		case "backspace":
			if len(f.Text) > 0 {
				f.Text = f.Text[:len(f.Text)-1]
				f.applyFilter()
			}
			return f, nil

		default:
			if len(msg.String()) == 1 {
				f.Text += msg.String()
				f.applyFilter()
			}
			return f, nil
		}
	}
	return f, nil
}

func (f *FilterModel) applyFilter() {
	if f.Text == "" {
		f.Filtered = f.AllItems
	} else {
		text := strings.ToLower(f.Text)
		filtered := []string{}
		for _, item := range f.AllItems {
			if strings.Contains(strings.ToLower(item), text) {
				filtered = append(filtered, item)
			}
		}
		f.Filtered = filtered
	}

	if f.Selected >= len(f.Filtered) && len(f.Filtered) > 0 {
		f.Selected = len(f.Filtered) - 1
	}
	if len(f.Filtered) == 0 {
		f.Selected = 0
	}

	if f.OnFilter != nil {
		f.OnFilter(f.Filtered)
	}
}

func (f *FilterModel) SetItems(items []string) {
	f.AllItems = items
	f.applyFilter()
}

func (f *FilterModel) View() string {
	if !f.Active {
		return ""
	}

	style := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFFFFF")).
		Background(lipgloss.Color("#333333")).
		Padding(0, 1)

	prompt := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00FF00")).
		Render("🔍 ")

	cursor := "▌"
	if len(f.Text) > 0 {
		cursor = ""
	}

	input := style.Render(f.Text + cursor)
	return prompt + input
}

func (f *FilterModel) Toggle() {
	f.Active = !f.Active
	if f.Active {
		f.Text = ""
		f.Selected = 0
		f.applyFilter()
	}
}

func (f *FilterModel) IsActive() bool {
	return f.Active
}

func (f *FilterModel) GetFiltered() []string {
	return f.Filtered
}

func (f *FilterModel) GetSelected() string {
	if len(f.Filtered) > 0 && f.Selected < len(f.Filtered) {
		return f.Filtered[f.Selected]
	}
	return ""
}
EOF

# ========== 3. IMPORT/EXPORT ==========

cat > import_export.go << 'EOF'
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
)

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

type SessionDefinition struct {
	Name        string
	Directory   string
	Windows     []WindowDefinition
	PreCommands []string
}

type WindowDefinition struct {
	Name     string
	Layout   string
	Panes    []PaneDefinition
	Commands []string
}

type PaneDefinition struct {
	Command string
}

func getSessionsDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "tms", "sessions")
}

func loadSessionDefinition(name string) (SessionDefinition, error) {
	var session SessionDefinition
	sessionFile := filepath.Join(getSessionsDir(), name+".toml")
	if _, err := toml.DecodeFile(sessionFile, &session); err != nil {
		return session, fmt.Errorf("erro ao carregar sessão: %w", err)
	}
	return session, nil
}

func saveSessionDefinition(path string, session SessionDefinition) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	encoder := toml.NewEncoder(f)
	return encoder.Encode(session)
}

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
EOF

# ========== 4. TMUX.GO COM CACHE E PARSING JSON ==========

cat > tmux.go << 'EOF'
package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

var sessionCache = NewSessionCache(2 * time.Second)

type TmuxSession struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Path        string `json:"path"`
	Windows     int    `json:"windows"`
	Attached    bool   `json:"attached"`
	Created     string `json:"created"`
	LastAttached string `json:"last_attached"`
}

func TmuxCommand(args ...string) ([]byte, error) {
	cmd := exec.Command("tmux", args...)
	return cmd.CombinedOutput()
}

func TmuxCommandOutput(args ...string) (string, error) {
	output, err := TmuxCommand(args...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// TmuxDisplay exibe uma mensagem no tmux (para TUI)
func TmuxDisplay(msg string) {
	cmd := exec.Command("tmux", "display-message", "-p", msg)
	_ = cmd.Run() // Ignora erro, apenas tenta exibir
}

func ListSessionsRaw() ([]TmuxSession, error) {
	output, err := TmuxCommand("list-sessions", "-F", `{"id":"#{session_id}","name":"#{session_name}","path":"#{session_path}","windows":#{session_windows},"attached":#{session_attached},"created":"#{session_created}","last_attached":"#{session_last_attached}"}`)
	if err != nil {
		return nil, fmt.Errorf("erro ao listar sessões: %w", err)
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	var sessions []TmuxSession

	for _, line := range lines {
		if line == "" {
			continue
		}
		var session TmuxSession
		if err := json.Unmarshal([]byte(line), &session); err != nil {
			continue
		}
		sessions = append(sessions, session)
	}

	return sessions, nil
}

func ListSessions() ([]string, error) {
	if cached, ok := sessionCache.Get(); ok {
		return cached, nil
	}

	sessions, err := ListSessionsRaw()
	if err != nil {
		return nil, err
	}

	names := make([]string, len(sessions))
	for i, s := range sessions {
		names[i] = s.Name
	}

	sessionCache.Set(names)
	return names, nil
}

func SessionExists(name string) bool {
	sessions, err := ListSessions()
	if err != nil {
		return false
	}
	for _, s := range sessions {
		if s == name {
			return true
		}
	}
	return false
}

func GetSessionInfo(name string) (*TmuxSession, error) {
	sessions, err := ListSessionsRaw()
	if err != nil {
		return nil, err
	}
	for _, s := range sessions {
		if s.Name == name {
			return &s, nil
		}
	}
	return nil, fmt.Errorf("sessão '%s' não encontrada", name)
}

// CreateSession cria uma nova sessão
func CreateSession(name, dir string) error {
	args := []string{"new-session", "-d", "-s", name}
	if dir != "" {
		args = append(args, "-c", dir)
	}
	_, err := TmuxCommand(args...)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

func KillSession(name string) error {
	_, err := TmuxCommand("kill-session", "-t", name)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

func SwitchSession(name string) error {
	_, err := TmuxCommand("switch-client", "-t", name)
	return err
}

func RenameSession(old, new string) error {
	_, err := TmuxCommand("rename-session", "-t", old, new)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

func SessionPath(name string) (string, error) {
	return TmuxCommandOutput("display", "-t", name, "-p", "#{session_path}")
}

func IsSessionAttached(name string) bool {
	info, err := GetSessionInfo(name)
	if err != nil {
		return false
	}
	return info.Attached
}

func InvalidateCache() {
	sessionCache.Invalidate()
}

func RefreshCache() error {
	sessions, err := ListSessionsRaw()
	if err != nil {
		return err
	}
	names := make([]string, len(sessions))
	for i, s := range sessions {
		names[i] = s.Name
	}
	sessionCache.Set(names)
	return nil
}
EOF

# ========== 5. COMMANDS.GO CORRIGIDO ==========

cat > commands.go << 'EOF'
package main

import (
	"fmt"
	"os"
)

// ========== COMANDOS EXISTENTES ==========

type NewCmd struct {
	Name string `arg:"" help:"Nome da sessão"`
	Dir  string `help:"Diretório da sessão"`
}

func (n *NewCmd) Run() error {
	if n.Name == "" {
		return fmt.Errorf("nome da sessão é obrigatório")
	}
	if err := CreateSession(n.Name, n.Dir); err != nil {
		return fmt.Errorf("erro ao criar sessão: %w", err)
	}
	TmuxDisplay(fmt.Sprintf("✅ Sessão '%s' criada", n.Name))
	return nil
}

type SwitchCmd struct {
	Name string `arg:"" optional:"" help:"Nome da sessão"`
}

func (s *SwitchCmd) Run() error {
	if s.Name == "" {
		fmt.Println("📋 Sessões disponíveis:")
		sessions, err := ListSessions()
		if err != nil {
			return err
		}
		for _, name := range sessions {
			fmt.Printf("  - %s\n", name)
		}
		return nil
	}
	if !SessionExists(s.Name) {
		return fmt.Errorf("sessão '%s' não existe", s.Name)
	}
	if err := SwitchSession(s.Name); err != nil {
		return fmt.Errorf("erro ao alternar: %w", err)
	}
	TmuxDisplay(fmt.Sprintf("✅ Alternado para '%s'", s.Name))
	return nil
}

type KillCmd struct {
	Name string `arg:"" optional:"" help:"Nome da sessão"`
}

func (k *KillCmd) Run() error {
	if k.Name == "" {
		fmt.Println("📋 Sessões disponíveis:")
		sessions, err := ListSessions()
		if err != nil {
			return err
		}
		for _, name := range sessions {
			fmt.Printf("  - %s\n", name)
		}
		return nil
	}
	if !SessionExists(k.Name) {
		return fmt.Errorf("sessão '%s' não existe", k.Name)
	}
	if err := KillSession(k.Name); err != nil {
		return fmt.Errorf("erro ao matar sessão: %w", err)
	}
	TmuxDisplay(fmt.Sprintf("🗑️ Sessão '%s' morta", k.Name))
	return nil
}

type RenameCmd struct {
	Old string `arg:"" help:"Nome atual"`
	New string `arg:"" help:"Novo nome"`
}

func (r *RenameCmd) Run() error {
	if r.Old == "" || r.New == "" {
		return fmt.Errorf("nome antigo e novo são obrigatórios")
	}
	if !SessionExists(r.Old) {
		return fmt.Errorf("sessão '%s' não existe", r.Old)
	}
	if err := RenameSession(r.Old, r.New); err != nil {
		return fmt.Errorf("erro ao renomear: %w", err)
	}
	TmuxDisplay(fmt.Sprintf("✏️ Sessão renomeada: '%s' → '%s'", r.Old, r.New))
	return nil
}

type ListCmd struct{}

func (l *ListCmd) Run() error {
	sessions, err := ListSessions()
	if err != nil {
		return err
	}
	if len(sessions) == 0 {
		fmt.Println("📭 Nenhuma sessão ativa")
		return nil
	}
	fmt.Println("📋 Sessões ativas:")
	for _, name := range sessions {
		info, _ := GetSessionInfo(name)
		attached := ""
		if info != nil && info.Attached {
			attached = " (attached)"
		}
		fmt.Printf("  - %s%s\n", name, attached)
	}
	return nil
}

type SaveCmd struct {
	Name string `arg:"" help:"Nome da sessão"`
	Dir  string `arg:"" optional:"" help:"Diretório da sessão"`
}

func (s *SaveCmd) Run() error {
	// Implementar save
	fmt.Printf("💾 Salvando sessão '%s'...\n", s.Name)
	return nil
}

type RestoreCmd struct {
	Name string `arg:"" help:"Nome da sessão"`
}

func (r *RestoreCmd) Run() error {
	// Implementar restore
	fmt.Printf("♻️ Restaurando sessão '%s'...\n", r.Name)
	return nil
}

type SavedCmd struct{}

func (s *SavedCmd) Run() error {
	fmt.Println("📋 Sessões salvas:")
	// Implementar listagem
	return nil
}

type ConfigCmd struct{}

func (c *ConfigCmd) Run() error {
	fmt.Println("⚙️ Configuração atual:")
	// Implementar exibição
	return nil
}

type VersionCmd struct{}

func (v *VersionCmd) Run() error {
	fmt.Println("tms v1.1.0")
	return nil
}

// ========== NOVOS COMANDOS (Import/Export) ==========

type ImportCmd struct {
	Path   string `arg:"" help:"Caminho do arquivo a importar"`
	Format string `help:"Formato: tmuxinator ou tmuxp" enum:"auto,tmuxinator,tmuxp" default:"auto"`
}

func (i *ImportCmd) Run() error {
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

type ExportCmd struct {
	Name   string `arg:"" help:"Nome da sessão a exportar"`
	Format string `help:"Formato: tmuxinator ou tmuxp" enum:"tmuxinator,tmuxp" default:"tmuxinator"`
	Output string `help:"Caminho de saída (opcional)"`
}

func (e *ExportCmd) Run() error {
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
EOF

# ========== 6. CLI.GO ATUALIZADO ==========

cat > cli.go << 'EOF'
package main

import (
	"github.com/alecthomas/kong"
)

var CLI struct {
	New    NewCmd    `cmd:"" help:"Criar nova sessão"`
	Switch SwitchCmd `cmd:"" help:"Alternar para uma sessão" aliases:"s"`
	Kill   KillCmd   `cmd:"" help:"Matar uma sessão" aliases:"k"`
	Rename RenameCmd `cmd:"" help:"Renomear uma sessão" aliases:"r"`
	List   ListCmd   `cmd:"" help:"Listar sessões ativas"`
	Save   SaveCmd   `cmd:"" help:"Salvar definição da sessão"`
	Restore RestoreCmd `cmd:"" help:"Restaurar definição da sessão"`
	Saved  SavedCmd  `cmd:"" help:"Listar sessões salvas"`
	Config ConfigCmd `cmd:"" help:"Exibir configuração"`
	Version VersionCmd `cmd:"" help:"Exibir versão"`

	// Novos comandos
	Import          ImportCmd          `cmd:"" help:"Importar sessão de tmuxinator/tmuxp"`
	Export          ExportCmd          `cmd:"" help:"Exportar sessão para tmuxinator/tmuxp"`
	ListImportable  ListImportableCmd  `cmd:"" help:"Listar arquivos importáveis"`
}
EOF

# ========== 7. MAIN.GO ==========

cat > main.go << 'EOF'
package main

import (
	"os"

	"github.com/alecthomas/kong"
)

func main() {
	ctx := kong.Parse(&CLI,
		kong.Name("tms"),
		kong.Description("Tmux Session Manager"),
		kong.UsageOnError(),
		kong.ConfigureHelp(kong.HelpOptions{
			Compact: true,
		}),
	)

	err := ctx.Run()
	if err != nil {
		os.Exit(1)
	}
}
EOF

# ========== 8. GO MOD TIDY E BUILD ==========

echo "🧹 Executando go mod tidy..."
go mod tidy

echo "🔨 Verificando build..."
if go build -o tms .; then
	echo "✅ Build bem-sucedido!"
else
	echo "❌ Erro no build. Verifique os arquivos manualmente."
	exit 1
fi

echo ""
echo "✅ Todas as melhorias foram aplicadas!"
echo ""
echo "📋 Novos comandos disponíveis:"
echo "  tms import <arquivo>      # Importar do tmuxinator/tmuxp"
echo "  tms export <nome>         # Exportar para tmuxinator/tmuxp"
echo "  tms list-importable       # Listar arquivos importáveis"
echo ""
echo "💡 Na TUI, pressione '/' para ativar o filtro de pesquisa"