# Parcheador Automático (AutoPatcher) de A-Chassis Tune 6 (AC6) 

![Roblox](https://img.shields.io/badge/Roblox-Studio-00A2FF?logo=robloxstudio&logoColor=white)
![Luau](https://img.shields.io/badge/Luau-servidor-335FFF)
![Licencia](https://img.shields.io/badge/licencia-MIT-green)

Un parche del lado del servidor para juegos de Roblox que usan versiones vulnerables del sistema de sonido de **A-Chassis 6**.

La vulnerabilidad aparece porque algunas instalaciones de AC6 confían en datos que manda el cliente, como el ID del audio, dónde crearlo, el nombre, el volumen o la velocidad. Con eso, un atacante puede pedirle al servidor que cree y reproduzca sonidos arbitrarios.

Este script reemplaza los remotos vulnerables por una versión controlada por el servidor, sin cambiar el protocolo de sonido clásico de AC6.

> [!IMPORTANT]
> Ponelo como `Script` dentro de `ServerScriptService`. Con una sola copia alcanza.

## ¿Qué protege?

- Trata todo lo que manda el cliente como información manipulable.
- Solo acepta pedidos del jugador que está manejando el vehículo.
- Usa IDs y plantillas de sonido elegidos por el servidor.
- No deja que el cliente elija dónde crear el sonido.
- Limita el volumen, la velocidad y la cantidad de pedidos.
- Si un chasis está mal armado, el error queda aislado y el parcheador sigue funcionando.
- Detecta vehículos agregados después de arrancar el servidor.
- Vuelve a revisar chasis incompletos cuando aparecen las piezas que faltaban.

## Código usado para explotar la vulnerabilidad

El código original está acá:

https://pastebin.com/5FUE10fZ

Este es un ejemplo neutralizado del payload. Usa un nombre tranqui, un ID vacío y volumen cero para mostrar cómo funciona sin reproducir contenido inapropiado:

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

El nombre del sonido no es la vulnerabilidad. El problema real es que el handler original confía en el destino, el ID y otras propiedades que manda el cliente. (Nunca se debe de confiar en el cliente para este tipo de casos: la autoridad la debe de tener el servidor, que es lo que se trata de aplicar en el parcheador de forma automática) 

## Compatibilidad

El parcheador reconoce remotos llamados `AC6_FE_Sounds` y mantiene estas acciones:

- `newSound`
- `updateSound`
- `playSound`
- `pauseSound`
- `stopSound`
- `removeSound`

Funciona con variantes de AC6 que tengan ese `RemoteEvent` y plantillas `Sound` controladas por el servidor.

Si tu chasis usa otro nombre de remoto, otro asiento, otro protocolo o guarda los IDs solamente dentro de módulos personalizados, probablemente tengas que ajustar la tabla `configuracion`.

> [!NOTE]
> Los nombres técnicos como `RemoteEvent`, `VehicleSeat`, `Sound` y `AC6_FE_Sounds` quedan en inglés porque son parte de Roblox o de AC6. Si se traducen, el sistema deja de reconocerlos. Se deben de mantener los nombres originales predeterminados brindados por A-Chassis Tune 6 para que funcione todo de forma automática. 

## Instalación

1. Creá un `Script` dentro de `ServerScriptService`.
2. Ponele `ParcheadorAutomaticoAC6` o el nombre que más quieras.
3. Copiá adentro el contenido de `ParcheadorAutomaticoAC6.server.luau`.
4. Asegurate de tener una sola copia.
5. Probá los vehículos en un servidor local antes de publicar el juego.

No hace falta reemplazar a mano el handler de cada vehículo si el remoto AC6 es reconocido. 
Un fix comun fue brindado en el [Developer Forum](https://devforum.roblox.com/t/fix-the-a-chassis-module-sound-exploit/1857115) el cual consiste en lo siguiente: 

- Remover el `AC6_Stock_Sound` ubicado en Plugins, y reemplazarlo por [esta otra versión](https://create.roblox.com/store/asset/10272541756/AC6-Sound-Fix)

Ese fix rompe los sonidos de cada vehículo de forma continua, haciendo que haya un flood de errores en consola, como menciona esta usuaria: 

<img width="776" height="470" alt="image" src="https://github.com/user-attachments/assets/77c4250b-50b9-40ce-9cde-056415857d94" />

Mi parche no genera errores en los sonidos del vehículo, sino que es un manager para que se gestione todo automáticamente en el servidor y que no permita modificaciones que influyan en todo el servidor viniendo desde el lado del cliente. 

## ¿Qué muestra en la consola?

Cada remoto parcheado recibe estos atributos:

- `ac6_version_parche`
- `ac6_estado_parche`
- `ac6_motivo_parche`

*Un exploiter que se limita a copiar y pegar scripts difícilmente podría identificar correctamente, dentro del `Workspace` de un juego en producción, el nombre de cada `RemoteEvent` modificado. Por lo general, este tipo de usuario solo ejecuta scripts prefabricados en su executor de confianza y no suele recurrir a herramientas como `Dex Explorer`, que permite inspeccionar desde una interfaz el contenido del juego disponible para el cliente, o `Remote Spy`, que intercepta y registra las comunicaciones mediante `RemoteEvent` y `RemoteFunction`, mostrando en tiempo real los datos y argumentos enviados entre el cliente y el servidor.*

Estados posibles:

- `seguro_listo`: el chasis quedó protegido y el audio está disponible.
- `seguro_degradado`: está protegido, pero usa temporalmente el asiento como emisor.
- `seguro_esperando`: está protegido y espera un asiento, una plantilla o un emisor compatible.

Si el primer escaneo no encuentra nada vulnerable, aparece:

```text
Parcheador AC6 no encontro vulnerabilidades en el escaneo inicial
```

Eso no significa que el script se apagó. Sigue atento y revisa los vehículos que aparezcan después.

## Casos raros

Si encuentra un remoto vulnerable pero al chasis le falta algo, primero neutraliza el remoto inseguro. Después espera y vuelve a intentar cuando aparecen las dependencias necesarias.

En ese caso, el vehículo queda protegido, aunque el audio del motor puede no funcionar hasta que estén disponibles el asiento, la plantilla o el emisor que faltaba.

Los permisos de los audios son otro tema: el parcheador no puede darle al juego acceso a un recurso que Roblox no le permite usar.

## Qué se verificó

- Sintaxis válida de Luau.
- Payload de creación arbitraria de sonidos.
- Pedidos de jugadores que no están manejando.
- IDs y destinos controlados por el cliente.
- Volumen excesivo.
- Vehículos agregados repentinamente en el Workspace.
- Chasis incompletos y dependencias que aparecen más tarde.
- Plantillas no clonables.
- Vehículos clonados desde almacenamiento compartido.

Igual, antes de publicarlo, hacé una prueba en Roblox Studio con los modelos exactos de tu juego. Cada versión modificada de A-Chassis puede venir armada distinto.

## Fuentes
- [Roblox Developer Forum](https://devforum.roblox.com/t/fix-the-a-chassis-module-sound-exploit/1857115)
- [Reddit](https://www.reddit.com/r/robloxhackers/comments/s715ir/sound_exploit_for_a_brazilian_game_and_other/)
- [Pastebin](https://pastebin.com/5FUE10fZ)

## Licencia

Este proyecto usa la [licencia MIT](LICENSE).
