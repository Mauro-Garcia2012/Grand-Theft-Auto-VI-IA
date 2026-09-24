# VICE CITY · Leonida Free Roam

Réplica fan de **GTA VI** en modo **mundo libre** (sin historia) para **Windows (.exe)** y
**Android (.apk)**, hecha con
[Godot 4.7](https://godotengine.org). Recrea Vice City y el estado de Leonida a partir de la
información pública de los tráilers (Ocean Drive, Downtown, Little Cuba/Havana, el puerto, el
aeropuerto, los Everglades/Grassrivers, los Cayos...), con Jason y Lucía como protagonistas.

> Proyecto fan **no oficial** y para **uso privado**. No contiene material filtrado ni archivos de
> Rockstar Games. Todos los modelos 3D son de terceros (ver [Créditos](#créditos-y-licencias)).

![Ocean Drive](docs/screenshots/ocean_drive_aerial.jpg)

## Descargar y jugar

<p align="center">
  <a href="https://github.com/Mauro-Garcia2012/Grand-Theft-Auto-VI-IA/releases/latest/download/ViceCity-Windows-x64.zip">
    <img src="https://img.shields.io/badge/DESCARGAR%20PARA%20WINDOWS-ViceCity--Windows--x64.zip-e91e63?style=for-the-badge&logo=windows&logoColor=white" alt="Descargar para Windows (un solo zip)" height="44">
  </a>
  &nbsp;
  <a href="https://github.com/Mauro-Garcia2012/Grand-Theft-Auto-VI-IA/releases/latest/download/ViceCity-Android.apk">
    <img src="https://img.shields.io/badge/DESCARGAR%20PARA%20ANDROID-ViceCity--Android.apk-3ddc84?style=for-the-badge&logo=android&logoColor=white" alt="Descargar para Android (APK)" height="44">
  </a>
</p>

**Windows**
1. Pulsa el botón rosa: se descarga **un solo archivo**, `ViceCity-Windows-x64.zip`
   (unos 200 MB, siempre la última versión).
2. Descomprímelo (clic derecho → *Extraer todo*) y ejecuta `ViceCity/ViceCity.exe`
   (Windows 10/11 de 64 bits, GPU con Vulkan o DirectX 12). `ViceCity.exe` y `ViceCity.pck`
   tienen que estar juntos. Si SmartScreen avisa: *Más información → Ejecutar de todas formas*.

**Android**
1. Abre este repositorio en el móvil y pulsa el botón verde: se descarga `ViceCity-Android.apk`
   (unos 200 MB; mejor con Wi-Fi).
2. Ábrelo e instálalo. La primera vez Android pide permiso para *instalar apps desconocidas*
   desde el navegador o el gestor de archivos: actívalo. Si Play Protect avisa, pulsa
   *Instalar de todas formas* (es una app hecha para uso privado, sin publicar en Google Play).
3. Requisitos: Android 7 o superior de 64 bits (arm64) con Vulkan; recomendado un móvil de gama
   media-alta con 6 GB de RAM o más. Las versiones nuevas se instalan encima de la anterior.
4. Se juega en horizontal con **controles táctiles**: joystick a la izquierda (llévalo al borde
   para correr), arrastra a la derecha para mover la cámara y usa los botones (disparar, apuntar,
   saltar, coche, usar...). También funciona con mando Bluetooth. En *Pausa → Ajustes* puedes
   bajar la resolución 3D o quitar sombras si va lento.
5. Si Android dice *«la aplicación no se ha instalado porque parece que el paquete no es
   válido»*, casi siempre es que la descarga llegó cortada o dañada: borra el APK, descárgalo
   otra vez y comprueba en el gestor de archivos que ocupa **exactamente** lo que indica la página
   de [Releases](https://github.com/Mauro-Garcia2012/Grand-Theft-Auto-VI-IA/releases/latest)
   (también está su SHA-256).

Los dos archivos los compila y publica GitHub Actions automáticamente en cada cambio del juego
([workflow](.github/workflows/build-windows.yml)); también está en la página de
[Releases](https://github.com/Mauro-Garcia2012/Grand-Theft-Auto-VI-IA/releases/latest).

## Qué incluye

**Ciudad y mundo**
- Mapa de unos 3 × 4 km: Ocean Beach con hoteles art déco y neones, Vice Beach, Downtown con
  rascacielos, Brickell, Little Cuba, Stockyard (almacenes con grafitis), West/North Vice,
  Starfish Island y Fisher Island con mansiones, el puerto con grúas y cruceros, el aeropuerto
  internacional (terminal, aviones en las puertas, hangares), Grassrivers (pantano) y los Cayos
  con la autopista sobre el mar.
- Puentes y causeways, playas con sombrillas, socorristas y paseo marítimo, cocoteros y árboles
  realistas, farolas, bancos, papeleras, bocas de incendio y aparatos de aire acondicionado en las
  azoteas (modelos fotorrealistas de Poly Haven), 326 cruces con **semáforos que funcionan**,
  marinas con yates y veleros fondeados.
- Texturas fotográficas PBR (arena, césped, asfalto, hormigón, estuco, ladrillo, chapa) con
  relieve, iluminación con tonemapping AgX, oclusión ambiental y reflejos en pantalla.
- Ciclo día/noche (atardeceres rosados, ciudad iluminada de noche) y clima dinámico: nublado,
  lluvia y tormenta con relámpagos y calles mojadas.

**Personajes**
- Jason y Lucía, jugables e intercambiables (tecla **Z**); el otro te sigue, sube al coche y
  pelea a tu lado.
- Personajes **realistas** (modelos Mixamo): peatones, bañistas, bandas callejeras en sus barrios,
  médicos, policía y SWAT.
- Animaciones de **captura de movimiento** (Mixamo) reorientadas al esqueleto humanoide: andar,
  trotar, retroceder apuntando, correr y disparar con el rifle al hombro, hablar gesticulando,
  señalar, arrodillarse, reanimación (RCP), levantarse, reacciones y muertes; además de nadar,
  agacharse, recargar, puñetazos, lanzar granadas, caídas y entrar y salir de coches.

**Vehículos** (todos con modelos realistas)
- Coches de calle, deportivos, SUVs, taxis, furgonetas, pick-ups, camión de basura, grúa,
  autobuses, autobús escolar, ambulancias, bomberos, patrullas de la VCPD con sirenas y luces,
  yates, lanchas, veleros y remolcador.
- Coches de marcas reales: **BMW M5 CS, BMW M8, BMW M3 GTR, Dodge Challenger R/T, Tesla
  Roadster, Ferrari 599, Porsche 911 GT3 R, McLaren F1, Chevrolet Camaro y GMC Canyon**, además
  de un monster truck y un Fórmula 1 (Mercedes W14).
- **Helicópteros pilotables** (Eurocopter EC135 y Bell 407 de la VCPD) con vuelo estacionario
  automático, en el aeropuerto y en helipuertos de las azoteas de Downtown.
- **Aviones pilotables**: Cessna 172, Cessna Citation, Airbus A320 y caza Rafale, con despegue, sustentación
  y entrada en pérdida, aterrizaje con tren, choques y amerizajes. El avión vuela hacia donde
  miras con la cámara. Salta en pleno vuelo con **paracaídas** (Lucía te sigue).
- Física con suspensión, derrapes con freno de mano, daños (humo → fuego → explosión),
  gasolina, radio (VICE FM y RADIO LEONIDA), faros, claxon, robo de coches con conductor.
- Tráfico con IA que sigue los carriles, **para en los semáforos en rojo**, esquiva y huye.

**Combate y policía**
- 17 armas: puños, **cuchillo, bate de béisbol**, pistola, **revólver pesado**, micro SMG,
  **ametralladora de combate**, rifle de asalto, **carabina**, escopeta, **escopeta de asalto**,
  francotirador, **francotirador pesado**, lanzacohetes, **lanzagranadas**, **minigun**, granadas
  y **cócteles molotov** (dejan fuego en el suelo). Con retroceso, disparos a la cabeza, blindaje
  y munición.
- **Rueda de armas** como en GTA V: mantén TAB, el tiempo se ralentiza y eliges la categoría con
  el ratón (la rueda del ratón cambia dentro de la categoría). Teclas 1-8 = categorías.
- **Puedes matar a la gente dentro de los coches**: las balas atraviesan las ventanillas. El
  conductor muerto se queda desplomado en el asiento, el coche sigue rodando sin control (a veces
  con el claxon pegado) y los pasajeros huyen; puedes sacar el cadáver y llevarte el coche. Si
  matas al piloto de un helicóptero o avioneta, se estrella.
- **Policía al estilo GTA V**: cuando te pierden de vista buscan en tu última posición conocida
  (las estrellas parpadean), **controles de carretera** delante de ti a partir de 3 estrellas,
  SWAT en todoterrenos a 4 estrellas y **el ejército** con dos helicópteros a 5 estrellas.
  **¡WASTED!** y **¡BUSTED!**.
- **Tráfico aéreo que se puede derribar**: avionetas, jets y Airbus cruzan el cielo; con un
  cohete (o matando al piloto) caen ardiendo, se desintegran en pedazos y explotan al estrellarse.
- **Dificultad** (Fácil, Normal, Difícil, Realista) en Pausa → Ajustes: cambia el daño que
  recibes, la puntería de los enemigos, cuántas patrullas vienen y lo que cuesta despistarlas.
- La salud se regenera sola hasta la mitad (como en GTA V) si no te dan en unos segundos.

**Sistemas**
- **Armerías con interior**: se entra a pie por puertas de cristal automáticas; dentro hay
  paneles con las armas expuestas y sus precios, vitrina-mostrador, estanterías de munición,
  ventiladores de techo, dependiente que te saluda y te entrega el arma, y una **galería de tiro**
  detrás del cristal con dianas que se balancean y puntúan (disparar allí no es delito).
- Tiendas: gasolineras, tiendas de ropa, badulaques que se pueden atracar, Pinta
  Rápido (reparar, repintar y perder a la policía), hospitales, casas seguras para guardar.
- HUD al estilo GTA: minimapa giratorio con GPS, vida, blindaje, estrellas, dinero, arma,
  hora, nombres de zona y vehículo. Menú de pausa con mapa completo (clic para marcar destino),
  estadísticas, ajustes y controles.
- Guardar/cargar partida (F5/F9) y trucos.

## Controles

| Acción | Teclado y ratón | Mando |
|---|---|---|
| Mover / correr / andar | WASD / Shift / Alt | Stick izq. / B / — |
| Saltar / agacharse | Espacio / C | A / L3 |
| Apuntar / disparar | Clic der. / Clic izq. | LT / RT |
| Recargar / cambiar arma | R / 1-8 o rueda | X / LB-RB |
| Granada | G | — |
| Entrar / robar vehículo | F | Y |
| Interactuar (tiendas, gasolina...) | E | Cruceta → |
| Cambiar Jason ↔ Lucía | Z | Cruceta ↓ |
| Mapa / pausa | M / ESC | Back / Start |
| En coche: acelerar, frenar, girar | W / S / A-D | Stick izq. |
| Freno de mano / claxon | Espacio / H | A / R3 |
| Sirena / luces / radio / cámara | Q / L / N / V | — / — / — / Cruceta ↑ |
| Avión: potencia / dirección / alabeo | W-S / ratón / A-D | Stick izq. / cámara |
| Avión: frenos / saltar en paracaídas | Espacio / F | A / Y |
| Helicóptero: subir / bajar | Espacio / C | A / L3 |
| Helicóptero: avanzar, lateral, rumbo | W-S / A-D / ratón | Stick izq. / cámara |
| Paracaídas: planear | WASD | Stick izq. |
| Guardar / cargar | F5 / F9 | — |
| Trucos | T | — |

**Trucos:** `DINERO`, `ARMAS`, `VIDA`, `DIOS`, `MUNICION`, `SINPOLICIA`, `POLICIA5`,
`SUPERCOCHE` (McLaren F1), `INFERNUS` (Ferrari), `DEPORTIVO` (BMW M5), `DRAGSTER` (Porsche),
`MCLAREN`, `MONSTRUO` (monster truck), `F1` (Fórmula 1), `PATRULLA`, `TAXI`, `AMBULANCIA`, `BOMBEROS`, `CAMION`, `AUTOBUS`,
`AVIONETA`, `JET`, `CAZA`, `JUMBO` (te sube a un avión de pasajeros en la pista),
`HELICOPTERO`, `HELIPOLICIA`,
`LANCHA`, `TORMENTA`, `LLUVIA`, `SOL`, `NOCHE`, `MEDIODIA`, `ATARDECER`, `RAPIDO`, `CAOS`,
`TELEPORT`.

## Capturas

| | |
|---|---|
| ![Playa de Ocean Beach](docs/screenshots/beach.jpg) | ![Ocean Drive](docs/screenshots/ocean_drive_street.jpg) |
| ![Downtown](docs/screenshots/downtown_skyline.jpg) | ![Downtown de noche](docs/screenshots/downtown_night.jpg) |
| ![Ocean Drive de noche](docs/screenshots/ocean_drive_night.jpg) | ![Coches](docs/screenshots/brand_cars.jpg) |
| ![Vehículos](docs/screenshots/vehicles.jpg) | ![Aeropuerto](docs/screenshots/airport.jpg) |
| ![Puerto](docs/screenshots/port.jpg) | |

## Compilar desde el código

1. Instala [Godot 4.7.2](https://godotengine.org/download) y sus *export templates*.
2. Abre `game/project.godot`, o exporta por línea de comandos:
   ```
   godot --headless --path game --export-release "Windows Desktop" ../builds/ViceCity/ViceCity.exe
   godot --headless --path game --export-release "Android" ../builds/ViceCity-Android.apk
   ```
   El APK necesita el Android SDK y Java 17 configurados en Godot y se firma con
   `android/vicecity.keystore` (variables `GODOT_ANDROID_KEYSTORE_RELEASE_*`, ver el
   [workflow](.github/workflows/build-windows.yml)). Es una clave pública del proyecto, pensada
   solo para que cada versión se instale encima de la anterior.
3. Pruebas automáticas (sin ventana): `godot --headless --path game -- --test=smoke`
   (también `traffic`, `chase`, `combat`, `fly`, `perf`, `gunshop`; y `-- --test=touch --mobile`
   para los controles táctiles). Con `-- --touch` se prueban los controles táctiles en el PC
   usando el ratón como dedo.

Estructura: `game/scripts/world` (mapa, generación de la ciudad, zonas especiales, semáforos),
`actors`, `vehicles`, `combat`, `ai`, `player`, `systems` (población, policía, tiendas, radio,
trucos) y `ui`. `game/tools` contiene los scripts de prueba y los conversores de modelos.

## Créditos y licencias

- Personajes: modelos Mixamo (Adobe) publicados en proyectos de GitHub; animaciones: Quaternius
  *Universal Animation Library* 1 y 2 (CC0) y capturas de movimiento de Mixamo publicadas en
  [Interactive_Character_Experience](https://github.com/eseosapku/Interactive_Character_Experience),
  [CayneByron.github.io](https://github.com/CayneByron/CayneByron.github.io) y
  [ShootAll](https://github.com/MohamedIsseAhmed/ShootAll), retargeteadas en la importación.
- Armería: modelo propio hecho en Blender con texturas de ambientCG/Poly Haven (CC0); carteles,
  dianas y cajas de munición generados para el proyecto.
- Coches, servicios y barcos: proyecto [Motorpool](https://github.com/Atul-Senapati/Motorpool)
  (exportaciones de Sketchfab) y colección [Vivekkk-1/3D-Models](https://github.com/Vivekkk-1/3D-Models)
  (Boost Software License 1.0); las marcas y diseños pertenecen a sus fabricantes.
- Aviones: [FlightAirMap-3dmodels](https://github.com/Ysurac/FlightAirMap-3dmodels) (FlightGear,
  GPL) y [FlightSim](https://github.com/vinny-palumbo/FlightSim).
- Entorno: texturas PBR de ambientCG y Poly Haven (CC0), mobiliario urbano de Poly Haven (CC0),
  árbol SpeedTree de [Babylon.js Assets](https://github.com/BabylonJS/Assets) (CC BY 4.0),
  semáforos de [Rostock 3DModels](https://github.com/rostock/3DModels) (CC0).
- Armas: AK-74 (vía [three-fps](https://github.com/mohsenheydari/three-fps)), *Free Low Poly
  Weapons Pack* de amaraha (vía Jeh3no, MIT) y *Low Poly RPG-7* de Polyte (CC-BY 4.0).
- Sonidos: Kenney (CC0). Tipografía Inter (SIL OFL).
- Grand Theft Auto, Vice City y Leonida son marcas de Take-Two Interactive / Rockstar Games.
  Este proyecto no está afiliado a ellas.

Los textos completos están en [`game/assets/licenses`](game/assets/licenses).
