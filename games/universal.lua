local loadstring = function(src, chunkname)
        local res, err = loadstring(src, chunkname)
        if err and vape then
                vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
        end
        return res
end
local isfile = isfile or function(file)
        local suc, res = pcall(function()
                return readfile(file)
        end)
        return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
        if not isfile(path) then
                local suc, res = pcall(function()
                        return game:HttpGet('https://raw.githubusercontent.com/AverageClumzyPerson/AverageDeveloperScript/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
                end)
                if not suc or res == '404: Not Found' then
                        error(res)
                end
                if path:find('.lua') then
                        res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
                end
                writefile(path, res)
        end
        return (func or readfile)(path)
end


local run = function(func)
        local ok, err = pcall(func)
        if not ok then
                local errStr = tostring(err)
                
                local lineNum = errStr:match(':(%d+):')
                local cleanErr = errStr:gsub('^.-%:%d+%:%s*', '') 

                local notifMsg
                if lineNum then
                        notifMsg = 'Line ' .. lineNum .. ': ' .. cleanErr
                else
                        notifMsg = cleanErr
                end

                
                if #notifMsg > 120 then
                        notifMsg = notifMsg:sub(1, 117) .. '...'
                end

                if vape and vape.CreateNotification then
                        vape:CreateNotification('[Module Error]', notifMsg, 15, 'alert')
                end
                warn('[Fuzzynuts Module Error] ' .. errStr)
        end
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
        return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = function(...)
        if identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and getgenv().isnetworkowner then
                return getgenv().isnetworkowner(...)
        end
        return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
        local blur = Instance.new('ImageLabel')
        blur.Name = 'Blur'
        blur.Size = UDim2.new(1, 89, 1, 52)
        blur.Position = UDim2.fromOffset(-48, -31)
        blur.BackgroundTransparency = 1
        blur.Image = getcustomasset('newvape/assets/new/blur.png')
        blur.ScaleType = Enum.ScaleType.Slice
        blur.SliceCenter = Rect.new(52, 31, 261, 502)
        blur.Parent = parent
        return blur
end

local function calculateMoveVector(vec)
        local c, s
        local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
        if R12 < 1 and R12 > -1 then
                c = R22
                s = R02
        else
                c = R00
                s = -R01 * math.sign(R12)
        end
        vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
        return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
        if vape.Categories.Friends.Options['Use friends'].Enabled then
                local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
                if recolor then
                        friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
                end
                return friend
        end
        return nil
end

local function isTarget(plr)
        return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
        local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
        for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
                local obj = v:FindFirstAncestorOfClass('ScreenGui')
                if v.Active and v.Visible and obj and obj.Enabled then
                        return false
                end
        end
        for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
                local obj = v:FindFirstAncestorOfClass('ScreenGui')
                if v.Active and v.Visible and obj and obj.Enabled then
                        return false
                end
        end
        return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
        local ind = 0
        for _ in tab do ind = ind + 1 end
        return ind
end

local function getTool()
        return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
        return vape:CreateNotification(...)
end

local function removeTags(str)
        str = str:gsub('<br%s*/>', '\n')
        return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
        visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
        if not table.find(visited, game.JobId) then
                table.insert(visited, game.JobId)
        end
        if not pointer then
                notif('Vape', 'Searching for an available server.', 2)
        end

        local suc, httpdata = pcall(function()
                return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
        end)
        local data = suc and httpService:JSONDecode(httpdata) or nil
        if data and data.data then
                for _, v in data.data do
                        if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
                                cacheExpire, cache = tick() + 60, httpdata
                                table.insert(attempted, v.id)

                                notif('Vape', 'Found! Teleporting.', 5)
                                teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
                                return
                        end
                end

                if data.nextPageCursor then
                        serverHop(data.nextPageCursor, filter)
                else
                        notif('Vape', 'Failed to find an available server.', 5, 'warning')
                end
        else
                notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
        end
end

vape:Clean(lplr.OnTeleport:Connect(function()
        if not tpSwitch then
                tpSwitch = true
                queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
        end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
        if getTableSize(frictionTable) > 0 then
                if entitylib.isAlive then
                        for _, v in entitylib.character.Character:GetChildren() do
                                if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
                                        oldfrict[v] = v.CustomPhysicalProperties or 'none'
                                        v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
                                end
                        end
                end
        else
                for i, v in oldfrict do
                        i.CustomPhysicalProperties = v ~= 'none' and v or nil
                end
                table.clear(oldfrict)
        end
end

local function motorMove(target, cf)
        local part = Instance.new('Part')
        part.Anchored = true
        part.Parent = workspace
        local motor = Instance.new('Motor6D')
        motor.Part0 = target
        motor.Part1 = part
        motor.C1 = cf
        motor.Parent = part
        task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('newvape/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
        tag = function() return '' end,
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
        Normal = {
                {CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
                {CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
                {CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
                {CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
        },
        Random = {},
        ['Horizontal Spin'] = {
                {CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
                {CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
                {CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
                {CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
        },
        ['Vertical Spin'] = {
                {CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
                {CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
                {CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
                {CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
        },
        Exhibition = {
                {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
                {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
        },
        ['Exhibition Old'] = {
                {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
                {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
                {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
                {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
                {CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
        }
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
        Velocity = function(options, moveDirection)
                local root = entitylib.character.RootPart
                root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        end,
        Impulse = function(options, moveDirection)
                local root = entitylib.character.RootPart
                local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
                if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
                        root:ApplyImpulse(diff * root.AssemblyMass)
                end
        end,
        CFrame = function(options, moveDirection, dt)
                local root = entitylib.character.RootPart
                local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
                if options.WallCheck.Enabled then
                        options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                        options.rayCheck.CollisionGroup = root.CollisionGroup
                        local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
                        if ray then
                                dest = ((ray.Position + ray.Normal) - root.Position)
                        end
                end
                root.CFrame = root.CFrame + dest
        end,
        TP = function(options, moveDirection)
                if options.TPTiming < tick() then
                        options.TPTiming = tick() + options.TPFrequency.Value
                        SpeedMethods.CFrame(options, moveDirection, 1)
                end
        end,
        WalkSpeed = function(options)
                if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
                entitylib.character.Humanoid.WalkSpeed = options.Value.Value
        end,
        Pulse = function(options, moveDirection)
                local root = entitylib.character.RootPart
                local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
                dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
                root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        end
}
for name in SpeedMethods do
        if not table.find(SpeedMethodList, name) then
                table.insert(SpeedMethodList, name)
        end
end

run(function()
        entitylib.getUpdateConnections = function(ent)
                local hum = ent.Humanoid
                return {
                        hum:GetPropertyChangedSignal('Health'),
                        hum:GetPropertyChangedSignal('MaxHealth'),
                        {
                                Connect = function()
                                        ent.Friend = ent.Player and isFriend(ent.Player) or nil
                                        ent.Target = ent.Player and isTarget(ent.Player) or nil
                                        return {
                                                Disconnect = function() end
                                        }
                                end
                        }
                }
        end

        entitylib.targetCheck = function(ent)
                if ent.TeamCheck then
                        return ent:TeamCheck()
                end
                if ent.NPC then return true end
                if isFriend(ent.Player) then return false end
                if vape.Categories.Main.Options['Teams by server'].Enabled then
                        if not lplr.Team then return true end
                        if not ent.Player.Team then return true end
                        if ent.Player.Team ~= lplr.Team then return true end
                        return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
                end
                return true
        end

        entitylib.getEntityColor = function(ent)
                ent = ent.Player
                if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
                if isFriend(ent, true) then
                        return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
                end
                return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
        end

        vape:Clean(function()
                entitylib.kill()
                entitylib = nil
        end)
        vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
        vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
        vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
        vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
                gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
        end))
end)


entitylib.start()
        local function jump()
                local state = entitylib.isAlive and entitylib.character.Humanoid:GetState() or nil
        
                if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
                        local root = entitylib.character.RootPart
        
                        if Mode.Value == 'Velocity' then
                                entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Value.Value, root.AssemblyLinearVelocity.Z)
                        elseif Mode.Value == 'Impulse' then
                                entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                                task.delay(0, function()
                                        root:ApplyImpulse(Vector3.new(0, Value.Value - root.AssemblyLinearVelocity.Y, 0) * root.AssemblyMass)
                                end)
                        else
                                local start = math.max(Value.Value - entitylib.character.Humanoid.JumpHeight, 0)
                                repeat
                                        root.CFrame = root.CFrame + Vector3.new(0, start * 0.016, 0)
                                        start = start - (workspace.Gravity * 0.016)
                                        if Mode.Value == 'CFrame' then
                                                task.wait()
                                        end
                                until start <= 0
                        end
                end
        end
        
        HighJump = vape.Categories.Blatant:CreateModule({
                Name = 'HighJump',
                Function = function(callback)
                        if callback then
                                if AutoDisable.Enabled then
                                        jump()
                                        HighJump:Toggle()
                                else
                                        HighJump:Clean(runService.Heartbeat:Connect(function()
                                                if not inputService:GetFocusedTextBox() and inputService:IsKeyDown(Enum.KeyCode.Space) then
                                                        jump()
                                                end
                                        end))
                                end
                        end
                end,
                ExtraText = function()
                        return Mode.Value
                end,
                Tooltip = 'Lets you jump higher'
        })
        Mode = HighJump:CreateDropdown({
                Name = 'Mode',
                List = {'Impulse', 'Velocity', 'CFrame', 'Instant'},
                Tooltip = 'Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nInstant - Teleports you to the peak of the jump'
        })
        Value = HighJump:CreateSlider({
                Name = 'Velocity',
                Min = 1,
                Max = 150,
                Default = 50,
                Suffix = function(val)
                        return val == 1 and 'stud' or 'studs'
                end
        })
        AutoDisable = HighJump:CreateToggle({
                Name = 'Auto Disable',
                Default = true
        })
run(function()
        local Invisible
        local clone, oldroot, hip, valid
        local animtrack
        local proper = true
        
        local function doClone()
                if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
                        hip = entitylib.character.Humanoid.HipHeight
                        oldroot = entitylib.character.HumanoidRootPart
                        if not lplr.Character.Parent then
                                return false
                        end
        
                        lplr.Character.Parent = game
                        clone = oldroot:Clone()
                        clone.Parent = lplr.Character
                        oldroot.Parent = gameCamera
                        clone.CFrame = oldroot.CFrame
        
                        lplr.Character.PrimaryPart = clone
                        entitylib.character.HumanoidRootPart = clone
                        entitylib.character.RootPart = clone
                        lplr.Character.Parent = workspace
        
                        for _, v in lplr.Character:GetDescendants() do
                                if v:IsA('Weld') or v:IsA('Motor6D') then
                                        if v.Part0 == oldroot then
                                                v.Part0 = clone
                                        end
                                        if v.Part1 == oldroot then
                                                v.Part1 = clone
                                        end
                                end
                        end
        
                        return true
                end
        
                return false
        end
        
        local function revertClone()
                if not oldroot or not oldroot:IsDescendantOf(workspace) or not entitylib.isAlive then
                        return false
                end
        
                lplr.Character.Parent = game
                oldroot.Parent = lplr.Character
                lplr.Character.PrimaryPart = oldroot
                entitylib.character.HumanoidRootPart = oldroot
                entitylib.character.RootPart = oldroot
                lplr.Character.Parent = workspace
                oldroot.CanCollide = true
        
                for _, v in lplr.Character:GetDescendants() do
                        if v:IsA('Weld') or v:IsA('Motor6D') then
                                if v.Part0 == clone then
                                        v.Part0 = oldroot
                                end
                                if v.Part1 == clone then
                                        v.Part1 = oldroot
                                end
                        end
                end
        
                local oldpos = clone.CFrame
                if clone then
                        clone:Destroy()
                        clone = nil
                end
        
                oldroot.CFrame = oldpos
                oldroot = nil
                entitylib.character.Humanoid.HipHeight = hip or 2
        end
        
        local function animationTrickery()
                if entitylib.isAlive then
                        local anim = Instance.new('Animation')
                        anim.AnimationId = 'http://www.roblox.com/asset/?id=18537363391'
                        animtrack = entitylib.character.Humanoid.Animator:LoadAnimation(anim)
                        animtrack.Priority = Enum.AnimationPriority.Action4
                        animtrack:Play(0, 1, 0)
                        anim:Destroy()
                        animtrack.Stopped:Connect(function()
                                if Invisible.Enabled then
                                        animationTrickery()
                                end
                        end)
        
                        task.delay(0, function()
                                animtrack.TimePosition = 0.77
                                task.delay(1, function()
                                        animtrack:AdjustSpeed(math.huge)
                                end)
                        end)
                end
        end
        
        Invisible = vape.Categories.Blatant:CreateModule({
                Name = 'Invisible',
                Function = function(callback)
                        if callback then
                                if not proper then
                                        notif('Invisible', 'Broken state detected', 3, 'alert')
                                        Invisible:Toggle()
                                        return
                                end
        
                                success = doClone()
                                if not success then
                                        Invisible:Toggle()
                                        return
                                end
        
                                animationTrickery()
                                Invisible:Clean(runService.PreSimulation:Connect(function(dt)
                                        if entitylib.isAlive and oldroot then
                                                local root = entitylib.character.RootPart
                                                local cf = root.CFrame - Vector3.new(0, entitylib.character.Humanoid.HipHeight + (root.Size.Y / 2) - 1, 0)
        
                                                if not isnetworkowner(oldroot) then
                                                        root.CFrame = oldroot.CFrame
                                                        root.Velocity = oldroot.Velocity
                                                        return
                                                end
        
                                                oldroot.CFrame = cf * CFrame.Angles(math.rad(180), 0, 0)
                                                oldroot.Velocity = root.Velocity
                                                oldroot.CanCollide = false
                                        end
                                end))
        
                                Invisible:Clean(entitylib.Events.LocalAdded:Connect(function(char)
                                        local animator = char.Humanoid:WaitForChild('Animator', 1)
                                        if animator and Invisible.Enabled then
                                                oldroot = nil
                                                Invisible:Toggle()
                                                Invisible:Toggle()
                                        end
                                end))
                        else
                                if animtrack then
                                        animtrack:Stop()
                                        animtrack:Destroy()
                                end
        
                                if success and clone and oldroot and proper then
                                        proper = true
                                        if oldroot and clone then
                                                revertClone()
                                        end
                                end
                        end
                end,
                Tooltip = 'Turns you invisible.'
        })
        local StudLimit = {Object = {}}
        local rayCheck = RaycastParams.new()
        rayCheck.RespectCanCollide = true
        local overlapCheck = OverlapParams.new()
        overlapCheck.MaxParts = 9e9
        local modified, fflag = {}
        local teleported
        
        local function grabClosestNormal(ray)
                local partCF, mag, closest = ray.Instance.CFrame, 0, Enum.NormalId.Top
                for _, normal in Enum.NormalId:GetEnumItems() do
                        local dot = partCF:VectorToWorldSpace(Vector3.fromNormalId(normal)):Dot(ray.Normal)
                        if dot > mag then
                                mag, closest = dot, normal
                        end
                end
                return Vector3.fromNormalId(closest).X ~= 0 and 'X' or 'Z'
        end
        
        local Functions = {
                Part = function()
                        local chars = {gameCamera, lplr.Character}
                        for _, v in entitylib.List do
                                chars[#chars + 1] = v.Character
                        end
                        overlapCheck.FilterDescendantsInstances = chars
        
                        local parts = workspace:GetPartBoundsInBox(entitylib.character.RootPart.CFrame + Vector3.new(0, 1, 0), entitylib.character.RootPart.Size + Vector3.new(1, entitylib.character.HipHeight, 1), overlapCheck)
                        for _, part in parts do
                                if part.CanCollide and (not Spider.Enabled or SpiderShift) then
                                        modified[part] = true
                                        part.CanCollide = false
                                end
                        end
        
                        for part in modified do
                                if not table.find(parts, part) then
                                        modified[part] = nil
                                        part.CanCollide = true
                                end
                        end
                end,
                Character = function()
                        for _, part in lplr.Character:GetDescendants() do
                                if part:IsA('BasePart') and part.CanCollide and (not Spider.Enabled or SpiderShift) then
                                        modified[part] = true
                                        part.CanCollide = Spider.Enabled and not SpiderShift
                                end
                        end
                end,
                CFrame = function()
                        local chars = {gameCamera, lplr.Character}
                        for _, v in entitylib.List do
                                chars[#chars + 1] = v.Character
                        end
                        rayCheck.FilterDescendantsInstances = chars
                        overlapCheck.FilterDescendantsInstances = chars
        
                        local ray = workspace:Raycast(entitylib.character.Head.CFrame.Position, entitylib.character.Humanoid.MoveDirection * 1.1, rayCheck)
                        if ray and (not Spider.Enabled or SpiderShift) then
                                local phaseDirection = grabClosestNormal(ray)
                                if ray.Instance.Size[phaseDirection] <= StudLimit.Value then
                                        local root = entitylib.character.RootPart
                                        local dest = root.CFrame + (ray.Normal * (-(ray.Instance.Size[phaseDirection]) - (root.Size.X / 1.5)))
        
                                        if #workspace:GetPartBoundsInBox(dest, Vector3.one, overlapCheck) <= 0 then
                                                if Mode.Value == 'Motor' then
                                                        motorMove(root, dest)
                                                else
                                                        root.CFrame = dest
                                                end
                                        end
                                end
                        end
                end,
                FFlag = function()
                        if teleported then return end
                        setfflag('AssemblyExtentsExpansionStudHundredth', '-10000')
                        fflag = true
                end
        }
        Functions.Motor = Functions.CFrame
        
        Phase = vape.Categories.Blatant:CreateModule({
                Name = 'Phase',
                Function = function(callback)
                        if callback then
                                Phase:Clean(runService.Stepped:Connect(function()
                                        if entitylib.isAlive then
                                                Functions[Mode.Value]()
                                        end
                                end))
        
                                if Mode.Value == 'FFlag' then
                                        Phase:Clean(lplr.OnTeleport:Connect(function()
                                                teleported = true
                                                setfflag('AssemblyExtentsExpansionStudHundredth', '30')
                                        end))
                                end
                        else
                                if fflag then
                                        setfflag('AssemblyExtentsExpansionStudHundredth', '30')
                                end
                                for part in modified do
                                        part.CanCollide = true
                                end
                                table.clear(modified)
                                fflag = nil
                        end
                end,
                Tooltip = 'Lets you Phase/Clip through walls. (Hold shift to use Phase over spider)'
        })
        Mode = Phase:CreateDropdown({
                Name = 'Mode',
                List = {'Part', 'Character', 'CFrame', 'Motor', 'FFlag'},
                Function = function(val)
                        StudLimit.Object.Visible = val == 'CFrame' or val == 'Motor'
                        if fflag then
                                setfflag('AssemblyExtentsExpansionStudHundredth', '30')
                        end
                        for part in modified do
                                part.CanCollide = true
                        end
                        table.clear(modified)
                        fflag = nil
                end,
                Tooltip = 'Part - Modifies parts collision status around you\nCharacter - Modifies the local collision status of the character\nCFrame - Teleports you past parts\nMotor - Same as CFrame with a bypass\nFFlag - Directly adjusts all physics collisions'
        })
        StudLimit = Phase:CreateSlider({
                Name = 'Wall Size',
                Min = 1,
                Max = 20,
                Default = 5,
                Suffix = function(val)
                        return val == 1 and 'stud' or 'studs'
                end,
                Darker = true,
                Visible = false
        })
end)
run(function()
        local Mode
        local Value
        local State
        local rayCheck = RaycastParams.new()
        rayCheck.RespectCanCollide = true
        local Active, Truss
        
        Spider = vape.Categories.Blatant:CreateModule({
                Name = 'Spider',
                Function = function(callback)
                        if callback then
                                if Truss then Truss.Parent = gameCamera end
                                Spider:Clean(runService.PreSimulation:Connect(function(dt)
                                        if entitylib.isAlive then
                                                local root = entitylib.character.RootPart
                                                local chars = {gameCamera, lplr.Character, Truss}
                                                for _, v in entitylib.List do
                                                        chars[#chars + 1] = v.Character
                                                end
                                                SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
                                                rayCheck.FilterDescendantsInstances = chars
                                                rayCheck.CollisionGroup = root.CollisionGroup
        
                                                if Mode.Value ~= 'Part' then
                                                        local vec = entitylib.character.Humanoid.MoveDirection * 2.5
                                                        local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), vec, rayCheck)
                                                        if Active and not ray then
                                                                root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
                                                        end
        
                                                        Active = ray
                                                        if Active and ray.Normal.Y == 0 then
                                                                if not Phase.Enabled or not SpiderShift then
                                                                        if State.Enabled then
                                                                                entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                                                                        end
        
                                                                        root.Velocity = root.Velocity * Vector3.new(1, 0, 1)
                                                                        if Mode.Value == 'CFrame' then
                                                                                root.CFrame = root.CFrame + Vector3.new(0, Value.Value * dt, 0)
                                                                        elseif Mode.Value == 'Impulse' then
                                                                                root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
                                                                        else
                                                                                root.Velocity = root.Velocity + Vector3.new(0, Value.Value, 0)
                                                                        end
                                                                end
                                                        end
                                                else
                                                        local ray = workspace:Raycast(root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0), entitylib.character.RootPart.CFrame.LookVector * 2, rayCheck)
                                                        if ray and (not Phase.Enabled or not SpiderShift) then
                                                                Truss.Position = ray.Position - ray.Normal * 0.9 or Vector3.zero
                                                        else
                                                                Truss.Position = Vector3.zero
                                                        end
                                                end
                                        end
                                end))
                        else
                                if Truss then
                                        Truss.Parent = nil
                                end
                                SpiderShift = false
                        end
                end,
                Tooltip = 'Lets you climb up walls. (Hold shift to use Phase over spider)'
        })
        Mode = Spider:CreateDropdown({
                Name = 'Mode',
                List = {'Velocity', 'Impulse', 'CFrame', 'Part'},
                Function = function(val)
                        Value.Object.Visible = val ~= 'Part'
                        State.Object.Visible = val ~= 'Part'
                        if Truss then
                                Truss:Destroy()
                                Truss = nil
                        end
                        if val == 'Part' then
                                Truss = Instance.new('TrussPart')
                                Truss.Size = Vector3.new(2, 2, 2)
                                Truss.Transparency = 1
                                Truss.Anchored = true
                                Truss.Parent = Spider.Enabled and gameCamera or nil
                        end
                end,
                Tooltip = 'Velocity - Uses smooth movement to boost you upward\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you'
        })
        Value = Spider:CreateSlider({
                Name = 'Speed',
                Min = 0,
                Max = 100,
                Default = 30,
                Darker = true,
                Suffix = function(val)
                        return val == 1 and 'stud' or 'studs'
                end
        })
        State = Spider:CreateToggle({
                Name = 'Climb State',
                Darker = true
        })
end)
        
run(function()
        local SpinBot
        local Mode
        local XToggle
        local YToggle
        local ZToggle
        local Value
        local AngularVelocity
        
        SpinBot = vape.Categories.Blatant:CreateModule({
                Name = 'SpinBot',
                Function = function(callback)
                        if callback then
                                SpinBot:Clean(runService.PreSimulation:Connect(function()
                                        if entitylib.isAlive then
                                                if Mode.Value == 'RotVelocity' then
                                                        local originalRotVelocity = entitylib.character.RootPart.RotVelocity
                                                        entitylib.character.Humanoid.AutoRotate = false
                                                        entitylib.character.RootPart.RotVelocity = Vector3.new(XToggle.Enabled and Value.Value or originalRotVelocity.X, YToggle.Enabled and Value.Value or originalRotVelocity.Y, ZToggle.Enabled and Value.Value or originalRotVelocity.Z)
                                                elseif Mode.Value == 'CFrame' then
                                                        local val = math.rad((tick() * (20 * Value.Value)) % 360)
                                                        local x, y, z = entitylib.character.RootPart.CFrame:ToOrientation()
                                                        entitylib.character.RootPart.CFrame = CFrame.new(entitylib.character.RootPart.Position) * CFrame.Angles(XToggle.Enabled and val or x, YToggle.Enabled and val or y, ZToggle.Enabled and val or z)
                                                elseif AngularVelocity then
                                                        AngularVelocity.Parent = entitylib.isAlive and entitylib.character.RootPart
                                                        AngularVelocity.MaxTorque = Vector3.new(XToggle.Enabled and math.huge or 0, YToggle.Enabled and math.huge or 0, ZToggle.Enabled and math.huge or 0)
                                                        AngularVelocity.AngularVelocity = Vector3.new(Value.Value, Value.Value, Value.Value)
                                                end
                                        end
                                end))
                        else
                                if entitylib.isAlive and Mode.Value == 'RotVelocity' then
                                        entitylib.character.Humanoid.AutoRotate = true
                                end
                                if AngularVelocity then
                                        AngularVelocity.Parent = nil
                                end
                        end
                end,
                Tooltip = 'Makes your character spin around in circles (does not work in first person)'
        })
        Mode = SpinBot:CreateDropdown({
                Name = 'Mode',
                List = {'CFrame', 'RotVelocity', 'BodyMover'},
                Function = function(val)
                        if AngularVelocity then
                                AngularVelocity:Destroy()
                                AngularVelocity = nil
                        end
                        AngularVelocity = val == 'BodyMover' and Instance.new('BodyAngularVelocity') or nil
                end
        })
        Value = SpinBot:CreateSlider({
                Name = 'Speed',
                Min = 1,
                Max = 100,
                Default = 40
        })
        XToggle = SpinBot:CreateToggle({Name = 'Spin X'})
        YToggle = SpinBot:CreateToggle({
                Name = 'Spin Y',
                Default = true
        })
        ZToggle = SpinBot:CreateToggle({Name = 'Spin Z'})
end)
run(function()
        local TargetStrafe
        local Targets
        local SearchRange
        local StrafeRange
        local YFactor
        local MovementType
        local JumpMode
        local JumpHeight
        local AirStrafing
        local StrafeSpeed
        local rayCheck = RaycastParams.new()
        rayCheck.RespectCanCollide = true
        local module, old
        
        local movementTypes = {
                "Original",
                "Aggressive",
                "Defensive",
                "ZigZag",
                "SpinThisBitchHoe",
                "RandomShit"
        }
        
        local jumpModes = {
                "None",
                "Normal",
                "Spam",
                "Timed",
                "RandomSHi",
                "CantCatchMeBih"
        }
        
        local strafeState = {
                lastJumpTime = 0,
                jumpCooldown = 0,
                movementAngle = 0,
                zigzagDirection = 1,
                lastZigzagTime = 0,
                randomSeed = math.random(1, 1000),
                orbitDirection = 1,
                inAir = false,
                lastGroundTime = 0
        }

        local function calculateMovement(ent, root, targetPos, flymodEnabled, wallcheck)
                local movementType = MovementType.Value
                local jumpMode = JumpMode.Value
                local localPosition = root.Position
                local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
                local vec = Vector3.zero
                local shouldJump = false
                local jumpPower = JumpHeight.Value / 100
                
                if movementType == "Original" then
                        local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
                        local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * (StrafeRange.Value - yFactor))
                        vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
                        strafeState.movementAngle = (strafeState.movementAngle + (StrafeSpeed.Value * 0.5)) % 360
                        
                elseif movementType == "Aggressive" then
                        local closeRange = StrafeRange.Value * 0.7
                        local angleIncrement = StrafeSpeed.Value * 0.8
                        local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * closeRange)
                        vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
                        strafeState.movementAngle = (strafeState.movementAngle + angleIncrement) % 360
                        
                elseif movementType == "Defensive" then
                        local wideRange = StrafeRange.Value * 1.3
                        local angleIncrement = StrafeSpeed.Value * 0.3
                        local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * wideRange)
                        vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
                        strafeState.movementAngle = (strafeState.movementAngle + angleIncrement) % 360
                        
                elseif movementType == "ZigZag" then
                        if tick() - strafeState.lastZigzagTime > 0.3 then
                                strafeState.zigzagDirection = -strafeState.zigzagDirection
                                strafeState.lastZigzagTime = tick()
                        end
                        
                        local sideOffset = strafeState.zigzagDirection * (StrafeRange.Value * 0.5)
                        local rightVector = CFrame.lookAt(localPosition, entityPos).RightVector
                        local newPos = entityPos + (rightVector * sideOffset)
                        vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
                        
                elseif movementType == "Orbital" then
                        local orbitSpeed = StrafeSpeed.Value * 0.4
                        strafeState.orbitDirection = (localPosition - entityPos).Magnitude > StrafeRange.Value * 1.2 and 1 or strafeState.orbitDirection
                        strafeState.orbitDirection = (localPosition - entityPos).Magnitude < StrafeRange.Value * 0.8 and -1 or strafeState.orbitDirection
                        
                        local newPos = entityPos + (CFrame.Angles(0, math.rad(strafeState.movementAngle), 0).LookVector * StrafeRange.Value)
                        vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
                        strafeState.movementAngle = (strafeState.movementAngle + (orbitSpeed * strafeState.orbitDirection)) % 360
                        
                elseif movementType == "Random" then
                        math.randomseed(strafeState.randomSeed + math.floor(tick()))
                        local randomAngle = math.random(0, 360)
                        local randomRange = math.random(StrafeRange.Value * 0.7, StrafeRange.Value * 1.3)
                        local newPos = entityPos + (CFrame.Angles(0, math.rad(randomAngle), 0).LookVector * randomRange)
                        vec = ((newPos - localPosition) * Vector3.new(1, 0, 1)).Unit
                        
                        if math.random(1, 20) == 1 then
                                strafeState.randomSeed = math.random(1, 1000)
                        end
                end
                
                local currentTime = tick()
                local distanceToTarget = (localPosition - targetPos).Magnitude
                
                if jumpMode == "Normal" then
                        if not strafeState.inAir and currentTime - strafeState.lastJumpTime > 1.5 then
                                shouldJump = math.random(1, 4) == 1
                        end
                        
                elseif jumpMode == "Spam" then
                        if currentTime - strafeState.lastJumpTime > 0.4 then
                                shouldJump = true
                        end
                        
                elseif jumpMode == "Timed" then
                        if currentTime - strafeState.lastJumpTime > 1.0 then
                                shouldJump = true
                        end
                        
                elseif jumpMode == "Combat" then
                        if distanceToTarget < StrafeRange.Value * 1.2 and currentTime - strafeState.lastJumpTime > 0.8 then
                                shouldJump = true
                        end
                        
                elseif jumpMode == "AntiAim" then
                        if math.random(1, 15) == 1 and currentTime - strafeState.lastJumpTime > 0.5 then
                                shouldJump = true
                        end
                end
                
                if AirStrafing.Enabled and strafeState.inAir then
                        vec = vec * 0.7
                        
                        if jumpMode ~= "None" then
                                vec = vec + Vector3.new(0, 0.1 * jumpPower, 0)
                        end
                end
                
                return vec, shouldJump
        end

        local function performJump(shouldJump, humanoid)
                if shouldJump and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        strafeState.lastJumpTime = tick()
                        strafeState.inAir = true
                        strafeState.lastGroundTime = tick()
                end
        end

        local function updateAirState(humanoid)
                if humanoid then
                        strafeState.inAir = humanoid.FloorMaterial == Enum.Material.Air
                        if not strafeState.inAir then
                                strafeState.lastGroundTime = tick()
                        end
                end
        end

        TargetStrafe = vape.Categories.Blatant:CreateModule({
                Name = 'TargetStrafe',
                Function = function(callback)
                        if callback then
                                if not module then
                                        local suc = pcall(function() module = require(lplr.PlayerScripts.PlayerModule).controls end)
                                        if not suc then
                                                module = {}
                                        end
                                end
                                
                                old = module.moveFunction
                                local flymod, ang, oldent = vape.Modules.Fly or {Enabled = false}
                                
                                module.moveFunction = function(self, vec, face)
                                        local wallcheck = Targets.Walls.Enabled
                                        local ent = not inputService:IsKeyDown(Enum.KeyCode.S) and entitylib.EntityPosition({
                                                Range = SearchRange.Value,
                                                Wallcheck = wallcheck,
                                                Part = 'RootPart',
                                                Players = Targets.Players.Enabled,
                                                NPCs = Targets.NPCs.Enabled
                                        })
        
                                        if ent then
                                                local root, targetPos = entitylib.character.RootPart, ent.RootPart.Position
                                                rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, ent.Character}
                                                rayCheck.CollisionGroup = root.CollisionGroup
        
                                                if flymod.Enabled or workspace:Raycast(targetPos, Vector3.new(0, -70, 0), rayCheck) then
                                                        local factor, localPosition = 0, root.Position
                                                        if ent ~= oldent then
                                                                ang = math.deg(select(2, CFrame.lookAt(targetPos, localPosition):ToEulerAnglesYXZ()))
                                                                strafeState.movementAngle = ang
                                                        end
                                                        
                                                        updateAirState(entitylib.character.Humanoid)
                                                        
                                                        local newVec, shouldJump = calculateMovement(ent, root, targetPos, flymod.Enabled, wallcheck)
                                                        vec = newVec
                                                        
                                                        performJump(shouldJump, entitylib.character.Humanoid)
                                                        
                                                        local yFactor = math.abs(localPosition.Y - targetPos.Y) * (YFactor.Value / 100)
                                                        local entityPos = Vector3.new(targetPos.X, localPosition.Y, targetPos.Z)
                                                        local newPos = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (StrafeRange.Value - yFactor))
                                                        local startRay, endRay = entityPos, newPos
        
                                                        if not wallcheck and workspace:Raycast(targetPos, (localPosition - targetPos), rayCheck) then
                                                                startRay, endRay = entityPos + (CFrame.Angles(0, math.rad(ang), 0).LookVector * (entityPos - localPosition).Magnitude), entityPos
                                                        end
        
                                                        local ray = workspace:Blockcast(CFrame.new(startRay), Vector3.new(1, entitylib.character.HipHeight + (root.Size.Y / 2), 1), (endRay - startRay), rayCheck)
                                                        if (localPosition - newPos).Magnitude < 3 or ray then
                                                                factor = (8 - math.min((localPosition - newPos).Magnitude, 3))
                                                                if ray then
                                                                        newPos = ray.Position + (ray.Normal * 1.5)
                                                                        factor = (localPosition - newPos).Magnitude > 3 and 0 or factor
                                                                end
                                                        end
        
                                                        if not flymod.Enabled and not workspace:Raycast(newPos, Vector3.new(0, -70, 0), rayCheck) then
                                                                newPos = entityPos
                                                                factor = 40
                                                        end
        
                                                        ang = ang + factor % 360
                                                        vec = vec == vec and vec or Vector3.zero
                                                        TargetStrafeVector = vec
                                                else
                                                        ent = nil
                                                end
                                        end
        
                                        TargetStrafeVector = ent and vec or nil
                                        oldent = ent
                                        return old(self, vec, face)
                                end
                        else
                                if module and old then
                                        module.moveFunction = old
                                end
                                TargetStrafeVector = nil
                                strafeState = {
                                        lastJumpTime = 0,
                                        jumpCooldown = 0,
                                        movementAngle = 0,
                                        zigzagDirection = 1,
                                        lastZigzagTime = 0,
                                        randomSeed = math.random(1, 1000),
                                        orbitDirection = 1,
                                        inAir = false,
                                        lastGroundTime = 0
                                }
                        end
                end,
                Tooltip = 'Automatically strafes around the opponent with multiple movement types'
        })
        
        Targets = TargetStrafe:CreateTargets({
                Players = true,
                Walls = true
        })
        
        SearchRange = TargetStrafe:CreateSlider({
                Name = 'Search Range',
                Min = 1,
                Max = 30,
                Default = 24,
                Suffix = function(val)
                        return val == 1 and 'stud' or 'studs'
                end
        })
        
        StrafeRange = TargetStrafe:CreateSlider({
                Name = 'Strafe Range',
                Min = 1,
                Max = 30,
                Default = 18,
                Suffix = function(val)
                        return val == 1 and 'stud' or 'studs'
                end
        })
        
        YFactor = TargetStrafe:CreateSlider({
                Name = 'Y Factor',
                Min = 0,
                Max = 100,
                Default = 100,
                Suffix = '%'
        })
        
        StrafeSpeed = TargetStrafe:CreateSlider({
                Name = 'Strafe Speed',
                Min = 1,
                Max = 10,
                Default = 5,
                Function = function(val)
                end
        })
        
        MovementType = TargetStrafe:CreateDropdown({
                Name = 'Movement Type',
                List = movementTypes,
                Function = function(val)
                        strafeState.movementAngle = 0
                        strafeState.zigzagDirection = 1
                        strafeState.lastZigzagTime = 0
                end
        })
        
        JumpMode = TargetStrafe:CreateDropdown({
                Name = 'Jump Mode',
                List = jumpModes,
                Function = function(val)
                        strafeState.lastJumpTime = 0
                end
        })
        
        JumpHeight = TargetStrafe:CreateSlider({
                Name = 'Jump Power',
                Min = 50,
                Max = 150,
                Default = 100,
                Suffix = '%',
                Tooltip = 'Adjusts jump intensity for air strafing'
        })
        
        AirStrafing = TargetStrafe:CreateToggle({
                Name = 'Air Strafing',
                Function = function(callback)
                end,
                Default = true,
                Tooltip = 'Adjust movement when in air for better control'
        })
end)
run(function()
        local Arrows
        local Targets
        local Color
        local Teammates
        local Distance
        local DistanceLimit
        local Reference = {}
        local V3_XZ = Vector3.new(1, 0, 1)
        local Folder = Instance.new('Folder')
        Folder.Parent = vape.gui
        
        local function Added(ent)
                if not Targets.Players.Enabled and ent.Player then return end
                if not Targets.NPCs.Enabled and ent.NPC then return end
                if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
                if vape.ThreadFix then
                        setthreadidentity(8)
                end
        
                local arrow = Instance.new('ImageLabel')
                arrow.Size = UDim2.fromOffset(256, 256)
                arrow.Position = UDim2.fromScale(0.5, 0.5)
                arrow.AnchorPoint = Vector2.new(0.5, 0.5)
                arrow.BackgroundTransparency = 1
                arrow.BorderSizePixel = 0
                arrow.Visible = false
                arrow.Image = getcustomasset('newvape/assets/new/arrowmodule.png')
                arrow.ImageColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                arrow.Parent = Folder
                Reference[ent] = arrow
        end
        
        local function Removed(ent)
                local v = Reference[ent]
                if v then
                        if vape.ThreadFix then
                                setthreadidentity(8)
                        end
                        Reference[ent] = nil
                        v:Destroy()
                end
        end
        
        local function ColorFunc(hue, sat, val)
                local color = Color3.fromHSV(hue, sat, val)
                for ent, EntityArrow in Reference do
                        EntityArrow.ImageColor3 = entitylib.getEntityColor(ent) or color
                end
        end
        
        local function Loop()
                        for ent, arrow in Reference do
                                local _skip = false
                                if Distance.Enabled then
                                        local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
                                        if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                                                arrow.Visible = false
                                                _skip = true
                                        end
                                end
                                if not _skip then
                                        local _, rootVis = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
                                        arrow.Visible = not rootVis
                                        if not rootVis then
                                                local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * V3_XZ):PointToObjectSpace(ent.RootPart.Position)
                                                arrow.Rotation = math.deg(math.atan2(dir.Z, dir.X))
                                        end
                                end
                        end
        end
        
        Arrows = vape.Categories.Render:CreateModule({
                Name = 'Arrows',
                Function = function(callback)
                        if callback then
                                Arrows:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
                                for _, v in entitylib.List do
                                        if Reference[v] then Removed(v) end
                                        Added(v)
                                end
                                Arrows:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                                        if Reference[ent] then Removed(ent) end
                                        Added(ent)
                                end))
                                Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
                                        ColorFunc(Color.Hue, Color.Sat, Color.Value)
                                end))
                                Arrows:Clean(runService.Heartbeat:Connect(Loop))
                        else
                                for i in Reference do
                                        Removed(i)
                                end
                        end
                end,
                Tooltip = 'Draws arrows on screen when entities\nare out of your field of view.'
        })
        Targets = Arrows:CreateTargets({
                Players = true,
                Function = function()
                        if Arrows.Enabled then
                                Arrows:Toggle()
                                Arrows:Toggle()
                        end
                end
        })
        Color = Arrows:CreateColorSlider({
                Name = 'Player Color',
                Function = function(hue, sat, val)
                        if Arrows.Enabled then
                                ColorFunc(hue, sat, val)
                        end
                end,
        })
        Teammates = Arrows:CreateToggle({
                Name = 'Priority Only',
                Function = function()
                        if Arrows.Enabled then
                                Arrows:Toggle()
                                Arrows:Toggle()
                        end
                end,
                Default = true,
                Tooltip = 'Hides teammates & non targetable entities'
        })
        Distance = Arrows:CreateToggle({
                Name = 'Distance Check',
                Function = function(callback)
                        DistanceLimit.Object.Visible = callback
                end
        })
        DistanceLimit = Arrows:CreateTwoSlider({
                Name = 'Player Distance',
                Min = 0,
                Max = 256,
                DefaultMin = 0,
                DefaultMax = 64,
                Darker = true,
                Visible = false
        })
end)
        
run(function()
        local Chams
        local Targets
        local Mode
        local FillColor
        local OutlineColor
        local FillTransparency
        local OutlineTransparency
        local Teammates
        local Walls
        local Reference = {}
        local Folder = Instance.new('Folder')
        Folder.Parent = vape.gui
        
        local function Added(ent)
                if not Targets.Players.Enabled and ent.Player then return end
                if not Targets.NPCs.Enabled and ent.NPC then return end
                if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
                if vape.ThreadFix then
                        setthreadidentity(8)
                end
        
                if Mode.Value == 'Highlight' then
                        local cham = Instance.new('Highlight')
                        cham.Adornee = ent.Character
                        cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and 'AlwaysOnTop' or 'Occluded']
                        cham.FillColor = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
                        cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
                        cham.FillTransparency = FillTransparency.Value
                        cham.OutlineTransparency = OutlineTransparency.Value
                        cham.Parent = Folder
                        Reference[ent] = cham
                else
                        local chams = {}
                        for _, v in ent.Character:GetChildren() do
                                if v:IsA('BasePart') and (ent.NPC or v.Name:find('Arm') or v.Name:find('Leg') or v.Name:find('Hand') or v.Name:find('Feet') or v.Name:find('Torso') or v.Name == 'Head') then
                                        local box = Instance.new(v.Name == 'Head' and 'SphereHandleAdornment' or 'BoxHandleAdornment')
                                        if v.Name == 'Head' then
                                                box.Radius = 0.75
                                        else
                                                box.Size = v.Size
                                        end
                                        box.AlwaysOnTop = Walls.Enabled
                                        box.Adornee = v
                                        box.ZIndex = 0
                                        box.Transparency = FillTransparency.Value
                                        box.Color3 = entitylib.getEntityColor(ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
                                        box.Parent = Folder
                                        chams[#chams + 1] = box
                                end
                        end
                        Reference[ent] = chams
                end
        end
        
        local function Removed(ent)
                if Reference[ent] then
                        if vape.ThreadFix then
                                setthreadidentity(8)
                        end
                        if type(Reference[ent]) == 'table' then
                                for _, v in Reference[ent] do
                                        v:Destroy()
                                end
                                table.clear(Reference[ent])
                        else
                                Reference[ent]:Destroy()
                        end
                        Reference[ent] = nil
                end
        end
        
        Chams = vape.Categories.Render:CreateModule({
                Name = 'Chams',
                Function = function(callback)
                        if callback then
                                Chams:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
                                Chams:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                                        if Reference[ent] then
                                                Removed(ent)
                                        end
                                        Added(ent)
                                end))
                                Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
                                        for i, v in Reference do
                                                local color = entitylib.getEntityColor(i) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
                                                if type(v) == 'table' then
                                                        for _, v2 in v do v2.Color3 = color end
                                                else
                                                        v.FillColor = color
                                                end
                                        end
                                end))
                                for _, v in entitylib.List do
                                        if Reference[v] then
                                                Removed(v)
                                        end
                                        Added(v)
                                end
                        else
                                for i in Reference do
                                        Removed(i)
                                end
                        end
                end,
                Tooltip = 'Render players through walls'
        })
        Targets = Chams:CreateTargets({
                Players = true,
                Function = function()
                        if Chams.Enabled then
                                Chams:Toggle()
                                Chams:Toggle()
                        end
                end
                })
        Mode = Chams:CreateDropdown({
                Name = 'Mode',
                List = {'Highlight', 'BoxHandles'},
                Function = function(val)
                        OutlineColor.Object.Visible = val == 'Highlight'
                        OutlineTransparency.Object.Visible = val == 'Highlight'
                        if Chams.Enabled then
                                Chams:Toggle()
                                Chams:Toggle()
                        end
                end
        })
        FillColor = Chams:CreateColorSlider({
                Name = 'Color',
                Function = function(hue, sat, val)
                        for i, v in Reference do
                                local color = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
                                if type(v) == 'table' then
                                        for _, v2 in v do v2.Color3 = color end
                                else
                                        v.FillColor = color
                                end
                        end
                end
        })
        OutlineColor = Chams:CreateColorSlider({
                Name = 'Outline Color',
                DefaultSat = 0,
                Function = function(hue, sat, val)
                        for i, v in Reference do
                                if type(v) ~= 'table' then
                                        v.OutlineColor = entitylib.getEntityColor(i) or Color3.fromHSV(hue, sat, val)
                                end
                        end
                end,
                Darker = true
        })
        FillTransparency = Chams:CreateSlider({
                Name = 'Transparency',
                Min = 0,
                Max = 1,
                Default = 0.5,
                Function = function(val)
                        for _, v in Reference do
                                if type(v) == 'table' then
                                        for _, v2 in v do v2.Transparency = val end
                                else
                                        v.FillTransparency = val
                                end
                        end
                end,
                Decimal = 10
        })
        OutlineTransparency = Chams:CreateSlider({
                Name = 'Outline Transparency',
                Min = 0,
                Max = 1,
                Default = 0.5,
                Function = function(val)
                        for _, v in Reference do
                                if type(v) ~= 'table' then
                                        v.OutlineTransparency = val
                                end
                        end
                end,
                Decimal = 10,
                Darker = true
        })
        Walls = Chams:CreateToggle({
                Name = 'Render Walls',
                Function = function(callback)
                        for _, v in Reference do
                                if type(v) == 'table' then
                                        for _, v2 in v do
                                                v2.AlwaysOnTop = callback
                                        end
                                else
                                        v.DepthMode = Enum.HighlightDepthMode[callback and 'AlwaysOnTop' or 'Occluded']
                                end
                        end
                end,
                Default = true
        })
        Teammates = Chams:CreateToggle({
                Name = 'Priority Only',
                Function = function()
                        if Chams.Enabled then
                                Chams:Toggle()
                                Chams:Toggle()
                        end
                end,
                Default = true,
                Tooltip = 'Hides teammates & non targetable entities'
        })
end)
        
run(function()
        local ESP
        local Targets
        local Color
        local Method
        local BoundingBox
        local Filled
        local HealthBar
        local HealthBarColor
        local HealthBarColorToggle
        local Name
        local DisplayName
        local Background
        local Teammates
        local Distance
        local DistanceLimit
        local BoxSize
        local Reference = {}
        local methodused
        local V3_DOWN_05 = Vector3.new(0, 0.5, 0)
        local V2_HALF = Vector2.new(0.5, 0.5)

        local function ESPWorldToViewport(pos)
                local newpos = gameCamera:WorldToViewportPoint(pos)
                return Vector2.new(newpos.X, newpos.Y)
        end

        local function getHealthBarColor(ent)
                if HealthBarColorToggle and HealthBarColorToggle.Enabled and HealthBarColor then
                        return Color3.fromHSV(HealthBarColor.Hue, HealthBarColor.Sat, HealthBarColor.Value)
                end
                return Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
        end

        local ESPAdded = {
                Drawing2D = function(ent)
                        if not Targets.Players.Enabled and ent.Player then return end
                        if not Targets.NPCs.Enabled and ent.NPC then return end
                        if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
                        if vape.ThreadFix then
                                setthreadidentity(8)
                        end
                        local EntityESP = {}
                        EntityESP.Main = Drawing.new('Square')
                        EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
                        EntityESP.Main.ZIndex = 2
                        EntityESP.Main.Filled = false
                        EntityESP.Main.Thickness = 1
                        EntityESP.Main.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)

                        if BoundingBox.Enabled then
                                EntityESP.Border = Drawing.new('Square')
                                EntityESP.Border.Transparency = 0.35
                                EntityESP.Border.ZIndex = 1
                                EntityESP.Border.Thickness = 1
                                EntityESP.Border.Filled = false
                                EntityESP.Border.Color = Color3.new()
                                EntityESP.Border2 = Drawing.new('Square')
                                EntityESP.Border2.Transparency = 0.35
                                EntityESP.Border2.ZIndex = 1
                                EntityESP.Border2.Thickness = 1
                                EntityESP.Border2.Filled = Filled.Enabled
                                EntityESP.Border2.Color = Color3.new()
                        end

                        if HealthBar.Enabled then
                                EntityESP.HealthLine = Drawing.new('Line')
                                EntityESP.HealthLine.Thickness = 1
                                EntityESP.HealthLine.ZIndex = 2
                                EntityESP.HealthLine.Color = getHealthBarColor(ent)
                                EntityESP.HealthBorder = Drawing.new('Line')
                                EntityESP.HealthBorder.Thickness = 3
                                EntityESP.HealthBorder.Transparency = 0.35
                                EntityESP.HealthBorder.ZIndex = 1
                                EntityESP.HealthBorder.Color = Color3.new()
                        end

                        if Name.Enabled then
                                if Background.Enabled then
                                        EntityESP.TextBKG = Drawing.new('Square')
                                        EntityESP.TextBKG.Transparency = 0.35
                                        EntityESP.TextBKG.ZIndex = 0
                                        EntityESP.TextBKG.Thickness = 1
                                        EntityESP.TextBKG.Filled = true
                                        EntityESP.TextBKG.Color = Color3.new()
                                end
                                EntityESP.Drop = Drawing.new('Text')
                                EntityESP.Drop.Color = Color3.new()
                                EntityESP.Drop.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
                                EntityESP.Drop.ZIndex = 1
                                EntityESP.Drop.Center = true
                                EntityESP.Drop.Size = 22
                                EntityESP.Text = Drawing.new('Text')
                                EntityESP.Text.Text = EntityESP.Drop.Text
                                EntityESP.Text.ZIndex = 2
                                EntityESP.Text.Color = EntityESP.Main.Color
                                EntityESP.Text.Center = true
                                EntityESP.Text.Size = 22
                        end
                        Reference[ent] = EntityESP
                end,
                Drawing3D = function(ent)
                        if not Targets.Players.Enabled and ent.Player then return end
                        if not Targets.NPCs.Enabled and ent.NPC then return end
                        if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
                        if vape.ThreadFix then
                                setthreadidentity(8)
                        end
                        local EntityESP = {}
                        EntityESP.Line1 = Drawing.new('Line')
                        EntityESP.Line2 = Drawing.new('Line')
                        EntityESP.Line3 = Drawing.new('Line')
                        EntityESP.Line4 = Drawing.new('Line')
                        EntityESP.Line5 = Drawing.new('Line')
                        EntityESP.Line6 = Drawing.new('Line')
                        EntityESP.Line7 = Drawing.new('Line')
                        EntityESP.Line8 = Drawing.new('Line')
                        EntityESP.Line9 = Drawing.new('Line')
                        EntityESP.Line10 = Drawing.new('Line')
                        EntityESP.Line11 = Drawing.new('Line')
                        EntityESP.Line12 = Drawing.new('Line')

                        local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        for _, v in EntityESP do
                                v.Thickness = 1
                                v.Color = color
                        end

                        Reference[ent] = EntityESP
                end,
                DrawingSkeleton = function(ent)
                        if not Targets.Players.Enabled and ent.Player then return end
                        if not Targets.NPCs.Enabled and ent.NPC then return end
                        if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
                        if vape.ThreadFix then
                                setthreadidentity(8)
                        end
                        local EntityESP = {}
                        EntityESP.Head = Drawing.new('Line')
                        EntityESP.HeadFacing = Drawing.new('Line')
                        EntityESP.Torso = Drawing.new('Line')
                        EntityESP.UpperTorso = Drawing.new('Line')
                        EntityESP.LowerTorso = Drawing.new('Line')
                        EntityESP.LeftArm = Drawing.new('Line')
                        EntityESP.RightArm = Drawing.new('Line')
                        EntityESP.LeftLeg = Drawing.new('Line')
                        EntityESP.RightLeg = Drawing.new('Line')

                        local color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        for _, v in EntityESP do
                                v.Thickness = 2
                                v.Color = color
                        end

                        Reference[ent] = EntityESP
                end
        }

        local ESPRemoved = {
                Drawing2D = function(ent)
                        local EntityESP = Reference[ent]
                        if EntityESP then
                                if vape.ThreadFix then
                                        setthreadidentity(8)
                                end
                                Reference[ent] = nil
                                for _, v in EntityESP do
                                        pcall(function()
                                                v.Visible = false
                                                v:Remove()
                                        end)
                                end
                        end
                end
        }
        ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
        ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D

        local ESPUpdated = {
                Drawing2D = function(ent)
                        local EntityESP = Reference[ent]
                        if EntityESP then
                                if vape.ThreadFix then
                                        setthreadidentity(8)
                                end

                                if EntityESP.HealthLine then
                                        EntityESP.HealthLine.Color = getHealthBarColor(ent)
                                end

                                if EntityESP.Text then
                                        EntityESP.Text.Text = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name
                                        EntityESP.Drop.Text = EntityESP.Text.Text
                                end
                        end
                end
        }

        local ColorFunc = {
                Drawing2D = function(hue, sat, val)
                        local color = Color3.fromHSV(hue, sat, val)
                        for i, v in Reference do
                                v.Main.Color = entitylib.getEntityColor(i) or color
                                if v.Text then
                                        v.Text.Color = v.Main.Color
                                end
                        end
                end,
                Drawing3D = function(hue, sat, val)
                        local color = Color3.fromHSV(hue, sat, val)
                        for i, v in Reference do
                                local playercolor = entitylib.getEntityColor(i) or color
                                for _, v2 in v do
                                        v2.Color = playercolor
                                end
                        end
                end
        }
        ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D

        local ESPLoop = {
                Drawing2D = function()
                        for ent, EntityESP in Reference do
                                if Distance.Enabled then
                                        local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
                                        if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                                                for _, obj in EntityESP do
                                                        obj.Visible = false
                                                end
                                                continue
                                        end
                                end

                                local pos = ent.RootPart.Position

                                if shared.vape and shared.vape.hackerTable and table.find(shared.vape.hackerTable, ent.Player) and entitylib.isAlive then
                                        pos = Vector3.new(pos.X, entitylib.character.RootPart.Position.Y, pos.Z)
                                end

                                local rootPos, rootVis = gameCamera:WorldToViewportPoint(pos - V3_DOWN_05)
                                for _, obj in EntityESP do
                                        obj.Visible = rootVis
                                end
                                if not rootVis then continue end

                                local scale = BoxSize.Value
                                local lookOrigin = pos - V3_DOWN_05
                                local topPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(lookOrigin, gameCamera.CFrame.LookVector) * CFrame.new(scale, ent.HipHeight * scale, 0)).p)
                                local bottomPos = gameCamera:WorldToViewportPoint((CFrame.lookAlong(lookOrigin, gameCamera.CFrame.LookVector) * CFrame.new(-scale, -ent.HipHeight * scale - 1, 0)).p)
                                local sizex, sizey = topPos.X - bottomPos.X, topPos.Y - bottomPos.Y
                                local posx, posy = (rootPos.X - sizex / 2),  ((rootPos.Y - sizey / 2))
                                EntityESP.Main.Position = Vector2.new(posx, posy) // 1
                                EntityESP.Main.Size = Vector2.new(sizex, sizey) // 1
                                if EntityESP.Border then
                                        EntityESP.Border.Position = Vector2.new(posx - 1, posy + 1) // 1
                                        EntityESP.Border.Size = Vector2.new(sizex + 2, sizey - 2) // 1
                                        EntityESP.Border2.Position = Vector2.new(posx + 1, posy - 1) // 1
                                        EntityESP.Border2.Size = Vector2.new(sizex - 2, sizey + 2) // 1
                                end

                                if EntityESP.HealthLine then
                                        local healthposy = sizey * math.clamp(ent.Health / ent.MaxHealth, 0, 1)
                                        EntityESP.HealthLine.Visible = ent.Health > 0
                                        EntityESP.HealthLine.From = Vector2.new(posx - 6, posy + (sizey - (sizey - healthposy))) // 1
                                        EntityESP.HealthLine.To = Vector2.new(posx - 6, posy) // 1
                                        EntityESP.HealthBorder.From = Vector2.new(posx - 6, posy + 1) // 1
                                        EntityESP.HealthBorder.To = Vector2.new(posx - 6, (posy + sizey) - 1) // 1
                                end

                                if EntityESP.Text then
                                        EntityESP.Text.Position = Vector2.new(posx + (sizex / 2) + 4, posy + (sizey - 28)) // 1
                                        EntityESP.Drop.Position = EntityESP.Text.Position + V2_HALF
                                        if EntityESP.TextBKG then
                                                EntityESP.TextBKG.Size = EntityESP.Text.TextBounds + Vector2.new(8, 4)
                                                EntityESP.TextBKG.Position = EntityESP.Text.Position - Vector2.new(4 + (EntityESP.Text.TextBounds.X / 2), 0)
                                        end
                                end
                        end
                end,
                Drawing3D = function()
                        for ent, EntityESP in Reference do
                                if Distance.Enabled then
                                        local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
                                        if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                                                for _, obj in EntityESP do
                                                        obj.Visible = false
                                                end
                                                continue
                                        end
                                end

                                local pos = ent.RootPart.Position

                                if shared.vape and shared.vape.hackerTable and table.find(shared.vape.hackerTable, ent.Player) and entitylib.isAlive then
                                        pos = Vector3.new(pos.X, entitylib.character.RootPart.Position.Y, pos.Z)
                                end

                                local _, rootVis = gameCamera:WorldToViewportPoint(pos)
                                for _, obj in EntityESP do
                                        obj.Visible = rootVis
                                end
                                if not rootVis then continue end

                                local point1 = ESPWorldToViewport(pos + Vector3.new(1.5, ent.HipHeight, 1.5))
                                local point2 = ESPWorldToViewport(pos + Vector3.new(1.5, -ent.HipHeight, 1.5))
                                local point3 = ESPWorldToViewport(pos + Vector3.new(-1.5, ent.HipHeight, 1.5))
                                local point4 = ESPWorldToViewport(pos + Vector3.new(-1.5, -ent.HipHeight, 1.5))
                                local point5 = ESPWorldToViewport(pos + Vector3.new(1.5, ent.HipHeight, -1.5))
                                local point6 = ESPWorldToViewport(pos + Vector3.new(1.5, -ent.HipHeight, -1.5))
                                local point7 = ESPWorldToViewport(pos + Vector3.new(-1.5, ent.HipHeight, -1.5))
                                local point8 = ESPWorldToViewport(pos + Vector3.new(-1.5, -ent.HipHeight, -1.5))
                                EntityESP.Line1.From = point1
                                EntityESP.Line1.To = point2
                                EntityESP.Line2.From = point3
                                EntityESP.Line2.To = point4
                                EntityESP.Line3.From = point5
                                EntityESP.Line3.To = point6
                                EntityESP.Line4.From = point7
                                EntityESP.Line4.To = point8
                                EntityESP.Line5.From = point1
                                EntityESP.Line5.To = point3
                                EntityESP.Line6.From = point1
                                EntityESP.Line6.To = point5
                                EntityESP.Line7.From = point5
                                EntityESP.Line7.To = point7
                                EntityESP.Line8.From = point7
                                EntityESP.Line8.To = point3
                                EntityESP.Line9.From = point2
                                EntityESP.Line9.To = point4
                                EntityESP.Line10.From = point2
                                EntityESP.Line10.To = point6
                                EntityESP.Line11.From = point6
                                EntityESP.Line11.To = point8
                                EntityESP.Line12.From = point8
                                EntityESP.Line12.To = point4
                        end
                end,
                DrawingSkeleton = function()
                        for ent, EntityESP in Reference do
                                if Distance.Enabled then
                                        local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
                                        if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                                                for _, obj in EntityESP do
                                                        obj.Visible = false
                                                end
                                                continue
                                        end
                                end

                                local _, rootVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position)
                                for _, obj in EntityESP do
                                        obj.Visible = rootVis
                                end
                                if not rootVis then continue end

                                local rigcheck = ent.Humanoid.RigType == Enum.HumanoidRigType.R6
                                pcall(function()
                                        local offset = rigcheck and CFrame.new(0, -0.8, 0) or CFrame.identity
                                        local head = ESPWorldToViewport((ent.Head.CFrame).p)
                                        local headfront = ESPWorldToViewport((ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
                                        local toplefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
                                        local toprighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(1.5, 0.8, 0)).p)
                                        local toptorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, 0.8, 0)).p)
                                        local bottomtorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0, -0.8, 0)).p)
                                        local bottomlefttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
                                        local bottomrighttorso = ESPWorldToViewport((ent.Character[(rigcheck and 'Torso' or 'UpperTorso')].CFrame * CFrame.new(0.5, -0.8, 0)).p)
                                        local leftarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Arm' or 'LeftHand')].CFrame * offset).p)
                                        local rightarm = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Arm' or 'RightHand')].CFrame * offset).p)
                                        local leftleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Left Leg' or 'LeftFoot')].CFrame * offset).p)
                                        local rightleg = ESPWorldToViewport((ent.Character[(rigcheck and 'Right Leg' or 'RightFoot')].CFrame * offset).p)
                                        EntityESP.Head.From = toptorso
                                        EntityESP.Head.To = head
                                        EntityESP.HeadFacing.From = head
                                        EntityESP.HeadFacing.To = headfront
                                        EntityESP.UpperTorso.From = toplefttorso
                                        EntityESP.UpperTorso.To = toprighttorso
                                        EntityESP.Torso.From = toptorso
                                        EntityESP.Torso.To = bottomtorso
                                        EntityESP.LowerTorso.From = bottomlefttorso
                                        EntityESP.LowerTorso.To = bottomrighttorso
                                        EntityESP.LeftArm.From = toplefttorso
                                        EntityESP.LeftArm.To = leftarm
                                        EntityESP.RightArm.From = toprighttorso
                                        EntityESP.RightArm.To = rightarm
                                        EntityESP.LeftLeg.From = bottomlefttorso
                                        EntityESP.LeftLeg.To = leftleg
                                        EntityESP.RightLeg.From = bottomrighttorso
                                        EntityESP.RightLeg.To = rightleg
                                end)
                        end
                end
        }

        ESP = vape.Categories.Render:CreateModule({
                Name = 'ESP',
                Function = function(callback)
                        if callback then
                                methodused = 'Drawing'..Method.Value
                                if ESPRemoved[methodused] then
                                        ESP:Clean(entitylib.Events.EntityRemoved:Connect(ESPRemoved[methodused]))
                                end
                                if ESPAdded[methodused] then
                                        for _, v in entitylib.List do
                                                if Reference[v] then
                                                        ESPRemoved[methodused](v)
                                                end
                                                ESPAdded[methodused](v)
                                        end
                                        ESP:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                                                if Reference[ent] then
                                                        ESPRemoved[methodused](ent)
                                                end
                                                ESPAdded[methodused](ent)
                                        end))
                                end
                                if ESPUpdated[methodused] then
                                        ESP:Clean(entitylib.Events.EntityUpdated:Connect(ESPUpdated[methodused]))
                                        for _, v in entitylib.List do
                                                ESPUpdated[methodused](v)
                                        end
                                end
                                if ColorFunc[methodused] then
                                        ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
                                                ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
                                        end))
                                end
                                if ESPLoop[methodused] then
                                        ESP:Clean(runService.RenderStepped:Connect(ESPLoop[methodused]))
                                end
                        else
                                if ESPRemoved[methodused] then
                                        for i in Reference do
                                                ESPRemoved[methodused](i)
                                        end
                                end
                        end
                end,
                Tooltip = 'Extra Sensory Perception\nRenders an ESP on players.'
        })
        Targets = ESP:CreateTargets({
                Players = true,
                Function = function()
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                end
        })
        Method = ESP:CreateDropdown({
                Name = 'Mode',
                List = {'2D', '3D', 'Skeleton'},
                Function = function(val)
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                        BoundingBox.Object.Visible = (val == '2D')
                        Filled.Object.Visible = (val == '2D')
                        HealthBar.Object.Visible = (val == '2D')
                        HealthBarColorToggle.Object.Visible = (val == '2D') and HealthBar.Enabled
                        HealthBarColor.Object.Visible = (val == '2D') and HealthBar.Enabled and HealthBarColorToggle.Enabled
                        Name.Object.Visible = (val == '2D')
                        DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
                        Background.Object.Visible = Name.Object.Visible and Name.Enabled
                end,
        })
        Color = ESP:CreateColorSlider({
                Name = 'Player Color',
                Function = function(hue, sat, val)
                        if ESP.Enabled and ColorFunc[methodused] then
                                ColorFunc[methodused](hue, sat, val)
                        end
                end
        })
        BoxSize = ESP:CreateSlider({
                Name = 'Box Size',
                Min = 0.1,
                Max = 5,
                Default = 2,
                Decimal = 10,
                Darker = true
        })
        BoundingBox = ESP:CreateToggle({
                Name = 'Bounding Box',
                Function = function()
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                end,
                Default = true,
                Darker = true
        })
        Filled = ESP:CreateToggle({
                Name = 'Filled',
                Function = function()
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                end,
                Darker = true
        })
        HealthBar = ESP:CreateToggle({
                Name = 'Health Bar',
                Function = function(callback)
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                        HealthBarColorToggle.Object.Visible = callback
                        HealthBarColor.Object.Visible = callback and HealthBarColorToggle.Enabled
                end,
                Darker = true
        })
        HealthBarColorToggle = ESP:CreateToggle({
                Name = 'Custom Health Color',
                Function = function(callback)
                        HealthBarColor.Object.Visible = callback
                        for ent, EntityESP in Reference do
                                if EntityESP.HealthLine then
                                        EntityESP.HealthLine.Color = getHealthBarColor(ent)
                                end
                        end
                end,
                Darker = true,
                Visible = false
        })
        HealthBarColor = ESP:CreateColorSlider({
                Name = 'Health Bar Color',
                Function = function(hue, sat, val)
                        if not HealthBarColorToggle.Enabled then return end
                        local color = Color3.fromHSV(hue, sat, val)
                        for _, EntityESP in Reference do
                                if EntityESP.HealthLine then
                                        EntityESP.HealthLine.Color = color
                                end
                        end
                end,
                Darker = true,
                Visible = false
        })
        Name = ESP:CreateToggle({
                Name = 'Name',
                Function = function(callback)
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                        DisplayName.Object.Visible = callback
                        Background.Object.Visible = callback
                end,
                Darker = true
        })
        DisplayName = ESP:CreateToggle({
                Name = 'Use Displayname',
                Function = function()
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                end,
                Default = true,
                Darker = true
        })
        Background = ESP:CreateToggle({
                Name = 'Show Background',
                Function = function()
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                end,
                Darker = true
        })
        Teammates = ESP:CreateToggle({
                Name = 'Priority Only',
                Function = function()
                        if ESP.Enabled then
                                ESP:Toggle()
                                ESP:Toggle()
                        end
                end,
                Default = true,
                Tooltip = 'Hides teammates & non targetable entities'
        })
        Distance = ESP:CreateToggle({
                Name = 'Distance Check',
                Function = function(callback)
                        DistanceLimit.Object.Visible = callback
                end
        })
        DistanceLimit = ESP:CreateTwoSlider({
                Name = 'Player Distance',
                Min = 0,
                Max = 256,
                DefaultMin = 0,
                DefaultMax = 64,
                Darker = true,
                Visible = false
        })
end)
        
run(function()
        local GamingChair = {Enabled = false}
        local Color
        local wheelpositions = {
                Vector3.new(-0.8, -0.6, -0.18),
                Vector3.new(0.1, -0.6, -0.88),
                Vector3.new(0, -0.6, 0.7)
        }
        local chairhighlight
        local currenttween
        local movingsound
        local flyingsound
        local chairanim
        local chair
        
        GamingChair = vape.Categories.Render:CreateModule({
                Name = 'GamingChair',
                Function = function(callback)
                        if callback then
                                if vape.ThreadFix then
                                        setthreadidentity(8)
                                end
                                chair = Instance.new('MeshPart')
                                chair.Color = Color3.fromRGB(21, 21, 21)
                                chair.Size = Vector3.new(2.16, 3.6, 2.3) / Vector3.new(12.37, 20.636, 13.071)
                                chair.CanCollide = false
                                chair.Massless = true
                                chair.MeshId = 'rbxassetid://12972961089'
                                chair.Material = Enum.Material.SmoothPlastic
                                chair.Parent = workspace
                                movingsound = Instance.new('Sound')
                                movingsound.Volume = 0.4
                                movingsound.Looped = true
                                movingsound.Parent = workspace
                                flyingsound = Instance.new('Sound')
                                flyingsound.Volume = 0.4
                                flyingsound.Looped = true
                                flyingsound.Parent = workspace
                                local chairweld = Instance.new('WeldConstraint')
                                chairweld.Part0 = chair
                                chairweld.Parent = chair
                                if entitylib.isAlive then
                                        chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
                                        chairweld.Part1 = entitylib.character.RootPart
                                end
                                chairhighlight = Instance.new('Highlight')
                                chairhighlight.FillTransparency = 1
                                chairhighlight.OutlineColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                                chairhighlight.DepthMode = Enum.HighlightDepthMode.Occluded
                                chairhighlight.OutlineTransparency = 0.2
                                chairhighlight.Parent = chair
                                local chairarms = Instance.new('MeshPart')
                                chairarms.Color = chair.Color
                                chairarms.Size = Vector3.new(1.39, 1.345, 2.75) / Vector3.new(97.13, 136.216, 234.031)
                                chairarms.CFrame = chair.CFrame * CFrame.new(-0.169, -1.129, -0.013)
                                chairarms.MeshId = 'rbxassetid://12972673898'
                                chairarms.CanCollide = false
                                chairarms.Parent = chair
                                local chairarmsweld = Instance.new('WeldConstraint')
                                chairarmsweld.Part0 = chairarms
                                chairarmsweld.Part1 = chair
                                chairarmsweld.Parent = chair
                                local chairlegs = Instance.new('MeshPart')
                                chairlegs.Color = chair.Color
                                chairlegs.Name = 'Legs'
                                chairlegs.Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
                                chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
                                chairlegs.MeshId = 'rbxassetid://13003181606'
                                chairlegs.CanCollide = false
                                chairlegs.Parent = chair
                                local chairfan = Instance.new('MeshPart')
                                chairfan.Color = chair.Color
                                chairfan.Name = 'Fan'
                                chairfan.Size = Vector3.zero
                                chairfan.CFrame = chair.CFrame * CFrame.new(0, -1.873, 0)
                                chairfan.MeshId = 'rbxassetid://13004977292'
                                chairfan.CanCollide = false
                                chairfan.Parent = chair
                                local trails = {}
                                for _, v in wheelpositions do
                                        local attachment = Instance.new('Attachment')
                                        attachment.Position = v
                                        attachment.Parent = chairlegs
                                        local attachment2 = Instance.new('Attachment')
                                        attachment2.Position = v + Vector3.new(0, 0, 0.18)
                                        attachment2.Parent = chairlegs
                                        local trail = Instance.new('Trail')
                                        trail.Texture = 'http://www.roblox.com/asset/?id=13005168530'
                                        trail.TextureMode = Enum.TextureMode.Static
                                        trail.Transparency = NumberSequence.new(0.5)
                                        trail.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
                                        trail.Attachment0 = attachment
                                        trail.Attachment1 = attachment2
                                        trail.Lifetime = 20
                                        trail.MaxLength = 60
                                        trail.MinLength = 0.1
                                        trail.Parent = chairlegs
                                        table.insert(trails, trail)
                                end
                                GamingChair:Clean(chair)
                                GamingChair:Clean(movingsound)
                                GamingChair:Clean(flyingsound)
                                chairanim = {Stop = function() end}
                                local oldmoving = false
                                local oldflying = false
                                repeat
                                        if entitylib.isAlive and entitylib.character.Humanoid.Health > 0 then
                                                if not chairanim.IsPlaying then
                                                        local temp2 = Instance.new('Animation')
                                                        temp2.AnimationId = entitylib.character.Humanoid.RigType == Enum.HumanoidRigType.R15 and 'http://www.roblox.com/asset/?id=2506281703' or 'http://www.roblox.com/asset/?id=178130996'
                                                        chairanim = entitylib.character.Humanoid:LoadAnimation(temp2)
                                                        chairanim.Priority = Enum.AnimationPriority.Movement
                                                        chairanim.Looped = true
                                                        chairanim:Play()
                                                end
                                                chair.CFrame = entitylib.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
                                                chairweld.Part1 = entitylib.character.RootPart
                                                chairlegs.Velocity = Vector3.zero
                                                chairlegs.CFrame = chair.CFrame * CFrame.new(0.047, -2.324, 0)
                                                chairfan.Velocity = Vector3.zero
                                                chairfan.CFrame = chair.CFrame * CFrame.new(0.047, -1.873, 0) * CFrame.Angles(0, math.rad(tick() * 180 % 360), math.rad(180))
                                                local moving = entitylib.character.Humanoid:GetState() == Enum.HumanoidStateType.Running and entitylib.character.Humanoid.MoveDirection ~= Vector3.zero
                                                local flying = vape.Modules.Fly and vape.Modules.Fly.Enabled or vape.Modules.LongJump and vape.Modules.LongJump.Enabled or vape.Modules.InfiniteFly and vape.Modules.InfiniteFly.Enabled
                                                if movingsound.TimePosition > 1.9 then
                                                        movingsound.TimePosition = 0.2
                                                end
                                                movingsound.PlaybackSpeed = (entitylib.character.RootPart.Velocity * Vector3.new(1, 0, 1)).Magnitude / 16
                                                for _, v in trails do
                                                        v.Enabled = not flying and moving
                                                        v.Color = ColorSequence.new(movingsound.PlaybackSpeed > 1.5 and Color3.new(1, 0.5, 0) or Color3.new())
                                                end
                                                if moving ~= oldmoving then
                                                        if movingsound.IsPlaying then
                                                                if not moving then
                                                                        movingsound:Stop()
                                                                end
                                                        else
                                                                if not flying and moving then
                                                                        movingsound:Play()
                                                                end
                                                        end
                                                        oldmoving = moving
                                                end
                                                if flying ~= oldflying then
                                                        if flying then
                                                                if movingsound.IsPlaying then
                                                                        movingsound:Stop()
                                                                end
                                                                if not flyingsound.IsPlaying then
                                                                        flyingsound:Play()
                                                                end
                                                                if currenttween then
                                                                        currenttween:Cancel()
                                                                end
                                                                tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
                                                                        Size = Vector3.zero
                                                                })
                                                                tween.Completed:Connect(function(state)
                                                                        if state == Enum.PlaybackState.Completed then
                                                                                chairfan.Transparency = 0
                                                                                chairlegs.Transparency = 1
                                                                                tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
                                                                                        Size = Vector3.new(1.534, 0.328, 1.537) / Vector3.new(791.138, 168.824, 792.027)
                                                                                })
                                                                                tween:Play()
                                                                        end
                                                                end)
                                                                tween:Play()
                                                        else
                                                                if flyingsound.IsPlaying then
                                                                        flyingsound:Stop()
                                                                end
                                                                if not movingsound.IsPlaying and moving then
                                                                        movingsound:Play()
                                                                end
                                                                if currenttween then currenttween:Cancel() end
                                                                tween = tweenService:Create(chairfan, TweenInfo.new(0.15), {
                                                                        Size = Vector3.zero
                                                                })
                                                                tween.Completed:Connect(function(state)
                                                                        if state == Enum.PlaybackState.Completed then
                                                                                chairfan.Transparency = 1
                                                                                chairlegs.Transparency = 0
                                                                                tween = tweenService:Create(chairlegs, TweenInfo.new(0.15), {
                                                                                        Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
                                                                                })
                                                                                tween:Play()
                                                                        end
                                                                end)
                                                                tween:Play()
                                                        end
                                                        oldflying = flying
                                                end
                                        else
                                                chair.Anchored = true
                                                chairlegs.Anchored = true
                                                chairfan.Anchored = true
                                                repeat task.wait() until entitylib.isAlive and entitylib.character.Humanoid.Health > 0
                                                chair.Anchored = false
                                                chairlegs.Anchored = false
                                                chairfan.Anchored = false
                                                chairanim:Stop()
                                        end
                                        task.wait()
                                until not GamingChair.Enabled
                        else
                                if chairanim then
                                        chairanim:Stop()
                                end
                        end
                end,
                Tooltip = 'Sit in the best gaming chair known to mankind.'
        })
        Color = GamingChair:CreateColorSlider({
                Name = 'Color',
                Function = function(h, s, v)
                        if chairhighlight then
                                chairhighlight.OutlineColor = Color3.fromHSV(h, s, v)
                        end
                end
        })
end)
        
run(function()
        local Health
        
        Health = vape.Categories.Render:CreateModule({
                Name = 'Health',
                Function = function(callback)
                        if callback then
                                local label = Instance.new('TextLabel')
                                label.Size = UDim2.fromOffset(100, 20)
                                label.Position = UDim2.new(0.5, 6, 0.5, 30)
                                label.AnchorPoint = Vector2.new(0.5, 0)
                                label.BackgroundTransparency = 1
                                label.Text = '100 ❤️'
                                label.TextSize = 18
                                label.Font = Enum.Font.Arial
                                label.Parent = vape.gui
                                Health:Clean(label)
                                
                                repeat
                                        label.Text = entitylib.isAlive and math.round(entitylib.character.Humanoid.Health)..' ❤️' or ''
                                        label.TextColor3 = entitylib.isAlive and Color3.fromHSV((entitylib.character.Humanoid.Health / entitylib.character.Humanoid.MaxHealth) / 2.8, 0.86, 1) or Color3.new()
                                        task.wait()
                                until not Health.Enabled
                        end
                end,
                Tooltip = 'Displays your health in the center of your screen.'
        })
        local Radar
        local Targets
        local DotStyle
        local PlayerColor
        local Clamp
        local Reference = {}
        local V3_XZ = Vector3.new(1, 0, 1)
        local bkg
        
        local function Added(ent)
                if not Targets.Players.Enabled and ent.Player then return end
                if not Targets.NPCs.Enabled and ent.NPC then return end
                if (not ent.Targetable) and (not ent.Friend) then return end
                if vape.ThreadFix then
                        setthreadidentity(8)
                end
        
                local dot = Instance.new('Frame')
                dot.Size = UDim2.fromOffset(4, 4)
                dot.AnchorPoint = Vector2.new(0.5, 0.5)
                dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
                dot.Parent = bkg
                local corner = Instance.new('UICorner')
                corner.CornerRadius = UDim.new(DotStyle.Value == 'Circles' and 1 or 0, 0)
                corner.Parent = dot
                local stroke = Instance.new('UIStroke')
                stroke.Color = Color3.new()
                stroke.Thickness = 1
                stroke.Transparency = 0.8
                stroke.Parent = dot
                Reference[ent] = dot
        end
        
        local function Removed(ent)
                local v = Reference[ent]
                if v then
                        if vape.ThreadFix then
                                setthreadidentity(8)
                        end
                        Reference[ent] = nil
                        v:Destroy()
                end
        end
        
        Radar = vape:CreateOverlay({
                Name = 'Radar',
                Icon = getcustomasset('newvape/assets/new/radaricon.png'),
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.fromOffset(12, 13),
                Function = function(callback)
                        if callback then
                                Radar:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
                                for _, v in entitylib.List do
                                        if Reference[v] then
                                                Removed(v)
                                        end
                                        Added(v)
                                end
                                Radar:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                                        if Reference[ent] then
                                                Removed(ent)
                                        end
                                        Added(ent)
                                end))
                                Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
                                        for ent, dot in Reference do
                                                dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
                                        end
                                end))
                                Radar:Clean(runService.Heartbeat:Connect(function()
                                        for ent, dot in Reference do
                                                if entitylib.isAlive then
                                                        local dt = CFrame.lookAlong(entitylib.character.RootPart.Position, gameCamera.CFrame.LookVector * V3_XZ):PointToObjectSpace(ent.RootPart.Position)
                                                        dot.Position = UDim2.fromOffset(Clamp.Enabled and math.clamp(108 + dt.X, 2, 214) or 108 + dt.X, Clamp.Enabled and math.clamp(108 + dt.Z, 8, 214) or 108 + dt.Z)
                                                end
                                        end
                                end))
                        else
                                for ent in Reference do
                                        Removed(ent)
                                end
                        end
                end
        })
        Targets = Radar:CreateTargets({
                Players = true,
                Function = function()
                        if Radar.Button.Enabled then
                                Radar.Button:Toggle()
                                Radar.Button:Toggle()
                        end
                end
        })
        DotStyle = Radar:CreateDropdown({
                Name = 'Dot Style',
                List = {'Circles', 'Squares'},
                Function = function(val)
                        for _, dot in Reference do
                                dot.UICorner.CornerRadius = UDim.new(val == 'Circles' and 1 or 0, 0)
                        end
                end
        })
        PlayerColor = Radar:CreateColorSlider({
                Name = 'Player Color',
                Function = function(hue, sat, val)
                        for ent, dot in Reference do
                                dot.BackgroundColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(hue, sat, val)
                        end
                end
        })
        bkg = Instance.new('Frame')
        bkg.Size = UDim2.fromOffset(216, 216)
        bkg.Position = UDim2.fromOffset(2, 2)
        bkg.BackgroundColor3 = Color3.new()
        bkg.BackgroundTransparency = 0.5
        bkg.ClipsDescendants = true
        bkg.Parent = Radar.Children
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = bkg
        local stroke = Instance.new('UIStroke')
        stroke.Thickness = 2
        stroke.Color = Color3.new()
        stroke.Transparency = 0.4
        stroke.Parent = bkg
        local line1 = Instance.new('Frame')
        line1.Size = UDim2.new(0, 2, 1, 0)
        line1.Position = UDim2.fromScale(0.5, 0.5)
        line1.AnchorPoint = Vector2.new(0.5, 0.5)
        line1.ZIndex = 0
        line1.BackgroundColor3 = Color3.new(1, 1, 1)
        line1.BackgroundTransparency = 0.5
        line1.BorderSizePixel = 0
        line1.Parent = bkg
        local line2 = line1:Clone()
        line2.Size = UDim2.new(1, 0, 0, 2)
        line2.Parent = bkg
        local bar = Instance.new('Frame')
        bar.Size = UDim2.new(1, -6, 0, 4)
        bar.Position = UDim2.fromOffset(3, 0)
        bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
        bar.Parent = bkg
        local barcorner = Instance.new('UICorner')
        barcorner.CornerRadius = UDim.new(0, 8)
        barcorner.Parent = bar
        Radar:CreateColorSlider({
                Name = 'Bar Color',
                Function = function(hue, sat, val)
                        bar.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                end
        })
        Radar:CreateToggle({
                Name = 'Show Background',
                Default = true,
                Function = function(callback)
                        bkg.BackgroundTransparency = callback and 0.5 or 1
                        bar.BackgroundTransparency = callback and 0 or 1
                        stroke.Transparency = callback and 0.4 or 1
                end
        })
        Radar:CreateToggle({
                Name = 'Show Cross',
                Default = true,
                Function = function(callback)
                        line1.BackgroundTransparency = callback and 0.5 or 1
                        line2.BackgroundTransparency = callback and 0.5 or 1
                end
        })
        Clamp = Radar:CreateToggle({
                Name = 'Clamp Radar',
                Default = true
        })
end)
run(function()
        local SessionInfo
        local FontOption
        local Hide
        local TextSize
        local BorderColor
        local Title
        local TitleOffset = {}
        local Custom
        local CustomBox
        local infoholder
        local infolabel
        local infostroke
        
        SessionInfo = vape:CreateOverlay({
                Name = 'Session Info',
                Icon = getcustomasset('newvape/assets/new/textguiicon.png'),
                Size = UDim2.fromOffset(16, 12),
                Position = UDim2.fromOffset(12, 14),
                Function = function(callback)
                        if callback then
                                local teleportedServers
                                SessionInfo:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
                                        if not teleportedServers then
                                                teleportedServers = true
                                                queue_on_teleport("shared.vapesessioninfo = '"..httpService:JSONEncode(vape.Libraries.sessioninfo.Objects).."'")
                                        end
                                end))
        
                                if shared.vapesessioninfo then
                                        for i, v in httpService:JSONDecode(shared.vapesessioninfo) do
                                                if vape.Libraries.sessioninfo.Objects[i] and v.Saved then
                                                        vape.Libraries.sessioninfo.Objects[i].Value = v.Value
                                                end
                                        end
                                end
        
                                repeat
                                        if vape.Libraries.sessioninfo then
                                                local stuff = {''}
                                                if Title.Enabled then
                                                        stuff[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>' or '<b>Session Info</b>'
                                                end
        
                                                for i, v in vape.Libraries.sessioninfo.Objects do
                                                        stuff[v.Index] = not table.find(Hide.ListEnabled, i) and i..': '..v.Function(v.Value) or false
                                                end
        
                                                if #Hide.ListEnabled > 0 then
                                                        local key, val
                                                        repeat
                                                                local oldkey = key
                                                                key, val = next(stuff, key)
                                                                if val == false then
                                                                        table.remove(stuff, key)
                                                                        key = oldkey
                                                                end
                                                        until not key
                                                end
        
                                                if Custom.Enabled then
                                                        table.insert(stuff, CustomBox.Value)
                                                end
        
                                                if not Title.Enabled then
                                                        table.remove(stuff, 1)
                                                end
                                                infolabel.Text = table.concat(stuff, '\n')
                                                infolabel.FontFace = FontOption.Value
                                                infolabel.TextSize = TextSize.Value
                                                local size = getfontsize(removeTags(infolabel.Text), infolabel.TextSize, infolabel.FontFace)
                                                infoholder.Size = UDim2.fromOffset(size.X + 16, size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
                                        end
                                        task.wait(1)
                                until not SessionInfo.Button or not SessionInfo.Button.Enabled
                        end
                end
        })
        FontOption = SessionInfo:CreateFont({
                Name = 'Font',
                Blacklist = 'Arial'
        })
        Hide = SessionInfo:CreateTextList({
                Name = 'Blacklist',
                Tooltip = 'Name of entry to hide.',
                Icon = getcustomasset('newvape/assets/new/blockedicon.png'),
                Tab = getcustomasset('newvape/assets/new/blockedtab.png'),
                TabSize = UDim2.fromOffset(21, 16),
                Color = Color3.fromRGB(250, 50, 56)
        })
        SessionInfo:CreateColorSlider({
                Name = 'Background Color',
                DefaultValue = 0,
                DefaultOpacity = 0.5,
                Function = function(hue, sat, val, opacity)
                        infoholder.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        infoholder.BackgroundTransparency = 1 - opacity
                end
        })
        BorderColor = SessionInfo:CreateColorSlider({
                Name = 'Border Color',
                Function = function(hue, sat, val, opacity)
                        infostroke.Color = Color3.fromHSV(hue, sat, val)
                        infostroke.Transparency = 1 - opacity
                end,
                Darker = true,
                Visible = false
        })
        TextSize = SessionInfo:CreateSlider({
                Name = 'Text Size',
                Min = 1,
                Max = 30,
                Default = 16
        })
        Title = SessionInfo:CreateToggle({
                Name = 'Title',
                Function = function(callback)
                        if TitleOffset.Object then
                                TitleOffset.Object.Visible = callback
                        end
                end,
                Default = true
        })
        TitleOffset = SessionInfo:CreateToggle({
                Name = 'Offset',
                Default = true,
                Darker = true
        })
        SessionInfo:CreateToggle({
                Name = 'Border',
                Function = function(callback)
                        infostroke.Enabled = callback
                        BorderColor.Object.Visible = callback
                end
        })
        Custom = SessionInfo:CreateToggle({
                Name = 'Add custom text',
                Function = function(enabled)
                        CustomBox.Object.Visible = enabled
                end
        })
        CustomBox = SessionInfo:CreateTextBox({
                Name = 'Custom text',
                Darker = true,
                Visible = false
        })
        infoholder = Instance.new('Frame')
        infoholder.BackgroundColor3 = Color3.new()
        infoholder.BackgroundTransparency = 0.5
        infoholder.Parent = SessionInfo.Children
        vape:Clean(SessionInfo.Children:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
                if vape.ThreadFix then
                        setthreadidentity(8)
                end
                local newside = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
                infoholder.Position = UDim2.fromScale(newside and 1 or 0, 0)
                infoholder.AnchorPoint = Vector2.new(newside and 1 or 0, 0)
        end))
        local sessioninfocorner = Instance.new('UICorner')
        sessioninfocorner.CornerRadius = UDim.new(0, 5)
        sessioninfocorner.Parent = infoholder
        infolabel = Instance.new('TextLabel')
        infolabel.Size = UDim2.new(1, -16, 1, -16)
        infolabel.Position = UDim2.fromOffset(8, 8)
        infolabel.BackgroundTransparency = 1
        infolabel.TextXAlignment = Enum.TextXAlignment.Left
        infolabel.TextYAlignment = Enum.TextYAlignment.Top
        infolabel.TextSize = 16
        infolabel.TextColor3 = Color3.new(1, 1, 1)
        infolabel.TextStrokeColor3 = Color3.new()
        infolabel.TextStrokeTransparency = 0.8
        infolabel.Font = Enum.Font.Arial
        infolabel.RichText = true
        infolabel.Parent = infoholder
        infostroke = Instance.new('UIStroke')
        infostroke.Enabled = false
        infostroke.Color = Color3.fromHSV(0.44, 1, 1)
        infostroke.Parent = infoholder
        addBlur(infoholder)
        vape.Libraries.sessioninfo = {
                Objects = {},
                AddItem = function(self, name, startvalue, func, saved)
                        func, saved = func or function(val) return val end, saved == nil or saved
                        self.Objects[name] = {Function = func, Saved = saved, Value = startvalue or 0, Index = getTableSize(self.Objects) + 2}
                        return {
                                Increment = function(_, val)
                                        self.Objects[name].Value = self.Objects[name].Value + (val or 1)
                                end,
                                Get = function()
                                        return self.Objects[name].Value
                                end
                        }
                end
        }
        vape.Libraries.sessioninfo:AddItem('Time Played', os.clock(), function(value)
                return os.date('!%X', math.floor(os.clock() - value))
        end)
end)
        
run(function()
        local Tracers
        local Targets
        local Color
        local Transparency
        local StartPosition
        local EndPosition
        local Teammates
        local DistanceColor
        local Distance
        local DistanceLimit
        local Behind
        local Reference = {}
        
        local function Added(ent)
                if not Targets.Players.Enabled and ent.Player then return end
                if not Targets.NPCs.Enabled and ent.NPC then return end
                if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
                if vape.ThreadFix then
                        setthreadidentity(8)
                end
        
                local EntityTracer = Drawing.new('Line')
                EntityTracer.Thickness = 1
                EntityTracer.Transparency = 1 - Transparency.Value
                EntityTracer.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                Reference[ent] = EntityTracer
        end
        
        local function Removed(ent)
                local v = Reference[ent]
                if v then
                        if vape.ThreadFix then
                                setthreadidentity(8)
                        end
                        Reference[ent] = nil
                        pcall(function()
                                v.Visible = false
                                v:Remove()
                        end)
                end
        end
        
        local function ColorFunc(hue, sat, val)
                if DistanceColor.Enabled then return end
                local tracerColor = Color3.fromHSV(hue, sat, val)
                for ent, EntityTracer in Reference do
                        EntityTracer.Color = entitylib.getEntityColor(ent) or tracerColor
                end
        end
        
        local function Loop()
                local screenSize = vape.gui.AbsoluteSize
                local startVector = StartPosition.Value == 'Mouse' and inputService:GetMouseLocation() or Vector2.new(screenSize.X / 2, (StartPosition.Value == 'Middle' and screenSize.Y / 2 or screenSize.Y))
        
                for ent, EntityTracer in Reference do
                        local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
                        if Distance.Enabled and distance then
                                if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
                                        EntityTracer.Visible = false
                                        continue
                                end
                        end
        
                        local pos = ent[EndPosition.Value == 'Torso' and 'RootPart' or 'Head'].Position
                        local rootPos, rootVis = gameCamera:WorldToViewportPoint(pos)
                        if not rootVis and Behind.Enabled then
                                local tempPos = gameCamera.CFrame:PointToObjectSpace(pos)
                                tempPos = CFrame.Angles(0, 0, (math.atan2(tempPos.Y, tempPos.X) + math.pi)):VectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))))
                                rootPos = gameCamera:WorldToViewportPoint(gameCamera.CFrame:pointToWorldSpace(tempPos))
                                rootVis = true
                        end
        
                        local endVector = Vector2.new(rootPos.X, rootPos.Y)
                        EntityTracer.Visible = rootVis
                        EntityTracer.From = startVector
                        EntityTracer.To = endVector
                        if DistanceColor.Enabled and distance then
                                EntityTracer.Color = Color3.fromHSV(math.min((distance / 128) / 2.8, 0.4), 0.89, 0.75)
                        end
                end
        end
        
        Tracers = vape.Categories.Render:CreateModule({
                Name = 'Tracers',
                Function = function(callback)
                        if callback then
                                Tracers:Clean(entitylib.Events.EntityRemoved:Connect(Removed))
                                for _, v in entitylib.List do
                                        if Reference[v] then
                                                Removed(v)
                                        end
                                        Added(v)
                                end
                                Tracers:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
                                        if Reference[ent] then
                                                Removed(ent)
                                        end
                                        Added(ent)
                                end))
                                Tracers:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
                                        ColorFunc(Color.Hue, Color.Sat, Color.Value)
                                end))
                                Tracers:Clean(runService.Heartbeat:Connect(Loop))
                        else
                                for i in Reference do
                                        Removed(i)
                                end
                        end
                end,
                Tooltip = 'Renders tracers on players.'
        })
        Targets = Tracers:CreateTargets({
                Players = true,
                Function = function()
                        if Tracers.Enabled then
                                Tracers:Toggle()
                                Tracers:Toggle()
                        end
                end
        })
        StartPosition = Tracers:CreateDropdown({
                Name = 'Start Position',
                List = {'Middle', 'Bottom', 'Mouse'},
                Function = function()
                        if Tracers.Enabled then
                                Tracers:Toggle()
                                Tracers:Toggle()
                        end
                end
        })
        EndPosition = Tracers:CreateDropdown({
                Name = 'End Position',
                List = {'Head', 'Torso'},
                Function = function()
                        if Tracers.Enabled then
                                Tracers:Toggle()
                                Tracers:Toggle()
                        end
                end
        })
        Color = Tracers:CreateColorSlider({
                Name = 'Player Color',
                Function = function(hue, sat, val)
                        if Tracers.Enabled then
                                ColorFunc(hue, sat, val)
                        end
                end
        })
        Transparency = Tracers:CreateSlider({
                Name = 'Transparency',
                Min = 0,
                Max = 1,
                Function = function(val)
                        for _, tracer in Reference do
                                tracer.Transparency = 1 - val
                        end
                end,
                Decimal = 10
        })
        DistanceColor = Tracers:CreateToggle({
                Name = 'Color by distance',
                Function = function()
                        if Tracers.Enabled then
                                Tracers:Toggle()
                                Tracers:Toggle()
                        end
                end
        })
        Distance = Tracers:CreateToggle({
                Name = 'Distance Check',
                Function = function(callback)
                        DistanceLimit.Object.Visible = callback
                end
        })
        DistanceLimit = Tracers:CreateTwoSlider({
                Name = 'Player Distance',
                Min = 0,
                Max = 256,
                DefaultMin = 0,
                DefaultMax = 64,
                Darker = true,
                Visible = false
        })
        Behind = Tracers:CreateToggle({
                Name = 'Behind',
                Default = true
        })
        Teammates = Tracers:CreateToggle({
                Name = 'Priority Only',
                Function = function()
                        if Tracers.Enabled then
                                Tracers:Toggle()
                                Tracers:Toggle()
                        end
                end,
                Default = true,
                Tooltip = 'Hides teammates & non targetable entities'
        })
end)
run(function()
        local AnimationPlayer
        local IDBox
        local Priority
        local Speed
        local anim, animobject
        
        local function playAnimation(char)
                local animcheck = anim
                if animcheck then
                        anim = nil
                        animcheck:Stop()
                end
        
                local suc, res = pcall(function()
                        anim = char.Humanoid.Animator:LoadAnimation(animobject)
                end)
        
                if suc then
                        local currentanim = anim
                        anim.Priority = Enum.AnimationPriority[Priority.Value]
                        anim:Play()
                        anim:AdjustSpeed(Speed.Value)
                        AnimationPlayer:Clean(anim.Stopped:Connect(function()
                                if currentanim == anim then
                                        anim:Play()
                                end
                        end))
                else
                        notif('AnimationPlayer', 'failed to load anim : '..(res or 'invalid animation id'), 5, 'warning')
                end
        end
        
        AnimationPlayer = vape.Categories.Utility:CreateModule({
                Name = 'AnimationPlayer',
                Function = function(callback)
                        if callback then
                                animobject = Instance.new('Animation')
                                local suc, id = pcall(function()
                                        return string.match(game:GetObjects('rbxassetid://'..IDBox.Value)[1].AnimationId, '%?id=(%d+)')
                                end)
                                animobject.AnimationId = 'rbxassetid://'..(suc and id or IDBox.Value)
        
                                if entitylib.isAlive then
                                        playAnimation(entitylib.character)
                                end
                                AnimationPlayer:Clean(entitylib.Events.LocalAdded:Connect(playAnimation))
                                AnimationPlayer:Clean(animobject)
                        else
                                if anim then
                                        anim:Stop()
                                end
                        end
                end,
                Tooltip = 'Plays a specific animation of your choosing at a certain speed'
        })
        IDBox = AnimationPlayer:CreateTextBox({
                Name = 'Animation',
                Placeholder = 'anim (num only)',
                Function = function(enter)
                        if enter and AnimationPlayer.Enabled then
                                AnimationPlayer:Toggle()
                                AnimationPlayer:Toggle()
                        end
                end
        })
        local prio = {'Action4'}
        for _, v in Enum.AnimationPriority:GetEnumItems() do
                if v.Name ~= 'Action4' then
                        table.insert(prio, v.Name)
                end
        end
        Priority = AnimationPlayer:CreateDropdown({
                Name = 'Priority',
                List = prio,
                Function = function(val)
                        if anim then
                                anim.Priority = Enum.AnimationPriority[val]
                        end
                end
        })
        Speed = AnimationPlayer:CreateSlider({
                Name = 'Speed',
                Function = function(val)
                        if anim then
                                anim:AdjustSpeed(val)
                        end
                end,
                Min = 0.1,
                Max = 2,
                Decimal = 10
        })
        local Lines
        local Mode
        local Delay
        local Hide
        local oldchat
        
        ChatSpammer = vape.Categories.Utility:CreateModule({
                Name = 'ChatSpammer',
                Function = function(callback)
                        if callback then
                                if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                                        if Hide.Enabled and coreGui:FindFirstChild('ExperienceChat') then
                                                ChatSpammer:Clean(coreGui.ExperienceChat:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(msg)
                                                        if msg.Name:sub(1, 2) == '0-' and msg.ContentText == 'You must wait before sending another message.' then
                                                                msg.Visible = false
                                                        end
                                                end))
                                        end
                                elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
                                        if Hide.Enabled then
                                                oldchat = hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, function(data, ...)
                                                        if data.Message:find('ChatFloodDetector') then return end
                                                        return oldchat(data, ...)
                                                end)
                                        end
                                else
                                        notif('ChatSpammer', 'unsupported chat', 5, 'warning')
                                        ChatSpammer:Toggle()
                                        return
                                end
                                
                                local ind = 1
                                repeat
                                        local message = (#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or 'skidv7 on top')
                                        if Mode.Value == 'Order' and #Lines.ListEnabled > 0 then
                                                message = Lines.ListEnabled[ind] or Lines.ListEnabled[1]
                                                ind = (ind % #Lines.ListEnabled) + 1
                                        end
        
                                        if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                                                textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(message)
                                        else
                                                replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
                                        end
        
                                        task.wait(Delay.Value)
                                until not ChatSpammer.Enabled
                        else
                                if oldchat then
                                        hookfunction(getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, oldchat)
                                end
                        end
                end,
                Tooltip = 'Automatically types in chat'
        })
        Lines = ChatSpammer:CreateTextList({Name = 'Lines'})
        Mode = ChatSpammer:CreateDropdown({
                Name = 'Mode',
                List = {'Random', 'Order'}
        })
        Delay = ChatSpammer:CreateSlider({
                Name = 'Delay',
                Min = 0.1,
                Max = 10,
                Default = 1,
                Decimal = 10,
                Suffix = function(val)
                        return val == 1 and 'second' or 'seconds'
                end
        })
        Hide = ChatSpammer:CreateToggle({
                Name = 'Hide Flood Message',
                Default = true,
                Function = function()
                        if ChatSpammer.Enabled then
                                ChatSpammer:Toggle()
                                ChatSpammer:Toggle()
                        end
                end
        })
end)
run(function()
        vape.Categories.Utility:CreateModule({
                Name = 'Panic',
                Function = function(callback)
                        if callback then
                                for _, v in vape.Modules do
                                        if v.Enabled then
                                                v:Toggle()
                                        end
                                end
                        end
                end,
                Tooltip = 'Disables all currently enabled modules'
        })
        vape.Categories.World:CreateModule({
                Name = 'AntiAFK',
                Function = function(callback)
                        if callback then
                                for _, v in getconnections(lplr.Idled) do
                                        table.insert(connections, v)
                                        v:Disable()
                                end
                        else
                                for _, v in connections do
                                        v:Enable()
                                end
                                table.clear(connections)
                        end
                end,
                Tooltip = 'Lets you stay ingame without getting kicked'
        })
end)
        
run(function()
        local Freecam
        local Value
        local randomkey, module, old = httpService:GenerateGUID(false)
        
        Freecam = vape.Categories.World:CreateModule({
                Name = 'Freecam',
                Function = function(callback)
                        if callback then
                                repeat
                                        task.wait(0.1)
                                        for _, v in getconnections(gameCamera:GetPropertyChangedSignal('CameraType')) do
                                                if v.Function then
                                                        module = debug.getupvalue(v.Function, 1)
                                                end
                                        end
                                until module or not Freecam.Enabled
        
                                if module and module.activeCameraController and Freecam.Enabled then
                                        old = module.activeCameraController.GetSubjectPosition
                                        local camPos = old(module.activeCameraController) or Vector3.zero
                                        module.activeCameraController.GetSubjectPosition = function()
                                                return camPos
                                        end
        
                                        Freecam:Clean(runService.PreSimulation:Connect(function(dt)
                                                if not inputService:GetFocusedTextBox() then
                                                        local forward = (inputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
                                                        local side = (inputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0)
                                                        local up = (inputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (inputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0)
                                                        dt = dt * (inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
                                                        camPos = (CFrame.lookAlong(camPos, gameCamera.CFrame.LookVector) * CFrame.new(Vector3.new(side, up, forward) * (Value.Value * dt))).Position
                                                end
                                        end))
        
                                        contextService:BindActionAtPriority('FreecamKeyboard'..randomkey, function()
                                                return Enum.ContextActionResult.Sink
                                        end, false, Enum.ContextActionPriority.High.Value,
                                                Enum.KeyCode.W,
                                                Enum.KeyCode.A,
                                                Enum.KeyCode.S,
                                                Enum.KeyCode.D,
                                                Enum.KeyCode.E,
                                                Enum.KeyCode.Q,
                                                Enum.KeyCode.Up,
                                                Enum.KeyCode.Down
                                        )
                                end
                        else
                                pcall(function()
                                        contextService:UnbindAction('FreecamKeyboard'..randomkey)
                                end)
                                if module and old then
                                        module.activeCameraController.GetSubjectPosition = old
                                        module = nil
                                        old = nil
                                end
                        end
                end,
                Tooltip = 'Lets you fly and clip through walls freely\nwithout moving your player server-sided.'
        })
        Value = Freecam:CreateSlider({
                Name = 'Speed',
                Min = 1,
                Max = 150,
                Default = 50,
                Suffix = function(val)
                        return val == 1 and 'stud' or 'studs'
                end
        })
end)
        
run(function()
        local Gravity
        local Mode
        local Value
        local changed, old = false
        
        Gravity = vape.Categories.World:CreateModule({
                Name = 'Gravity',
                Function = function(callback)
                        if callback then
                                if Mode.Value == 'Workspace' then
                                        old = workspace.Gravity
                                        workspace.Gravity = Value.Value
                                        Gravity:Clean(workspace:GetPropertyChangedSignal('Gravity'):Connect(function()
                                                if changed then return end
                                                changed = true
                                                old = workspace.Gravity
                                                workspace.Gravity = Value.Value
                                                changed = false
                                        end))
                                else
                                        Gravity:Clean(runService.PreSimulation:Connect(function(dt)
                                                if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
                                                        local root = entitylib.character.RootPart
                                                        if Mode.Value == 'Impulse' then
                                                                root:ApplyImpulse(Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0) * root.AssemblyMass)
                                                        else
                                                                root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, dt * (workspace.Gravity - Value.Value), 0)
                                                        end
                                                end
                                        end))
                                end
                        else
                                if old then
                                        workspace.Gravity = old
                                        old = nil
                                end
                        end
                end,
                Tooltip = 'Changes the rate you fall'
        })
        Mode = Gravity:CreateDropdown({
                Name = 'Mode',
                List = {'Workspace', 'Velocity', 'Impulse'},
                Tooltip = 'Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead'
        })
        Value = Gravity:CreateSlider({
                Name = 'Gravity',
                Min = 0,
                Max = 192,
                Function = function(val)
                        if Gravity.Enabled and Mode.Value == 'Workspace' then
                                changed = true
                                workspace.Gravity = val
                                changed = false
                        end
                end,
                Default = 192
        })
end)
        
run(function()
        local Parkour
        
        Parkour = vape.Categories.World:CreateModule({
                Name = 'Parkour',
                Function = function(callback)
                        if callback then 
                                local oldfloor
                                Parkour:Clean(runService.Heartbeat:Connect(function()
                                        if entitylib.isAlive then 
                                                local material = entitylib.character.Humanoid.FloorMaterial
                                                if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then 
                                                        entitylib.character.Humanoid.Jump = true
                                                end
                                                oldfloor = material
                                        end
                                end))
                        end
                end,
                Tooltip = 'Automatically jumps after reaching the edge'
        })
end)
        
run(function()
        local rayCheck = RaycastParams.new()
        rayCheck.RespectCanCollide = true
        local module, old
        
        vape.Categories.World:CreateModule({
                Name = 'SafeWalk',
                Function = function(callback)
                        if callback then
                                if not module then
                                        local suc = pcall(function() 
                                                module = require(lplr.PlayerScripts.PlayerModule).controls 
                                        end)
                                        if not suc then module = {} end
                                end
                                
                                old = module.moveFunction
                                module.moveFunction = function(self, vec, face)
                                        if entitylib.isAlive then
                                                rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                                                local root = entitylib.character.RootPart
                                                local movedir = root.Position + vec
                                                local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
                                                if not ray then
                                                        local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
                                                        if check then
                                                                vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
                                                        end
                                                end
                                        end
        
                                        return old(self, vec, face)
                                end
                        else
                                if module and old then
                                        module.moveFunction = old
                                end
                        end
                end,
                Tooltip = 'Prevents you from walking off the edge of parts'
        })
end)
        
run(function()
        local Xray
        local List
        local modified = {}
        
        local function modifyPart(v)
                if v:IsA('BasePart') and not table.find(List.ListEnabled, v.Name) then
                        modified[v] = true
                        v.LocalTransparencyModifier = 0.5
                end
        end
        
        Xray = vape.Categories.World:CreateModule({
                Name = 'Xray',
                Function = function(callback)
                        if callback then
                                Xray:Clean(workspace.DescendantAdded:Connect(modifyPart))
                                for _, v in workspace:GetDescendants() do
                                        modifyPart(v)
                                end
                        else
                                for i in modified do
                                        i.LocalTransparencyModifier = 0
                                end
                                table.clear(modified)
                        end
                end,
                Tooltip = 'Renders whitelisted parts through walls.'
        })
        List = Xray:CreateTextList({
                Name = 'Part',
                Function = function()
                        if Xray.Enabled then
                                Xray:Toggle()
                                Xray:Toggle()
                        end
                end
        })
end)
run(function()
        local Atmosphere
        local Toggles = {}
        local newobjects, oldobjects = {}, {}
        local apidump = {
                Sky = {
                        SkyboxUp = 'Text',
                        SkyboxDn = 'Text',
                        SkyboxLf = 'Text',
                        SkyboxRt = 'Text',
                        SkyboxFt = 'Text',
                        SkyboxBk = 'Text',
                        SunTextureId = 'Text',
                        SunAngularSize = 'Number',
                        MoonTextureId = 'Text',
                        MoonAngularSize = 'Number',
                        StarCount = 'Number'
                },
                Atmosphere = {
                        Color = 'Color',
                        Decay = 'Color',
                        Density = 'Number',
                        Offset = 'Number',
                        Glare = 'Number',
                        Haze = 'Number'
                },
                BloomEffect = {
                        Intensity = 'Number',
                        Size = 'Number',
                        Threshold = 'Number'
                },
                DepthOfFieldEffect = {
                        FarIntensity = 'Number',
                        FocusDistance = 'Number',
                        InFocusRadius = 'Number',
                        NearIntensity = 'Number'
                },
                SunRaysEffect = {
                        Intensity = 'Number',
                        Spread = 'Number'
                },
                ColorCorrectionEffect = {
                        TintColor = 'Color',
                        Saturation = 'Number',
                        Contrast = 'Number',
                        Brightness = 'Number'
                }
        }
        
        local function removeObject(v)
                if not table.find(newobjects, v) then
                        local toggle = Toggles[v.ClassName]
                        if toggle and toggle.Toggle.Enabled then
                                if v.Parent then
                                        table.insert(oldobjects, v)
                                        v.Parent = game
                                end
                        end
                end
        end
        
        Atmosphere = vape.Categories.Legit:CreateModule({
                Name = 'Atmosphere',
                Function = function(callback)
                        if callback then
                                for _, v in lightingService:GetChildren() do
                                        removeObject(v)
                                end
                                Atmosphere:Clean(lightingService.ChildAdded:Connect(function(v)
                                        task.defer(removeObject, v)
                                end))
        
                                for i, v in Toggles do
                                        if v.Toggle.Enabled then
                                                local obj = Instance.new(i)
                                                for i2, v2 in v.Objects do
                                                        if v2.Type == 'ColorSlider' then
                                                                obj[i2] = Color3.fromHSV(v2.Hue, v2.Sat, v2.Value)
                                                        else
                                                                obj[i2] = apidump[i][i2] ~= 'Number' and v2.Value or tonumber(v2.Value) or 0
                                                        end
                                                end
                                                obj.Parent = lightingService
                                                table.insert(newobjects, obj)
                                        end
                                end
                        else
                                for _, v in newobjects do
                                        v:Destroy()
                                end
                                for _, v in oldobjects do
                                        v.Parent = lightingService
                                end
                                table.clear(newobjects)
                                table.clear(oldobjects)
                        end
                end,
                Tooltip = 'Custom lighting objects'
        })
        for i, v in apidump do
                Toggles[i] = {Objects = {}}
                Toggles[i].Toggle = Atmosphere:CreateToggle({
                        Name = i,
                        Function = function(callback)
                                if Atmosphere.Enabled then
                                        Atmosphere:Toggle()
                                        Atmosphere:Toggle()
                                end
                                for _, toggle in Toggles[i].Objects do
                                        toggle.Object.Visible = callback
                                end
                        end
                })
        
                for i2, v2 in v do
                        if v2 == 'Text' or v2 == 'Number' then
                                Toggles[i].Objects[i2] = Atmosphere:CreateTextBox({
                                        Name = i2,
                                        Function = function(enter)
                                                if Atmosphere.Enabled and enter then
                                                        Atmosphere:Toggle()
                                                        Atmosphere:Toggle()
                                                end
                                        end,
                                        Darker = true,
                                        Default = v2 == 'Number' and '0' or nil,
                                        Visible = false
                                })
                        elseif v2 == 'Color' then
                                Toggles[i].Objects[i2] = Atmosphere:CreateColorSlider({
                                        Name = i2,
                                        Function = function()
                                                if Atmosphere.Enabled then
                                                        Atmosphere:Toggle()
                                                        Atmosphere:Toggle()
                                                end
                                        end,
                                        Darker = true,
                                        Visible = false
                                })
                        end
                end
        end
end)
        
run(function()
        local Breadcrumbs
        local Texture
        local Lifetime
        local Thickness
        local FadeIn
        local FadeOut
        local trail, point, point2
        
        Breadcrumbs = vape.Categories.Legit:CreateModule({
                Name = 'Breadcrumbs',
                Function = function(callback)
                        if callback then
                                point = Instance.new('Attachment')
                                point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
                                point2 = Instance.new('Attachment')
                                point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
                                trail = Instance.new('Trail')
                                trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
                                trail.TextureMode = Enum.TextureMode.Static
                                trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
                                trail.Lifetime = Lifetime.Value
                                trail.Attachment0 = point
                                trail.Attachment1 = point2
                                trail.FaceCamera = true
        
                                Breadcrumbs:Clean(trail)
                                Breadcrumbs:Clean(point)
                                Breadcrumbs:Clean(point2)
                                Breadcrumbs:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
                                        point.Parent = ent.HumanoidRootPart
                                        point2.Parent = ent.HumanoidRootPart
                                        trail.Parent = gameCamera
                                end))
                                if entitylib.isAlive then
                                        point.Parent = entitylib.character.RootPart
                                        point2.Parent = entitylib.character.RootPart
                                        trail.Parent = gameCamera
                                end
                        else
                                trail = nil
                                point = nil
                                point2 = nil
                        end
                end,
                Tooltip = 'Shows a trail behind your character'
        })
        Texture = Breadcrumbs:CreateTextBox({
                Name = 'Texture',
                Placeholder = 'Texture Id',
                Function = function(enter)
                        if enter and trail then
                                trail.Texture = Texture.Value == '' and 'http://www.roblox.com/asset/?id=14166981368' or Texture.Value
                        end
                end
        })
        FadeIn = Breadcrumbs:CreateColorSlider({
                Name = 'Fade In',
                Function = function(hue, sat, val)
                        if trail then
                                trail.Color = ColorSequence.new(Color3.fromHSV(hue, sat, val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
                        end
                end
        })
        FadeOut = Breadcrumbs:CreateColorSlider({
                Name = 'Fade Out',
                Function = function(hue, sat, val)
                        if trail then
                                trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(hue, sat, val))
                        end
                end
        })
        Lifetime = Breadcrumbs:CreateSlider({
                Name = 'Lifetime',
                Min = 1,
                Max = 5,
                Default = 3,
                Decimal = 10,
                Function = function(val)
                        if trail then
                                trail.Lifetime = val
                        end
                end,
                Suffix = function(val)
                        return val == 1 and 'second' or 'seconds'
                end
        })
        Thickness = Breadcrumbs:CreateSlider({
                Name = 'Thickness',
                Min = 0,
                Max = 2,
                Default = 0.1,
                Decimal = 100,
                Function = function(val)
                        if point then
                                point.Position = Vector3.new(0, val - 2.7, 0)
                        end
                        if point2 then
                                point2.Position = Vector3.new(0, -val - 2.7, 0)
                        end
                end,
                Suffix = function(val)
                        return val == 1 and 'stud' or 'studs'
                end
        })
end)
        
run(function()
        local Cape
        local Texture
        local part, motor
        
        local function createMotor(char)
                if motor then 
                        motor:Destroy() 
                end
                part.Parent = gameCamera
                motor = Instance.new('Motor6D')
                motor.MaxVelocity = 0.08
                motor.Part0 = part
                motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
                motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
                motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
                motor.Parent = part
        end
        
        Cape = vape.Categories.Legit:CreateModule({
                Name = 'Cape',
                Function = function(callback)
                        if callback then
                                part = Instance.new('Part')
                                part.Size = Vector3.new(2, 4, 0.1)
                                part.CanCollide = false
                                part.CanQuery = false
                                part.Massless = true
                                part.Transparency = 0
                                part.Material = Enum.Material.SmoothPlastic
                                part.Color = Color3.new()
                                part.CastShadow = false
                                part.Parent = gameCamera
                                local capesurface = Instance.new('SurfaceGui')
                                capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
                                capesurface.Adornee = part
                                capesurface.Parent = part
        
                                if Texture.Value:find('.webm') then
                                        local decal = Instance.new('VideoFrame')
                                        decal.Video = getcustomasset(Texture.Value)
                                        decal.Size = UDim2.fromScale(1, 1)
                                        decal.BackgroundTransparency = 1
                                        decal.Looped = true
                                        decal.Parent = capesurface
                                        decal:Play()
                                else
                                        local decal = Instance.new('ImageLabel')
                                        decal.Image = Texture.Value ~= '' and (Texture.Value:find('rbxasset') and Texture.Value or assetfunction(Texture.Value)) or 'rbxassetid://14637958134'
                                        decal.Size = UDim2.fromScale(1, 1)
                                        decal.BackgroundTransparency = 1
                                        decal.Parent = capesurface
                                end
                                Cape:Clean(part)
                                Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
                                if entitylib.isAlive then
                                        createMotor(entitylib.character)
                                end
        
                                repeat
                                        if motor and entitylib.isAlive then
                                                local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
                                                motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
                                        end
                                        capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
                                        part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
                                        task.wait()
                                until not Cape.Enabled
                        else
                                part = nil
                                motor = nil
                        end
                end,
                Tooltip = 'Add\'s a cape to your character'
        })
        Texture = Cape:CreateTextBox({
                Name = 'Texture'
        })
end)
        
run(function()
        local ChinaHat
        local Material
        local Color
        local hat
        
        ChinaHat = vape.Categories.Legit:CreateModule({
                Name = 'China Hat',
                Function = function(callback)
                        if callback then
                                if vape.ThreadFix then
                                        setthreadidentity(8)
                                end
                                hat = Instance.new('MeshPart')
                                hat.Size = Vector3.new(3, 0.7, 3)
                                hat.Name = 'ChinaHat'
                                hat.Material = Enum.Material[Material.Value]
                                hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                                hat.CanCollide = false
                                hat.CanQuery = false
                                hat.Massless = true
                                hat.MeshId = 'http://www.roblox.com/asset/?id=1778999'
                                hat.Transparency = 1 - Color.Opacity
                                hat.Parent = gameCamera
                                hat.CFrame = entitylib.isAlive and entitylib.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
                                local weld = Instance.new('WeldConstraint')
                                weld.Part0 = hat
                                weld.Part1 = entitylib.isAlive and entitylib.character.Head or nil
                                weld.Parent = hat
                                ChinaHat:Clean(hat)
                                ChinaHat:Clean(entitylib.Events.LocalAdded:Connect(function(char)
                                        if weld then 
                                                weld:Destroy() 
                                        end
                                        hat.Parent = gameCamera
                                        hat.CFrame = char.Head.CFrame + Vector3.new(0, 1, 0)
                                        hat.Velocity = Vector3.zero
                                        weld = Instance.new('WeldConstraint')
                                        weld.Part0 = hat
                                        weld.Part1 = char.Head
                                        weld.Parent = hat
                                end))
        
                                repeat
                                        hat.LocalTransparencyModifier = ((gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
                                        task.wait()
                                until not ChinaHat.Enabled
                        else
                                hat = nil
                        end
                end,
                Tooltip = 'Puts a china hat on your character (ty mastadawn)'
        })
        local materials = {'ForceField'}
        for _, v in Enum.Material:GetEnumItems() do
                if v.Name ~= 'ForceField' then
                        table.insert(materials, v.Name)
                end
        end
        Material = ChinaHat:CreateDropdown({
                Name = 'Material',
                List = materials,
                Function = function(val)
                        if hat then
                                hat.Material = Enum.Material[val]
                        end
                end
        })
        Color = ChinaHat:CreateColorSlider({
                Name = 'Hat Color',
                DefaultOpacity = 0.7,
                Function = function(hue, sat, val, opacity)
                        if hat then
                                hat.Color = Color3.fromHSV(hue, sat, val)
                                hat.Transparency = 1 - opacity
                        end
                end
        })
end)
        
run(function()
        local Clock
        local TwentyFourHour
        local label
        
        Clock = vape.Categories.Legit:CreateModule({
                Name = 'Clock',
                Function = function(callback)
                        if callback then
                                repeat
                                        label.Text = DateTime.now():FormatLocalTime('LT', TwentyFourHour.Enabled and 'zh-cn' or 'en-us')
                                        task.wait(1)
                                until not Clock.Enabled
                        end
                end,
                Size = UDim2.fromOffset(100, 41),
                Tooltip = 'Shows the current local time'
        })
        Clock:CreateFont({
                Name = 'Font',
                Blacklist = 'Gotham',
                Function = function(val)
                        label.FontFace = val
                end
        })
        Clock:CreateColorSlider({
                Name = 'Color',
                DefaultValue = 0,
                DefaultOpacity = 0.5,
                Function = function(hue, sat, val, opacity)
                        label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        label.BackgroundTransparency = 1 - opacity
                end
        })
        TwentyFourHour = Clock:CreateToggle({
                Name = '24 Hour Clock'
        })
        label = Instance.new('TextLabel')
        label.Size = UDim2.new(0, 100, 0, 41)
        label.BackgroundTransparency = 0.5
        label.TextSize = 15
        label.Font = Enum.Font.Gotham
        label.Text = '0:00 PM'
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundColor3 = Color3.new()
        label.Parent = Clock.Children
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = label
end)
        
run(function()
        local Disguise
        local Mode
        local IDBox
        local desc
        
        local function itemAdded(v, manual)
                if (not v:GetAttribute('Disguise')) and ((v:IsA('Accessory') and (not v:GetAttribute('InvItem')) and (not v:GetAttribute('ArmorSlot'))) or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') or manual) then
                        repeat
                                task.wait()
                                v.Parent = game
                        until v.Parent == game
                        v:ClearAllChildren()
                        v:Destroy()
                end
        end
        
        local function characterAdded(char)
                if Mode.Value == 'Character' then
                        task.wait(0.1)
                        char.Character.Archivable = true
                        local clone = char.Character:Clone()
                        repeat
                                if pcall(function()
                                        desc = playersService:GetHumanoidDescriptionFromUserId(IDBox.Value == '' and 239702688 or tonumber(IDBox.Value))
                                end) and desc then break end
                                task.wait(1)
                        until not Disguise.Enabled
                        if not Disguise.Enabled then
                                clone:ClearAllChildren()
                                clone:Destroy()
                                clone = nil
                                if desc then
                                        desc:Destroy()
                                        desc = nil
                                end
                                return
                        end
                        clone.Parent = game
        
                        local originalDesc = char.Humanoid:WaitForChild('HumanoidDescription', 2) or {
                                HeightScale = 1,
                                SetEmotes = function() end,
                                SetEquippedEmotes = function() end
                        }
                        originalDesc.JumpAnimation = desc.JumpAnimation
                        desc.HeightScale = originalDesc.HeightScale
        
                        for _, v in clone:GetChildren() do
                                if v:IsA('Accessory') or v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') then
                                        v:ClearAllChildren()
                                        v:Destroy()
                                end
                        end
        
                        local savedAnims = {}
                        local animate = char.Character:FindFirstChild('Animate')
                        if animate then
                                for _, v in animate:GetChildren() do
                                        local anim = v:FindFirstChildWhichIsA('Animation')
                                        if anim then
                                                savedAnims[v.Name] = anim.AnimationId
                                        end
                                end
                        end

                         clone.Humanoid:ApplyDescriptionClientServer(desc)

                        task.wait(0.5)
                        local cloneAnimate = clone:FindFirstChild('Animate')
                        local myAnimate = char.Character:FindFirstChild('Animate')
                        if cloneAnimate and myAnimate then
                                for _, slot in cloneAnimate:GetChildren() do
                                        local mySlot = myAnimate:FindFirstChild(slot.Name)
                                        if mySlot then
                                                local targetAnim = slot:FindFirstChildWhichIsA('Animation')
                                                local myAnim = mySlot:FindFirstChildWhichIsA('Animation')
                                                if targetAnim and myAnim then
                                                        pcall(function() myAnim.AnimationId = targetAnim.AnimationId end)
                                                end
                                        end
                                end
                        end


                        if animate then
                                for name, id in savedAnims do
                                        local slot = animate:FindFirstChild(name)
                                        if slot then
                                                local anim = slot:FindFirstChildWhichIsA('Animation')
                                                if anim then
                                                        anim.AnimationId = id
                                                end
                                        end
                                end
                        end

                        for _, v in char.Character:GetChildren() do
                                itemAdded(v)
                        end
                        Disguise:Clean(char.Character.ChildAdded:Connect(itemAdded))

        
                        for _, v in clone:GetChildren() do
                                v:SetAttribute('Disguise', true)
                                if v:IsA('Accessory') then
                                        for _, v2 in v:GetDescendants() do
                                                if v2:IsA('Weld') and v2.Part1 then
                                                        v2.Part1 = char.Character[v2.Part1.Name]
                                                end
                                        end
                                        v.Parent = char.Character
                                elseif v:IsA('ShirtGraphic') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('BodyColors') then
                                        v.Parent = char.Character
                                elseif v.Name == 'Head' and char.Head:IsA('MeshPart') and (not char.Head:FindFirstChild('FaceControls')) then
                                        char.Head.MeshId = v.MeshId
                                end
                        end
        
                        local localface = char.Character:FindFirstChild('face', true)
                        local cloneface = clone:FindFirstChild('face', true)
                        if localface and cloneface then
                                itemAdded(localface, true)
                                cloneface.Parent = char.Head
                        end
                        pcall(function() originalDesc:SetEmotes(desc:GetEmotes()) end)
                        pcall(function() originalDesc:SetEquippedEmotes(desc:GetEquippedEmotes()) end)
                        clone:ClearAllChildren()
                        clone:Destroy()
                        clone = nil
                        if desc then
                                desc:Destroy()
                                desc = nil
                        end
                else
                        local data
                        repeat
                                if pcall(function()
                                        data = marketplaceService:GetProductInfo(IDBox.Value == '' and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
                                end) then break end
                                task.wait(1)
                        until not Disguise.Enabled
                        if not Disguise.Enabled then
                                if data then
                                        table.clear(data)
                                        data = nil
                                end
                                return
                        end
                        if data.BundleType == 'AvatarAnimations' then
                                local animate = char.Character:FindFirstChild('Animate')
                                if not animate then return end
                                for _, v in (desc.Items or {}) do
                                        local animtype = v.Name:split(' ')[2]:lower()
                                        if animtype ~= 'animation' then
                                                local suc, res = pcall(function() return game:GetObjects('rbxassetid://'..v.Id) end)
                                                if suc then
                                                        animate[animtype]:FindFirstChildWhichIsA('Animation').AnimationId = res[1]:FindFirstChildWhichIsA('Animation', true).AnimationId
                                                end
                                        end
                                end
                        else
                                notif('Disguise', 'that\'s not an animation pack', 5, 'warning')
                        end
                end
        end
        
        Disguise = vape.Categories.Legit:CreateModule({
                Name = 'Disguise',
                Function = function(callback)
                        if callback then
                                Disguise:Clean(entitylib.Events.LocalAdded:Connect(characterAdded))
                                if entitylib.isAlive then
                                        characterAdded(entitylib.character)
                                end
                        end
                end,
                Tooltip = 'Changes your character or animation to a specific ID (aniamtions only work if they are in the same server as u)'
        })
        Mode = Disguise:CreateDropdown({
                Name = 'Mode',
                List = {'Character', 'Animation'},
                Function = function()
                        if Disguise.Enabled then
                                Disguise:Toggle()
                                Disguise:Toggle()
                        end
                end
        })
        IDBox = Disguise:CreateTextBox({
                Name = 'Disguise',
                Placeholder = 'Disguise User Id',
                Function = function()
                        if Disguise.Enabled then
                                Disguise:Toggle()
                                Disguise:Toggle()
                        end
                end
        })
end)
        
run(function()
        local FOV
        local Value
        local oldfov
        
        FOV = vape.Categories.Legit:CreateModule({
                Name = 'FOV',
                Function = function(callback)
                        if callback then
                                oldfov = gameCamera.FieldOfView
                                repeat
                                        gameCamera.FieldOfView = Value.Value
                                        task.wait()
                                until not FOV.Enabled
                        else
                                gameCamera.FieldOfView = oldfov
                        end
                end,
                Tooltip = 'Adjusts camera vision'
        })
        Value = FOV:CreateSlider({
                Name = 'FOV',
                Min = 30,
                Max = 120
        })
end)
        
run(function()
        local FPS
        local label
        
        FPS = vape.Categories.Legit:CreateModule({
                Name = 'FPS',
                Function = function(callback)
                        if callback then
                                local startClock = os.clock()
                                local frameCount = 0
                                local lastSecondTick = tick()
                                FPS:Clean(runService.Heartbeat:Connect(function()
                                        frameCount = frameCount + 1
                                        local now = tick()
                                        local elapsed = now - lastSecondTick
                                        if elapsed >= 1 then
                                                local fps = os.clock() - startClock >= 1 and math.round(frameCount / elapsed) or math.round(frameCount / math.max(os.clock() - startClock, 0.001))
                                                frameCount = 0
                                                lastSecondTick = now
                                                label.Text = fps .. ' FPS'
                                        end
                                end))
                        end
                end,
                Size = UDim2.fromOffset(100, 41),
                Tooltip = 'Shows the current framerate'
        })
        FPS:CreateFont({
                Name = 'Font',
                Blacklist = 'Gotham',
                Function = function(val)
                        label.FontFace = val
                end
        })
        FPS:CreateColorSlider({
                Name = 'Color',
                DefaultValue = 0,
                DefaultOpacity = 0.5,
                Function = function(hue, sat, val, opacity)
                        label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        label.BackgroundTransparency = 1 - opacity
                end
        })
        label = Instance.new('TextLabel')
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 0.5
        label.TextSize = 15
        label.Font = Enum.Font.Gotham
        label.Text = 'inf FPS'
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundColor3 = Color3.new()
        label.Parent = FPS.Children
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = label
end)
        
run(function()
        local Keystrokes
        local Style
        local Color
        local keys, holder = {}
        
        local function createKeystroke(keybutton, pos, pos2, text)
                if keys[keybutton] then
                        keys[keybutton].Key:Destroy()
                        keys[keybutton] = nil
                end
                local key = Instance.new('Frame')
                key.Size = keybutton == Enum.KeyCode.Space and UDim2.new(0, 110, 0, 24) or UDim2.new(0, 34, 0, 36)
                key.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                key.BackgroundTransparency = 1 - Color.Opacity
                key.Position = pos
                key.Name = keybutton.Name
                key.Parent = holder
                local keytext = Instance.new('TextLabel')
                keytext.BackgroundTransparency = 1
                keytext.Size = UDim2.fromScale(1, 1)
                keytext.Font = Enum.Font.Gotham
                keytext.Text = text or keybutton.Name
                keytext.TextXAlignment = Enum.TextXAlignment.Left
                keytext.TextYAlignment = Enum.TextYAlignment.Top
                keytext.Position = pos2
                keytext.TextSize = keybutton == Enum.KeyCode.Space and 18 or 15
                keytext.TextColor3 = Color3.new(1, 1, 1)
                keytext.Parent = key
                local corner = Instance.new('UICorner')
                corner.CornerRadius = UDim.new(0, 4)
                corner.Parent = key
                keys[keybutton] = {Key = key}
        end
        
        Keystrokes = vape.Categories.Legit:CreateModule({
                Name = 'Keystrokes',
                Function = function(callback)
                        if callback then
                                createKeystroke(Enum.KeyCode.W, UDim2.new(0, 38, 0, 0), UDim2.new(0, 6, 0, 5), Style.Value == 'Arrow' and '↑' or nil)
                                createKeystroke(Enum.KeyCode.S, UDim2.new(0, 38, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '↓' or nil)
                                createKeystroke(Enum.KeyCode.A, UDim2.new(0, 0, 0, 42), UDim2.new(0, 7, 0, 5), Style.Value == 'Arrow' and '←' or nil)
                                createKeystroke(Enum.KeyCode.D, UDim2.new(0, 76, 0, 42), UDim2.new(0, 8, 0, 5), Style.Value == 'Arrow' and '→' or nil)
        
                                Keystrokes:Clean(inputService.InputBegan:Connect(function(inputType)
                                        local key = keys[inputType.KeyCode]
                                        if key then
                                                if key.Tween then
                                                        key.Tween:Cancel()
                                                end
                                                if key.Tween2 then
                                                        key.Tween2:Cancel()
                                                end
        
                                                key.Pressed = true
                                                key.Tween = tweenService:Create(key.Key, TweenInfo.new(0.1), {
                                                        BackgroundColor3 = Color3.new(1, 1, 1), 
                                                        BackgroundTransparency = 0
                                                })
                                                key.Tween2 = tweenService:Create(key.Key.TextLabel, TweenInfo.new(0.1), {
                                                        TextColor3 = Color3.new()
                                                })
                                                key.Tween:Play()
                                                key.Tween2:Play()
                                        end
                                end))
        
                                Keystrokes:Clean(inputService.InputEnded:Connect(function(inputType)
                                        local key = keys[inputType.KeyCode]
                                        if key then
                                                if key.Tween then
                                                        key.Tween:Cancel()
                                                end
                                                if key.Tween2 then
                                                        key.Tween2:Cancel()
                                                end
        
                                                key.Pressed = false
                                                key.Tween = tweenService:Create(key.Key, TweenInfo.new(0.1), {
                                                        BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value), 
                                                        BackgroundTransparency = 1 - Color.Opacity
                                                })
                                                key.Tween2 = tweenService:Create(key.Key.TextLabel, TweenInfo.new(0.1), {
                                                        TextColor3 = Color3.new(1, 1, 1)
                                                })
                                                key.Tween:Play()
                                                key.Tween2:Play()
                                        end
                                end))
                        end
                end,
                Size = UDim2.fromOffset(110, 176),
                Tooltip = 'Shows movement keys onscreen'
        })
        holder = Instance.new('Frame')
        holder.Size = UDim2.fromScale(1, 1)
        holder.BackgroundTransparency = 1
        holder.Parent = Keystrokes.Children
        Style = Keystrokes:CreateDropdown({
                Name = 'Key Style',
                List = {'Keyboard', 'Arrow'},
                Function = function()
                        if Keystrokes.Enabled then
                                Keystrokes:Toggle()
                                Keystrokes:Toggle()
                        end
                end
        })
        Color = Keystrokes:CreateColorSlider({
                Name = 'Color',
                DefaultValue = 0,
                DefaultOpacity = 0.5,
                Function = function(hue, sat, val, opacity)
                        for _, v in keys do
                                if not v.Pressed then
                                        v.Key.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                                        v.Key.BackgroundTransparency = 1 - opacity
                                end
                        end
                end
        })
        Keystrokes:CreateToggle({
                Name = 'Show Spacebar',
                Function = function(callback)
                        Keystrokes.Children.Size = UDim2.fromOffset(110, callback and 107 or 78)
                        if callback then
                                createKeystroke(Enum.KeyCode.Space, UDim2.new(0, 0, 0, 83), UDim2.new(0, 25, 0, -10), '______')
                        else
                                keys[Enum.KeyCode.Space].Key:Destroy()
                                keys[Enum.KeyCode.Space] = nil
                        end
                end,
                Default = true
        })
end)
        
run(function()
        local Memory
        local label
        local perfStats = game:GetService('Stats'):FindFirstChild('PerformanceStats')

        Memory = vape.Categories.Legit:CreateModule({
                Name = 'Memory',
                Function = function(callback)
                        if callback then
                                repeat
                                        label.Text = math.floor(tonumber(perfStats.Memory:GetValue()))..' MB'
                                        task.wait(1)
                                until not Memory.Enabled
                        end
                end,
                Size = UDim2.fromOffset(100, 41),
                Tooltip = 'A label showing the memory currently used by roblox'
        })
        Memory:CreateFont({
                Name = 'Font',
                Blacklist = 'Gotham',
                Function = function(val)
                        label.FontFace = val
                end
        })
        Memory:CreateColorSlider({
                Name = 'Color',
                DefaultValue = 0,
                DefaultOpacity = 0.5,
                Function = function(hue, sat, val, opacity)
                        label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        label.BackgroundTransparency = 1 - opacity
                end
        })
        label = Instance.new('TextLabel')
        label.Size = UDim2.new(0, 100, 0, 41)
        label.BackgroundTransparency = 0.5
        label.TextSize = 15
        label.Font = Enum.Font.Gotham
        label.Text = '0 MB'
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundColor3 = Color3.new()
        label.Parent = Memory.Children
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = label
end)
        
run(function()
        local Ping
        local label
        local perfStatsPing = game:GetService('Stats'):FindFirstChild('PerformanceStats')

        Ping = vape.Categories.Legit:CreateModule({
                Name = 'Ping',
                Function = function(callback)
                        if callback then
                                repeat
                                        label.Text = math.floor(tonumber(perfStatsPing.Ping:GetValue()))..' ms'
                                        task.wait(1)
                                until not Ping.Enabled
                        end
                end,
                Size = UDim2.fromOffset(100, 41),
                Tooltip = 'Shows the current connection speed to the roblox server'
        })
        Ping:CreateFont({
                Name = 'Font',
                Blacklist = 'Gotham',
                Function = function(val)
                        label.FontFace = val
                end
        })
        Ping:CreateColorSlider({
                Name = 'Color',
                DefaultValue = 0,
                DefaultOpacity = 0.5,
                Function = function(hue, sat, val, opacity)
                        label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        label.BackgroundTransparency = 1 - opacity
                end
        })
        label = Instance.new('TextLabel')
        label.Size = UDim2.new(0, 100, 0, 41)
        label.BackgroundTransparency = 0.5
        label.TextSize = 15
        label.Font = Enum.Font.Gotham
        label.Text = '0 ms'
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundColor3 = Color3.new()
        label.Parent = Ping.Children
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = label
end)
run(function()
        local Speedmeter
        local label
        
        Speedmeter = vape.Categories.Legit:CreateModule({
                Name = 'Speedmeter',
                Function = function(callback)
                        if callback then
                                repeat
                                        local lastpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
                                        local dt = task.wait(0.2)
                                        local newpos = entitylib.isAlive and entitylib.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
                                        label.Text = math.round(((lastpos - newpos) / dt).Magnitude)..' sps'
                                until not Speedmeter.Enabled
                        end
                end,
                Size = UDim2.fromOffset(100, 41),
                Tooltip = 'A label showing the average velocity in studs'
        })
        Speedmeter:CreateFont({
                Name = 'Font',
                Blacklist = 'Gotham',
                Function = function(val)
                        label.FontFace = val
                end
        })
        Speedmeter:CreateColorSlider({
                Name = 'Color',
                DefaultValue = 0,
                DefaultOpacity = 0.5,
                Function = function(hue, sat, val, opacity)
                        label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                        label.BackgroundTransparency = 1 - opacity
                end
        })
        label = Instance.new('TextLabel')
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 0.5
        label.TextSize = 15
        label.Font = Enum.Font.Gotham
        label.Text = '0 sps'
        label.TextColor3 = Color3.new(1, 1, 1)
        label.BackgroundColor3 = Color3.new()
        label.Parent = Speedmeter.Children
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = label
end)
        
run(function()
        local TimeChanger
        local Value
        local old
        
        TimeChanger = vape.Categories.Legit:CreateModule({
                Name = 'Time Changer',
                Function = function(callback)
                        if callback then
                                old = lightingService.TimeOfDay
                                lightingService.TimeOfDay = Value.Value..':00:00'
                        else
                                lightingService.TimeOfDay = old
                                old = nil
                        end
                end,
                Tooltip = 'Change the time of the current world'
        })
        Value = TimeChanger:CreateSlider({
                Name = 'Time',
                Min = 0,
                Max = 24,
                Default = 12,
                Function = function(val)
                        if TimeChanger.Enabled then 
                                lightingService.TimeOfDay = val..':00:00'
                        end
                end
        })
        
end)
        
        
run(function()
    local ProximityPromptService = cloneref(game:GetService('ProximityPromptService'))

    local InstantPP = vape.Categories.Utility:CreateModule({
        Name = 'InstantPP',
        Function = function(callback)
            if callback then
                if fireproximityprompt then
                    InstantPP:Clean(ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
                        fireproximityprompt(prompt)
                    end))
                else
                    errorNotification('InstantPP', 'Your executer does not support this command (missing fireproximityprompt)', 5)
                    InstantPP:Toggle()
                end
            end
        end,
        Tooltip = 'Instantly activates proximity prompts.'
    })
end)

run(function()
    if not setfflag or type(setfflag) ~= 'function' then
        vape:CreateNotification('Vape', 'setfflag not supported by this executor', 5, 'warning')
        return
    end

    local FFlag
    local Flags

    local function ChangeFFlag(suc)
        if not suc or not FFlag.Enabled then return end
        local success, json = pcall(function()
            return httpService:JSONDecode(Flags.Value)
        end)

        if not success or typeof(json) ~= 'table' then
            vape:CreateNotification('Vape', 'Invalid json format for fflag', 12, 'warning')
            return
        end

        for i, v in json do
            i = i:gsub('DFInt', ''):gsub('DFFlag', ''):gsub('FFlag', ''):gsub('FInt', ''):gsub('DFString', ''):gsub('FString', '')

            pcall(setfflag, i, tostring(v))
        end

        vape:CreateNotification('Vape', 'FFlags applied, Go in a new game to take effect', 12, 'info')
    end

    FFlag = vape.Categories.Legit:CreateModule({
        Name = 'FFlag Editor',
        Function = function(call)
            if call then
                ChangeFFlag(true)
            else
                vape:CreateNotification('Vape', 'In order to disable fflags you have applied, you need to restart Roblox', 20, 'info')
            end
        end
    })

    Flags = FFlag:CreateTextBox({
        Name = 'FFlags',
        Placeholder = 'json format only',
        Function = ChangeFFlag
    })
end)

run(function()
        local Shaders
        local Lighting = lightingService
        local snapshot = {}
        local createdEffects = {}
        local hiddenChildren = {}
        local isEnabled = false

        local VISUAL_TYPES = {
                BloomEffect           = true,
                BlurEffect            = true,
                ColorCorrectionEffect = true,
                DepthOfFieldEffect    = true,
                SunRaysEffect         = true,
                Atmosphere            = true,
                Sky                   = true,
        }

        local function saveSnapshot()
                snapshot = {
                        Technology               = Lighting.Technology,
                        GlobalShadows            = Lighting.GlobalShadows,
                        ShadowSoftness           = Lighting.ShadowSoftness,
                        Brightness               = Lighting.Brightness,
                        ExposureCompensation     = Lighting.ExposureCompensation,
                        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
                        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
                        ClockTime                = Lighting.ClockTime,
                        OutdoorAmbient           = Lighting.OutdoorAmbient,
                }
        end

        local function restoreSnapshot()
                if not next(snapshot) then return end
                pcall(function()
                        Lighting.Technology              = snapshot.Technology
                        Lighting.GlobalShadows           = snapshot.GlobalShadows
                        Lighting.ShadowSoftness          = snapshot.ShadowSoftness
                        Lighting.Brightness              = snapshot.Brightness
                        Lighting.ExposureCompensation    = snapshot.ExposureCompensation
                        Lighting.EnvironmentDiffuseScale  = snapshot.EnvironmentDiffuseScale
                        Lighting.EnvironmentSpecularScale = snapshot.EnvironmentSpecularScale
                        Lighting.ClockTime               = snapshot.ClockTime
                        Lighting.OutdoorAmbient          = snapshot.OutdoorAmbient
                end)
                snapshot = {}
        end

        local function stashLightingChildren()
                hiddenChildren = {}
                for _, v in ipairs(Lighting:GetChildren()) do
                        if VISUAL_TYPES[v.ClassName] then
                                v.Parent = nil
                                table.insert(hiddenChildren, v)
                        end
                end
        end

        local function restoreLightingChildren()
                for _, v in ipairs(hiddenChildren) do
                        pcall(function() v.Parent = Lighting end)
                end
                hiddenChildren = {}
        end

        local function makeEffect(className)
                local inst = Instance.new(className)
                table.insert(createdEffects, inst)
                return inst
        end

        local function destroyCreatedEffects()
                for _, v in ipairs(createdEffects) do
                        pcall(function() v:Destroy() end)
                end
                createdEffects = {}
        end

        local function applyLighting()
                pcall(function()
                        Lighting.Technology              = Enum.Technology.Future
                        Lighting.GlobalShadows           = true
                        Lighting.ShadowSoftness          = 0.7
                        Lighting.Brightness              = Brightness.Value
                        Lighting.ExposureCompensation    = ExposureComp.Value
                        Lighting.EnvironmentDiffuseScale  = DiffuseScale.Value
                        Lighting.EnvironmentSpecularScale = SpecularScale.Value
                        Lighting.ClockTime               = TimeOfDay.Value
                        Lighting.OutdoorAmbient          = Color3.fromRGB(160, 160, 160)
                end)
        end

        local function buildEffects()
                if BloomToggle.Enabled then
                        local Bloom = makeEffect("BloomEffect")
                        Bloom.Intensity = BloomIntensity.Value
                        Bloom.Size      = 32
                        Bloom.Threshold = 0.9
                        Bloom.Parent    = Lighting
                end

                if ColorToggle.Enabled then
                        local Color = makeEffect("ColorCorrectionEffect")
                        Color.Brightness = 0.05
                        Color.Contrast   = -0.05
                        Color.Saturation = Saturation.Value
                        Color.TintColor  = Color3.fromRGB(255, 242, 230)
                        Color.Parent     = Lighting
                end

                if DoFToggle.Enabled then
                        local DoF = makeEffect("DepthOfFieldEffect")
                        DoF.FarIntensity  = 0.15
                        DoF.NearIntensity = 0
                        DoF.FocusDistance = DoFFocus.Value
                        DoF.InFocusRadius = 50
                        DoF.Parent        = Lighting
                end

                if BlurToggle.Enabled then
                        local Blur = makeEffect("BlurEffect")
                        Blur.Size   = BlurSize.Value
                        Blur.Parent = Lighting
                end

                if AtmosphereToggle.Enabled then
                        local Atmo = makeEffect("Atmosphere")
                        Atmo.Density = AtmoDensity.Value
                        Atmo.Offset  = 0.25
                        Atmo.Glare   = 0
                        Atmo.Haze    = 1.2
                        Atmo.Color   = Color3.fromRGB(245, 235, 225)
                        Atmo.Parent  = Lighting
                end

                if SunRaysToggle.Enabled then
                        local Sun = makeEffect("SunRaysEffect")
                        Sun.Intensity = 0.25
                        Sun.Spread    = 0.5
                        Sun.Parent    = Lighting
                end
        end

        local function enable()
                if isEnabled then return end
                isEnabled = true
                saveSnapshot()
                stashLightingChildren()
                applyLighting()
                buildEffects()
        end

        local function disable()
                if not isEnabled then return end
                isEnabled = false
                destroyCreatedEffects()
                restoreSnapshot()
                restoreLightingChildren()
        end

        Shaders = vape.Categories.Legit:CreateModule({
                Name = "Shaders",
                Function = function(callback)
                        if callback then enable() else disable() end
                end,
                Tooltip = "Post-processing shaders with customisable effects"
        })

        Brightness = Shaders:CreateSlider({
                Name    = "Brightness",
                Min     = 0,
                Max     = 5,
                Default = 1.5,
                Decimal = 1,
                Function = function(val)
                        if isEnabled then pcall(function() Lighting.Brightness = val end) end
                end,
                Tooltip = "Scene brightness"
        })

        ExposureComp = Shaders:CreateSlider({
                Name    = "Exposure",
                Min     = -1,
                Max     = 1,
                Default = -0.15,
                Decimal = 2,
                Function = function(val)
                        if isEnabled then pcall(function() Lighting.ExposureCompensation = val end) end
                end,
                Tooltip = "Exposure compensation"
        })

        DiffuseScale = Shaders:CreateSlider({
                Name    = "Diffuse Scale",
                Min     = 0,
                Max     = 1,
                Default = 0.6,
                Decimal = 2,
                Function = function(val)
                        if isEnabled then pcall(function() Lighting.EnvironmentDiffuseScale = val end) end
                end
        })

        SpecularScale = Shaders:CreateSlider({
                Name    = "Specular Scale",
                Min     = 0,
                Max     = 1,
                Default = 0.4,
                Decimal = 2,
                Function = function(val)
                        if isEnabled then pcall(function() Lighting.EnvironmentSpecularScale = val end) end
                end
        })

        TimeOfDay = Shaders:CreateSlider({
                Name    = "Time of Day",
                Min     = 0,
                Max     = 24,
                Default = 14,
                Decimal = 1,
                Function = function(val)
                        if isEnabled then pcall(function() Lighting.ClockTime = val end) end
                end,
                Tooltip = "0 = midnight, 12 = noon, 24 = midnight"
        })

        BloomToggle = Shaders:CreateToggle({
                Name    = "Bloom",
                Default = true,
                Function = function()
                        if isEnabled then disable() enable() end
                end
        })

        BloomIntensity = Shaders:CreateSlider({
                Name    = "Bloom Intensity",
                Min     = 0,
                Max     = 2,
                Default = 0.45,
                Decimal = 2,
                Darker  = true,
                Function = function(val)
                        if not isEnabled then return end
                        for _, v in ipairs(Lighting:GetChildren()) do
                                if v:IsA("BloomEffect") then v.Intensity = val end
                        end
                end
        })

        ColorToggle = Shaders:CreateToggle({
                Name    = "Color Correction",
                Default = true,
                Function = function()
                        if isEnabled then disable() enable() end
                end
        })

        Saturation = Shaders:CreateSlider({
                Name    = "Saturation",
                Min     = -1,
                Max     = 1,
                Default = 0.12,
                Decimal = 2,
                Darker  = true,
                Function = function(val)
                        if not isEnabled then return end
                        for _, v in ipairs(Lighting:GetChildren()) do
                                if v:IsA("ColorCorrectionEffect") then v.Saturation = val end
                        end
                end
        })

        DoFToggle = Shaders:CreateToggle({
                Name    = "Depth of Field",
                Default = true,
                Function = function()
                        if isEnabled then disable() enable() end
                end,
                Tooltip = "Blurs distant objects. Disable if it hurts visibility."
        })

        DoFFocus = Shaders:CreateSlider({
                Name    = "DoF Focus Distance",
                Min     = 10,
                Max     = 200,
                Default = 60,
                Darker  = true,
                Function = function(val)
                        if not isEnabled then return end
                        for _, v in ipairs(Lighting:GetChildren()) do
                                if v:IsA("DepthOfFieldEffect") then v.FocusDistance = val end
                        end
                end
        })

        BlurToggle = Shaders:CreateToggle({
                Name    = "Blur",
                Default = true,
                Function = function()
                        if isEnabled then disable() enable() end
                end
        })

        BlurSize = Shaders:CreateSlider({
                Name    = "Blur Size",
                Min     = 0,
                Max     = 10,
                Default = 2,
                Darker  = true,
                Function = function(val)
                        if not isEnabled then return end
                        for _, v in ipairs(Lighting:GetChildren()) do
                                if v:IsA("BlurEffect") then v.Size = val end
                        end
                end
        })

        AtmosphereToggle = Shaders:CreateToggle({
                Name    = "Atmosphere",
                Default = true,
                Function = function()
                        if isEnabled then disable() enable() end
                end
        })

        AtmoDensity = Shaders:CreateSlider({
                Name    = "Atmosphere Density",
                Min     = 0,
                Max     = 1,
                Default = 0.35,
                Decimal = 2,
                Darker  = true,
                Function = function(val)
                        if not isEnabled then return end
                        for _, v in ipairs(Lighting:GetChildren()) do
                                if v:IsA("Atmosphere") then v.Density = val end
                        end
                end,
                Tooltip = "Higher = more fog/haze. Lower for better visibility."
        })

        SunRaysToggle = Shaders:CreateToggle({
                Name    = "Sun Rays",
                Default = false,
                Function = function()
                        if isEnabled then disable() enable() end
                end,
                Tooltip = "God rays effect through objects"
        })
end)

run(function()
    local WaterAmbient
    local WaterColor
    local waterY = 0

    local function findLowestBlock()
        local lowest = 99999
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {lplr.Character, workspace.CurrentCamera}

        for _, v in collectionService:GetTagged('block') do
            if v and v.Position then
                local ray = workspace:Raycast(v.Position + Vector3.new(0, 800, 0), Vector3.new(0, -1000, 0), params)
                if ray and ray.Position.Y < lowest then
                    lowest = ray.Position.Y
                end
            end
        end

        if lowest == 99999 then
            if entitylib.isAlive and entitylib.character and entitylib.character.RootPart then
                local pos = entitylib.character.RootPart.Position
                local ray = workspace:Raycast(pos, Vector3.new(0, -1000, 0), params)
                if ray then
                    return ray.Position.Y - 7
                end
            end
            return -20
        end

        return math.max(lowest - 7, -20)
    end

    WaterAmbient = vape.Categories.World:CreateModule({
        Name = 'Water Ambient1',
        Tooltip = 'Fills the map with a decorative water layer.',
        Function = function(callback)
            local terrain = workspace:FindFirstChildOfClass('Terrain')
            if callback then
                waterY = findLowestBlock()

                terrain:FillBlock(
                    CFrame.new(0, waterY, 0),
                    Vector3.new(5000, 0.01, 5000),
                    Enum.Material.Water
                )
                terrain.WaterColor = Color3.fromHSV(WaterColor.Hue, WaterColor.Sat, WaterColor.Val)
                terrain.WaterTransparency = 0.25
                terrain.WaterReflectance = 0.7
                terrain.WaterWaveSize = 0.13
                terrain.WaterWaveSpeed = 8

                if entitylib.isAlive then
                    entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
                end

                WaterAmbient:Clean(entitylib.Events.LocalAdded:Connect(function(char)
                    char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
                end))
            else
                terrain:FillBlock(
                    CFrame.new(0, waterY, 0),
                    Vector3.new(5000, 0.01, 5000),
                    Enum.Material.Air
                )
                waterY = 0
                if entitylib.isAlive then
                    entitylib.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                end
            end
        end
    })

    WaterColor = WaterAmbient:CreateColorSlider({
        Name = 'Water Color',
        Tooltip = 'Color of the water.',
        Function = function(h, s, v)
            WaterColor.Hue = h
            WaterColor.Sat = s
            WaterColor.Val = v
            if WaterAmbient.Enabled then
                workspace:FindFirstChildOfClass('Terrain').WaterColor = Color3.fromHSV(h, s, v)
            end
        end
    })
end)
run(function()
    local lightingService = cloneref(game:GetService('Lighting'))
    local lightingsettings = {}
    local Fullbright = {Enabled = false}
    local BrightnessSlider
    
    local lastLightingChange = 0
    local DEBOUNCE_TIME = 0.016 
    
    Fullbright = vape.Categories.World:CreateModule({
        Name = "Fullbright",
        Function = function(callback)
            if callback then
                lightingsettings = {
                    Brightness = lightingService.Brightness,
                    ClockTime = lightingService.ClockTime,
                    FogEnd = lightingService.FogEnd,
                    GlobalShadows = lightingService.GlobalShadows,
                    OutdoorAmbient = lightingService.OutdoorAmbient,
                    Ambient = lightingService.Ambient,
                    ExposureCompensation = lightingService.ExposureCompensation
                }
                
                local brightnessValue = BrightnessSlider and BrightnessSlider.Value or 5
                
                lastLightingChange = tick()
                lightingService.Brightness = brightnessValue
                lightingService.ClockTime = 14  
                lightingService.FogEnd = 100000 
                lightingService.GlobalShadows = false  
                lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)  
                lightingService.Ambient = Color3.fromRGB(255, 255, 255)  
                lightingService.ExposureCompensation = 1  
                
                local function protectProperty(propertyName, value)
                    return lightingService:GetPropertyChangedSignal(propertyName):Connect(function()
                        local now = tick()
                        if now - lastLightingChange > DEBOUNCE_TIME then
                            lastLightingChange = now
                            lightingService[propertyName] = value
                        end
                    end)
                end
                
                Fullbright:Clean(protectProperty("Brightness", brightnessValue))
                Fullbright:Clean(protectProperty("Ambient", Color3.fromRGB(255, 255, 255)))
                Fullbright:Clean(protectProperty("ExposureCompensation", 1))
                
            else
                lastLightingChange = tick()
                
                for property, value in pairs(lightingsettings) do
                    if value ~= nil then
                        lightingService[property] = value
                    end
                end
                
                table.clear(lightingsettings)
            end
        end,
        HoverText = "Makes everything bright and removes shadows"
    })
    
    BrightnessSlider = Fullbright:CreateSlider({
        Name = "Brightness",
        Min = 1,
        Max = 10,
        Default = 5,
        Function = function(value)
            if Fullbright.Enabled then
                lastLightingChange = tick()
                lightingService.Brightness = value
            end
        end
    })
    
    local ExtraBright = Fullbright:CreateToggle({
        Name = "Extra Bright",
        Function = function(callback)
            if Fullbright.Enabled then
                lastLightingChange = tick()
                if callback then
                    lightingService.Brightness = 10
                    lightingService.Ambient = Color3.fromRGB(255, 255, 255)
                    lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                    lightingService.ExposureCompensation = 2
                    
                    if not lightingService:FindFirstChild("VapeSun") then
                        local sun = Instance.new("SunRaysEffect")
                        sun.Name = "VapeSun"
                        sun.Intensity = 0.1
                        sun.Spread = 1
                        sun.Parent = lightingService
                    end
                else
                    lightingService.Brightness = BrightnessSlider.Value
                    lightingService.Ambient = Color3.fromRGB(255, 255, 255)
                    lightingService.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                    lightingService.ExposureCompensation = 1
                    
                    local sun = lightingService:FindFirstChild("VapeSun")
                    if sun then
                        sun:Destroy()
                    end
                end
            end
        end
    })
    
    local NoShadows = Fullbright:CreateToggle({
        Name = "No Shadows",
        Function = function(callback)
            if Fullbright.Enabled then
                lastLightingChange = tick()
                lightingService.GlobalShadows = not callback
            end
        end,
        Default = true
    })
end)
