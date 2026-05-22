package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/alecthomas/kong"
)

// ==================== Build Information ====================
var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildTime = "unknown"
)

// ====================== Tmux Helper ======================
func runTmux(args ...string) (string, error) {
	cmd := exec.Command("tmux", args...)
	output, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(output)), err
}

func listSessions() []string {
	output, err := runTmux("ls", "-F", "#{session_name}")
	if err != nil || output == "" {
		return []string{}
	}
	return strings.Split(output, "\n")
}

func tmuxDisplay(message string) {
	runTmux("display-message", message)
}

// ====================== Styles ======================
var (
	titleStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5555")).Bold(true)
	selectedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5555")).Bold(true)
	itemStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("#BBBBBB"))
	helpStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("#888888"))
	inputStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFCC00")).Bold(true)
)

// ====================== Text Input Model ======================
type textInputModel struct {
	prompt   string
	value    string
	action   string // "new" or "rename"
	oldName  string
}

func initialTextInput(prompt, action, oldName string) textInputModel {
	return textInputModel{
		prompt:  prompt,
		value:   "",
		action:  action,
		oldName: oldName,
	}
}

func (m textInputModel) Init() tea.Cmd { return nil }

func (m textInputModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc":
			return initialMenuModel(), nil
		case "enter":
			if m.value == "" {
				return m, nil
			}
			switch m.action {
			case "new":
				_, _ = runTmux("new-session", "-d", "-s", m.value)
				runTmux("switch-client", "-t", m.value)
				tmuxDisplay("Created session: " + m.value)
			case "rename":
				if m.oldName != "" {
					_, _ = runTmux("rename-session", "-t", m.oldName, m.value)
					tmuxDisplay(fmt.Sprintf("Renamed: %s → %s", m.oldName, m.value))
				}
			}
			return initialMenuModel(), nil
		case "backspace":
			if len(m.value) > 0 {
				m.value = m.value[:len(m.value)-1]
			}
		default:
			if len(msg.String()) == 1 {
				m.value += msg.String()
			}
		}
	}
	return m, nil
}

func (m textInputModel) View() string {
	var s strings.Builder
	s.WriteString(titleStyle.Render("✏️ "+m.prompt) + "\n\n")
	s.WriteString(inputStyle.Render(" > " + m.value + "█") + "\n\n")
	s.WriteString(helpStyle.Render("Type name • Enter = confirm • Esc = cancel"))
	return s.String()
}

// ====================== Main Menu ======================
type menuModel struct {
	cursor int
}

var menuOptions = []string{
	"New Session",
	"Switch Session",
	"Kill Session",
	"Rename Current Session",
	"List Sessions",
	"Show Version",
	"Quit",
}

func initialMenuModel() menuModel {
	return menuModel{cursor: 0}
}

func (m menuModel) Init() tea.Cmd { return nil }

func (m menuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit

		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(menuOptions)-1 {
				m.cursor++
			}

		case "enter":
			switch menuOptions[m.cursor] {
			case "New Session":
				return initialTextInput("New Session Name", "new", ""), nil
			case "Switch Session":
				return initialSwitchModel(), nil
			case "Kill Session":
				return initialKillModel(), nil
			case "Rename Current Session":
				current, _ := runTmux("display-message", "-p", "#S")
				return initialTextInput("New name for: "+current, "rename", current), nil
			case "List Sessions":
				sessions := listSessions()
				if len(sessions) == 0 {
					fmt.Println("No active tmux sessions.")
				} else {
					fmt.Println("Active sessions:")
					for _, s := range sessions {
						fmt.Printf(" • %s\n", s)
					}
				}
				fmt.Scanln()
				return m, nil
			case "Show Version":
				fmt.Printf("tms version %s\n", Version)
				fmt.Printf("Git Commit : %s\n", GitCommit)
				fmt.Printf("Built      : %s\n", BuildTime)
				fmt.Scanln()
				return m, nil
			case "Quit":
				return m, tea.Quit
			}
		}
	}
	return m, nil
}

func (m menuModel) View() string {
	var s strings.Builder
	s.WriteString(titleStyle.Render("🚀 TMS - Tmux Session Manager") + "\n\n")

	for i, option := range menuOptions {
		if i == m.cursor {
			s.WriteString(selectedStyle.Render(" → "+option) + "\n")
		} else {
			s.WriteString(itemStyle.Render("   "+option) + "\n")
		}
	}

	s.WriteString("\n" + helpStyle.Render("↑↓/jk • Enter = select • q = quit"))
	return s.String()
}

// ====================== Switch Model ======================
type switchModel struct {
	sessions []string
	cursor   int
}

func initialSwitchModel() switchModel {
	return switchModel{sessions: listSessions(), cursor: 0}
}

func (m switchModel) Init() tea.Cmd { return nil }

func (m switchModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return initialMenuModel(), nil
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.sessions)-1 {
				m.cursor++
			}
		case "enter":
			if len(m.sessions) > 0 {
				selected := m.sessions[m.cursor]
				runTmux("switch-client", "-t", selected)
				tmuxDisplay("Switched to: " + selected)
			}
			return initialMenuModel(), nil
		}
	}
	return m, nil
}

func (m switchModel) View() string {
	if len(m.sessions) == 0 {
		return "No sessions found.\n"
	}

	var s strings.Builder
	s.WriteString(titleStyle.Render("🔄 Switch Session") + "\n\n")

	for i, session := range m.sessions {
		if i == m.cursor {
			s.WriteString(selectedStyle.Render(" → "+session) + "\n")
		} else {
			s.WriteString(itemStyle.Render("   "+session) + "\n")
		}
	}

	s.WriteString("\n" + helpStyle.Render("↑↓/jk • Enter = switch • q = back"))
	return s.String()
}

// ====================== Kill Model ======================
type killModel struct {
	sessions []string
	cursor   int
}

func initialKillModel() killModel {
	return killModel{sessions: listSessions(), cursor: 0}
}

func (m killModel) Init() tea.Cmd { return nil }

func (m killModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return initialMenuModel(), nil
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.sessions)-1 {
				m.cursor++
			}
		case "enter":
			if len(m.sessions) > 0 {
				selected := m.sessions[m.cursor]
				_, err := runTmux("kill-session", "-t", selected)
				if err == nil {
					tmuxDisplay("Killed: " + selected)
				}
			}
			return initialMenuModel(), nil
		}
	}
	return m, nil
}

func (m killModel) View() string {
	if len(m.sessions) == 0 {
		return "No sessions found.\n"
	}

	var s strings.Builder
	s.WriteString(titleStyle.Render("🗑️ Kill Session") + "\n\n")

	for i, session := range m.sessions {
		if i == m.cursor {
			s.WriteString(selectedStyle.Render(" → "+session) + "\n")
		} else {
			s.WriteString(itemStyle.Render("   "+session) + "\n")
		}
	}

	s.WriteString("\n" + helpStyle.Render("↑↓/jk • Enter = kill • q = back"))
	return s.String()
}

// ====================== CLI (mantido) ======================
type CLI struct {
	New     NewCmd     `cmd:"" help:"Create a new session"`
	Switch  SwitchCmd  `cmd:"" aliases:"s" help:"Switch to a session"`
	Kill    KillCmd    `cmd:"" aliases:"k" help:"Kill a session"`
	Rename  RenameCmd  `cmd:"" aliases:"r" help:"Rename a session"`
	List    ListCmd    `cmd:"" help:"List sessions"`
	Version VersionCmd `cmd:"" help:"Show version"`
}

type ListCmd struct{}
type VersionCmd struct{}
type NewCmd struct{ Name string `arg:"" optional:"" help:"Session name"` }
type SwitchCmd struct{ Name string `arg:"" optional:"" help:"Session name"` }
type KillCmd struct{ Name string `arg:"" optional:"" help:"Session name"` }
type RenameCmd struct {
	Old string `arg:"" name:"old"`
	New string `arg:"" name:"new"`
}

// ====================== Command Implementations ======================
func (c ListCmd) Run() error {
	sessions := listSessions()
	if len(sessions) == 0 {
		fmt.Println("No tmux sessions found.")
		return nil
	}
	fmt.Println("Active tmux sessions:")
	for _, s := range sessions {
		fmt.Printf(" • %s\n", s)
	}
	return nil
}

func (c VersionCmd) Run() error {
	fmt.Printf("tms version %s\n", Version)
	fmt.Printf("Git Commit : %s\n", GitCommit)
	fmt.Printf("Built      : %s\n", BuildTime)
	return nil
}

func (c NewCmd) Run() error {
	name := c.Name
	if name == "" {
		name = "main"
	}
	_, err := runTmux("new-session", "-d", "-s", name)
	if err != nil {
		tmuxDisplay("Failed to create session")
		return err
	}
	tmuxDisplay(fmt.Sprintf("Created session: %s", name))
	runTmux("switch-client", "-t", name)
	return nil
}

func (c SwitchCmd) Run() error {
	if c.Name == "" {
		fmt.Println("Use 'tms switch <name>' or use the interactive menu.")
		return nil
	}
	_, err := runTmux("switch-client", "-t", c.Name)
	if err != nil {
		tmuxDisplay(fmt.Sprintf("Session '%s' not found", c.Name))
	} else {
		tmuxDisplay(fmt.Sprintf("Switched to: %s", c.Name))
	}
	return nil
}

func (c KillCmd) Run() error {
	if c.Name == "" {
		p := tea.NewProgram(initialKillModel())
		if _, err := p.Run(); err != nil {
			fmt.Printf("Error: %v\n", err)
		}
		return nil
	}

	_, err := runTmux("kill-session", "-t", c.Name)
	if err != nil {
		tmuxDisplay(fmt.Sprintf("Failed to kill '%s'", c.Name))
	} else {
		tmuxDisplay(fmt.Sprintf("Killed session: %s", c.Name))
	}
	return nil
}

func (c RenameCmd) Run() error {
	_, err := runTmux("rename-session", "-t", c.Old, c.New)
	if err != nil {
		tmuxDisplay("Failed to rename session")
	} else {
		tmuxDisplay(fmt.Sprintf("Renamed: %s → %s", c.Old, c.New))
	}
	return nil
}

// ====================== Main ======================
func main() {
	if len(os.Args) > 1 {
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
		return
	}

	// Menu interativo
	p := tea.NewProgram(initialMenuModel())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
	}
}
