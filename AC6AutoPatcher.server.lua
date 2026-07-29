local config = {
	rootnames = {
		"Workspace",
		"ReplicatedStorage",
		"ServerStorage",
		"StarterPack",
		"Players",
	},
	remotenames = {
		ac6_fe_sounds = true,
	},
	seatnames = {
		driveseat = true,
		driverseat = true,
	},
	emitternames = {
		motor = true,
		engine = true,
		exhaust = true,
	},
	maxrequests = 240,
	retryinterval = 2,
	warninginterval = 5,
	minplaybackspeed = 0.05,
	maxplaybackspeed = 3,
	maxvolume = 6,
	seatfallback = true,
	version = 2,
}

local players = game:GetService("Players")
local serverscripts = game:GetService("ServerScriptService")
local token = string.format("%s:%0.6f", game.JobId, os.clock())

if serverscripts:GetAttribute("ac6_autopatcher_running") then
	warn("AC6 AutoPatcher ya tiene una instancia activa")
	return
end

serverscripts:SetAttribute("ac6_autopatcher_running", token)

script.Destroying:Connect(function()
	if serverscripts:GetAttribute("ac6_autopatcher_running") == token then
		serverscripts:SetAttribute("ac6_autopatcher_running", nil)
	end
end)

local roots = {}
local rootset = setmetatable({}, {__mode = "k"})
local patched = setmetatable({}, {__mode = "k"})
local profiles = setmetatable({}, {__mode = "k"})
local contexts = setmetatable({}, {__mode = "k"})
local lastscans = setmetatable({}, {__mode = "k"})
local waiting = setmetatable({}, {__mode = "k"})
local states = setmetatable({}, {__mode = "k"})
local requeststates = setmetatable({}, {__mode = "k"})
local warningstates = setmetatable({}, {__mode = "k"})
local patchcount = 0

for _, rootname in ipairs(config.rootnames) do
	local ok, root = pcall(game.GetService, game, rootname)
	if ok and root then
		table.insert(roots, root)
		rootset[root] = true
	end
end

local function normalize(value)
	if type(value) ~= "string" then
		return ""
	end
	return string.lower(value)
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function safe(scope, callback, ...)
	local values = table.pack(...)
	local ok, result = pcall(function()
		return callback(table.unpack(values, 1, values.n))
	end)
	if not ok then
		warn(string.format("AC6 AutoPatcher aislo un error en %s: %s", scope, tostring(result)))
	end
	return ok, result
end

local function fullname(item)
	local ok, result = pcall(function()
		return item:GetFullName()
	end)
	if ok then
		return result
	end
	return item.Name
end

local function remotematches(item)
	return item:IsA("RemoteEvent") and config.remotenames[normalize(item.Name)] == true
end

local function rateallowed(player)
	local now = os.clock()
	local state = requeststates[player]
	if not state or now - state.started >= 1 then
		state = {
			started = now,
			count = 0,
		}
		requeststates[player] = state
	end
	state.count += 1
	return state.count <= config.maxrequests
end

local function warnattempt(player, remote, reason)
	local now = os.clock()
	local state = warningstates[player]
	if not state or now - state.started >= config.warninginterval then
		warningstates[player] = {
			started = now,
		}
		warn(string.format(
			"AC6 AutoPatcher bloqueo a %s (%d) en %s: %s",
			player.Name,
			player.UserId,
			fullname(remote),
			reason
		))
	end
end

local function findseatwithin(container)
	for _, item in ipairs(container:GetDescendants()) do
		if item:IsA("VehicleSeat") and config.seatnames[normalize(item.Name)] then
			return item
		end
	end
	return nil
end

local function haschassismarker(container)
	if string.find(normalize(container.Name), "chassis", 1, true) then
		return true
	end
	if container:FindFirstChild("Body") then
		return true
	end
	if container:FindFirstChild("A-Chassis Tune", true) then
		return true
	end
	return false
end

local function findcar(remote)
	local current = remote.Parent
	local fallback = nil
	while current and current ~= game do
		if rootset[current] then
			break
		end
		if current:IsA("Model") or current:IsA("Folder") then
			local seat = findseatwithin(current)
			if seat then
				return current, seat
			end
			if not fallback and haschassismarker(current) then
				fallback = current
			end
		end
		current = current.Parent
	end
	return fallback, nil
end

local function isemitter(item)
	return item:IsA("BasePart") or item:IsA("Attachment")
end

local function findemitter(car, seat)
	if not car then
		return nil, "missing"
	end
	local body = nil
	for _, item in ipairs(car:GetDescendants()) do
		if normalize(item.Name) == "body" then
			body = item
			break
		end
	end
	if body then
		for _, item in ipairs(body:GetDescendants()) do
			if isemitter(item) and config.emitternames[normalize(item.Name)] then
				return item, "configured"
			end
		end
	end
	for _, item in ipairs(car:GetDescendants()) do
		if isemitter(item) and config.emitternames[normalize(item.Name)] then
			return item, "configured"
		end
	end
	if config.seatfallback and seat then
		return seat, "seat"
	end
	return nil, "missing"
end

local function contextvalid(remote, context)
	if not context or not context.car or not context.car.Parent then
		return false
	end
	if not remote:IsDescendantOf(context.car) then
		return false
	end
	if context.seat then
		if not context.seat:IsA("VehicleSeat") or not context.seat:IsDescendantOf(context.car) then
			return false
		end
	end
	if context.emitter and not context.emitter:IsDescendantOf(context.car) then
		return false
	end
	return true
end

local function resolvecontext(remote, force)
	local now = os.clock()
	local context = contexts[remote]
	if not force and context then
		if contextvalid(remote, context) then
			return context.car, context.seat, context.emitter, context.emittermode
		end
		if now - context.checked < config.retryinterval then
			return context.car, context.seat, context.emitter, context.emittermode
		end
	end
	local car, seat = findcar(remote)
	local emitter, emittermode = findemitter(car, seat)
	context = {
		car = car,
		seat = seat,
		emitter = emitter,
		emittermode = emittermode,
		checked = now,
	}
	contexts[remote] = context
	return car, seat, emitter, emittermode
end

local function sourceancestor(item, stop)
	local current = item.Parent
	while current and current ~= stop do
		if current:IsA("LuaSourceContainer") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function readprofile(sound)
	local ok, profile = pcall(function()
		return {
			name = sound.Name,
			soundid = sound.SoundId,
			volume = math.clamp(sound.Volume, 0, config.maxvolume),
			playbackspeed = math.clamp(
				sound.PlaybackSpeed,
				config.minplaybackspeed,
				config.maxplaybackspeed
			),
			looped = sound.Looped,
			rolloffmax = sound.RollOffMaxDistance,
			rolloffmin = sound.RollOffMinDistance,
			rolloffmode = sound.RollOffMode,
			soundgroup = sound.SoundGroup,
		}
	end)
	if ok then
		return profile
	end
	return nil
end

local function addprofile(bank, sound, priority)
	local key = normalize(sound.Name)
	if key == "" then
		return
	end
	local profile = readprofile(sound)
	if not profile then
		return
	end
	local previous = bank[key]
	if not previous or priority >= previous.priority then
		bank[key] = {
			profile = profile,
			template = sound,
			priority = priority,
		}
	end
end

local function collectprofiles(bank, container, priority)
	if not container then
		return
	end
	for _, item in ipairs(container:GetDescendants()) do
		if item:IsA("Sound") then
			addprofile(bank, item, priority)
		end
	end
end

local function scanprofiles(remote, car, original, force)
	local now = os.clock()
	if not force and lastscans[remote] and now - lastscans[remote] < config.retryinterval then
		return
	end
	lastscans[remote] = now
	local bank = profiles[remote]
	if not bank then
		bank = {}
		profiles[remote] = bank
	end
	if original then
		collectprofiles(bank, original, 7)
	end
	local parent = remote.Parent
	if parent and parent:IsA("LuaSourceContainer") then
		collectprofiles(bank, parent, 6)
	end
	if car then
		for _, item in ipairs(car:GetDescendants()) do
			if item:IsA("Sound") then
				local priority = 1
				if sourceancestor(item, car) then
					priority = 5
				end
				addprofile(bank, item, priority)
			end
		end
	end
end

local function profilecount(remote)
	local count = 0
	for _ in pairs(profiles[remote] or {}) do
		count += 1
	end
	return count
end

local function findprofile(remote, car, name)
	scanprofiles(remote, car, nil, false)
	local bank = profiles[remote]
	if not bank then
		return nil, nil
	end
	local entry = bank[normalize(name)]
	if not entry then
		return nil, nil
	end
	return entry.profile, entry.template
end

local function setproperty(item, property, value)
	pcall(function()
		item[property] = value
	end)
end

local function applyprofile(sound, profile)
	setproperty(sound, "SoundId", profile.soundid)
	setproperty(sound, "Volume", profile.volume)
	setproperty(sound, "PlaybackSpeed", profile.playbackspeed)
	setproperty(sound, "Pitch", profile.playbackspeed)
	setproperty(sound, "Looped", profile.looped)
	setproperty(sound, "RollOffMaxDistance", profile.rolloffmax)
	setproperty(sound, "RollOffMinDistance", profile.rolloffmin)
	setproperty(sound, "RollOffMode", profile.rolloffmode)
	setproperty(sound, "SoundGroup", profile.soundgroup)
	setproperty(sound, "PlayOnRemove", false)
end

local function makesound(template, profile, emitter)
	local sound = nil
	if template and template:IsA("Sound") and template.Archivable then
		local ok, clone = pcall(function()
			return template:Clone()
		end)
		if ok and clone and clone:IsA("Sound") then
			sound = clone
		end
	end
	if not sound then
		sound = Instance.new("Sound")
	end
	for _, item in ipairs(sound:GetDescendants()) do
		if item:IsA("LuaSourceContainer") or item:IsA("RemoteEvent") or item:IsA("RemoteFunction") then
			item:Destroy()
		end
	end
	sound.Name = profile.name
	applyprofile(sound, profile)
	sound.Parent = emitter
	return sound
end

local function findsound(emitter, name)
	local key = normalize(name)
	for _, item in ipairs(emitter:GetChildren()) do
		if item:IsA("Sound") and normalize(item.Name) == key then
			return item
		end
	end
	return nil
end

local function getsound(remote, car, emitter, name, create)
	local profile, template = findprofile(remote, car, name)
	if not profile then
		return nil, nil
	end
	local sound = findsound(emitter, profile.name)
	if not sound and create then
		sound = makesound(template, profile, emitter)
	end
	return sound, profile
end

local function isdriver(player, seat)
	if not seat or not seat:IsA("VehicleSeat") then
		return false
	end
	local occupant = seat.Occupant
	if not occupant or not occupant.Parent then
		return false
	end
	return players:GetPlayerFromCharacter(occupant.Parent) == player
end

local function setstate(remote, state, reason)
	local signature = state .. "|" .. reason
	if states[remote] == signature then
		return
	end
	states[remote] = signature
	pcall(function()
		remote:SetAttribute("ac6_patch_version", config.version)
		remote:SetAttribute("ac6_patch_state", state)
		remote:SetAttribute("ac6_patch_reason", reason)
	end)
	warn(string.format("AC6 AutoPatcher %s: %s (%s)", state, fullname(remote), reason))
	if state == "secure_ready" then
		waiting[remote] = nil
	else
		waiting[remote] = true
	end
end

local function refreshstate(remote, force)
	if not remote.Parent then
		waiting[remote] = nil
		return
	end
	local car, seat, emitter, emittermode = resolvecontext(remote, force)
	scanprofiles(remote, car, nil, force)
	if not car then
		setstate(remote, "secure_waiting", "no se encontro el contenedor del chasis")
	elseif not seat then
		setstate(remote, "secure_waiting", "falta un VehicleSeat permitido")
	elseif profilecount(remote) == 0 then
		setstate(remote, "secure_waiting", "faltan plantillas Sound del chasis")
	elseif not emitter then
		setstate(remote, "secure_waiting", "falta un emisor Body, Motor, Engine o Exhaust")
	elseif emittermode == "seat" then
		setstate(remote, "secure_degraded", "usa DriveSeat como emisor mientras falta Motor")
	else
		setstate(remote, "secure_ready", "chasis protegido y audio disponible")
	end
end

local function handleevent(remote, player, action, name, ...)
	if not rateallowed(player) then
		warnattempt(player, remote, "demasiadas solicitudes")
		return
	end
	local actionkey = normalize(action)
	if actionkey ~= "newsound"
		and actionkey ~= "updatesound"
		and actionkey ~= "playsound"
		and actionkey ~= "pausesound"
		and actionkey ~= "stopsound"
		and actionkey ~= "removesound"
	then
		warnattempt(player, remote, "accion desconocida")
		return
	end
	if type(name) ~= "string" or name == "" then
		warnattempt(player, remote, "nombre de sonido invalido")
		return
	end
	local car, seat, emitter = resolvecontext(remote, false)
	if not car or not seat then
		warnattempt(player, remote, "chasis incompleto")
		refreshstate(remote, true)
		return
	end
	if not isdriver(player, seat) then
		warnattempt(player, remote, "no es el conductor")
		return
	end
	local profile, template = findprofile(remote, car, name)
	if not profile then
		warnattempt(player, remote, "sonido sin plantilla autorizada")
		refreshstate(remote, true)
		return
	end
	if not emitter then
		warnattempt(player, remote, "no hay emisor de audio")
		refreshstate(remote, true)
		return
	end
	local values = table.pack(...)
	if actionkey == "newsound" then
		local pitch = values[3]
		local volume = values[4]
		local looped = values[5]
		if pitch ~= nil and not finite(pitch) then
			warnattempt(player, remote, "velocidad invalida")
			return
		end
		if volume ~= nil and not finite(volume) then
			warnattempt(player, remote, "volumen invalido")
			return
		end
		local previous = findsound(emitter, profile.name)
		if previous then
			previous:Stop()
			previous:Destroy()
		end
		local sound = makesound(template, profile, emitter)
		sound.PlaybackSpeed = math.clamp(
			pitch or profile.playbackspeed,
			config.minplaybackspeed,
			config.maxplaybackspeed
		)
		setproperty(sound, "Pitch", sound.PlaybackSpeed)
		sound.Volume = math.min(
			profile.volume,
			math.clamp(volume or profile.volume, 0, config.maxvolume)
		)
		if type(looped) == "boolean" then
			sound.Looped = looped
		end
	elseif actionkey == "updatesound" then
		local pitch = values[2]
		local volume = values[3]
		if not finite(pitch) then
			warnattempt(player, remote, "velocidad invalida")
			return
		end
		if not finite(volume) then
			warnattempt(player, remote, "volumen invalido")
			return
		end
		local sound = findsound(emitter, profile.name)
		if not sound then
			sound = makesound(template, profile, emitter)
		end
		sound.SoundId = profile.soundid
		sound.PlaybackSpeed = math.clamp(
			pitch,
			config.minplaybackspeed,
			config.maxplaybackspeed
		)
		setproperty(sound, "Pitch", sound.PlaybackSpeed)
		sound.Volume = math.min(
			profile.volume,
			math.clamp(volume, 0, config.maxvolume)
		)
	elseif actionkey == "playsound" then
		local sound = getsound(remote, car, emitter, name, true)
		if sound then
			sound:Play()
		end
	elseif actionkey == "pausesound" then
		local sound = getsound(remote, car, emitter, name, false)
		if sound then
			sound:Pause()
		end
	elseif actionkey == "stopsound" then
		local sound = getsound(remote, car, emitter, name, false)
		if sound then
			sound:Stop()
		end
	elseif actionkey == "removesound" then
		local sound = getsound(remote, car, emitter, name, false)
		if sound then
			sound:Stop()
			sound:Destroy()
		end
	end
end

local function connectremote(remote)
	remote.OnServerEvent:Connect(function(player, action, name, ...)
		local values = table.pack(...)
		local ok, result = pcall(function()
			handleevent(remote, player, action, name, table.unpack(values, 1, values.n))
		end)
		if not ok then
			warnattempt(player, remote, "error interno aislado: " .. tostring(result))
		end
	end)
end

local function patchremote(remote)
	if not remotematches(remote) or patched[remote] then
		return
	end
	local parent = remote.Parent
	if not parent then
		return
	end
	local oldname = remote.Name
	local car = select(1, resolvecontext(remote, true))
	profiles[remote] = {}
	scanprofiles(remote, car, remote, true)
	local bank = profiles[remote]
	local replacement = Instance.new("RemoteEvent")
	replacement.Name = oldname
	replacement:SetAttribute("ac6_patch_version", config.version)
	replacement:SetAttribute("ac6_patch_state", "secure_initializing")
	replacement:SetAttribute("ac6_patch_reason", "reemplazando el remoto inseguro")
	patched[replacement] = true
	profiles[replacement] = bank
	connectremote(replacement)
	remote.Name = oldname .. "_Insecure"
	remote:Destroy()
	replacement.Parent = parent
	profiles[remote] = nil
	contexts[remote] = nil
	lastscans[remote] = nil
	patchcount += 1
	refreshstate(replacement, true)
end

for _, root in ipairs(roots) do
	root.DescendantAdded:Connect(function(item)
		if remotematches(item) then
			safe("DescendantAdded", patchremote, item)
		end
	end)
end

for _, root in ipairs(roots) do
	for _, item in ipairs(root:GetDescendants()) do
		if remotematches(item) then
			safe("escaneo inicial", patchremote, item)
		end
	end
end

if patchcount == 0 then
	print("AC6 AutoPatcher no encontro vulnerabilidades en el escaneo inicial")
end

task.spawn(function()
	while script.Parent do
		task.wait(config.retryinterval)
		for remote in pairs(waiting) do
			if remote.Parent then
				safe("reintento de dependencias", refreshstate, remote, true)
			else
				waiting[remote] = nil
			end
		end
	end
end)
