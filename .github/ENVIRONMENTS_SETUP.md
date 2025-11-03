# Configuración de Environments para Aprobaciones

Este workflow utiliza **GitHub Environments** para controlar aprobaciones manuales en cada stage.

## 🔧 Configuración en GitHub

### 1. Crear Environments

Ve a: **Settings → Environments → New environment**

Crea estos 4 environments:

#### Environment: `qa-scripts`
- ✅ **Deployment branches**: `develop` only
- ⏱️ **Wait timer**: 0 minutos (deploy automático)
- 👥 **Required reviewers**: Ninguno (automático)
- 📝 **Descripción**: Para hot-reload de scripts sin recompilar
- 🔐 **Variables**: Mismas que `qa`

#### Environment: `qa`
- ✅ **Deployment branches**: `develop` only
- ⏱️ **Wait timer**: 0 minutos (deploy automático)
- 👥 **Required reviewers**: Ninguno (automático)
- 🔑 **Secrets** (opcionales):
  - `QA_SSH_HOST`
  - `QA_SSH_USER`
  - `QA_SSH_KEY`
- 🔐 **Variables**:
  - `QA_DEPLOY_ENABLED=true` (si quieres auto-deploy a servidor)

#### Environment: `staging`
- ✅ **Deployment branches**: `develop` only
- ⏱️ **Wait timer**: 0 minutos
- 👥 **Required reviewers**: **TÚ** (requiere aprobación manual) ⭐
- 🔑 **Secrets** (opcionales):
  - `STAGING_SSH_HOST`
  - `STAGING_SSH_USER`
  - `STAGING_SSH_KEY`
- 🔐 **Variables**:
  - `STAGING_DEPLOY_ENABLED=true` (si tienes servidor staging)

#### Environment: `production`
- ✅ **Deployment branches**: `main` only ⚠️
- ⏱️ **Wait timer**: 5 minutos (tiempo para cancelar si es necesario)
- 👥 **Required reviewers**: **TÚ + otro reviewer** (doble aprobación) ⭐⭐
- 🔑 **Secrets** (opcionales):
  - `PROD_SSH_HOST`
  - `PROD_SSH_USER`
  - `PROD_SSH_KEY`
- 🔐 **Variables**:
  - `PROD_DEPLOY_ENABLED=true` (si quieres auto-deploy a prod)

---

## 🚀 Flujo de Trabajo

### Escenario 1: Solo cambios en Scripts (Lua/XML)

```
Push a develop (solo archivos .lua o .xml)
    ↓
Stage 1: Detect Changes ✅
    ↓
Stage 3A: Sync Scripts to QA ✅ (automático, sin build, sin restart)
    └─> Hot-reload con SIGHUP (servidor NO se reinicia)
```

**Ventajas:**
- ⚡ Muy rápido (~30 segundos)
- 🔄 Hot-reload sin downtime
- 📦 No recompila ni republica releases

---

### Escenario 2: Cambios en C++ (con o sin scripts)

```
Push a develop (archivos .cpp, .hpp, CMakeLists.txt, etc.)
    ↓
Stage 1: Detect Changes ✅
    ↓
Stage 2: Build & Test ✅ (compila + tests, ~8-12 min con cache)
    ↓
Stage 3B: Deploy Binary to QA ✅ (automático, publica qa-latest)
    └─> Deploys binario + scripts, restart completo
    ↓
🛑 PAUSA - Esperando aprobación manual para Staging
    ↓
[Apruebas manualmente en GitHub]
    ↓
Stage 4: Deploy to Staging ✅
```

---

### Escenario 3: Promoción a Producción

```
Merge develop → main
    ↓
Stage 1: Detect Changes ✅
    ↓
Stage 2: Build & Test ✅ (si hay cambios C++, sino se salta)
    ↓
🛑 PAUSA - Esperando aprobación manual para Production
    ↓
[Apruebas manualmente en GitHub]
    ↓
Stage 5: Promote to Production ✅ (descarga qa-latest, publica prod-latest)
```

---

## 📋 Ventajas de este Enfoque

1. **Un solo workflow** en lugar de múltiples archivos
2. **Stages visuales** en GitHub Actions UI
3. **Aprobaciones manuales** como Azure Pipelines
4. **Artifacts compartidos** entre stages (no recompila)
5. **Diferentes ambientes** con sus propios secretos
6. **Historial de aprobaciones** (quién aprobó y cuándo)
7. **Branch protection** por ambiente
8. **Detección inteligente de cambios**:
   - Solo scripts → Hot-reload sin build ni restart (~30s)
   - C++ changes → Build completo + deploy (~8-12 min)
9. **Sin downtime** en deploys de solo scripts

---

## 🎯 Cómo Aprobar un Deploy

1. Ve a **Actions** en GitHub
2. Selecciona el workflow run que está esperando
3. Verás "Review deployments" en amarillo
4. Click en **Review deployments**
5. Selecciona el ambiente (staging/production)
6. Agrega un comentario (opcional)
7. Click **Approve and deploy**

---

## 🔐 Secretos Opcionales

Si NO tienes servidores QA/Staging/Prod configurados aún:
- **NO configures** las variables `*_DEPLOY_ENABLED`
- Los steps de SSH se saltarán automáticamente
- Solo se publicarán los releases (qa-latest, prod-latest)

---

## 🧹 Limpieza

Una vez que este workflow funcione, puedes eliminar:
- ❌ `build-ubuntu.yml`
- ❌ `promote-to-prod.yml`
- ❌ `deploy-qa-olmeraot.yml`
- ✅ Mantener: `deploy-with-stages.yml` (es solo ejemplo)
- ✅ Usar: `ci-cd-pipeline.yml` (este nuevo)

---

## 🛠️ Variables de Configuración

Para habilitar/deshabilitar deploys automáticos a servidores:

**Settings → Environments → [environment] → Add variable**

- `QA_DEPLOY_ENABLED=true` → Deploy automático a QA
- `STAGING_DEPLOY_ENABLED=true` → Deploy automático a Staging (después de aprobar)
- `PROD_DEPLOY_ENABLED=true` → Deploy automático a Prod (después de aprobar)

Si no existen estas variables, solo se publican releases sin deployar.
