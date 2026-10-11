-- CAW MORPH SCRIPT (COMPLETE WITH ANIMATIONS, KEYBINDS & RAW GITHUB MODEL)
local modelName = "CawLive"
local modelUrl = "https://raw.githubusercontent.com/Homelessman1223/Caw/main/Caw.rbxm?v=" .. tostring(os.time())
local fileName = "CawModel.rbxm"

-- CONFIGURATION
local heightOffset = 0
local toolGripOffset = CFrame.new(0, 0, 0)
local isThirdPerson = true 

-- KEYBINDS FOR ANIMATIONS
local CAW_KEY = Enum.KeyCode.Z  -- Press Z to Caw
local PECK_KEY = Enum.KeyCode.X -- Press X to Peck

-- ANIMATION IDs
local animIds = {
    Idle = "rbxassetid://98086518736203",
    Fly  = "rbxassetid://115856794497552",
    Caw  = "rbxassetid://121686166701305",
    Peck = "rbxassetid://113608529185105",
}

if _G.morphCleanup then
    pcall(_G.morphCleanup)
end

local Players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local function applyMorph(character)
    if not character then return end

    local Humanoid = character:WaitForChild("Humanoid", 5) or character:FindFirstChildOfClass("Humanoid")
    local RootPart = character:WaitForChild("HumanoidRootPart", 5) or character:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera

    if not Humanoid or not RootPart then return end

    -- Download fresh Caw model from GitHub
    local success, content = pcall(function() return game:HttpGet(modelUrl) end)
    if success and content then
        writefile(fileName, content)
    end

    local rawModel = getcustomasset(fileName)
    local morphModel = game:GetObjects(rawModel)[1]

    if not morphModel then return end

    local oldMorph = character:FindFirstChild(modelName)
    if oldMorph then oldMorph:Destroy() end

    morphModel.Name = modelName
    morphModel.Parent = character
    
    local function findPartRecursive(parent, targetName)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("BasePart") and child.Name == targetName then
                return child
            end
            local found = findPartRecursive(child, targetName)
            if found then return found end
        end
        return nil
    end

    local morphRoot = findPartRecursive(morphModel, "HumanoidRootPart") or morphModel.PrimaryPart or findPartRecursive(morphModel, "UpperTorso") or findPartRecursive(morphModel, "Torso")
    local morphHeadPart = findPartRecursive(morphModel, "Head") or morphRoot
    local rootWeld
    
    if morphRoot then
        morphModel:PivotTo(RootPart.CFrame * CFrame.new(0, heightOffset, 0))
        
        rootWeld = Instance.new("Weld")
        rootWeld.Name = "RootWeld"
        rootWeld.Part0 = RootPart
        rootWeld.Part1 = morphRoot
        rootWeld.C0 = CFrame.new(0, heightOffset, 0)
        rootWeld.Parent = morphRoot
    end

    local highFrictionProps = PhysicalProperties.new(0.7, 1.0, 0, 100, 100)

    for _, part in ipairs(morphModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.CustomPhysicalProperties = highFrictionProps
            
            if part.Name == "HumanoidRootPart" then
                part.Transparency = 1
                part.LocalTransparencyModifier = 1
                part.CastShadow = false
            else
                part.LocalTransparencyModifier = 0
            end
        end
    end

    -- Setup Animation Controller
    local morphController = morphModel:FindFirstChildOfClass("AnimationController") or morphModel:FindFirstChildOfClass("Humanoid")
    if not morphController then
        morphController = Instance.new("AnimationController", morphModel)
    end
    
    local animator = morphController:FindFirstChildOfClass("Animator") or Instance.new("Animator", morphController)
    local loadedTracks = {}

    if animator then
        for name, id in pairs(animIds) do
            local anim = Instance.new("Animation")
            anim.AnimationId = id
            loadedTracks[name] = animator:LoadAnimation(anim)
        end
    end

    local currentAnim = nil
    local isActionPlaying = false

    local function playAnim(name, isAction)
        if isActionPlaying and not isAction then return end
        if currentAnim == name then return end
        
        for animName, track in pairs(loadedTracks) do
            if animName ~= name and track.IsPlaying then
                track:Stop(0.15)
            end
        end
        
        if loadedTracks[name] then
            loadedTracks[name]:Play(0.15)
            currentAnim = name
            
            if isAction then
                isActionPlaying = true
                loadedTracks[name].Stopped:Once(function()
                    isActionPlaying = false
                    currentAnim = nil
                end)
            end
        end
    end

    -- Keybind listener for Caw (Z) and Peck (X)
    local inputConn = userInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == CAW_KEY then
            playAnim("Caw", true)
        elseif input.KeyCode == PECK_KEY then
            playAnim("Peck", true)
        end
    end)

    -- Movement state loop
    local animConnection
    animConnection = runService.Heartbeat:Connect(function()
        if not character or not Humanoid or not Humanoid.Parent then
            if animConnection then animConnection:Disconnect() end
            if inputConn then inputConn:Disconnect() end
            return
        end
        
        if isActionPlaying then return end

        local isMoving = Humanoid.MoveDirection.Magnitude > 0.05
        local currentSpeed = RootPart.AssemblyLinearVelocity.Magnitude

        if isMoving and currentSpeed > 0.5 then
            playAnim("Fly", false)
        else
            playAnim("Idle", false)
        end
    end)

    -- Render Loop
    local enforceLoop
    enforceLoop = runService.RenderStepped:Connect(function()
        if not character or not character.Parent then
            enforceLoop:Disconnect()
            if animConnection then animConnection:Disconnect() end
            if inputConn then inputConn:Disconnect() end
            return
        end
        
        if rootWeld and rootWeld.Parent then
            rootWeld.C0 = CFrame.new(0, heightOffset, 0)
        end

        local isLocalUserTarget = (LocalPlayer.Character == character)
        if isLocalUserTarget and camera and morphHeadPart and morphHeadPart:IsDescendantOf(workspace) then
            local lookVector = camera.CFrame.LookVector
            local upVector = camera.CFrame.UpVector
            local headPos = morphHeadPart.Position

            if isThirdPerson then
                local camPos = headPos - (lookVector * 10) + Vector3.new(0, 1.5, 0)
                camera.CFrame = CFrame.lookAt(camPos, headPos, upVector)
            else
                local offset = Vector3.new(0, 0.2, -0.5)
                local targetPosition = morphHeadPart.CFrame:PointToWorldSpace(offset)
                camera.CFrame = CFrame.lookAt(targetPosition, targetPosition + lookVector, upVector)
            end
        end

        -- Hide original avatar
        for _, child in ipairs(character:GetChildren()) do
            if child ~= morphModel then
                if child:IsA("BasePart") then
                    child.LocalTransparencyModifier = 1
                elseif child:IsA("Accessory") then
                    local h = child:FindFirstChild("Handle")
                    if h then h.LocalTransparencyModifier = 1 end
                end
            end
        end

        -- Render Caw parts
        for _, part in ipairs(morphModel:GetDescendants()) do
            if part:IsA("BasePart") then
                if part.Name == "HumanoidRootPart" then
                    part.LocalTransparencyModifier = 1
                else
                    part.LocalTransparencyModifier = 0
                end
            end
        end
    end)
    
    _G.morphCleanup = function()
        if enforceLoop then enforceLoop:Disconnect() end
        if animConnection then animConnection:Disconnect() end
        if inputConn then inputConn:Disconnect() end
        if Humanoid and Humanoid.Parent then Humanoid.CameraOffset = Vector3.new(0, 0, 0) end
        if morphModel then morphModel:Destroy() end
    end
end

if LocalPlayer.Character then
    task.spawn(applyMorph, LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    applyMorph(char)
end)
