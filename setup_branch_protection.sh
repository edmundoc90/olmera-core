#!/bin/bash
# Script para configurar protecciones de rama en main
# Requisito: GitHub CLI (gh) instalado y autenticado
# Uso: ./setup_branch_protection.sh

set -euo pipefail

REPO="${1:-edmundoc90/olmera-core}"
BRANCH="main"

echo "🔒 Configurando protecciones de rama para: $REPO ($BRANCH)"
echo ""

# Verificar que gh CLI está instalado
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) no está instalado"
    echo "   Instala con: https://cli.github.com/"
    exit 1
fi

# Verificar autenticación
if ! gh auth status &> /dev/null; then
    echo "❌ Error: No estás autenticado con GitHub CLI"
    echo "   Ejecuta: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI listo"
echo ""

# Crear regla de protección con todos los requerimientos
echo "📝 Aplicando regla de protección..."
echo ""

# Nota: gh API aún no tiene soporte completo para reglas complejas
# Usamos curl con gh auth token
TOKEN=$(gh auth token)

cat > /tmp/branch_protection.json << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Stage 1: Detect Changes",
      "Stage 1B: Detect PR Changes (main only)"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_deletions": false,
  "allow_force_pushes": false,
  "require_linear_history": true,
  "required_conversation_resolution": false,
  "allow_auto_merge": true
}
EOF

RESPONSE=$(curl -fsSL \
  -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d @/tmp/branch_protection.json \
  "https://api.github.com/repos/$REPO/branches/$BRANCH/protection" \
  2>/dev/null || echo "{\"message\": \"Error en API\"}")

if echo "$RESPONSE" | grep -q "\"url\""; then
    echo "✅ Protección de rama configurada exitosamente"
    echo ""
    echo "📋 Resumen de configuración:"
    echo "   ✓ Requerir PR antes de mergear"
    echo "   ✓ Requerir 1 aprobación"
    echo "   ✓ Requerir status checks en verde:"
    echo "     - Stage 1: Detect Changes"
    echo "     - Stage 1B: Detect PR Changes (main only)"
    echo "   ✓ Requerir rama actualizada antes de mergear"
    echo "   ✓ Prohibir force push"
    echo "   ✓ Prohibir eliminación de rama"
    echo "   ✓ Requerir historio lineal"
    echo "   ✓ Permitir auto-merge"
else
    echo "⚠️  Respuesta de API:"
    echo "$RESPONSE" | head -20
    echo ""
    echo "💡 Alternativa manual:"
    echo "   1. Ir a: https://github.com/$REPO/settings/branches"
    echo "   2. Crear/editar regla para '$BRANCH'"
    echo "   3. Aplicar configuración según DEPLOYMENT_FLOW.md"
fi

echo ""
echo "✨ Configuración completada"
rm -f /tmp/branch_protection.json
