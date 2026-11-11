MainScreen.startTutorial = function()
    local currentMods = ActiveMods.getById("default")
--  currentMods:clear()
    if ActiveMods.requiresResetLua(currentMods) then
        getCore():ResetLua("currentGame", "startTutorial")
    end

    -- 42.22+: deleteAllGameModeSaves takes a GameMode object; 42.21 has no GameMode.TUTORIAL and both calls take the id string
    local mode = GameMode and GameMode.TUTORIAL or "Tutorial"
    deleteAllGameModeSaves(mode);
    MainScreen.instance:setDefaultSandboxVars()
    getWorld():setGameMode(mode);
    local worldName = ZombRand(100000)..ZombRand(100000)..ZombRand(100000)..ZombRand(100000);
    getWorld():setWorld(worldName);
    doTutorial(Tutorial1);
    TutorialData = {}
    TutorialData.chosenTutorial = Tutorial1;
    createWorld(worldName);

    GameWindow.doRenderEvent(false);
    forceChangeState(LoadingQueueState.new());
end