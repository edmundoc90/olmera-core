# 🚀 OlmeraOT CI/CD Pipeline

Este documento describe el flujo de integración y despliegue continuo del proyecto **OlmeraOT**, basado en GitHub Actions y despliegues automatizados en VPS.

## 📘 Flujo de Trabajo Principal

> ⚠️ **IMPORTANTE**: Este documento fue actualizado el 2 de noviembre de 2025 para reflejar los últimos cambios en nuestro proceso de CI/CD.

### Desarrollo de Features
1. **Crear Feature Branch**
   ```bash
   # Crear branch desde develop (para tener últimos cambios)
   git checkout -b feature/xyz develop
   ```

2. **Desarrollo y Pruebas en QA**
   - Desarrollar en feature branch
   - Push frecuente a la feature branch
   - Cada push dispara:
     - Build (si hay cambios C++) o sync (si son scripts)
     - Deploy automático a QA
     - Notificación al equipo de QA

3. **Sistema de Feature Flags**
   ```lua
   -- En config.lua o similar
   FeatureFlags = {
     feature_xyz = false,  -- disabled por defecto
     -- otros flags...
   }
   ```

   ```lua
   -- En el código Lua
   if FeatureFlags.feature_xyz then
     -- nuevo comportamiento
   else
     -- comportamiento actual
   end
   ```
   - Esto dispara:
     1. Build específico para la feature
     2. Deploy a ambiente QA aislado (puerto diferente)
     3. Tests automatizados en ambiente limpio

4. **Pruebas de Integración**
   - Una vez que la feature pasa pruebas aisladas:
     1. Actualizar feature branch con main:
        ```bash
        git checkout feature/xyz
        git rebase main
        ```
     2. Crear PR feature → develop
     3. Build y tests en GitHub Actions
     4. Deploy a QA integrado (develop)
   
5. **Pruebas en QA (Integrado)**
   - El merge a develop dispara:
     1. Build y tests completos
     2. Publica binario en release `qa-latest`
     3. Deploy automático a VPS QA
   - Verificación de integración con otras features
   - Pruebas de regresión automatizadas

5. **Promoción a PROD**
   - Una vez validado en QA:
     1. Crear PR develop → main
     2. Aprobar PR (requiere reviews)
     3. Usar workflow "Promote QA Binary to Prod"
     4. Deploy a PROD (sin restart automático)

## 🛠️ Ambientes

### QA (Ambiente de Pruebas)
- Branch: `develop`
- Release tag: `qa-latest`
- Deploy automático
- Restart automático
- Logs: `/var/log/olmeraot/qa.log`
- URL: https://qa.example.com

### PROD (Producción)
- Branch: `main`
- Release tag: `prod-latest`
- Deploy manual o por PR
- Restart manual (seguridad)
- Logs: `/var/log/olmeraot/prod.log`
- URL: https://prod.example.com

## 🔒 Protecciones y Ambientes

### Branch Protection Rules
```yaml
# develop (rama integradora)
- name: develop
  protection:
    required_pull_request_reviews:
      required_approving_review_count: 1
      dismiss_stale_reviews: true
    required_status_checks:
      strict: true
      contexts: 
        - 'build-ubuntu/ubuntu-22.04-linux-release'
        - 'integration-tests'
        - 'e2e-tests'
    enforce_admins: true
    required_linear_history: true  # Forzar rebase

# main (producción)
- name: main
  protection:
    required_pull_request_reviews:
      required_approving_review_count: 2
      dismiss_stale_reviews: true
    required_status_checks:
      strict: true
      contexts:
        - 'build-ubuntu/ubuntu-22.04-linux-release'
        - 'integration-tests'
        - 'e2e-tests'
        - 'qa-validation'
    enforce_admins: true
    required_linear_history: true
```

### Ambientes de Prueba

### Pruebas en QA Compartido
   - Un solo ambiente QA pero con feature flags
   - Sistema de backup/restore rápido
   - Proceso de pruebas coordinado:
     1. Desarrollador hace push a feature branch
     2. CI detecta cambios y:
        - Si hay cambios C++: build + deploy
        - Si son scripts: sync + reload scripts
     3. Sistema notifica a QA vía Discord/Slack
     4. QA activa feature flag específico
     5. Si algo falla: restore rápido desde último backup

   Ejemplo de workflow:
   ```bash
   # 1. Developer push a feature branch
   git push origin feature/xyz

   # 2. CI detecta cambios y despliega
   # (Automático via GitHub Actions)

   # 3. QA activa feature para pruebas
   /feature enable xyz

   # 4. Si hay problemas, rollback rápido
   /backup restore latest
   ```
   
   Ejemplo de URL para pruebas:
   ```
   # Para PR #123:
   Server: qa.example.com
   Puerto: 7294 (7171 + 123)
   Logs: /var/log/olmeraot/pr-123/
   ```

   Commands para manejo del preview:
   ```bash
   # Crear preview
   sudo docker run -d \
     --name olmeraot-pr-123 \
     -p 7294:7171 \
     -v /data/olmeraot/pr-123:/app/data \
     -v /var/log/olmeraot/pr-123:/app/logs \
     olmeraot:latest

   # Ver logs
   tail -f /var/log/olmeraot/pr-123/server.log

   # Actualizar preview
   sudo docker restart olmeraot-pr-123

   # Eliminar preview
   sudo docker rm -f olmeraot-pr-123
   ```

2. **QA Integrado (develop)**
   - Puerto: 7171
   - Integración de todas las features
   - DB persistente
   - Configuración similar a PROD
   - Pruebas de regresión automáticas

3. **Staging (pre-prod)**
   - Puerto: 7172
   - Espejo de PROD
   - DB clonada de PROD
   - Configuración idéntica a PROD
   - Pruebas finales antes de PROD

## 🔄 Workflows y Tipos de Cambios

### Clasificación de Cambios

1. **Cambios que Requieren Build**
   - Modificaciones en `/src/**/*.{cpp,hpp,h}`
   - Cambios en `CMakeLists.txt`
   - Actualizaciones de dependencias C++ (vcpkg.json)

2. **Cambios Sin Build**
   - Scripts Lua (`/data/**/*.lua`)
   - Configuraciones XML (`/data/**/*.xml`)
   - Archivos de datos (items, monsters, etc.)

### Workflows Según Tipo de Cambio

| Workflow | Trigger | Tipo | Función |
|----------|---------|------|---------|
| `build-ubuntu.yml` | PR/push con cambios en src/ | C/C++ | Compila, tests, publica binario |
| `sync-scripts-qa.yml` | PR/push con cambios .lua/.xml | Scripts | Sincroniza scripts a QA |
| `deploy-qa-olmeraot.yml` | Push develop | Ambos | Deploy completo a QA |
| `promote-qa-to-prod.yml` | Manual | Binario | Promueve binario QA → PROD |
| `deploy-prod.yml` | Push main | Ambos | Deploy a PROD (sin restart) |

### Path Filters en Workflows
```yaml
# En build-ubuntu.yml
on:
  pull_request:
    paths:
      - "src/**"
      - "CMakeLists.txt"
      - "vcpkg.json"
  push:
    paths:
      - "src/**"
      - "CMakeLists.txt"
      - "vcpkg.json"
    branches:
      - main
      - develop

# En sync-scripts-qa.yml
on:
  pull_request:
    paths:
      - "data/**/*.lua"
      - "data/**/*.xml"
  push:
    paths:
      - "data/**/*.lua"
      - "data/**/*.xml"
    branches:
      - develop

## 📋 Mejores Prácticas

### Testing por Etapas y Tipo de Cambio

1. **Testing Local**
   
   a) Para cambios en C/C++:
   ```bash
   # Build y tests
   mkdir build && cd build
   cmake -DCMAKE_BUILD_TYPE=Debug ..
   make
   ctest -V -R unit
   
   # Análisis estático
   cppcheck src/
   clang-tidy src/*.cpp
   ```

   b) Para cambios en Lua:
   ```bash
   # Validación sintáctica
   luacheck data/**/*.lua
   
   # Test de carga de scripts
   ./test-lua-scripts.sh
   
   # Validación de XML
   xmllint --schema schema.xsd data/**/*.xml
   ```

2. **Feature Preview Testing**
   - Pruebas funcionales aisladas
   - Testing de performance baseline
   - Verificación de migraciones
   ```bash
   # Verificar feature en ambiente aislado
   curl -v http://qa.example.com:$FEATURE_PORT/health
   tail -f /var/log/olmeraot/feature-$PR_NUM.log
   ```

3. **Testing de Integración (develop)**
   - Pruebas de integración con otras features
   - Tests de regresión automáticos
   - Pruebas de carga básicas
   ```bash
   # Ejecutar suite de integración
   ./run-integration-tests.sh --env=qa
   ./run-load-tests.sh --users=100
   ```

4. **Testing Pre-Prod (staging)**
   - Pruebas end-to-end
   - Verificación de migraciones con datos reales
   - Tests de performance comparativos
   ```bash
   # Comparar métricas con PROD
   ./compare-metrics.sh --env=staging --vs=prod
   ```

### Code Review
- Requerir al menos 1 review para merge a develop
- Requerir 2 reviews para merge a main
- Verificar pruebas aisladas antes de revisar
- Validar métricas de performance
- No hacer bypass de protecciones

### Commits y PRs
- Usar commits atómicos y descriptivos
- Incluir ID de ticket/issue en commits
- PR debe incluir:
  - Descripción clara de cambios
  - Resultados de pruebas aisladas
  - Plan de rollback
  - Impacto en performance
- Mantener PRs pequeños y enfocados

### Deploy y Rollback
```bash
# Revisar logs QA
tail -f /var/log/olmeraot/qa.log

# Verificar servicio
systemctl status olmeraot-qa.service

# Rollback rápido
cd /opt/olmeraot/qa/bin
cp olmeraot olmeraot.bak  # Antes de actualizar
cp olmeraot.bak olmeraot  # Para rollback
sudo systemctl restart olmeraot-qa.service
```

### Monitoreo
- Revisar logs después de cada deploy
- Verificar métricas básicas (CPU, memoria)
- Alertas configuradas para errores críticos

## 🔍 Troubleshooting

### Deploy Fallido
1. Verificar logs de GitHub Actions
2. Comprobar permisos SSH en VPS
3. Validar SHA256SUMS del binario
4. Revisar logs del servicio

### Rollback de Emergencia
1. Identificar último release estable
2. Usar workflow dispatch manual
3. Verificar servicios post-rollback

## 📈 Propuestas de Mejora

1. **Deploy Preview para PRs**
   - Crear ambientes efímeros por PR
   - Permite pruebas paralelas sin conflictos

2. **Tests Automatizados**
   - Ampliar cobertura de tests
   - Añadir tests de integración
   - Automatizar pruebas de carga

3. **Versionado Semántico**
   - Implementar GitVersion
   - Tags automáticos en releases
   - Changelog automatizado

## 🧪 Ejemplos prácticos de deploy y recarga en QA

1) Sincronizar solo datapack (scripts/items/monsters) y forzar recarga (desde el runner o manualmente en VPS):

```bash
# Desde el runner (ejecutado por el workflow SSH)
rsync -av --delete data/ /opt/olmeraot/qa/data/
rsync -av --delete overrides/ /opt/olmeraot/qa/overrides/

# Trigger hot-reload vía SIGHUP (handler del servidor recarga items/events/scripts)
sudo systemctl kill -s HUP olmeraot-qa.service || sudo kill -HUP $(pidof olmeraot)

# Verificar logs
journalctl -u olmeraot-qa.service --no-pager -n 200
tail -n 200 /var/log/olmeraot/qa.log
```

2) Deploy de binario + datapack (cuando cambia C++):

```bash
# Copiar binario y descomprimir
unzip -o olmeraot-linux-x86_64.zip -d /opt/olmeraot/qa/bin/
chmod +x /opt/olmeraot/qa/bin/olmeraot

# Sync datapack
rsync -av --delete data/ /opt/olmeraot/qa/data/

# Reiniciar servicio (binario cambiado requiere restart)
sudo systemctl restart olmeraot-qa.service

# Verificar estado
systemctl --no-pager --lines=5 status olmeraot-qa.service
tail -n 200 /var/log/olmeraot/qa.log
```

3) Recargar tipos específicos (usar Game.reload desde Lua o talkaction admin):

```lua
-- Recargar scripts (desde lua):
Game.reload(13) -- RELOAD_TYPE_SCRIPTS

-- Recargar monsters/items:
Game.reload(15) -- RELOAD_TYPE_MONSTERS
Game.reload(14) -- RELOAD_TYPE_ITEMS
```

4) Cargar un mapa nuevo sin reiniciar (si aplica):

```lua
-- Desde Lua: carga asincrónica del mapa (usa la API expuesta en Game.loadMap)
Game.loadMap("/opt/olmeraot/qa/data/world/newmap.otbm")
```

5) Backup rápido antes de deploy de QA (workflow ya hace backup automático):

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/backups/olmeraot/qa/${TIMESTAMP}
mkdir -p "${BACKUP_DIR}"
systemctl stop olmeraot-qa.service
cp -a /opt/olmeraot/qa/bin/olmeraot "${BACKUP_DIR}/"
cp -a /opt/olmeraot/qa/data "${BACKUP_DIR}/"
# opcional: pg_dump
systemctl start olmeraot-qa.service
```

---

**Autor:** J. Edmundo Castellanos  
**Última actualización:** 2025-11-02  
**Versión:** 1.0.0