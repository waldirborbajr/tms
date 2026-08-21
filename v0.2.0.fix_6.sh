#!/bin/bash
# Script assertivo para corrigir apenas o que falta

set -e

echo "🔧 Aplicando correções assertivas..."

# ========== 1. ADICIONAR FUNÇÕES AUXILIARES AO SESSION.GO ==========

if [ -f session.go ]; then
    # Verificar se ListSessionsSafe já existe
    if ! grep -q "func ListSessionsSafe" session.go; then
        cat >> session.go << 'EOF'

// ========== FUNÇÕES AUXILIARES PARA COMPATIBILIDADE ==========

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
        echo "✅ Funções auxiliares adicionadas ao session.go"
    fi
fi

# ========== 2. CORRIGIR SWITCH_MODEL.GO ==========

if [ -f switch_model.go ]; then
    # Usar ListSessionsSafe e GetSessionInfoSafe
    sed -i 's/ListSessions()/ListSessionsSafe()/g' switch_model.go
    sed -i 's/GetSessionInfo(/GetSessionInfoSafe(/g' switch_model.go
    echo "✅ switch_model.go corrigido"
fi

# ========== 3. CORRIGIR KILL_MODEL.GO ==========

if [ -f kill_model.go ]; then
    sed -i 's/ListSessions()/ListSessionsSafe()/g' kill_model.go
    sed -i 's/GetSessionInfo(/GetSessionInfoSafe(/g' kill_model.go
    echo "✅ kill_model.go corrigido"
fi

# ========== 4. CORRIGIR DISPLAY.GO ==========

if [ -f display.go ]; then
    sed -i 's/ListSessions()/ListSessionsSafe()/g' display.go
    sed -i 's/GetSessionInfo(/GetSessionInfoSafe(/g' display.go
    echo "✅ display.go corrigido"
fi

# ========== 5. CORRIGIR INPUT_MODEL.GO ==========

if [ -f input_model.go ]; then
    # CreateSession agora aceita 2 argumentos
    sed -i 's/CreateSession(\([^,]*\))/CreateSession(\1, "")/g' input_model.go
    echo "✅ input_model.go corrigido"
fi

# ========== 6. CORRIGIR MENU_MODEL.GO ==========

if [ -f menu_model.go ]; then
    # Verificar se usa ListSessions
    if grep -q "ListSessions()" menu_model.go; then
        sed -i 's/ListSessions()/ListSessionsSafe()/g' menu_model.go
        echo "✅ menu_model.go corrigido"
    fi
fi

# ========== 7. REMOVER IMPORTS NÃO USADOS ==========

# display.go: remover tea se não usado
if grep -q '"github.com/charmbracelet/bubbletea"' display.go; then
    if ! grep -q "tea\." display.go; then
        sed -i '/"github.com\/charmbracelet\/bubbletea"/d' display.go
        echo "✅ Import removido de display.go"
    fi
fi

# cli.go: remover kong se não usado
if grep -q '"github.com/alecthomas/kong"' cli.go; then
    if ! grep -q "kong\." cli.go; then
        sed -i '/"github.com\/alecthomas\/kong"/d' cli.go
        echo "✅ Import removido de cli.go"
    fi
fi

# ========== 8. VERIFICAR E CORRIGIR OUTROS USOS ==========

# Procurar por outros arquivos que usam ListSessions()
for file in *.go; do
    if [ "$file" != "tmux.go" ] && [ "$file" != "session.go" ] && [ "$file" != "commands.go" ]; then
        if grep -q "ListSessions()" "$file" 2>/dev/null; then
            echo "⚠️ Arquivo $file ainda usa ListSessions() - corrigindo..."
            sed -i 's/ListSessions()/ListSessionsSafe()/g' "$file"
        fi
        if grep -q "GetSessionInfo(" "$file" 2>/dev/null; then
            echo "⚠️ Arquivo $file ainda usa GetSessionInfo() - corrigindo..."
            sed -i 's/GetSessionInfo(/GetSessionInfoSafe(/g' "$file"
        fi
    fi
done

# ========== 9. EXECUTAR GO MOD TIDY E BUILD ==========

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
    echo "  go build ./..."
    echo ""
    echo "E me envie a saída completa para eu corrigir."
    exit 1
fi