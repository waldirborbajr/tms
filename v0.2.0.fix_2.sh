#!/bin/bash
# Script para corrigir incompatibilidades após melhorias

set -e

echo "🔧 Corrigindo incompatibilidades no tms..."

# ========== 1. ADICIONAR VARIÁVEIS EM DISPLAY.GO ==========

if [ -f display.go ]; then
    # Adicionar variáveis no topo se não existirem
    if ! grep -q "var Version" display.go; then
        sed -i '1i\
var Version = "dev"\
var GitCommit = "unknown"\
var BuildTime = "unknown"\
' display.go
    fi

    # Corrigir uso de ListSessions (agora retorna 2 valores)
    sed -i 's/sessions := ListSessions()/sessions, _ := ListSessions()/g' display.go
    sed -i 's/GetSessionInfo(sess)/GetSessionInfo(sess)/g' display.go
    # Ajustar para ignorar erro em GetSessionInfo
    sed -i 's/info := GetSessionInfo(sess)/info, _ := GetSessionInfo(sess)/g' display.go
fi

# ========== 2. CORRIGIR INPUT_MODEL.GO ==========

if [ -f input_model.go ]; then
    # CreateSession agora espera 2 argumentos (nome, dir)
    sed -i 's/CreateSession(input)/CreateSession(input, "")/g' input_model.go
fi

# ========== 3. CORRIGIR KILL_MODEL.GO ==========

if [ -f kill_model.go ]; then
    # ListSessions retorna 2 valores
    sed -i 's/sessions := ListSessions()/sessions, _ := ListSessions()/g' kill_model.go
    # GetSessionInfo retorna 2 valores
    sed -i 's/session := GetSessionInfo(name)/session, _ := GetSessionInfo(name)/g' kill_model.go
fi

# ========== 4. CORRIGIR SESSION.GO ==========

if [ -f session.go ]; then
    # ListSessions retorna 2 valores
    sed -i 's/sessions := ListSessions()/sessions, _ := ListSessions()/g' session.go
    # Criar CreateSessionWithDir como alias para CreateSession
    if ! grep -q "func CreateSessionWithDir" session.go; then
        echo '
// CreateSessionWithDir é um alias para CreateSession (compatibilidade)
func CreateSessionWithDir(name, dir string) error {
    return CreateSession(name, dir)
}' >> session.go
    fi
fi

# ========== 5. VERIFICAR SE HÁ OUTROS ARQUIVOS COM O MESMO PROBLEMA ==========

# Procurar por usos de ListSessions() sem tratamento de erro
for file in *.go; do
    if grep -q ":= ListSessions()" "$file" && [ "$file" != "tmux.go" ] && [ "$file" != "commands.go" ]; then
        echo "⚠️ Arquivo $file pode precisar de ajuste manual para ListSessions()"
    fi
    if grep -q ":= GetSessionInfo(" "$file" && [ "$file" != "tmux.go" ]; then
        echo "⚠️ Arquivo $file pode precisar de ajuste manual para GetSessionInfo()"
    fi
done

# ========== 6. EXECUTAR GO MOD TIDY E BUILD ==========

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
echo "📋 Comandos disponíveis:"
echo "  ./tms --help"