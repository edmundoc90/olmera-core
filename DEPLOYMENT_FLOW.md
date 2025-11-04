# 🚀 Flujo de Despliegue CI/CD Unificado

## Resumen Ejecutivo

Este documento describe el flujo completo de despliegue desde feature branches hasta producción, garantizando que:
- **QA** recibe cambios de forma automática para validación
- **Producción** recibe SOLO los cambios de la feature aprobada (no cambios acumulados de develop)
- **Main** nunca se reconstruye; promueve binarios probados desde QA

---

## 📋 Configuración Inicial (Una sola vez)

### 1. Protecciones de Rama en `main`

Acceder a: **Settings → Branches → Branch protection rules**

#### Crear regla para `main`:

- ✅ **Require a pull request before merging**
  - Require approvals: `1`
  - Dismiss stale pull request approvals when new commits are pushed
  - Require review from code owners: `false` (opcional)

- ✅ **Require status checks to pass before merging**
  - Require branches to be up to date before merging
  - Status checks required:
    - `Stage 1: Detect Changes`
    - `Stage 1B: Detect PR Changes (main)` (aparecerá después del primer run)

- ✅ **Restrict who can push to matching branches**
  - Allow force pushes: `false`
  - Allow deletions: `false`

- ✅ **Require a linear history**

- ✅ **Allow auto-merge**

### 2. Configurar Merge Strategy

**Settings → General → Pull Request → Default merge strategy**
- ✅ Seleccionar **Squash and merge** como única opción
- Esto mantiene el historio limpio en main y facilita cherry-pick en el futuro

---

## 🔄 Flujo Operacional

```
┌─────────────────────────────────────────────────────────────────┐
│                     FEATURE BRANCH                              │
│  (feature/my-feature)                                           │
└───────────────────────┬─────────────────────────────────────────┘
                        │ Push changes
                        ↓
┌─────────────────────────────────────────────────────────────────┐
│              STAGE 1: CAMBIOS DETECTADOS                         │
│  ✓ paths-filter detecta: cpp, scripts, overrides                │
└───────────────────────┬─────────────────────────────────────────┘
                        │ Si cpp=true
                        ↓
                 ┌──────────────┐
                 │ BUILD & TEST │ (ubuntu-22.04, gcc-13, CMake)
                 └──────┬───────┘
                        │ ✓ Build OK, tests pass
                        ↓
            ┌───────────────────────────┐
            │ Publish qa-latest release │
            │ (binary + SHA256)         │
            └───────┬───────────────────┘
                    │
        ┌───────────┴────────────┐
        │ Si scripts=true        │ Si cpp=true
        ↓                        ↓
    ┌────────────┐      ┌───────────────┐
    │ Sync       │      │ Deploy Binary │
    │ Scripts QA │      │ + Binary      │
    │ (SIGHUP)   │      │ Deploy QA     │
    └──────┬─────┘      └───────┬───────┘
           │                     │
           └──────────┬──────────┘
                      ↓
        ┌──────────────────────────────┐
        │ STAGE 2: QA DEPLOYMENT OK    │
        │ Notify: ✅ Changes in QA     │
        └──────────┬───────────────────┘
                   │
        ┌──────────┴──────────┐
        │ TEST IN QA SERVER   │
        │ Validar funcionalidad│
        │ Verificar rendimiento│
        └──────────┬──────────┘
                   │ ✅ QA OK
                   ↓
        ┌──────────────────────────────┐
        │ APROBA​R PR: feature→develop   │
        │ (Manual click en GitHub)      │
        └──────────┬───────────────────┘
                   │ Merge (Squash)
                   ↓
        ┌──────────────────────────────┐
        │ STAGE 3: AUTO-RELEASE PR     │
        │ Workflow: auto-release-pr    │
        │ Acciones:                    │
        │ 1. Crea rama release/pr-XXX  │
        │    desde main                │
        │ 2. Aplica SOLO diff del PR   │
        │    (no todo develop)         │
        │ 3. Abre PR a main            │
        │ 4. Etiqueta: prod-promotion  │
        └──────────┬───────────────────┘
                   │
        ┌──────────┴──────────┐
        │ TEST IN MAIN        │
        │ PR checks en verde  │
        │ CI/CD valida cambios│
        └──────────┬──────────┘
                   │ ✅ Checks OK
                   ↓
        ┌──────────────────────────────┐
        │ APROBAR PR: release/pr-XXX   │
        │ →main                        │
        │ (Manual click en GitHub)      │
        └──────────┬───────────────────┘
                   │ Merge (Squash)
                   ↓
        ┌──────────────────────────────┐
        │ STAGE 4: PROD DEPLOYMENT     │
        │ changes-main-pr detecta solo │
        │ cambios del PR mergeado      │
        │ if cpp=true → deploy binary  │
        │ if scripts=true → sync scripts│
        └──────────┬───────────────────┘
                   │
        ┌──────────┴──────────┐
        │ PRODUCTION OK       │
        │ ✅ Cambios en Prod  │
        │ health-check +OK    │
        └─────────────────────┘
```

---

## 📝 Paso a Paso

### Paso 1: Crear Feature Branch

```bash
git checkout -b feature/my-feature develop
# Hacer cambios
git add .
git commit -m "feat: descripción"
git push origin feature/my-feature
```

### Paso 2: Abrir PR a Develop

1. En GitHub: **Pull Requests → New PR**
2. Base: `develop`, Compare: `feature/my-feature`
3. Título descriptivo, descripción de cambios
4. Crear PR

**Resultado esperado:**
- CI/CD corre `changes` job (detección)
- Si hay cambios C++: `build`, `deploy-qa` corren
- Si hay cambios scripts: `sync-scripts-qa` corre
- Dentro de 5-15 min: cambios en **QA** (servidor qa.olmeraot.com)

### Paso 3: Validar en QA

1. Acceder a **QA server** (credenciales en vault)
2. Probar funcionalidades modificadas
3. Verificar logs si es necesario
4. Confirmar no hay errores

### Paso 4: Aprobar PR a Develop

1. Volver a la PR en GitHub
2. Hacer click en **"Approve"** (revisión)
3. Click en **"Squash and merge"** (merge automático si checks pasan)
4. Confirmar

**Resultado esperado:**
- PR se mergea a `develop`
- Workflow `auto-release-pr.yml` se dispara automáticamente (evento: PR closed + merged)
- **Dentro de 2-3 min:** se crea `release/pr-123` desde `main`
- **Dentro de 2-3 min:** se abre PR `release/pr-123 → main` con etiqueta `prod-promotion`

### Paso 5: Esperar a que Auto-Release PR esté Lista

Verificar en la PR automática a `main`:
- Status checks en verde ✅ (al menos 2-3 min)
- Título: `Release: PR #123 to main (only feature changes)`
- Body: describe que solo contiene cambios de esa feature

### Paso 6: Aprobar PR a Main (Production)

1. En la PR auto-generada a `main`
2. Revisar cambios (deben ser SOLO los de tu feature)
3. Click **"Approve"**
4. Click **"Squash and merge"** (única opción disponible)

**Resultado esperado:**
- PR se mergea a `main`
- Workflow `ci-cd-pipeline.yml` detecta cambios en `main` via `changes-main-pr`
- Si cpp=true: **deploy-qa** y **promote-production** corren (promueven binarios)
- Si scripts=true y cpp=false: **deploy-scripts-prod** corre (solo scripts)
- **Dentro de 10-20 min:** cambios en **Production** (servidor olmeraot.com)

---

## 🔍 Monitoreo de Jobs

### Ver Status en GitHub Actions

1. **Actions → Seleccionar workflow**
2. Buscar el run más reciente
3. Expandir jobs para ver detalles
4. Si hay errores, ver logs completos

### Workflows Principales

| Workflow | Trigger | Duración | Resultado |
|----------|---------|----------|-----------|
| `ci-cd-pipeline.yml` | push `develop`/`main`, PR | 5-30 min | QA o Prod deployment |
| `auto-release-pr.yml` | PR merged to `develop` | 2-3 min | PR a `main` creado |

---

## ⚙️ Variables de Control (Opcional)

Para casos especiales, puedes usar variables en Settings → Secrets and variables → Variables:

| Variable | Default | Uso |
|----------|---------|-----|
| `PROD_DEPLOY_ENABLED` | true | Control global de deploys a producción |
| `QA_DEPLOY_ENABLED` | true | Control global de deploys a QA |
| `USE_OLD_DEVELOP_TO_MAIN_FLOW` | false | **No usar** (job deprecated) |

---

## 🆘 Troubleshooting

### Auto-Release PR no se crea

**Síntomas:**
- Mergeaste PR a develop pero no hay PR automático a main después de 5 min

**Causas y Soluciones:**
1. Workflow `auto-release-pr.yml` no existe o tiene error
   - Verificar: `.github/workflows/auto-release-pr.yml` existe
   - Chequear: **Actions → Runs** para ver errores
2. El merge no fue "merge commit" sino rebase o squash
   - Solución manual: crear rama `release/pr-XXX` desde `main`, cherry-pick o apply diff manualmente, abrir PR

### Cambios inesperados en PR a main

**Síntomas:**
- PR a `main` contiene cambios que no esperabas

**Causa:**
- El `git apply` falló y usaste fallback manual (rebase)

**Solución:**
- Eliminar la rama `release/pr-XXX` y PR
- Crear nueva rama desde `main` limpio
- Usar: `git cherry-pick <commit>` solo de tu feature

### Deploy a Production no corre

**Síntomas:**
- Mergeaste PR a `main` pero `promote-production` o `deploy-scripts-prod` no corrió

**Causas:**
1. `PROD_DEPLOY_ENABLED` está en false
   - Solución: revisar variable en Settings
2. `changes-main-pr` detectó cpp=false y scripts=false
   - Solución: revisar qué cambios había en el PR (tal vez solo docs)
3. Checks requeridos no pasaron
   - Solución: fix en PR, requiere nueva PR a main

---

## 📚 Referencias Útiles

- [GitHub Actions: Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub Actions: Pull Request Events](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request)
- [Git: Cherry-pick](https://git-scm.com/docs/git-cherry-pick)

---

**Última actualización:** 4 de noviembre de 2025
**Status:** ✅ Activo y en uso

