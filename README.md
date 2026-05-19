# 🎭 torp_animtest

Bilingual documentation / Documentación bilingüe: **[English](#english) | [Español](#español)**

---

<a name="english"></a>
# English Description

A massive, high-performance **RedM** animation, scenario, and emote previewer designed with a premium glassmorphic sidebar, cinematic 3D orbital controls, and buttery-smooth progressive rendering.

### ⚡ Extreme Performance & Fluidity
Despite handling a colossal dataset, the script runs at a **stable 144 FPS** and is completely immune to Chromium thread freezes. Thanks to our custom **Lazy Loading (infinite scroll) engine**, elements (both animations and scenarios) are dynamically rendered in progressive blocks of 80 as the user scrolls, keeping NUI memory usage virtually zero and the interface ultra-responsive.

---

## 🤝 Database & Credits

This script utilizes the complete database of animations and ambient scenarios extracted directly from **Femga's** legendary RedM repository:
👉 **[rdr3_discoveries by Femga](https://github.com/femga/rdr3_discoveries)**

Special thanks to **Femga** for their outstanding work collecting native hashes, which forms the core of our uninhibited search database.

---

## 🌟 Key Features

*   📦 **Massive Catalog Support:** Out-of-the-box support for all **25,831 animation directories** and **1,322 ambient scenarios** with zero performance drops.
*   🔄 **Orbital 3D Preview Camera (360° Orbit):** Cinematic camera orbiting via mouse drag. By rotating the camera instead of the entity, it **bypasses RedM/RDR3 physical constraints**, allowing you to preview the player even in locked scenarios (sitting, sleeping, washing hands, etc.).
*   🔍 **Physical 3D Zoom (1.0m - 10.0m):** Sleek vertical slider on the right side of the screen to physically translate camera coordinates up to 10 meters smoothly without changing the field of view (FOV).
*   📂 **Smart Folder Grouping:** Automatically merges identical or duplicate dictionaries (e.g., 80 variations of campfire) into a single folder and structures their sub-animations into behavioral categories (🟩 Loop/Base, 🟦 Enter, 🟪 Exit, 🟧 Reactions, ⭐ Others).
*   📋 **Universal Quick Copy Button:** Split-button layout for each item to play (left) and copy (right clipboard `📋` icon with a temporary green `✔️` checkmark feedback). Copies clean, ready-to-use strings (`dictionary, animation`, native scenario names, or emote commands).
*   🌐 **Multi-language Localization (ES/EN):** Built-in native support for English and Spanish via JSON translation files (`html/locales/`).
*   📌 **Sticky 'Back to Categories' Button:** Navigation bar floating beneath the search input that remains visible at all times during heavy scrolling.
*   ↩️ **Safe Teleport Return:** Memorizes original coordinates upon opening and teleports the player back safely when stopping actions or closing the menu.
*   🛑 **NUI Safeshield Cleanup:** Client-side `onResourceStop` event handler ensures NUI focus is released and preview camera is destroyed if the resource is stopped or restarted in console.

---

## 🛠️ Project Structure

```yaml
torp_animtest/
├── fxmanifest.lua        # RedM resource configuration
├── config.lua            # Configuration for command, default keys, and default language
├── client.lua            # Client-side logic (Camera, Zoom, Orbit, Animations, Teleport)
└── html/                 # Web interface (NUI)
    ├── index.html        # Main glassmorphic sidebar layout
    ├── style.css         # Styling system and right vertical zoom slider
    ├── script.js         # Interface logic, Lazy Loading, CEF copying, Grouping
    ├── anims_data.js     # Unified database of animations, emotes, and 1,322 scenarios
    └── locales/          # Localization folder
        ├── es.json       # Spanish translations
        └── en.json       # English translations
```

---

## 🚀 Installation

1.  Download the repository and rename the folder to `torp_animtest`.
2.  Place it inside the `resources/` directory of your RedM server (preferably inside a category like `[TORP]`).
3.  Add `ensure torp_animtest` to your `server.cfg` file.

---

## ⚙️ Configuration

Customize the resource using the **`config.lua`** file:

```lua
Config = {}

-- Default Language: 'es' for Spanish, 'en' for English
Config.Language = 'en'

-- Chat/Console command to open the menu
Config.Command = 'animtest'

-- Default keyboard mapping to open the menu (F9)
Config.DefaultKey = 'F9'
```

---

## 🎨 Menu Controls

*   **Open / Close Menu:** Press **`F9`** (or type `/animtest` in chat). Can also be closed with the **`Escape`** key.
*   **Drag & Orbit:** Left-click and drag your mouse on any empty area of the screen outside of the sidebar to orbit the camera **360°** around your character.
*   **Zoom Slider:** Scroll or drag the vertical slider on the right side of the screen to move the camera closer or further away.
*   **Copy Action:** Click the clipboard `📋` icon next to any item to copy the formatted string directly to your Windows clipboard.

---
---

<a name="español"></a>
# Descripción en Español

Un selector y probador de animaciones, escenarios y gestos masivo para **RedM**, diseñado con una interfaz de usuario premium, fluidez cinematográfica y características avanzadas de previsualización para desarrolladores y creadores de contenido.

### ⚡ Fluidez y Rendimiento Extremo
A pesar de manejar un catálogo colosal de datos, el script se ejecuta a **144 FPS estables** y es completamente inmune a congelamientos del hilo CEF. Gracias a nuestro **motor de Carga Diferida (lazy loading)** personalizado, los elementos de las listas se renderizan dinámicamente en bloques progresivos de 80 elementos a medida que el usuario hace scroll, manteniendo el consumo de memoria NUI virtualmente en cero.

---

## 🤝 Base de Datos y Créditos

Este script utiliza la base de datos completa de animaciones y escenarios ambientales extraídos directamente del legendario repositorio de descubrimientos de **Femga**:
👉 **[rdr3_discoveries de Femga](https://github.com/femga/rdr3_discoveries)**

Agradecimiento especial a **Femga** por su extraordinario trabajo de ingeniería recopilando hashes nativos, lo cual forma el núcleo del buscador masivo de este recurso.

---

## 🌟 Características Principales

*   📦 **Catálogo Masivo Integrado:** Soporte completo e inmediato para las **25,831 carpetas de animaciones** nativas de RDR3 y **1,322 escenarios ambientales únicos** sin caídas de rendimiento.
*   🔄 **Cámara Orbital 3D Interactiva (360° Orbit):** Orbitación cinematográfica de la cámara con arrastre de ratón. Al rotar la cámara en lugar de la entidad, se **soluciona el bloqueo físico del juego**, permitiendo previsualizar al personaje incluso en escenarios complejos (sentado en sillas, acostado a dormir, lavándose las manos, etc.).
*   🔍 **Zoom Físico Tridimensional (1.0m - 10.0m):** Slider vertical táctil en el lateral derecho para alejar o acercar físicamente la cámara hasta 10 metros del personaje de forma suave y sin deformar el lente (FOV).
*   📂 **Agrupación Inteligente de Carpetas:** Clasifica automáticamente diccionarios idénticos o duplicados (ej: 80 variantes de campfire o fogatas) en una única carpeta raíz y divide sus animaciones en subcarpetas de comportamiento (🟩 Bucle/Base, 🟦 Entrar, 🟪 Salir, 🟧 Reacciones, ⭐ Otros).
*   📋 **Botón de Copiado Rápido Universal:** Botones de acción dividida en cada elemento para reproducir (izquierda) y copiar al portapapeles (derecha con icono `📋` y feedback temporal de checkmark `✔️`). Copia formatos ideales listos para programar (`diccionario, animacion`, nombres de escenario nativos o comandos de emotes).
*   🌐 **Localización Multi-idioma (ES/EN):** Soporte nativo para traducción dinámica al Español e Inglés a través de archivos JSON de traducción (`html/locales/`).
*   📌 **Volver a Categorías Sticky:** Botón de navegación flotante anclado debajo de la barra de búsqueda que permanece siempre visible al hacer scroll.
*   ↩️ **Teletransporte de Retorno Seguro:** Memoriza las coordenadas exactas de entrada y devuelve al jugador a su punto inicial al presionar detener o cerrar el menú.
*   🛑 **Cierre con Salvaguarda NUI:** Control automático `onResourceStop` en el cliente Lua que asegura que la NUI libere el foco y destruya la cámara si el script se detiene o reinicia desde la consola del servidor.

---

## 🛠️ Estructura del Proyecto

```yaml
torp_animtest/
├── fxmanifest.lua        # Configuración del recurso RedM
├── config.lua            # Configuración personalizada de comando, teclas e idioma
├── client.lua            # Lógica cliente Lua (Cámara, Zoom, Orbit, Animaciones, Teletransporte)
└── html/                 # Interfaz de Usuario (NUI)
    ├── index.html        # Estructura del menú Glassmorphism
    ├── style.css         # Hoja de estilos premium y slider de zoom vertical
    ├── script.js         # Lógica UI, Lazy Loading, Copiado CEF, Emojis, Agrupación
    ├── anims_data.js     # Base de datos unificada de animaciones, emotes y los 1,322 escenarios
    └── locales/          # Archivos de localización
        ├── es.json       # Traducción al Español
        └── en.json       # Traducción al Inglés
```

---

## 🚀 Instalación

1.  Descarga el repositorio y renombra la carpeta a `torp_animtest`.
2.  Colócala en el directorio `resources/` de tu servidor RedM (preferiblemente dentro de una categoría como `[TORP]`).
3.  Agrega `ensure torp_animtest` a tu archivo de configuración del servidor `server.cfg`.

---

## ⚙️ Configuración

Puedes personalizar los parámetros principales modificando el archivo **`config.lua`**:

```lua
Config = {}

-- Idioma por defecto: 'es' para Español, 'en' para Inglés
Config.Language = 'es'

-- Comando de consola/chat para abrir el menú
Config.Command = 'animtest'

-- Tecla por defecto para abrir el menú (F9)
Config.DefaultKey = 'F9'
```

---

## 🎨 Controles en el Menú

*   **Abrir / Cerrar Menú:** Pulsa **`F9`** (o escribe `/animtest` en el chat). También puedes cerrarlo con la tecla **`Escape`**.
*   **Arrastrar y Rotar:** Haz clic izquierdo y arrastra el ratón sobre cualquier parte vacía de la pantalla fuera del menú lateral para orbitar la cámara **360°** alrededor de tu personaje.
*   **Slider de Zoom:** Haz scroll o arrastra el slider vertical en la parte derecha de la pantalla para acercar o alejar la cámara.
*   **Copiar Acción:** Pulsa el icono del portapapeles `📋` al lado de cualquier animación, escenario o emote para copiar la cadena directamente al portapapeles de Windows.
