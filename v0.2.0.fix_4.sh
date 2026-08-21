#!/bin/bash
# Script para corrigir todas as incompatibilidades do tms

set -e

echo "🔧 Corrigindo todas as incompatibilidades..."

# ========== 1. CORRIGIR SESSION.GO ==========

if [ -f session.go ]; then
    # Fazer backup
    cp session.go session.go.bak

    # Corrigir ListSessions() para lidar com múltiplos retornos
    sed -i 's/ListSessions()/ListSessionsSafe()/g' session.go

    # Adicionar import do toml se não existir
    if ! grep -q '"github.com/BurntSushi/toml"' session.go; then
        sed -i '/^import (/a\
	"github.com/BurntSushi/toml"' session.go
    fi

    # Adicionar funções auxiliares no final se não existirem
    if ! grep -q "ListSessionsSafe" session.go; then
        cat >> session.go << 'EOF'

// ListSessionsSafe retorna lista de sessões (ignora erro)
func ListSessionsSafe() []string {
    sessions, err := ListSessions()
    if err != nil {
        return []string{}
    }
    return sessions
}

// GetSessionInfoSafe retorna info da sessão (ignora erro)
func GetSessionInfoSafe(name string) *TmuxSession {
    info, err := GetSessionInfo(name)
    if err != nil {
        return nil
    }
    return info
}
EOF
    fi
fi

# ========== 2. CORRIGIR SWITCH_MODEL.GO ==========

if [ -f switch_model.go ]; then
    cp switch_model.go switch_model.go.bak

    # Corrigir ListSessions()
    sed -i 's/ListSessions()/ListSessionsSafe()/g' switch_model.go

    # Corrigir GetSessionInfo()
    sed -i 's/GetSessionInfo(/GetSessionInfoSafe(/g' switch_model.go
fi

# ========== 3. CORRIGIR CLI.GO (remover import não usado) ==========

if [ -f cli.go ]; then
    cp cli.go cli.go.bak
    # Remover import do kong (não é usado diretamente)
    sed -i '/"github.com\/alecthomas\/kong"/d' cli.go
fi

# ========== 4. CORRIGIR DISPLAY.GO (remover import não usado) ==========

if [ -f display.go ]; then
    cp display.go display.go.bak
    # Remover import do bubbletea
    sed -i '/"github.com\/charmbracelet\/bubbletea"/d' display.go
fi

# ========== 5. CORRIGIR INPUT_MODEL.GO (remover import não usado) ==========

if [ -f input_model.go ]; then
    cp input_model.go input_model.go.bak
    # Remover import do fmt
    sed -i '/"fmt"/d' input_model.go
fi

# ========== 6. VERIFICAR OUTROS ARQUIVOS ==========

# Procurar por usos de ListSessions() sem tratamento de erro
for file in *.go; do
    if [ "$file" != "tmux.go" ] && [ "$file" != "commands.go" ] && [ "$file" != "session.go" ] && [ "$file" != "switch_model.go" ]; then
        if grep -q "ListSessions()" "$file" 2>/dev/null; then
            echo "⚠️ Arquivo $file pode precisar de ajuste manual para ListSessions()"
        fi
    fi
done

# ========== 7. EXECUTAR GO MOD TIDY E BUILD ==========

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
echo "✅ Correções aplicadas com sucesso!"
echo ""
echo "📋 Para testar:"
echo "  ./tms --help"
echo "  ./tms list"