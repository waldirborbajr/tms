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

// ====================== Lip Gloss Styles ======================
var (
	titleStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5555")).Bold(true)
	selectedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF5555")).Bold(true)
	itemStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#BBBBBB"))
)

// ====================== Bubble Tea Model ======================
type killModel struct {
	sessions []string
	cursor   int
}

func initialKillModel() killModel {
	return killModel{
		sessions: listSessions(),
		cursor:   0,
	}
}

func (m killModel) Init() tea.Cmd { return nil }

func (m killModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
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
			if m.cursor < len(m.sessions)-1 {
				m.cursor++
			}
		case "enter":
			if len(m.sessions) > 0 {
				selected := m.sessions[m.cursor]
				_, err := runTmux("kill-session", "-t", selected)
				if err != nil {
					tmuxDisplay("Failed to kill session")
				} else {
					tmuxDisplay(fmt.Sprintf("Killed session: %s", selected))
				}
			}
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m killModel) View() string {
	if len(m.sessions) == 0 {
		return "No tmux sessions found.\n"
	}

	var s strings.Builder
	s.WriteString(titleStyle.Render("Kill Tmux Session") + "\n\n")

	for i, session := range m.sessions {
		if i == m.cursor {
			s.WriteString(selectedStyle.Render(" → "+session) + "\n")
		} else {
			s.WriteString(itemStyle.Render("  "+session) + "\n")
		}
	}

	s.WriteString("\n" + lipgloss.NewStyle().Foreground(lipgloss.Color("#888888")).Render("↑↓/jk • Enter = kill • q = cancel"))
	return s.String()
}

// ====================== CLI Structure ======================
type CLI struct {
	List    ListCmd    `cmd:"" help:"List active tmux sessions"`
	New     NewCmd     `cmd:"" help:"Create a new tmux session"`
	Switch  SwitchCmd  `cmd:"" aliases:"s" help:"Switch to a tmux session"`
	Attach  AttachCmd  `cmd:"" help:"Attach to a tmux session"`
	Kill    KillCmd    `cmd:"" aliases:"k" help:"Kill a tmux session (interactive if no name)"`
	Rename  RenameCmd  `cmd:"" aliases:"r" help:"Rename a tmux session"`
	Version VersionCmd `cmd:"" help:"Show version and build information"`
}

type ListCmd struct{}
type VersionCmd struct{}

type NewCmd struct {
	Name string `arg:"" optional:"" help:"Name of the new session"`
}

type SwitchCmd struct {
	Name string `arg:"" optional:"" help:"Session name to switch to"`
}

type AttachCmd struct {
	Name string `arg:"" required:"" help:"Session name to attach"`
}

type KillCmd struct {
	Name string `arg:"" optional:"" help:"Session name to kill (empty = interactive)"`
}

type RenameCmd struct {
	Old string `arg:"" name:"old" help:"Current session name"`
	New string `arg:"" name:"new" help:"New session name"`
}

// ====================== Command Handlers ======================
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
	fmt.Printf("Creating session: %s\n", name)
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
		// Interactive switch (future enhancement)
		fmt.Println("Switch command without name not implemented yet.")
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

func (c AttachCmd) Run() error {
	fmt.Printf("Attaching to session: %s\n", c.Name)
	return runTmux("attach-session", "-t", c.Name)
}

func (c KillCmd) Run() error {
	if c.Name == "" {
		// Interactive mode
		p := tea.NewProgram(initialKillModel())
		if _, err := p.Run(); err != nil {
			fmt.Printf("Error running interactive kill: %v\n", err)
		}
		return nil
	}

	// Direct kill
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
	var cli CLI
	ctx := kong.Parse(&cli,
		kong.Name("tms"),
		kong.Description("Simple and lightweight Tmux session manager"),
		kong.UsageOnError(),
		kong.ConfigureHelp(kong.HelpOptions{Compact: true}),
	)

	err := ctx.Run()
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}
