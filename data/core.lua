DATA_DIRECTORY = configManager.getString(configKeys.DATA_DIRECTORY)
CORE_DIRECTORY = configManager.getString(configKeys.CORE_DIRECTORY)

-- Pipeline test: tar+ssh extraction in place
dofile(CORE_DIRECTORY .. "/global.lua")
dofile(CORE_DIRECTORY .. "/libs/libs.lua")
dofile(CORE_DIRECTORY .. "/stages.lua")
