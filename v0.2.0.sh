#!/bin/bash
# Script para aplicar melhorias ao projeto tms
# Mantém tudo existente, apenas adiciona e modifica

set -e

echo "🚀 Aplicando melhorias ao tms..."

# ========== 1. CACHE DE SESSÕES (Prioridade 2) ==========

cat > cache.go << 'EOF'
package main

import (
	"sync"
	"time"
)

// Cache simples para armazenar listas de sessões
type SessionCache struct {
	data      []string
	expiresAt time.Time
	mu        sync.RWMutex
	ttl       time.Duration
}

// NewSessionCache cria um novo cache com TTL padrão de 2 segundos
func NewSessionCache(ttl ...time.Duration) *SessionCache {
	duration := 2 * time.Second
	if len(ttl) > 0 && ttl[0] > 0 {
		duration = ttl[0]
	}
	return &SessionCache{
		ttl: duration,
	}
}

// Get retorna os dados do cache se válido
func (c *SessionCache) Get() ([]string, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if c.data == nil || time.Now().After(c.expiresAt) {
		return nil, false
	}
	return c.data, true
}

// Set armazena dados no cache
func (c *SessionCache) Set(data []string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = data
	c.expiresAt = time.Now().Add(c.ttl)
}

// Invalidate invalida o cache
func (c *SessionCache) Invalidate() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = nil
	c.expiresAt = time.Time{}
}

// Clear limpa completamente o cache
func (c *SessionCache) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = nil
	c.expiresAt = time.Time{}
}

// IsValid verifica se o cache ainda é válido
func (c *SessionCache) IsValid() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.data != nil && time.Now().Before(c.expiresAt)
}
EOF

# ========== 2. PESQUISA E FILTRO (Prioridade 1) ==========

cat > filter_model.go << 'EOF'
package main

import (
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// FilterModel gerencia o estado da pesquisa/filtro na TUI
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

// NewFilterModel cria um novo modelo de filtro
func NewFilterModel(items []string) *FilterModel {
	return &FilterModel{
		Text:     "",
		Active:   false,
		AllItems: items,
		Filtered: items,
		Selected: 0,
	}
}

// Init implementa tea.Model
func (f *FilterModel) Init() tea.Cmd {
	return nil
}

// Update implementa tea.Model
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
			// Adicionar caractere ao texto do filtro
			if len(msg.String()) == 1 {
				f.Text += msg.String()
				f.applyFilter()
			}
			return f, nil
		}
	}
	return f, nil
}

// applyFilter aplica o filtro atual à lista de itens
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

// SetItems atualiza a lista de itens
func (f *FilterModel) SetItems(items []string) {
	f.AllItems = items
	f.applyFilter()
}

// View renderiza o campo de filtro
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

// Toggle ativa/desativa o filtro
func (f *FilterModel) Toggle() {
	f.Active = !f.Active
	if f.Active {
		f.Text = ""
		f.Selected = 0
		f.applyFilter()
	}
}

// IsActive retorna se o filtro está ativo
func (f *FilterModel) IsActive() bool {
	return f.Active
}

// GetFiltered retorna a lista filtrada
func (f *FilterModel) GetFiltered() []string {
	return f.Filtered
}

// GetSelected retorna o item selecionado
func (f *FilterModel) GetSelected() string {
	if len(f.Filtered) > 0 && f.Selected < len(f.Filtered) {
		return f.Filtered[f.Selected]
	}
	return ""
}
EOF

# ========== 3. IMPORTAÇÃO/EXPORTAÇÃO (Prioridade 4) ==========

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

// TmuxinatorConfig representa a estrutura de um projeto tmuxinator
type TmuxinatorConfig struct {
	Name     string            `toml:"name"`
	Root     string            `toml:"root"`
	Windows  []TmuxinatorWindow `toml:"windows"`
	Options  map[string]string `toml:"options"`
	Pre      string            `toml:"pre"`
	PreWindow string           `toml:"pre_window"`
}

// TmuxinatorWindow representa uma janela no tmuxinator
type TmuxinatorWindow struct {
	Name     string   `toml:"name"`
	Panes    []string `toml:"panes"`
	Layout   string   `toml:"layout,omitempty"`
	Commands []string `toml:"commands,omitempty"`
}

// TmuxpConfig representa a estrutura de um projeto tmuxp
type TmuxpConfig struct {
	Name          string                 `json:"session_name"`
	StartDirectory string                `json:"start_directory"`
	Windows       []TmuxpWindow          `json:"windows"`
	GlobalOptions map[string]interface{} `json:"global_options"`
}

// TmuxpWindow representa uma janela no tmuxp
type TmuxpWindow struct {
	Name     string   `json:"window_name"`
	Panes    []string `json:"panes"`
	Layout   string   `json:"layout,omitempty"`
	Commands []string `json:"commands,omitempty"`
	Options  map[string]interface{} `json:"options,omitempty"`
}

// ImportTmuxinator importa uma configuração do tmuxinator
func ImportTmuxinator(path string) error {
	var config TmuxinatorConfig

	// Ler arquivo TOML
	if _, err := toml.DecodeFile(path, &config); err != nil {
		return fmt.Errorf("erro ao ler tmuxinator config: %w", err)
	}

	if config.Name == "" {
		return fmt.Errorf("nome da sessão não encontrado no arquivo")
	}

	// Criar diretório de sessões salvas se não existir
	sessionsDir := getSessionsDir()
	if err := os.MkdirAll(sessionsDir, 0755); err != nil {
		return fmt.Errorf("erro ao criar diretório: %w", err)
	}

	// Converter para formato nativo do tms
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
			// Adicionar pane padrão se não houver
			window.Panes = append(window.Panes, PaneDefinition{
				Command: "bash",
			})
		}

		session.Windows = append(session.Windows, window)
	}

	// Salvar no formato tms
	sessionFile := filepath.Join(sessionsDir, config.Name+".toml")
	if err := saveSessionDefinition(sessionFile, session); err != nil {
		return fmt.Errorf("erro ao salvar sessão: %w", err)
	}

	fmt.Printf("✅ Sessão '%s' importada do tmuxinator com sucesso!\n", config.Name)
	return nil
}

// ImportTmuxp importa uma configuração do tmuxp
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

// ExportTmuxinator exporta uma sessão para formato tmuxinator
func ExportTmuxinator(name string, outputPath string) error {
	// Carregar definição da sessão
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

	// Escrever arquivo TOML
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

// ExportTmuxp exporta uma sessão para formato tmuxp
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

// ListImportable lista arquivos importáveis de tmuxinator/tmuxp
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

	// Verificar também o diretório ~/.tmuxinator/
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

	// Verificar também ~/.tmuxp/
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

# ========== 4. ATUALIZAR TMUX.GO (Prioridade 3) ==========

# Fazer backup do tmux.go existente
if [ -f tmux.go ]; then
	cp tmux.go tmux.go.bak
fi

# Modificar tmux.go com parsing robusto e cache
cat > tmux.go << 'EOF'
package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"time"
)

// SessionCache global para listagem de sessões
var sessionCache = NewSessionCache(2 * time.Second)

// TmuxSession representa uma sessão do tmux com informações detalhadas
type TmuxSession struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Path        string `json:"path"`
	Windows     int    `json:"windows"`
	Attached    bool   `json:"attached"`
	Created     string `json:"created"`
	LastAttached string `json:"last_attached"`
}

// TmuxCommand executa um comando tmux e retorna a saída
func TmuxCommand(args ...string) ([]byte, error) {
	cmd := exec.Command("tmux", args...)
	return cmd.CombinedOutput()
}

// TmuxCommandOutput executa e retorna saída como string (trimmed)
func TmuxCommandOutput(args ...string) (string, error) {
	output, err := TmuxCommand(args...)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// ListSessionsRaw lista sessões usando formato JSON para parsing robusto
func ListSessionsRaw() ([]TmuxSession, error) {
	// Usar JSON para parsing robusto
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
			continue // Pular linha com erro
		}
		sessions = append(sessions, session)
	}

	return sessions, nil
}

// ListSessions retorna lista de nomes de sessões (usa cache)
func ListSessions() ([]string, error) {
	// Verificar cache
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

	// Atualizar cache
	sessionCache.Set(names)
	return names, nil
}

// SessionExists verifica se uma sessão existe (usa cache)
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

// GetSessionInfo obtém informações detalhadas de uma sessão
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

// NewSession cria uma nova sessão
func NewSession(name, dir string) error {
	args := []string{"new-session", "-d", "-s", name}
	if dir != "" {
		args = append(args, "-c", dir)
	}
	_, err := TmuxCommand(args...)
	if err == nil {
		sessionCache.Invalidate() // Invalidar cache
	}
	return err
}

// KillSession mata uma sessão
func KillSession(name string) error {
	_, err := TmuxCommand("kill-session", "-t", name)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

// SwitchSession alterna para uma sessão
func SwitchSession(name string) error {
	_, err := TmuxCommand("switch-client", "-t", name)
	return err
}

// RenameSession renomeia uma sessão
func RenameSession(old, new string) error {
	_, err := TmuxCommand("rename-session", "-t", old, new)
	if err == nil {
		sessionCache.Invalidate()
	}
	return err
}

// SessionPath retorna o caminho da sessão
func SessionPath(name string) (string, error) {
	return TmuxCommandOutput("display", "-t", name, "-p", "#{session_path}")
}

// IsSessionAttached verifica se a sessão está anexada
func IsSessionAttached(name string) bool {
	info, err := GetSessionInfo(name)
	if err != nil {
		return false
	}
	return info.Attached
}

// InvalidateCache invalida o cache de sessões
func InvalidateCache() {
	sessionCache.Invalidate()
}

// RefreshCache força a atualização do cache
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

# ========== 5. ATUALIZAR MENU_MODEL.GO (Adicionar filtro) ==========

# Fazer backup
if [ -f menu_model.go ]; then
	cp menu_model.go menu_model.go.bak
fi

# Modificar menu_model.go para adicionar filtro
# (Usando patch para adicionar o filtro sem remover nada)
cat > menu_model.go << 'EOF'
package main

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// MenuModel representa o menu principal
type MenuModel struct {
	Choices       []string
	Cursor        int
	Selected      int
	Width         int
	Height        int
	Filter        *FilterModel
	FilterActive  bool
	Quit          bool
}

// NewMenuModel cria um novo modelo de menu
func NewMenuModel() *MenuModel {
	items := []string{"New Session", "Switch Session", "Kill Session", "Rename Session", "List Sessions", "Save Session", "Restore Session", "Import Session", "Export Session", "Quit"}
	return &MenuModel{
		Choices:      items,
		Cursor:       0,
		Selected:     -1,
		Filter:       NewFilterModel(items),
		FilterActive: false,
	}
}

// Init implementa tea.Model
func (m *MenuModel) Init() tea.Cmd {
	return nil
}

// Update implementa tea.Model
func (m *MenuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.FilterActive {
		return m.updateFilter(msg)
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.Quit = true
			return m, tea.Quit

		case "up", "k":
			if m.Cursor > 0 {
				m.Cursor--
			}
			return m, nil

		case "down", "j":
			if m.Cursor < len(m.Choices)-1 {
				m.Cursor++
			}
			return m, nil

		case "enter":
			m.Selected = m.Cursor
			return m, m.handleSelection()

		case "/":
			m.FilterActive = true
			m.Filter.Toggle()
			return m, nil

		default:
			return m, nil
		}
	}
	return m, nil
}

// updateFilter atualiza o estado do filtro
func (m *MenuModel) updateFilter(msg tea.Msg) (tea.Model, tea.Cmd) {
	newFilter, cmd := m.Filter.Update(msg)
	m.Filter = newFilter

	if !m.Filter.IsActive() {
		m.FilterActive = false
		// Restaurar lista original
		m.Choices = []string{"New Session", "Switch Session", "Kill Session", "Rename Session", "List Sessions", "Save Session", "Restore Session", "Import Session", "Export Session", "Quit"}
	} else {
		m.Choices = m.Filter.GetFiltered()
	}

	return m, cmd
}

// handleSelection processa a seleção do menu
func (m *MenuModel) handleSelection() tea.Cmd {
	choice := m.Choices[m.Cursor]
	switch choice {
	case "New Session":
		return func() tea.Msg { return NewSessionMsg{} }
	case "Switch Session":
		return func() tea.Msg { return SwitchSessionMsg{} }
	case "Kill Session":
		return func() tea.Msg { return KillSessionMsg{} }
	case "Rename Session":
		return func() tea.Msg { return RenameSessionMsg{} }
	case "List Sessions":
		return func() tea.Msg { return ListSessionsMsg{} }
	case "Save Session":
		return func() tea.Msg { return SaveSessionMsg{} }
	case "Restore Session":
		return func() tea.Msg { return RestoreSessionMsg{} }
	case "Import Session":
		return func() tea.Msg { return ImportSessionMsg{} }
	case "Export Session":
		return func() tea.Msg { return ExportSessionMsg{} }
	case "Quit":
		m.Quit = true
		return tea.Quit
	}
	return nil
}

// View implementa tea.Model
func (m *MenuModel) View() string {
	if m.Quit {
		return ""
	}

	var b strings.Builder

	// Título
	titleStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#00FF00")).
		Bold(true).
		MarginBottom(1)

	b.WriteString(titleStyle.Render("🚀 tms - Tmux Session Manager"))
	b.WriteString("\n\n")

	// Barra de filtro
	if m.FilterActive {
		filterView := m.Filter.View()
		if filterView != "" {
			filterStyle := lipgloss.NewStyle().
				Background(lipgloss.Color("#333333")).
				Padding(0, 1).
				MarginBottom(1)
			b.WriteString(filterStyle.Render(filterView))
			b.WriteString("\n\n")
		}
	}

	// Lista de itens
	for i, choice := range m.Choices {
		cursor := " "
		if m.Cursor == i {
			cursor = ">"
		}

		style := lipgloss.NewStyle()
		if m.Cursor == i {
			style = style.Foreground(lipgloss.Color("#00FF00")).Bold(true)
		}

		item := fmt.Sprintf("%s %s", cursor, choice)
		b.WriteString(style.Render(item))
		b.WriteString("\n")
	}

	// Dicas de teclado
	helpStyle := lipgloss.NewStyle().
		Foreground(lipgloss.Color("#666666")).
		MarginTop(1)

	help := "↑/↓: navigate • enter: select • q: quit • /: filter"
	if m.FilterActive {
		help = "🔍 filter mode: type to search • enter: select • esc: cancel"
	}
	b.WriteString(helpStyle.Render(help))

	return b.String()
}

// ========== MENSAGENS PARA COMANDOS ==========

type NewSessionMsg struct{}
type SwitchSessionMsg struct{}
type KillSessionMsg struct{}
type RenameSessionMsg struct{}
type ListSessionsMsg struct{}
type SaveSessionMsg struct{}
type RestoreSessionMsg struct{}
type ImportSessionMsg struct{}
type ExportSessionMsg struct{}
EOF

# ========== 6. ATUALIZAR COMMANDS.GO (Adicionar import/export) ==========

# Verificar se commands.go existe e adicionar funções
if [ -f commands.go ]; then
	# Adicionar funções de import/export se não existirem
	if ! grep -q "ImportSession" commands.go; then
		cat >> commands.go << 'EOF'

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
EOF
	fi
fi

# ========== 7. ATUALIZAR CLI.GO (Adicionar comandos) ==========

# Verificar se cli.go existe e adicionar comandos
if [ -f cli.go ]; then
	if ! grep -q "ImportSession" cli.go; then
		# Encontrar a estrutura CLI e adicionar os comandos
		# Usando sed para inserir antes do último }
		sed -i '/^var CLI struct {/,/^}/ {
			/^}/ i\
	Import ImportSessionCmd `cmd:"" help:"Importar sessão de tmuxinator/tmuxp"`\
	Export ExportSessionCmd `cmd:"" help:"Exportar sessão para tmuxinator/tmuxp"`\
	ListImportable ListImportableCmd `cmd:"" help:"Listar arquivos importáveis"`
		}' cli.go
	fi
fi

# ========== 8. ATUALIZAR SESSION.GO (Adicionar estruturas) ==========

# Verificar e adicionar estruturas para definições de sessão
if [ -f session.go ]; then
	if ! grep -q "SessionDefinition" session.go; then
		cat >> session.go << 'EOF'

// ========== DEFINIÇÕES DE SESSÃO PARA IMPORTAÇÃO/EXPORTAÇÃO ==========

// SessionDefinition representa uma definição de sessão
type SessionDefinition struct {
	Name        string
	Directory   string
	Windows     []WindowDefinition
	PreCommands []string
}

// WindowDefinition representa uma janela na definição
type WindowDefinition struct {
	Name     string
	Layout   string
	Panes    []PaneDefinition
	Commands []string
}

// PaneDefinition representa um painel na definição
type PaneDefinition struct {
	Command string
}

// getSessionsDir retorna o diretório de sessões salvas
func getSessionsDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "tms", "sessions")
}

// loadSessionDefinition carrega uma definição de sessão
func loadSessionDefinition(name string) (SessionDefinition, error) {
	var session SessionDefinition
	sessionFile := filepath.Join(getSessionsDir(), name+".toml")
	if _, err := toml.DecodeFile(sessionFile, &session); err != nil {
		return session, fmt.Errorf("erro ao carregar sessão: %w", err)
	}
	return session, nil
}

// saveSessionDefinition salva uma definição de sessão
func saveSessionDefinition(path string, session SessionDefinition) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	encoder := toml.NewEncoder(f)
	return encoder.Encode(session)
}
EOF
	fi
fi

# ========== 9. ADICIONAR IMPORTS NECESSÁRIOS ==========

# Adicionar imports que podem faltar
for file in import_export.go session.go; do
	if [ -f "$file" ]; then
		# Verificar se tem os imports necessários
		if ! grep -q "^import (" "$file"; then
			sed -i '1i\
import (\
	"encoding/json"\
	"fmt"\
	"os"\
	"path/filepath"\
	"strings"\
	"github.com/BurntSushi/toml"\
)
' "$file"
		fi
	fi
done

# ========== 10. EXECUTAR GO MOD TIDY ==========

echo "🧹 Executando go mod tidy..."
go mod tidy

# ========== 11. VERIFICAR BUILD ==========

echo "🔨 Verificando build..."
if go build -o tms .; then
	echo "✅ Build bem-sucedido!"
else
	echo "❌ Erro no build. Verifique os arquivos manualmente."
	exit 1
fi

# ========== 12. LIMPEZA ==========

echo ""
echo "✅ Todas as melhorias foram aplicadas!"
echo ""
echo "📋 Resumo das mudanças:"
echo "  1. 🔍 Pesquisa e Filtro na TUI (tecla '/' para ativar)"
echo "  2. ⚡ Cache de Sessões (TTL de 2 segundos)"
echo "  3. 🛡️ Parsing Robusto do tmux (formato JSON)"
echo "  4. 🔄 Importação/Exportação tmuxinator/tmuxp"
echo ""
echo "📁 Novos arquivos criados:"
echo "  - filter_model.go"
echo "  - cache.go"
echo "  - import_export.go"
echo ""
echo "📝 Arquivos modificados:"
echo "  - tmux.go (cache + parsing JSON)"
echo "  - menu_model.go (filtro integrado)"
echo "  - commands.go (comandos import/export)"
echo "  - cli.go (novos comandos)"
echo "  - session.go (definições de sessão)"
echo ""
echo "🔧 Comandos disponíveis:"
echo "  tms import <arquivo>      # Importar do tmuxinator/tmuxp"
echo "  tms export <nome>         # Exportar para tmuxinator/tmuxp"
echo "  tms list-importable       # Listar arquivos importáveis"
echo ""
echo "💡 Na TUI, pressione '/' para ativar o filtro de pesquisa"