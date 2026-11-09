MainScreen.startTutorial = function()
    local currentMods = ActiveMods.getById("default")
--  currentMods:clear()
    if ActiveMods.requiresResetLua(currentMods) then
        getCore():ResetLua("currentGame", "startTutorial")
    end

    deleteAllGameModeSaves(GameMode.TUTORIAL);
    MainScreen.instance:setDefaultSandboxVars()
    getWorld():setGameMode(GameMode.TUTORIAL);
    local worldName = ZombRand(100000)..ZombRand(100000)..ZombRand(100000)..ZombRand(100000);
    getWorld():setWorld(worldName);
    doTutorial(Tutorial1);
    TutorialData = {}
    TutorialData.chosenTutorial = Tutorial1;
    createWorld(worldName);

    GameWindow.doRenderEvent(false);
    forceChangeState(LoadingQueueState.new());
end