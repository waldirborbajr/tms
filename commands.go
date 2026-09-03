package main

import (
	"fmt"
	"strings"
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
	fmt.Printf("💾 Salvando sessão '%s'...\n", s.Name)
	return nil
}

type RestoreCmd struct {
	Name string `arg:"" help:"Nome da sessão"`
}

func (r *RestoreCmd) Run() error {
	fmt.Printf("♻️ Restaurando sessão '%s'...\n", r.Name)
	return nil
}

type SavedCmd struct{}

func (s *SavedCmd) Run() error {
	fmt.Println("📋 Sessões salvas:")
	return nil
}

type ConfigCmd struct{}

func (c *ConfigCmd) Run() error {
	fmt.Println("⚙️ Configuração atual:")
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
