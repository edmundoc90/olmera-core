DATA_DIRECTORY = configManager.getString(configKeys.DATA_DIRECTORY)
CORE_DIRECTORY = configManager.getString(configKeys.CORE_DIRECTORY)

dofile(CORE_DIRECTORY .. "/global.lua")
dofile(CORE_DIRECTORY .. "/libs/libs.lua")
dofile(CORE_DIRECTORY .. "/stages.lua")

-- test: clean scripts-only deployment with protected files (2024-11-03)
-- deploy: scripts-only validation run
