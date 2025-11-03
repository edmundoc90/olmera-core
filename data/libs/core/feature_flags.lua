--[[
  Feature Flags System
  Archivo: data/libs/core/feature_flags.lua
--]]

-- Tabla global de features
FeatureFlags = {
  -- Estado de features
  _flags = {},
  
  -- Registro de features y sus metadatos
  _registry = {},
  
  -- Archivo de persistencia
  _savePath = "data/feature_flags.json"
}

-- Registrar una nueva feature
function FeatureFlags.register(featureId, metadata)
  if not featureId then
    error("Feature ID is required")
  end

  FeatureFlags._registry[featureId] = {
    id = featureId,
    description = metadata.description or "",
    author = metadata.author or "unknown",
    createdAt = os.time(),
    dependencies = metadata.dependencies or {},
    isEnabled = false
  }
  
  -- Estado inicial desde configuración
  FeatureFlags._flags[featureId] = false
end

-- Habilitar una feature
function FeatureFlags.enable(featureId)
  if not FeatureFlags._registry[featureId] then
    return false, "Feature not registered"
  end
  
  -- Verificar dependencias
  for _, dep in ipairs(FeatureFlags._registry[featureId].dependencies) do
    if not FeatureFlags.isEnabled(dep) then
      return false, string.format("Dependency '%s' must be enabled first", dep)
    end
  end
  
  FeatureFlags._flags[featureId] = true
  FeatureFlags.save()
  return true
end

-- Deshabilitar una feature
function FeatureFlags.disable(featureId)
  if not FeatureFlags._registry[featureId] then
    return false, "Feature not registered"
  end
  
  -- Verificar dependientes
  for id, feature in pairs(FeatureFlags._registry) do
    if feature.dependencies[featureId] and FeatureFlags.isEnabled(id) then
      return false, string.format("Feature '%s' depends on this", id)
    end
  end
  
  FeatureFlags._flags[featureId] = false
  FeatureFlags.save()
  return true
end

-- Verificar si una feature está activa
function FeatureFlags.isEnabled(featureId)
  return FeatureFlags._flags[featureId] == true
end

-- Listar todas las features
function FeatureFlags.list()
  local features = {}
  for id, metadata in pairs(FeatureFlags._registry) do
    features[id] = {
      description = metadata.description,
      author = metadata.author,
      enabled = FeatureFlags.isEnabled(id),
      dependencies = metadata.dependencies
    }
  end
  return features
end

-- Guardar estado
function FeatureFlags.save()
  local file = io.open(FeatureFlags._savePath, "w")
  if file then
    file:write(json.encode(FeatureFlags._flags))
    file:close()
    return true
  end
  return false
end

-- Cargar estado
function FeatureFlags.load()
  local file = io.open(FeatureFlags._savePath, "r")
  if file then
    local content = file:read("*all")
    file:close()
    FeatureFlags._flags = json.decode(content)
    return true
  end
  return false
end

-- Inicialización
FeatureFlags.load()