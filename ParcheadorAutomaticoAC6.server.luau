local configuracion = {
	nombresraices = {
		"Workspace",
		"ReplicatedStorage",
		"ServerStorage",
		"StarterPack",
		"Players",
	},
	nombresremotos = {
		ac6_fe_sounds = true,
	},
	nombresasientos = {
		driveseat = true,
		driverseat = true,
	},
	nombresemisores = {
		motor = true,
		engine = true,
		exhaust = true,
	},
	maximosolicitudes = 240,
	intervaloreintento = 2,
	intervaloadvertencia = 5,
	velocidadminima = 0.05,
	velocidadmaxima = 3,
	volumenmaximo = 6,
	usarasientocomorespaldo = true,
	version = 2,
}

local jugadores = game:GetService("Players")
local scriptsservidor = game:GetService("ServerScriptService")
local identificador = string.format("%s:%0.6f", game.JobId, os.clock())

if scriptsservidor:GetAttribute("ac6_parcheador_activo") then
	warn("Parcheador AC6 ya tiene una instancia activa")
	return
end

scriptsservidor:SetAttribute("ac6_parcheador_activo", identificador)

script.Destroying:Connect(function()
	if scriptsservidor:GetAttribute("ac6_parcheador_activo") == identificador then
		scriptsservidor:SetAttribute("ac6_parcheador_activo", nil)
	end
end)

local raices = {}
local conjuntoraices = setmetatable({}, {__mode = "k"})
local parcheados = setmetatable({}, {__mode = "k"})
local perfiles = setmetatable({}, {__mode = "k"})
local contextos = setmetatable({}, {__mode = "k"})
local ultimosescaneos = setmetatable({}, {__mode = "k"})
local esperando = setmetatable({}, {__mode = "k"})
local estados = setmetatable({}, {__mode = "k"})
local estadossolicitudes = setmetatable({}, {__mode = "k"})
local estadosadvertencias = setmetatable({}, {__mode = "k"})
local cantidadparches = 0

for _, nombreraiz in ipairs(configuracion.nombresraices) do
	local correcto, raiz = pcall(game.GetService, game, nombreraiz)
	if correcto and raiz then
		table.insert(raices, raiz)
		conjuntoraices[raiz] = true
	end
end

local function normalizar(valor)
	if type(valor) ~= "string" then
		return ""
	end
	return string.lower(valor)
end

local function esfinito(valor)
	return type(valor) == "number" and valor == valor and valor > -math.huge and valor < math.huge
end

local function ejecutarseguro(ambito, funcion, ...)
	local valores = table.pack(...)
	local correcto, resultado = pcall(function()
		return funcion(table.unpack(valores, 1, valores.n))
	end)
	if not correcto then
		warn(string.format("Parcheador AC6 aislo un error en %s: %s", ambito, tostring(resultado)))
	end
	return correcto, resultado
end

local function nombrecompleto(instancia)
	local correcto, resultado = pcall(function()
		return instancia:GetFullName()
	end)
	if correcto then
		return resultado
	end
	return instancia.Name
end

local function remotocoincide(instancia)
	return instancia:IsA("RemoteEvent") and configuracion.nombresremotos[normalizar(instancia.Name)] == true
end

local function frecuenciapermitida(jugador)
	local ahora = os.clock()
	local estado = estadossolicitudes[jugador]
	if not estado or ahora - estado.inicio >= 1 then
		estado = {
			inicio = ahora,
			cantidad = 0,
		}
		estadossolicitudes[jugador] = estado
	end
	estado.cantidad += 1
	return estado.cantidad <= configuracion.maximosolicitudes
end

local function advertirintento(jugador, remoto, motivo)
	local ahora = os.clock()
	local estado = estadosadvertencias[jugador]
	if not estado or ahora - estado.inicio >= configuracion.intervaloadvertencia then
		estadosadvertencias[jugador] = {
			inicio = ahora,
		}
		warn(string.format(
			"Parcheador AC6 bloqueo a %s (%d) en %s: %s",
			jugador.Name,
			jugador.UserId,
			nombrecompleto(remoto),
			motivo
		))
	end
end

local function buscarasiento(contenedor)
	for _, instancia in ipairs(contenedor:GetDescendants()) do
		if instancia:IsA("VehicleSeat") and configuracion.nombresasientos[normalizar(instancia.Name)] then
			return instancia
		end
	end
	return nil
end

local function tienemarcachasis(contenedor)
	if string.find(normalizar(contenedor.Name), "chassis", 1, true) then
		return true
	end
	if contenedor:FindFirstChild("Body") then
		return true
	end
	if contenedor:FindFirstChild("A-Chassis Tune", true) then
		return true
	end
	return false
end

local function buscarvehiculo(remoto)
	local actual = remoto.Parent
	local alternativa = nil
	while actual and actual ~= game do
		if conjuntoraices[actual] then
			break
		end
		if actual:IsA("Model") or actual:IsA("Folder") then
			local asiento = buscarasiento(actual)
			if asiento then
				return actual, asiento
			end
			if not alternativa and tienemarcachasis(actual) then
				alternativa = actual
			end
		end
		actual = actual.Parent
	end
	return alternativa, nil
end

local function esemisor(instancia)
	return instancia:IsA("BasePart") or instancia:IsA("Attachment")
end

local function buscaremisor(vehiculo, asiento)
	if not vehiculo then
		return nil, "faltante"
	end
	local carroceria = nil
	for _, instancia in ipairs(vehiculo:GetDescendants()) do
		if normalizar(instancia.Name) == "body" then
			carroceria = instancia
			break
		end
	end
	if carroceria then
		for _, instancia in ipairs(carroceria:GetDescendants()) do
			if esemisor(instancia) and configuracion.nombresemisores[normalizar(instancia.Name)] then
				return instancia, "configurado"
			end
		end
	end
	for _, instancia in ipairs(vehiculo:GetDescendants()) do
		if esemisor(instancia) and configuracion.nombresemisores[normalizar(instancia.Name)] then
			return instancia, "configurado"
		end
	end
	if configuracion.usarasientocomorespaldo and asiento then
		return asiento, "asiento"
	end
	return nil, "faltante"
end

local function contextovalido(remoto, contexto)
	if not contexto or not contexto.vehiculo or not contexto.vehiculo.Parent then
		return false
	end
	if not remoto:IsDescendantOf(contexto.vehiculo) then
		return false
	end
	if contexto.asiento then
		if not contexto.asiento:IsA("VehicleSeat") or not contexto.asiento:IsDescendantOf(contexto.vehiculo) then
			return false
		end
	end
	if contexto.emisor and not contexto.emisor:IsDescendantOf(contexto.vehiculo) then
		return false
	end
	return true
end

local function resolvercontexto(remoto, forzar)
	local ahora = os.clock()
	local contexto = contextos[remoto]
	if not forzar and contexto then
		if contextovalido(remoto, contexto) then
			return contexto.vehiculo, contexto.asiento, contexto.emisor, contexto.modoemisor
		end
		if ahora - contexto.revisado < configuracion.intervaloreintento then
			return contexto.vehiculo, contexto.asiento, contexto.emisor, contexto.modoemisor
		end
	end
	local vehiculo, asiento = buscarvehiculo(remoto)
	local emisor, modoemisor = buscaremisor(vehiculo, asiento)
	contexto = {
		vehiculo = vehiculo,
		asiento = asiento,
		emisor = emisor,
		modoemisor = modoemisor,
		revisado = ahora,
	}
	contextos[remoto] = contexto
	return vehiculo, asiento, emisor, modoemisor
end

local function tieneancestrocodigo(instancia, limite)
	local actual = instancia.Parent
	while actual and actual ~= limite do
		if actual:IsA("LuaSourceContainer") then
			return true
		end
		actual = actual.Parent
	end
	return false
end

local function leerperfil(sonido)
	local correcto, perfil = pcall(function()
		return {
			nombre = sonido.Name,
			idsonido = sonido.SoundId,
			volumen = math.clamp(sonido.Volume, 0, configuracion.volumenmaximo),
			velocidadreproduccion = math.clamp(
				sonido.PlaybackSpeed,
				configuracion.velocidadminima,
				configuracion.velocidadmaxima
			),
			repetido = sonido.Looped,
			distanciamaxima = sonido.RollOffMaxDistance,
			distanciaminima = sonido.RollOffMinDistance,
			mododistancia = sonido.RollOffMode,
			gruposonido = sonido.SoundGroup,
		}
	end)
	if correcto then
		return perfil
	end
	return nil
end

local function agregarperfil(banco, sonido, prioridad)
	local clave = normalizar(sonido.Name)
	if clave == "" then
		return
	end
	local perfil = leerperfil(sonido)
	if not perfil then
		return
	end
	local anterior = banco[clave]
	if not anterior or prioridad >= anterior.prioridad then
		banco[clave] = {
			perfil = perfil,
			plantilla = sonido,
			prioridad = prioridad,
		}
	end
end

local function recolectarperfiles(banco, contenedor, prioridad)
	if not contenedor then
		return
	end
	for _, instancia in ipairs(contenedor:GetDescendants()) do
		if instancia:IsA("Sound") then
			agregarperfil(banco, instancia, prioridad)
		end
	end
end

local function escanearperfiles(remoto, vehiculo, original, forzar)
	local ahora = os.clock()
	if not forzar and ultimosescaneos[remoto] and ahora - ultimosescaneos[remoto] < configuracion.intervaloreintento then
		return
	end
	ultimosescaneos[remoto] = ahora
	local banco = perfiles[remoto]
	if not banco then
		banco = {}
		perfiles[remoto] = banco
	end
	if original then
		recolectarperfiles(banco, original, 7)
	end
	local padre = remoto.Parent
	if padre and padre:IsA("LuaSourceContainer") then
		recolectarperfiles(banco, padre, 6)
	end
	if vehiculo then
		for _, instancia in ipairs(vehiculo:GetDescendants()) do
			if instancia:IsA("Sound") then
				local prioridad = 1
				if tieneancestrocodigo(instancia, vehiculo) then
					prioridad = 5
				end
				agregarperfil(banco, instancia, prioridad)
			end
		end
	end
end

local function cantidadperfiles(remoto)
	local cantidad = 0
	for _ in pairs(perfiles[remoto] or {}) do
		cantidad += 1
	end
	return cantidad
end

local function buscarperfil(remoto, vehiculo, nombre)
	escanearperfiles(remoto, vehiculo, nil, false)
	local banco = perfiles[remoto]
	if not banco then
		return nil, nil
	end
	local entrada = banco[normalizar(nombre)]
	if not entrada then
		return nil, nil
	end
	return entrada.perfil, entrada.plantilla
end

local function asignarpropiedad(instancia, propiedad, valor)
	pcall(function()
		instancia[propiedad] = valor
	end)
end

local function aplicarperfil(sonido, perfil)
	asignarpropiedad(sonido, "SoundId", perfil.idsonido)
	asignarpropiedad(sonido, "Volume", perfil.volumen)
	asignarpropiedad(sonido, "PlaybackSpeed", perfil.velocidadreproduccion)
	asignarpropiedad(sonido, "Pitch", perfil.velocidadreproduccion)
	asignarpropiedad(sonido, "Looped", perfil.repetido)
	asignarpropiedad(sonido, "RollOffMaxDistance", perfil.distanciamaxima)
	asignarpropiedad(sonido, "RollOffMinDistance", perfil.distanciaminima)
	asignarpropiedad(sonido, "RollOffMode", perfil.mododistancia)
	asignarpropiedad(sonido, "SoundGroup", perfil.gruposonido)
	asignarpropiedad(sonido, "PlayOnRemove", false)
end

local function crearsonido(plantilla, perfil, emisor)
	local sonido = nil
	if plantilla and plantilla:IsA("Sound") and plantilla.Archivable then
		local correcto, clon = pcall(function()
			return plantilla:Clone()
		end)
		if correcto and clon and clon:IsA("Sound") then
			sonido = clon
		end
	end
	if not sonido then
		sonido = Instance.new("Sound")
	end
	for _, instancia in ipairs(sonido:GetDescendants()) do
		if instancia:IsA("LuaSourceContainer") or instancia:IsA("RemoteEvent") or instancia:IsA("RemoteFunction") then
			instancia:Destroy()
		end
	end
	sonido.Name = perfil.nombre
	aplicarperfil(sonido, perfil)
	sonido.Parent = emisor
	return sonido
end

local function buscarsonido(emisor, nombre)
	local clave = normalizar(nombre)
	for _, instancia in ipairs(emisor:GetChildren()) do
		if instancia:IsA("Sound") and normalizar(instancia.Name) == clave then
			return instancia
		end
	end
	return nil
end

local function obtenersonido(remoto, vehiculo, emisor, nombre, crear)
	local perfil, plantilla = buscarperfil(remoto, vehiculo, nombre)
	if not perfil then
		return nil, nil
	end
	local sonido = buscarsonido(emisor, perfil.nombre)
	if not sonido and crear then
		sonido = crearsonido(plantilla, perfil, emisor)
	end
	return sonido, perfil
end

local function esconductor(jugador, asiento)
	if not asiento or not asiento:IsA("VehicleSeat") then
		return false
	end
	local ocupante = asiento.Occupant
	if not ocupante or not ocupante.Parent then
		return false
	end
	return jugadores:GetPlayerFromCharacter(ocupante.Parent) == jugador
end

local function establecerestado(remoto, estado, motivo)
	local firma = estado .. "|" .. motivo
	if estados[remoto] == firma then
		return
	end
	estados[remoto] = firma
	pcall(function()
		remoto:SetAttribute("ac6_version_parche", configuracion.version)
		remoto:SetAttribute("ac6_estado_parche", estado)
		remoto:SetAttribute("ac6_motivo_parche", motivo)
	end)
	warn(string.format("Parcheador AC6 %s: %s (%s)", estado, nombrecompleto(remoto), motivo))
	if estado == "seguro_listo" then
		esperando[remoto] = nil
	else
		esperando[remoto] = true
	end
end

local function actualizarestado(remoto, forzar)
	if not remoto.Parent then
		esperando[remoto] = nil
		return
	end
	local vehiculo, asiento, emisor, modoemisor = resolvercontexto(remoto, forzar)
	escanearperfiles(remoto, vehiculo, nil, forzar)
	if not vehiculo then
		establecerestado(remoto, "seguro_esperando", "no se encontro el contenedor del chasis")
	elseif not asiento then
		establecerestado(remoto, "seguro_esperando", "falta un VehicleSeat permitido")
	elseif cantidadperfiles(remoto) == 0 then
		establecerestado(remoto, "seguro_esperando", "faltan plantillas Sound del chasis")
	elseif not emisor then
		establecerestado(remoto, "seguro_esperando", "falta un emisor Body, Motor, Engine o Exhaust")
	elseif modoemisor == "asiento" then
		establecerestado(remoto, "seguro_degradado", "usa DriveSeat como emisor mientras falta Motor")
	else
		establecerestado(remoto, "seguro_listo", "chasis protegido y audio disponible")
	end
end

local function manejarevento(remoto, jugador, accion, nombre, ...)
	if not frecuenciapermitida(jugador) then
		advertirintento(jugador, remoto, "demasiadas solicitudes")
		return
	end
	local claveaccion = normalizar(accion)
	if claveaccion ~= "newsound"
		and claveaccion ~= "updatesound"
		and claveaccion ~= "playsound"
		and claveaccion ~= "pausesound"
		and claveaccion ~= "stopsound"
		and claveaccion ~= "removesound"
	then
		advertirintento(jugador, remoto, "accion desconocida")
		return
	end
	if type(nombre) ~= "string" or nombre == "" then
		advertirintento(jugador, remoto, "nombre de sonido invalido")
		return
	end
	local vehiculo, asiento, emisor = resolvercontexto(remoto, false)
	if not vehiculo or not asiento then
		advertirintento(jugador, remoto, "chasis incompleto")
		actualizarestado(remoto, true)
		return
	end
	if not esconductor(jugador, asiento) then
		advertirintento(jugador, remoto, "no es el conductor")
		return
	end
	local perfil, plantilla = buscarperfil(remoto, vehiculo, nombre)
	if not perfil then
		advertirintento(jugador, remoto, "sonido sin plantilla autorizada")
		actualizarestado(remoto, true)
		return
	end
	if not emisor then
		advertirintento(jugador, remoto, "no hay emisor de audio")
		actualizarestado(remoto, true)
		return
	end
	local valores = table.pack(...)
	if claveaccion == "newsound" then
		local velocidad = valores[3]
		local volumen = valores[4]
		local repetido = valores[5]
		if velocidad ~= nil and not esfinito(velocidad) then
			advertirintento(jugador, remoto, "velocidad invalida")
			return
		end
		if volumen ~= nil and not esfinito(volumen) then
			advertirintento(jugador, remoto, "volumen invalido")
			return
		end
		local anterior = buscarsonido(emisor, perfil.nombre)
		if anterior then
			anterior:Stop()
			anterior:Destroy()
		end
		local sonido = crearsonido(plantilla, perfil, emisor)
		sonido.PlaybackSpeed = math.clamp(
			velocidad or perfil.velocidadreproduccion,
			configuracion.velocidadminima,
			configuracion.velocidadmaxima
		)
		asignarpropiedad(sonido, "Pitch", sonido.PlaybackSpeed)
		sonido.Volume = math.min(
			perfil.volumen,
			math.clamp(volumen or perfil.volumen, 0, configuracion.volumenmaximo)
		)
		if type(repetido) == "boolean" then
			sonido.Looped = repetido
		end
	elseif claveaccion == "updatesound" then
		local velocidad = valores[2]
		local volumen = valores[3]
		if not esfinito(velocidad) then
			advertirintento(jugador, remoto, "velocidad invalida")
			return
		end
		if not esfinito(volumen) then
			advertirintento(jugador, remoto, "volumen invalido")
			return
		end
		local sonido = buscarsonido(emisor, perfil.nombre)
		if not sonido then
			sonido = crearsonido(plantilla, perfil, emisor)
		end
		sonido.SoundId = perfil.idsonido
		sonido.PlaybackSpeed = math.clamp(
			velocidad,
			configuracion.velocidadminima,
			configuracion.velocidadmaxima
		)
		asignarpropiedad(sonido, "Pitch", sonido.PlaybackSpeed)
		sonido.Volume = math.min(
			perfil.volumen,
			math.clamp(volumen, 0, configuracion.volumenmaximo)
		)
	elseif claveaccion == "playsound" then
		local sonido = obtenersonido(remoto, vehiculo, emisor, nombre, true)
		if sonido then
			sonido:Play()
		end
	elseif claveaccion == "pausesound" then
		local sonido = obtenersonido(remoto, vehiculo, emisor, nombre, false)
		if sonido then
			sonido:Pause()
		end
	elseif claveaccion == "stopsound" then
		local sonido = obtenersonido(remoto, vehiculo, emisor, nombre, false)
		if sonido then
			sonido:Stop()
		end
	elseif claveaccion == "removesound" then
		local sonido = obtenersonido(remoto, vehiculo, emisor, nombre, false)
		if sonido then
			sonido:Stop()
			sonido:Destroy()
		end
	end
end

local function conectarremoto(remoto)
	remoto.OnServerEvent:Connect(function(jugador, accion, nombre, ...)
		local valores = table.pack(...)
		local correcto, resultado = pcall(function()
			manejarevento(remoto, jugador, accion, nombre, table.unpack(valores, 1, valores.n))
		end)
		if not correcto then
			advertirintento(jugador, remoto, "error interno aislado: " .. tostring(resultado))
		end
	end)
end

local function parchearremoto(remoto)
	if not remotocoincide(remoto) or parcheados[remoto] then
		return
	end
	local padre = remoto.Parent
	if not padre then
		return
	end
	local nombreanterior = remoto.Name
	local vehiculo = select(1, resolvercontexto(remoto, true))
	perfiles[remoto] = {}
	escanearperfiles(remoto, vehiculo, remoto, true)
	local banco = perfiles[remoto]
	local reemplazo = Instance.new("RemoteEvent")
	reemplazo.Name = nombreanterior
	reemplazo:SetAttribute("ac6_version_parche", configuracion.version)
	reemplazo:SetAttribute("ac6_estado_parche", "seguro_inicializando")
	reemplazo:SetAttribute("ac6_motivo_parche", "reemplazando el remoto inseguro")
	parcheados[reemplazo] = true
	perfiles[reemplazo] = banco
	conectarremoto(reemplazo)
	remoto.Name = nombreanterior .. "_Inseguro"
	remoto:Destroy()
	reemplazo.Parent = padre
	perfiles[remoto] = nil
	contextos[remoto] = nil
	ultimosescaneos[remoto] = nil
	cantidadparches += 1
	actualizarestado(reemplazo, true)
end

for _, raiz in ipairs(raices) do
	raiz.DescendantAdded:Connect(function(instancia)
		if remotocoincide(instancia) then
			ejecutarseguro("DescendantAdded", parchearremoto, instancia)
		end
	end)
end

for _, raiz in ipairs(raices) do
	for _, instancia in ipairs(raiz:GetDescendants()) do
		if remotocoincide(instancia) then
			ejecutarseguro("escaneo inicial", parchearremoto, instancia)
		end
	end
end

if cantidadparches == 0 then
	print("Parcheador AC6 no encontro vulnerabilidades en el escaneo inicial")
end

task.spawn(function()
	while script.Parent do
		task.wait(configuracion.intervaloreintento)
		for remoto in pairs(esperando) do
			if remoto.Parent then
				ejecutarseguro("reintento de dependencias", actualizarestado, remoto, true)
			else
				esperando[remoto] = nil
			end
		end
	end
end)
