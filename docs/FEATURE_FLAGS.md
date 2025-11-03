# Sistema de Feature Flags

## Descripción General
El sistema de Feature Flags permite habilitar/deshabilitar características específicas en tiempo real sin necesidad de reiniciar el servidor. Esto facilita el testing en QA y proporciona un mecanismo de rollback rápido.

## Ubicación de Archivos
- `data/libs/core/feature_flags.lua`: Sistema core de feature flags
- `data/scripts/talkactions/god/feature.lua`: Comandos para gestionar features
- `data/feature_flags.json`: Persistencia del estado de features

## Uso en Desarrollo

### 1. Registrar una Nueva Feature
```lua
-- En tu archivo de feature (ejemplo: data/scripts/features/new_combat_system.lua)
FeatureFlags.register("new_combat_system", {
    description = "Nuevo sistema de combate con efectos mejorados",
    author = "Edmundo",
    dependencies = {"base_combat"} -- opcional
})

-- Usar el flag en el código
if FeatureFlags.isEnabled("new_combat_system") then
    -- Nuevo comportamiento
else
    -- Comportamiento actual
end
```

### 2. Comandos In-Game
```
/feature enable <featureId>  -- Habilitar feature
/feature disable <featureId> -- Deshabilitar feature
/feature info <featureId>    -- Ver detalles de feature
/feature list               -- Listar todas las features
```

### 3. Ejemplos de Uso

#### Feature Simple
```lua
-- data/scripts/features/double_exp.lua
FeatureFlags.register("double_exp", {
    description = "Double exp weekend",
    author = "Edmundo"
})

-- En el código donde se calcula exp
function Player:addExperience(exp)
    if FeatureFlags.isEnabled("double_exp") then
        exp = exp * 2
    end
    -- resto del código...
end
```

#### Feature con Dependencias
```lua
-- data/scripts/features/special_boss.lua
FeatureFlags.register("special_boss", {
    description = "Nuevo boss con mecánicas especiales",
    author = "Edmundo",
    dependencies = {"new_combat_system"}
})

-- En el código del boss
function Boss:onThink()
    if FeatureFlags.isEnabled("special_boss") then
        -- Comportamiento especial
    else
        -- Comportamiento normal
    end
end
```

## Workflow con Feature Flags

1. **Desarrollo**
   ```bash
   # 1. Crear feature branch
   git checkout -b feature/xyz develop

   # 2. Implementar feature con flag
   # Editar archivos, añadir FeatureFlags.register(), etc.

   # 3. Push a QA
   git push origin feature/xyz
   ```

2. **Testing en QA**
   ```
   # QA habilita la feature
   /feature enable xyz

   # Si hay problemas, deshabilitar
   /feature disable xyz

   # Ver estado
   /feature info xyz
   ```

3. **Merge a Develop**
   - Feature permanece bajo flag hasta validación completa
   - Se puede habilitar/deshabilitar en cualquier momento
   - Rollback instantáneo si hay problemas

## Mejores Prácticas

1. **Naming de Features**
   - Usar nombres descriptivos: `new_combat_system`
   - Prefijos para categorías: `combat_`, `quest_`, `spell_`

2. **Granularidad**
   - Dividir features grandes en sub-features
   - Ejemplo: `combat_effects`, `combat_damage`, `combat_animations`

3. **Documentación**
   - Descripción clara en el registro
   - Documentar dependencias
   - Mantener una lista de features activas

4. **Testing**
   - Probar tanto enabled como disabled
   - Verificar dependencias
   - Documentar casos de prueba

## Seguridad
- Solo GODs pueden gestionar features
- Los cambios se persisten en `feature_flags.json`
- Se registran todos los cambios en logs

## Monitoreo
- Estado actual: `/feature list`
- Detalles específicos: `/feature info xyz`
- Logs de cambios en `/var/log/olmeraot/qa.log`