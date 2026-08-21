package main

import (
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
