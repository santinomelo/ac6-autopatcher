# Parcheador Automático AC6

Parcheador Automático AC6 es una capa de seguridad del lado del servidor para experiencias de Roblox que utilizan remotos de sonido vulnerables de A-Chassis 6.

El proyecto nació después de identificar que algunas instalaciones de AC6 confían en identificadores de sonido, destinos, nombres, volumen y velocidad enviados por el cliente. Un atacante puede abusar de ese comportamiento para crear y reproducir sonidos arbitrarios mediante el servidor.

El parcheador reemplaza los remotos inseguros reconocidos por una implementación controlada por el servidor, conservando el protocolo de sonido tradicional de AC6.

## Modelo de seguridad

- Considera que todos los argumentos enviados por el cliente son manipulables.
- Acepta solicitudes únicamente del ocupante actual del `VehicleSeat`.
- Utiliza identificadores y plantillas de sonido seleccionados por el servidor.
- Nunca acepta del cliente la instancia donde se creará un sonido.
- Limita el volumen y la velocidad de reproducción.
- Limita la cantidad de solicitudes por jugador.
- Aísla los errores para impedir que un chasis malformado detenga el monitor global.
- Reemplaza los remotos vulnerables de forma inmediata cuando se insertan vehículos.
- Revisa nuevamente los chasis incompletos hasta que aparezcan sus dependencias.

## Código utilizado para explotar la vulnerabilidad

El código original fue publicado en:

https://pastebin.com/5FUE10fZ

La siguiente es una reproducción neutralizada del payload observado. Se utiliza un nombre inocuo, un identificador vacío y volumen cero para documentar el flujo sin reproducir contenido inapropiado:

```lua
local espacio = game:GetService("Workspace")

for _, objeto in pairs(espacio:GetChildren()) do
	local vehiculo = objeto:FindFirstChild("Veiculo")
	if vehiculo then
		local remoto = vehiculo:FindFirstChild("AC6_FE_Sounds")
		if remoto then
			remoto:FireServer(
				"newSound",
				"prueba_segura",
				espacio,
				"rbxassetid://0",
				1,
				0,
				false
			)
			remoto:FireServer("playSound", "prueba_segura")
		end
	end
end
```

La vulnerabilidad no depende del nombre del sonido. El problema es que el manejador original confía en el destino, el identificador y otras propiedades suministradas por el cliente.

## Protocolo compatible

El parcheador reconoce remotos llamados `AC6_FE_Sounds` y mantiene las acciones tradicionales:

- `newSound`
- `updateSound`
- `playSound`
- `pauseSound`
- `stopSound`
- `removeSound`

Los nombres de acciones y remotos se comparan sin distinguir mayúsculas de minúsculas. Un nombre de sonido arbitrario se rechaza si no existe una plantilla `Sound` correspondiente y controlada por el servidor.

## Instalación

1. Crea un `Script` dentro de `ServerScriptService`.
2. Nómbralo `ParcheadorAutomaticoAC6`.
3. Copia el contenido de `ParcheadorAutomaticoAC6.server.lua` dentro del script.
4. Conserva una sola copia del parcheador en la experiencia.
5. Prueba todos los vehículos en un servidor local antes de publicar la experiencia.

No es necesario reemplazar individualmente el manejador de cada vehículo cuando el remoto AC6 es reconocido.

## Estados durante la ejecución

Cada remoto reemplazado recibe estos atributos:

- `ac6_version_parche`
- `ac6_estado_parche`
- `ac6_motivo_parche`

Los estados posibles incluyen:

- `seguro_listo`: el chasis está protegido y sus dependencias de audio están disponibles.
- `seguro_degradado`: el chasis está protegido y utiliza temporalmente el asiento del conductor como emisor.
- `seguro_esperando`: el chasis está protegido, pero espera un asiento, una plantilla o un emisor compatible.

Si el escaneo inicial no encuentra un remoto vulnerable reconocido, el servidor imprime:

```text
Parcheador AC6 no encontro vulnerabilidades en el escaneo inicial
```

El monitor continúa activo después de ese mensaje y procesa los vehículos insertados dinámicamente.

## Configuración

La tabla `configuracion`, ubicada al comienzo del script, controla:

- Los servicios supervisados.
- Los nombres de remotos aceptados.
- Los nombres de asientos del conductor aceptados.
- Los nombres preferidos para emisores de sonido.
- Los límites de solicitudes.
- El intervalo de reintento de dependencias.
- Los límites de volumen y velocidad.
- El uso del asiento como emisor de respaldo.

La configuración predeterminada supervisa `Workspace`, `ReplicatedStorage`, `ServerStorage`, `StarterPack` y `Players`.

Puedes retirar los servicios que nunca contengan vehículos en tu experiencia para reducir el alcance del monitoreo.

## Compatibilidad

El proyecto está dirigido a variantes AC6 que exponen un `RemoteEvent` llamado `AC6_FE_Sounds` y contienen plantillas de sonido controladas por el servidor.

Un chasis personalizado puede requerir cambios en la configuración cuando utiliza:

- Otro nombre para el remoto.
- Otro nombre para el asiento del conductor.
- Un protocolo de argumentos completamente diferente.
- Identificadores almacenados únicamente dentro de módulos personalizados.
- Un sistema vehicular distinto de AC6.

Cuando faltan dependencias, el parcheador falla de forma cerrada: neutraliza el remoto vulnerable, pero el audio del motor puede permanecer inactivo hasta que aparezcan los objetos requeridos.

La propiedad y los permisos de los audios son independientes de esta vulnerabilidad. El parcheador no puede conceder a una experiencia permiso para utilizar un recurso de audio.

## Validación

La fuente fue verificada sintácticamente en Luau y sometida a pruebas simuladas que abarcaron:

- El payload de creación arbitraria de sonidos.
- Jugadores no autorizados.
- Identificadores y destinos controlados por el cliente.
- Volumen excesivo.
- Inserción dinámica de vehículos.
- Chasis incompletos.
- Dependencias tardías.
- Plantillas no clonables.
- Vehículos clonados desde almacenamiento compartido.

Realiza siempre una prueba de servidor local en Roblox Studio con los modelos exactos utilizados por la experiencia de destino.

## Licencia

Este proyecto se distribuye bajo la licencia MIT.
