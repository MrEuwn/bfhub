# Recovered Blox Fruits source (Luraph v15 -> readable via caomod2077/Deobfuscator-Luraph-V15)
# Extracted key functions. Full file: reference/deobf-bloxfruit-v15-full.lua

--======================================================================
-- FindEnemy
--======================================================================
e] = child:GetPivot()
			end
		end
	end

	updateES()

	getEnemySpawn = function(arg)
		for k, v19 in tbl24, nil, nil do
			if k == arg then
				return v19
			end
		end
	end

	local tbl25 = {}

	tbl18.FindEnemy = function(arg, arg2, arg3, arg4)
		local character = localPlayer.Character
		character = character and character:FindFirstChild("HumanoidRootPart")
		if not character then
			return nil
		end
		local position = character.Position
		local huge = arg3 and arg3 * arg3 or math.huge
		local tbl26 = {}

		for _, v19 in ipairs(arg2) do
			tbl26[v19] = true
		end

		local children = tbl6.Enemies:GetChildren()
		local v19 = nil

		for i = 1, #children do
			local v20 = children[i]
			local humanoid = v20:FindFirstChild("Humanoid")

			if humanoid and humanoid.Health > 0 then
				local match = tbl25[v20.Name] or v20.Name:match("^(.-)%s*%[") or v20.Name
				tbl25[v20.Name] = match

				if tbl26[match] then
					local vehicleSeat = arg4 == "Boat" and v20:FindFirstChild("VehicleSeat") or v20:FindFirstChild("HumanoidRootPart")

					if vehicleSeat then
						local n3 = vehicleSeat.Position.X - position.X
						local n4 = vehicleSeat.Position.Y - position.Y
						local n5 = vehicleSeat.Position.Z - position.Z
						local n6 = n3 * n3 + n4 * n4 + n5 * n5

						if n6 < huge then
							huge = n6
							v19 = v20
						end
					end
				end
			end
		end

		return v19
	end

	local tbl26 = { angle = 0, radius = 35 }

	local function fn12(arg)
		tbl26.angle = (tbl26.angle + 5) % 360
		local v19 = math.rad(tbl26.angle)
		local n3 = tonumber(tbl14["Farm Distance"]) or 20
		local radius = tbl26.radius
		local radius2 = tbl26.radius
		return arg + Vector3.new(math.sin(v19) * radius, n3, math.cos(v19) * radius2)
	end

	local function fn13(arg)
		return fn12(arg)
	end

	tbl18.EngageEnemy = function(arg, arg2)
		for _, child in pairs(tbl6.Enemies:GetChildren()) do
			if child and table.find(arg2, child.Name) then
				local primaryPart = child.PrimaryPart
				local cFrame = primaryPart and primaryPart.CFrame

				if primaryPart and tbl18:IsEntityAlive(child) then
					tbl18:MonitorSkillUsage(child)

					while true do
						tbl5.RunService.Heartbeat:Wait()

						if not _G.DodgeTime or _G.DodgeTime < tick() then
							tbl18:EquipSelectedTool()
							tbl18:ActivateHaki()
							tbl18:BringEnemyToPosition(child, cFrame)
							tbl18:ExecuteTween(fn13(cFrame))
						else
							lo

--======================================================================
-- EngageEnemy
--======================================================================
al radius = tbl26.radius
		local radius2 = tbl26.radius
		return arg + Vector3.new(math.sin(v19) * radius, n3, math.cos(v19) * radius2)
	end

	local function fn13(arg)
		return fn12(arg)
	end

	tbl18.EngageEnemy = function(arg, arg2)
		for _, child in pairs(tbl6.Enemies:GetChildren()) do
			if child and table.find(arg2, child.Name) then
				local primaryPart = child.PrimaryPart
				local cFrame = primaryPart and primaryPart.CFrame

				if primaryPart and tbl18:IsEntityAlive(child) then
					tbl18:MonitorSkillUsage(child)

					while true do
						tbl5.RunService.Heartbeat:Wait()

						if not _G.DodgeTime or _G.DodgeTime < tick() then
							tbl18:EquipSelectedTool()
							tbl18:ActivateHaki()
							tbl18:BringEnemyToPosition(child, cFrame)
							tbl18:ExecuteTween(fn13(cFrame))
						else
							localPlayer.Character.PrimaryPart.CFrame = child.PrimaryPart.CFrame * CFrame.new(0, 500, 0)
						end

						if not (not tbl18:IsAnyFeatureActive() or v9.Unloaded or not child or not child.Parent or not tbl18:IsEntityAlive(child)) then
							continue
						end
						break
					end
				end
			end
		end

		for _, child in pairs(tbl5.ReplicatedStorage:GetChildren()) do
			if table.find(arg2, child.Name) and child and child.PrimaryPart then
				tbl18:ExecuteTween(CFrame.new(child.PrimaryPart.CFrame.Position + Vector3.new(0, tbl14["Farm Distance"], 10)))
			end
		end
	end

	tbl18.GetQuestInfo = function()
		local value = localPlayer.Data.Level.Value
		local str3 = tostring(localPlayer.Team)
		local character = localPlayer.Character
		character = character and character:FindFirstChild("HumanoidRootPart")
		local n3 = nil
		local cframe = nil
		local str4 = nil
		local str5 = nil
		local n4 = nil
		local str6 = nil

		local function fn14()
			return { n3, cframe, str4, str5, n4, str6 }
		end

		if value >= 1 and value <= 9 then
			if str3 == "Marines" then
				n3 = 1
				str5 = "MarineQuest"
				str4 = "Trainee"
				str6 = "Trainee"
				cframe = CFrame.new
				cframe = cframe(-2709.67944, 24.5206585, 2104.24585)
			else
				n3 = 1
				str5 = "BanditQuest1"
				str4 = "Bandit"
				str6 = "Bandit"
				cframe = CFrame.new
				cframe = cframe(1059.99731, 16.9222069, 1549.28162)
			end

			n4 = 1
			return (fn14())
		end

		if value >= 210 and value <= 249 then
			n3 = 2
			str5 = "PrisonerQuest"
			str4 = "Dangerous Prisoner"
			str6 = "Dangerous Prisoner"
			n4 = 210
			c

--======================================================================
-- ActivateHaki
--======================================================================
	position = arg2.Position
		else
			if typeof(arg2) ~= "Vector3" then
				return math.huge
			end
			position = arg2
		end

		return (character.PrimaryPart.Position - position).Magnitude
	end

	tbl18.ActivateHaki = function()
		local character = localPlayer.Character

		if not character or not character:FindFirstChild("HasBuso") then
			tbl18:FireRemote("Buso")
		end
	end

	tbl18.EquipToolByName = function(arg, arg2)
		local backpack = localPlayer.Backpack
		local character = localPlayer.Character
		if not (backpack and character) then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local v19 = backpack:FindFirstChild(arg2)

		if humanoid and v19 and v19:IsA("Tool") then
			humanoid:EquipTool(v19)
		end
	end

	tbl18.EquipToolByTip = function(arg, arg2)
		local backpack = localPlayer.Backpack
		if not backpack then
			return
		end
		local children = backpack:GetChildren()

		for i = 1, #children do
			local v19 = children[i]
			if v19:IsA("Tool") and v19.ToolTip == arg2 then
				tbl18:EquipToolByName(v19.Name)
				return
			end
		end
	end

	tbl18.EquipSelectedTool = function()
		local backpack = localPlayer.Backpack
		if not backpack then
			return
		end
		local weaponTool = tbl14["Weapon Tool"]
		local children = backpack:GetChildren()

		for i = 1, #children do
			local v19 = children[i]
			if v19:IsA("Tool") and v19.ToolTip == weaponTool then
				tbl18:EquipToolByName(v19.Name)
				return
			end
		end
	end

	tbl18.UnequipTool = function(arg, arg2)
		local character = localPlayer.Character
		if not character then
			return
		end
		local v19 = character:FindFirstChild(arg2)

		if v19 and v19:IsA("Tool") then
			v19.Parent = localPlayer.Backpack
		end
	end

	tbl18.HasTool = function(arg, arg2)
		local character = localPlayer.Character
		if not character then
			return false
		end
		return character:FindFirstChild(arg2) ~= nil or localPlayer.Backpack:FindFirstChild(arg2) ~= nil
	end

	tbl18.FindToolByTip = function(arg, arg2)
		local function fn11(arg3)
			if not arg3 then
				return nil
			end
			local children = arg3:GetChildren()

			for i = 1, #children do
				local v19 = children[i]
				if v19:IsA("Tool") and v19.ToolTip == arg2 then
					return v19
				end
			end

			return nil
		end

		return fn11(localPlayer.Backpack) or fn11(localPlayer.Character)
	end

	tbl18.SendKeyPress = function(arg, arg2, arg3)
		local n3 = arg3 

--======================================================================
-- EquipToolByName
--======================================================================
ude
	end

	tbl18.ActivateHaki = function()
		local character = localPlayer.Character

		if not character or not character:FindFirstChild("HasBuso") then
			tbl18:FireRemote("Buso")
		end
	end

	tbl18.EquipToolByName = function(arg, arg2)
		local backpack = localPlayer.Backpack
		local character = localPlayer.Character
		if not (backpack and character) then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local v19 = backpack:FindFirstChild(arg2)

		if humanoid and v19 and v19:IsA("Tool") then
			humanoid:EquipTool(v19)
		end
	end

	tbl18.EquipToolByTip = function(arg, arg2)
		local backpack = localPlayer.Backpack
		if not backpack then
			return
		end
		local children = backpack:GetChildren()

		for i = 1, #children do
			local v19 = children[i]
			if v19:IsA("Tool") and v19.ToolTip == arg2 then
				tbl18:EquipToolByName(v19.Name)
				return
			end
		end
	end

	tbl18.EquipSelectedTool = function()
		local backpack = localPlayer.Backpack
		if not backpack then
			return
		end
		local weaponTool = tbl14["Weapon Tool"]
		local children = backpack:GetChildren()

		for i = 1, #children do
			local v19 = children[i]
			if v19:IsA("Tool") and v19.ToolTip == weaponTool then
				tbl18:EquipToolByName(v19.Name)
				return
			end
		end
	end

	tbl18.UnequipTool = function(arg, arg2)
		local character = localPlayer.Character
		if not character then
			return
		end
		local v19 = character:FindFirstChild(arg2)

		if v19 and v19:IsA("Tool") then
			v19.Parent = localPlayer.Backpack
		end
	end

	tbl18.HasTool = function(arg, arg2)
		local character = localPlayer.Character
		if not character then
			return false
		end
		return character:FindFirstChild(arg2) ~= nil or localPlayer.Backpack:FindFirstChild(arg2) ~= nil
	end

	tbl18.FindToolByTip = function(arg, arg2)
		local function fn11(arg3)
			if not arg3 then
				return nil
			end
			local children = arg3:GetChildren()

			for i = 1, #children do
				local v19 = children[i]
				if v19:IsA("Tool") and v19.ToolTip == arg2 then
					return v19
				end
			end

			return nil
		end

		return fn11(localPlayer.Backpack) or fn11(localPlayer.Character)
	end

	tbl18.SendKeyPress = function(arg, arg2, arg3)
		local n3 = arg3 or 0
		tbl5.VirtualInputManager:SendKeyEvent(true, arg2, false, game)

		if n3 > 0 then
			task.wait(n3)
		end

		tbl5.VirtualInputManager:SendKeyEvent(false, arg2, false, game)
	end


--======================================================================
-- EquipToolByTip
--======================================================================
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		local v19 = backpack:FindFirstChild(arg2)

		if humanoid and v19 and v19:IsA("Tool") then
			humanoid:EquipTool(v19)
		end
	end

	tbl18.EquipToolByTip = function(arg, arg2)
		local backpack = localPlayer.Backpack
		if not backpack then
			return
		end
		local children = backpack:GetChildren()

		for i = 1, #children do
			local v19 = children[i]
			if v19:IsA("Tool") and v19.ToolTip == arg2 then
				tbl18:EquipToolByName(v19.Name)
				return
			end
		end
	end

	tbl18.EquipSelectedTool = function()
		local backpack = localPlayer.Backpack
		if not backpack then
			return
		end
		local weaponTool = tbl14["Weapon Tool"]
		local children = backpack:GetChildren()

		for i = 1, #children do
			local v19 = children[i]
			if v19:IsA("Tool") and v19.ToolTip == weaponTool then
				tbl18:EquipToolByName(v19.Name)
				return
			end
		end
	end

	tbl18.UnequipTool = function(arg, arg2)
		local character = localPlayer.Character
		if not character then
			return
		end
		local v19 = character:FindFirstChild(arg2)

		if v19 and v19:IsA("Tool") then
			v19.Parent = localPlayer.Backpack
		end
	end

	tbl18.HasTool = function(arg, arg2)
		local character = localPlayer.Character
		if not character then
			return false
		end
		return character:FindFirstChild(arg2) ~= nil or localPlayer.Backpack:FindFirstChild(arg2) ~= nil
	end

	tbl18.FindToolByTip = function(arg, arg2)
		local function fn11(arg3)
			if not arg3 then
				return nil
			end
			local children = arg3:GetChildren()

			for i = 1, #children do
				local v19 = children[i]
				if v19:IsA("Tool") and v19.ToolTip == arg2 then
					return v19
				end
			end

			return nil
		end

		return fn11(localPlayer.Backpack) or fn11(localPlayer.Character)
	end

	tbl18.SendKeyPress = function(arg, arg2, arg3)
		local n3 = arg3 or 0
		tbl5.VirtualInputManager:SendKeyEvent(true, arg2, false, game)

		if n3 > 0 then
			task.wait(n3)
		end

		tbl5.VirtualInputManager:SendKeyEvent(false, arg2, false, game)
	end

	local tbl22 = {
		["rbxassetid://9802959564"] = true,
		["rbxassetid://507766388"] = true,
		["http://www.roblox.com/asset/?id=9884584522"] = true,
	}

	tbl18.MonitorSkillUsage = function(arg, arg2)
		if not arg2 or not arg2.Parent then
			return
		end
		local humanoid = arg2:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local animator = human

--======================================================================
-- TeleportTo
--======================================================================
-- TeleportTo: not found


--======================================================================
-- TweenTo
--======================================================================
-- TweenTo: not found


--======================================================================
-- BringMob
--======================================================================
-- BringMob: not found


--======================================================================
-- ServerHop
--======================================================================
TweenService:Create(primaryPart, TweenInfo.new(math.max(0.1, (primaryPart.Position - arg3.p).Magnitude / 250), linear, out), { CFrame = arg3 })

		pcall(function()
			tween:Play()
		end)
	end

	tbl18.ServerHop = function(arg, text, arg2)
		local n3 = arg2 or tonumber(tbl14["Count Player"]) or 5
		text = text or "Singapore"

		for i = 1, 100 do
			pcall(function()
				playerGui.ServerBrowser.Frame.Filters.SearchRegion.TextBox.Text = text
			end)

			local response = tbl5.ReplicatedStorage.__ServerBrowser:InvokeServer(i)

			for k, v19 in pairs(response) do
				if k ~= game.JobId and v19.Count <= n3 and not string.find(tostring(v19.Private), "true") then
					tbl4.__spawn(function()
						tbl5.ReplicatedStorage.__ServerBrowser:InvokeServer("teleport", k)
					end)
				end
			end
		end
	end

	tbl18.FireRemote = function(...)
		return tbl6.CommF_:InvokeServer(select(2, ...))
	end

	tbl18.IsEntityAlive = function(arg, arg2)
		local humanoid = arg2:FindFirstChild("Humanoid")
		return humanoid and humanoid.Health > 0
	end

	tbl18.GetDistance = function(arg, arg2)
		local character = localPlayer.Character
		if not character or not character.PrimaryPart then
			return math.huge
		end
		local position

		if typeof(arg2) == "CFrame" then
			position = arg2.Position
		else
			if typeof(arg2) ~= "Vector3" then
				return math.huge
			end
			position = arg2
		end

		return (character.PrimaryPart.Position - position).Magnitude
	end

	tbl18.ActivateHaki = function()
		local character = localPlayer.Character

		if not character or not character:FindFirstChild("HasBuso") then
			tbl18:FireRemote("Buso")
		end
	end

	tbl18.EquipToolByName = function(arg, arg2)
		local backpack = localPlayer.Backpack
		local character = localPlayer.Character
		if not (backpack and character) then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local v19 = backpack:FindFirstChild(arg2)

		if humanoid and v19 and v19:IsA("Tool") then
			humanoid:EquipTool(v19)
		end
	end

	tbl18.EquipToolByTip = function(arg, arg2)
		local backpack = localPlayer.Backpack
		if not backpack then
			return
		end
		local children = backpack:GetChildren()

		for i = 1, #children do
			local v19 = children[i]
			if v19:IsA("Tool") and v19.ToolTip == arg2 then
				tbl18:EquipToolByName(v19.Name)
				return
			end
		end
	end

	tbl18.EquipSelectedTool = function()
		local backpack = localP
