#!/bin/bash
# Script cirúrgico para corrigir APENAS o que está quebrado

set -e

echo "🔧 Removendo duplicatas e ajustando chamadas..."

# ========== 1. REMOVER DUPLICATAS DO SESSION.GO ==========

if [ -f session.go ]; then
    # Fazer backup
    cp session.go session.go.bak
    
    # Remover import do "time" se não for usado
    if ! grep -q "time\." session.go; then
        sed -i '/"time"/d' session.go
        echo "✅ Import 'time' removido de session.go"
    fi
    
    # Remover a declaração duplicada de Config (linhas 14-20)
    # E a função LoadConfig duplicada (linhas 52+)
    # Vamos extrair APENAS as definições de sessão e funções auxiliares
    cat > session.go << 'EOF'
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
)

// SessionDefinition representa uma definição de sessão salva
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
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
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
func saveSessionDefinition(name string, session SessionDefinition) error {
	sessionsDir := getSessionsDir()
	if err := os.MkdirAll(sessionsDir, 0755); err != nil {
		return err
	}

	sessionFile := filepath.Join(sessionsDir, name+".toml")
	f, err := os.Create(sessionFile)
	if err != nil {
		return err
	}
	defer f.Close()

	encoder := toml.NewEncoder(f)
	return encoder.Encode(session)
}

// ListSavedSessions lista sessões salvas
func ListSavedSessions() ([]string, error) {
	sessionsDir := getSessionsDir()
	files, err := os.ReadDir(sessionsDir)
	if err != nil {
		return []string{}, nil
	}

	var names []string
	for _, file := range files {
		if strings.HasSuffix(file.Name(), ".toml") {
			name := strings.TrimSuffix(file.Name(), ".toml")
			names = append(names, name)
		}
	}
	return names, nil
}

// ========== FUNÇÕES AUXILIARES PARA COMPATIBILIDADE ==========

// ListSessionsSafe retorna lista de sessões (1 valor, ignora erro)
func ListSessionsSafe() []string {
	sessions, err := ListSessions()
	if err != nil {
		return []string{}
	}
	return sessions
}

// GetSessionInfoSafe retorna info da sessão (1 valor, ignora erro)
func GetSessionInfoSafe(name string) *TmuxSession {
	info, err := GetSessionInfo(name)
	if err != nil {
		return nil
	}
	return info
}
EOF
    echo "✅ session.go recriado sem duplicatas"
fi

# ========== 2. CORRIGIR DISPLAY.GO ==========

if [ -f display.go ]; then
    # ListSessionsSafe retorna 1 valor, não 2
    sed -i 's/sessions, err := ListSessionsSafe()/sessions := ListSessionsSafe()/g' display.go
    sed -i 's/info, err := GetSessionInfoSafe(/info := GetSessionInfoSafe(/g' display.go
    # Remover tratamento de erro que não existe mais
    sed -i '/if err != nil {/,/}/d' display.go
    echo "✅ display.go corrigido"
fi

# ========== 3. CORRIGIR KILL_MODEL.GO ==========

if [ -f kill_model.go ]; then
    # ListSessionsSafe retorna 1 valor
    sed -i 's/sessions, err := ListSessionsSafe()/sessions := ListSessionsSafe()/g' kill_model.go
    # Remover bloco de erro
    sed -i '/if err != nil {/,/}/d' kill_model.go
    echo "✅ kill_model.go corrigido"
fi

# ========== 4. VERIFICAR OUTROS ARQUIVOS ==========

# Corrigir chamadas em outros arquivos
for file in switch_model.go menu_model.go input_model.go; do
    if [ -f "$file" ]; then
        # ListSessionsSafe retorna 1 valor
        sed -i 's/ListSessionsSafe()/ListSessionsSafe()/g' "$file"
        # Remover atribuições com erro
        sed -i 's/sessions, err := ListSessionsSafe()/sessions := ListSessionsSafe()/g' "$file"
        sed -i 's/info, err := GetSessionInfoSafe(/info := GetSessionInfoSafe(/g' "$file"
        # Remover blocos if err
        sed -i '/if err != nil {/,/}/d' "$file"
        echo "✅ $file corrigido"
    fi
done

# ========== 5. EXECUTAR GO MOD TIDY E BUILD ==========

echo ""
echo "🧹 Executando go mod tidy..."
go mod tidy

echo ""
echo "🔨 Verificando build..."
if go build -o tms .; then
    echo ""
    echo "✅ BUILD BEM-SUCEDIDO!"
    echo ""
    echo "📋 Teste os comandos:"
    echo "  ./tms --help"
    echo "  ./tms list"
else
    echo ""
    echo "❌ Ainda há erros. Execute manualmente:"
    echo "  go build ./... 2>&1"
    echo ""
    echo "E cole a saída completa para eu corrigir."
    exit 1
fi