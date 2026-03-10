MainScreen.startTutorial = function()
    local currentMods = ActiveMods.getById("default")
--  currentMods:clear()
    if ActiveMods.requiresResetLua(currentMods) then
        getCore():ResetLua("currentGame", "startTutorial")
    end

    deleteAllGameModeSaves("Tutorial");
    MainScreen.instance:setDefaultSandboxVars()
    getWorld():setGameMode("Tutorial");
    local worldName = ZombRand(100000)..ZombRand(100000)..ZombRand(100000)..ZombRand(100000);
    getWorld():setWorld(worldName);
    doTutorial(Tutorial1);
    TutorialData = {}
    TutorialData.chosenTutorial = Tutorial1;
    createWorld(worldName);
--[[
    -- menu activated via joypad, we disable the joypads and will re-set them automatically when the game is started
    if MainScreen.instance.joyfocus then
        local joypadData = MainScreen.instance.joyfocus
        joypadData.focus = nil;
        updateJoypadFocus(joypadData)
        JoypadState.count = 0
        JoypadState.players = {};
        JoypadState.joypads = {};
        JoypadState.forceActivate = joypadData.id;
    end
--]]
    GameWindow.doRenderEvent(false);
    forceChangeState(LoadingQueueState.new());
end