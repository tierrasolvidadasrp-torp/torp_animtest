let currentTab = 'anims';
let animLimit = 80;
let loadedCount = 80;
let loadedScenariosCount = 80;
let currentAnimsKeys = [];
let groupedAnimItems = [];
let filteredScenarios = [];
let activeExpandedDict = null;
let currentCategory = null;
let currentLanguage = 'es';
let locales = {};

// Función para copiar texto de manera robusta al portapapeles en CEF
function copyToClipboard(text) {
    let el = document.createElement('textarea');
    el.value = text;
    el.style.position = 'fixed'; // fixed para no alterar layout
    el.style.left = '0';
    el.style.top = '0';
    el.style.opacity = '0'; // invisible pero presente en el DOM
    document.body.appendChild(el);
    el.focus();
    el.select();
    try {
        document.execCommand('copy');
    } catch (err) {
        console.error('Fallo al copiar texto al portapapeles:', err);
    }
    document.body.removeChild(el);
}

// Función auxiliar para crear botones de Acción Dividida (Play y Copy)
function createActionItem(labelText, descText, onPlayClick, onCopyClick, categoryGroup = "") {
    let container = document.createElement('div');
    container.className = 'list-item-action-container';
    
    // Botón de Reproducir (Izquierda)
    let playBtn = document.createElement('button');
    playBtn.className = 'list-item action-play-btn';
    if (categoryGroup) {
        playBtn.setAttribute('data-cat-group', categoryGroup);
        playBtn.setAttribute('data-name', descText);
    }
    playBtn.innerHTML = `
        <span style="font-weight:600; font-size:12.5px; color:var(--text-main); text-align:left;">${labelText}</span>
        <span style="font-family:monospace; font-size:9.5px; color:var(--text-muted); opacity:0.65; text-align:left; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${descText}</span>
    `;
    playBtn.onclick = onPlayClick;
    
    // Botón de Copiar (Derecha con icono universal)
    let copyBtn = document.createElement('button');
    copyBtn.className = 'copy-btn';
    copyBtn.innerHTML = '📋';
    copyBtn.title = t('copy_tooltip', 'Copiar al portapapeles');
    
    copyBtn.onclick = (e) => {
        e.stopPropagation();
        onCopyClick();
        
        // Animación visual de éxito
        copyBtn.innerHTML = '✔️';
        copyBtn.classList.add('copied');
        
        setTimeout(() => {
            copyBtn.innerHTML = '📋';
            copyBtn.classList.remove('copied');
        }, 1500);
    };
    
    container.appendChild(playBtn);
    container.appendChild(copyBtn);
    return container;
}

// Configuración de Mapeo de Categorías para los 25,831 diccionarios
const categoriesConfig = {
    cat_combat: { icon: "⚔️", prefix: ["ai_combat", "mech_melee", "melee"], keywords: ["combat", "melee", "weapon", "aim", "shoot"] },
    cat_work: { icon: "💼", prefix: ["amb_work", "script_work"], keywords: ["work", "clean", "sweep", "carry", "chop", "dig"] },
    cat_camp: { icon: "⛺", prefix: ["amb_camp", "cnv_camp"], keywords: ["camp", "sleep", "sit_ground", " campfire", "cook"] },
    cat_animals: { icon: "🦌", prefix: ["creatures_mammal", "creatures_bird", "creatures_insect", "amb_creature_mammal", "mech_skin"], keywords: ["creature", "animal", "mammal", "bird", "skin", "deer", "wolf", "horse"] },
    cat_vehicles: { icon: "🐎", prefix: ["veh_horseback", "veh_carriage", "veh_train", "veh_boat"], keywords: ["horseback", "saddle", "carriage", "train", "boat", "vehicle"] },
    cat_story: { icon: "🎬", prefix: ["script_story", "script_mission", "script_mp", "script_minigame"], keywords: ["story", "mission", "minigame", "cutscene"] },
    cat_others: { icon: "🎭", prefix: [], keywords: [] }
};

// Clasificador automático de diccionarios
function getDictionaryCategory(dict) {
    let lowerDict = dict.toLowerCase();
    
    // 1. Combate
    for (let p of categoriesConfig.cat_combat.prefix) {
        if (lowerDict.startsWith(p)) return 'cat_combat';
    }
    for (let kw of categoriesConfig.cat_combat.keywords) {
        if (lowerDict.includes(kw)) return 'cat_combat';
    }

    // 2. Trabajo
    for (let p of categoriesConfig.cat_work.prefix) {
        if (lowerDict.startsWith(p)) return 'cat_work';
    }
    for (let kw of categoriesConfig.cat_work.keywords) {
        if (lowerDict.includes(kw)) return 'cat_work';
    }

    // 3. Campamento
    for (let p of categoriesConfig.cat_camp.prefix) {
        if (lowerDict.startsWith(p)) return 'cat_camp';
    }
    for (let kw of categoriesConfig.cat_camp.keywords) {
        if (lowerDict.includes(kw)) return 'cat_camp';
    }

    // 4. Animales
    for (let p of categoriesConfig.cat_animals.prefix) {
        if (lowerDict.startsWith(p)) return 'cat_animals';
    }
    for (let kw of categoriesConfig.cat_animals.keywords) {
        if (lowerDict.includes(kw)) return 'cat_animals';
    }

    // 5. Caballos y Vehículos
    for (let p of categoriesConfig.cat_vehicles.prefix) {
        if (lowerDict.startsWith(p)) return 'cat_vehicles';
    }
    for (let kw of categoriesConfig.cat_vehicles.keywords) {
        if (lowerDict.includes(kw)) return 'cat_vehicles';
    }

    // 6. Historia y Misiones
    for (let p of categoriesConfig.cat_story.prefix) {
        if (lowerDict.startsWith(p)) return 'cat_story';
    }
    for (let kw of categoriesConfig.cat_story.keywords) {
        if (lowerDict.includes(kw)) return 'cat_story';
    }

    // 7. Por defecto: Otros
    return 'cat_others';
}

// Carga el archivo JSON de idioma dinámicamente
async function loadLocale(lang) {
    currentLanguage = lang;
    try {
        let response = await fetch(`locales/${lang}.json`);
        if (!response.ok) throw new Error("Locale not found");
        locales = await response.json();
    } catch (e) {
        console.warn("Fallo al cargar idioma, usando Español por defecto:", e);
        try {
            let response = await fetch(`locales/es.json`);
            locales = await response.json();
        } catch (err) {
            console.error("Error crítico de traducción:", err);
        }
    }
    updateStaticTranslations();
}

function t(key, defaultVal = "") {
    return locales[key] || defaultVal || key;
}

// Reemplazar textos estáticos del HTML usando la traducción cargada
function updateStaticTranslations() {
    document.getElementById('menu-subtitle').innerText = t('menu_subtitle', 'Selector de Animaciones y Escenarios');
    document.getElementById('tab-anims').innerText = t('tab_anims', '🎭 Anims');
    document.getElementById('tab-scenarios').innerText = t('tab_scenarios', '🎬 Escenarios');
    document.getElementById('tab-emotes').innerText = t('tab_emotes', '🤝 Gestos');
    document.getElementById('tab-free').innerText = t('tab_free', '🛠️ Libre');
    document.getElementById('search-input').placeholder = t('search_placeholder', 'Buscar...');
    document.getElementById('free-player-title').innerText = t('free_player', 'Reproductor Libre');
    document.getElementById('free-player-desc').innerText = t('free_desc', 'Ingresa cualquier animación del archivo masivo de RedM (336k+ anims):');
    document.getElementById('label-dict').innerText = t('input_dict', 'Diccionario de Animación');
    document.getElementById('label-name').innerText = t('input_name', 'Nombre de Animación');
    document.getElementById('label-upper').innerText = t('input_upper', 'Solo Parte Superior (Upper Body)');
    document.getElementById('btn-play').innerText = t('btn_play', '▶️ Reproducir Animación');
    document.getElementById('stop-btn').innerText = t('stop_action', '❌ DETENER ACCIÓN');
}

// Escuchar los mensajes del cliente Lua
window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.action === "toggleMenu") {
        let sidebar = document.getElementById('sidebar-container');
        let zoomContainer = document.getElementById('zoom-container');
        if (sidebar) {
            if (data.state) {
                sidebar.classList.add('active');
                if (zoomContainer) {
                    zoomContainer.classList.add('active');
                    document.getElementById('zoom-slider').value = 2.4; // Restablecer distancia de zoom por defecto
                }
                
                // Comprobar si cambió el idioma enviado desde config.lua de RedM
                if (data.language && data.language !== currentLanguage) {
                    loadLocale(data.language).then(() => {
                        currentCategory = null; // Volver al menú principal de carpetas
                        clearSearch();
                        switchTab('anims');
                    });
                } else {
                    currentCategory = null;
                    clearSearch();
                    switchTab('anims');
                }
            } else {
                sidebar.classList.remove('active');
                if (zoomContainer) zoomContainer.classList.remove('active');
            }
        }
    }
});

// Cerrar el menú con Escape o F9
document.addEventListener('keydown', function(event) {
    if (event.key === "Escape") {
        closeMenu();
    }
});

function closeMenu() {
    fetch(`https://${GetParentResourceName()}/closeMenu`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
    let sidebar = document.getElementById('sidebar-container');
    let zoomContainer = document.getElementById('zoom-container');
    if (sidebar) sidebar.classList.remove('active');
    if (zoomContainer) zoomContainer.classList.remove('active');
}

// Cambiar de pestaña
function switchTab(tabId) {
    currentTab = tabId;
    
    // Cambiar clases activas en botones
    let tabButtons = document.querySelectorAll('.tab-link');
    tabButtons.forEach(btn => btn.classList.remove('active'));
    
    let activeBtn = document.getElementById(`tab-${tabId === 'custom' ? 'free' : tabId}`);
    if (activeBtn) activeBtn.classList.add('active');
    
    let listContainer = document.getElementById('list-container');
    let customContainer = document.getElementById('custom-container');
    let searchBox = document.getElementById('search-box-container');
    
    if (tabId === 'custom') {
        listContainer.classList.add('hidden');
        customContainer.classList.remove('hidden');
        searchBox.classList.add('hidden');
        document.getElementById('back-nav-container').classList.add('hidden');
    } else {
        listContainer.classList.remove('hidden');
        customContainer.classList.add('hidden');
        searchBox.classList.remove('hidden');
        if (tabId !== 'anims') {
            document.getElementById('back-nav-container').classList.add('hidden');
        }
        clearSearch();
        renderList();
    }
}

// Limpiar barra de búsqueda
function clearSearch() {
    let searchInput = document.getElementById('search-input');
    if (searchInput) searchInput.value = '';
    
    if (currentTab === 'anims') {
        renderList();
    } else {
        filterList();
    }
}

// Filtrar la lista actual basada en la búsqueda (Llamado en oninput en index.html)
function filterList() {
    if (currentTab === 'anims' || currentTab === 'scenarios') {
        renderList(); // Re-renderizado paginado
        return;
    }
    
    let query = document.getElementById('search-input').value.toLowerCase().trim();
    let items = document.querySelectorAll('.list-item');
    let headers = document.querySelectorAll('.category-header');
    
    // Si no hay búsqueda, mostramos todo
    if (query === "") {
        items.forEach(el => el.classList.remove('hidden'));
        headers.forEach(el => el.classList.remove('hidden'));
        return;
    }
    
    // Ocultar/Mostrar elementos según la coincidencia (Pestañas de Escenarios y Gestos)
    items.forEach(el => {
        let text = el.innerText.toLowerCase();
        let name = el.getAttribute('data-name') ? el.getAttribute('data-name').toLowerCase() : '';
        
        if (text.includes(query) || name.includes(query)) {
            el.classList.remove('hidden');
        } else {
            el.classList.add('hidden');
        }
    });

    // Ocultar cabeceras si todos los elementos de esa categoría están ocultos
    headers.forEach(header => {
        let category = header.getAttribute('data-category');
        let visibleSibling = document.querySelector(`.list-item[data-cat-group="${category}"]:not(.hidden)`);
        
        if (visibleSibling) {
            header.classList.remove('hidden');
        } else {
            header.classList.add('hidden');
        }
    });
}

// Agrupar diccionarios unificados y sub-animaciones por comportamiento (Bucle, Entrar, Salir, Reacciones)
function groupCurrentAnims(keys) {
    let groups = {};
    let lang = currentLanguage || 'es';
    
    // Subcategorías traducidas
    const subCategoriesConfig = {
        es: {
            base: "🟩 Bucle / Base / Espera",
            enter: "🟦 Entrar / Inicio",
            exit: "🟪 Salir / Final",
            react: "🟧 Reacciones / Mirar",
            others: "⭐ Otros / Variaciones"
        },
        en: {
            base: "🟩 Loop / Base / Idle",
            enter: "🟦 Enter / Start",
            exit: "🟪 Exit / End",
            react: "🟧 Reactions / Look",
            others: "⭐ Others / Variations"
        }
    };
    
    let subLabels = subCategoriesConfig[lang] || subCategoriesConfig['es'];
    
    keys.forEach(dict => {
        let pretty = prettifyDictName(dict);
        
        // Quitar la sección de detalles "(Detalle)" para obtener el nombre del grupo principal
        let groupName = pretty;
        let parenIndex = pretty.indexOf(" (");
        if (parenIndex !== -1) {
            groupName = pretty.substring(0, parenIndex);
        }
        
        if (!groups[groupName]) {
            groups[groupName] = {
                name: groupName,
                dictionaries: [],
                subCategories: {
                    base: [],
                    enter: [],
                    exit: [],
                    react: [],
                    others: []
                },
                totalAnims: 0
            };
        }
        
        groups[groupName].dictionaries.push(dict);
        
        let anims = AllAnimations[dict] || [];
        anims.forEach(animName => {
            let lowerAnim = animName.toLowerCase();
            let animObj = { dict: dict, animName: animName };
            
            if (lowerAnim.includes("base") || lowerAnim.includes("idle") || lowerAnim.includes("loop") || lowerAnim === "wip_base") {
                groups[groupName].subCategories.base.push(animObj);
            } else if (lowerAnim.includes("enter") || lowerAnim.includes("intro") || lowerAnim.includes("start") || lowerAnim.includes("get_in") || lowerAnim.includes("pickup") || lowerAnim.includes("grab")) {
                groups[groupName].subCategories.enter.push(animObj);
            } else if (lowerAnim.includes("exit") || lowerAnim.includes("outro") || lowerAnim.includes("end") || lowerAnim.includes("putdown") || lowerAnim.includes("dump") || lowerAnim.includes("drop")) {
                groups[groupName].subCategories.exit.push(animObj);
            } else if (lowerAnim.includes("react") || lowerAnim.includes("look") || lowerAnim.includes("attract") || lowerAnim.includes("shock") || lowerAnim.includes("face")) {
                groups[groupName].subCategories.react.push(animObj);
            } else {
                groups[groupName].subCategories.others.push(animObj);
            }
            groups[groupName].totalAnims++;
        });
    });
    
    let sortedGroups = Object.values(groups);
    sortedGroups.sort((a, b) => a.name.localeCompare(b.name));
    return sortedGroups;
}

// Renderizar la lista dinámicamente según la pestaña seleccionada
function renderList() {
    let container = document.getElementById('list-container');
    container.innerHTML = '';
    activeExpandedDict = null;
    
    if (currentTab === 'anims') {
        let query = document.getElementById('search-input').value.toLowerCase().trim();
        
        // 1. Caso A: Hay búsqueda de texto activa -> Hacemos bypass del menú de carpetas
        if (query !== "") {
            document.getElementById('back-nav-container').classList.add('hidden');
            currentAnimsKeys = Object.keys(AllAnimations).filter(key => {
                if (key.toLowerCase().includes(query)) return true;
                let subAnims = AllAnimations[key];
                for (let i = 0; i < subAnims.length; i++) {
                    if (subAnims[i].toLowerCase().includes(query)) return true;
                }
                return false;
            });
            
            // Ordenar alfabéticamente
            currentAnimsKeys.sort();
            
            // Agrupar diccionarios
            groupedAnimItems = groupCurrentAnims(currentAnimsKeys);
            
            // Cabecera Informativa de Búsqueda
            let header = document.createElement('div');
            header.className = 'category-header';
            header.innerText = `${t('search_placeholder', 'Buscar')}: ${groupedAnimItems.length} carpetas unificadas (${currentAnimsKeys.length} dicc.)`;
            container.appendChild(header);
            
            // Cargar primer bloque de grupos
            loadedCount = Math.min(animLimit, groupedAnimItems.length);
            renderAnimItems(0, loadedCount);
            return;
        }
        
        // 2. Caso B: No hay búsqueda activa -> Mostrar carpetas por nivel
        if (currentCategory === null) {
            document.getElementById('back-nav-container').classList.add('hidden');
            
            // Nivel 1: Lista de Categorías
            let header = document.createElement('div');
            header.className = 'category-header';
            header.innerText = t('tab_anims', 'Categorías de Animación');
            container.appendChild(header);
            
            Object.keys(categoriesConfig).forEach(catId => {
                let catData = categoriesConfig[catId];
                let count = Object.keys(AllAnimations).filter(key => getDictionaryCategory(key) === catId).length;
                
                let btn = document.createElement('button');
                btn.className = 'list-item';
                btn.style.padding = '14px 18px';
                btn.style.borderLeft = '4px solid var(--gold)';
                btn.style.marginBottom = '10px';
                btn.innerHTML = `<span>${catData.icon} <b>${t(catId, catId)}</b></span> <span class="desc">${count} folders</span>`;
                
                btn.onclick = () => {
                    currentCategory = catId;
                    renderList();
                };
                container.appendChild(btn);
            });
        } else {
            document.getElementById('back-nav-container').classList.remove('hidden');
            
            // Filtrar llaves por categoría
            currentAnimsKeys = Object.keys(AllAnimations).filter(key => getDictionaryCategory(key) === currentCategory);
            currentAnimsKeys.sort();
            
            // Agrupar diccionarios
            groupedAnimItems = groupCurrentAnims(currentAnimsKeys);
            
            // Cabecera Informativa
            let header = document.createElement('div');
            header.className = 'category-header';
            let catData = categoriesConfig[currentCategory];
            header.innerText = `${catData.icon} ${t(currentCategory, currentCategory)} (${groupedAnimItems.length} unificadas)`;
            container.appendChild(header);
            
            // Cargar primer bloque de grupos
            loadedCount = Math.min(animLimit, groupedAnimItems.length);
            renderAnimItems(0, loadedCount);
        }
        
    } else if (currentTab === 'scenarios') {
        let query = document.getElementById('search-input').value.toLowerCase().trim();
        
        // Filtrar escenarios por búsqueda si hay una query activa
        if (query !== "") {
            filteredScenarios = Scenarios.filter(scen => {
                let prettyLabel = prettifyScenarioName(scen.name, scen.label).toLowerCase();
                return scen.name.toLowerCase().includes(query) || prettyLabel.includes(query);
            });
        } else {
            filteredScenarios = Scenarios;
        }
        
        let header = document.createElement('div');
        header.className = 'category-header';
        header.innerText = query !== "" ? `${t('general_scenarios', "Escenarios Disponibles")} (${filteredScenarios.length})` : t('general_scenarios', "Escenarios Disponibles");
        header.setAttribute('data-category', 'general_scenarios');
        container.appendChild(header);

        // Cargar primer bloque de escenarios paginados (Lazy loading)
        loadedScenariosCount = Math.min(animLimit, filteredScenarios.length);
        renderScenarioItems(0, loadedScenariosCount);
    } else if (currentTab === 'emotes') {
        const catMap = {
            0: t('emotes_reactions', "Reacciones (Reaction)"),
            1: t('emotes_actions', "Acciones (Action)"),
            2: t('emotes_taunts', "Burlas (Taunts)"),
            3: t('emotes_greets', "Saludos (Greets)"),
            4: t('emotes_twirl', "Giro de Armas (Twirl)"),
            5: t('emotes_dances', "Bailes (Dances)")
        };
        
        let categories = {};
        KitEmotes.forEach(emote => {
            let label = catMap[emote.category] || "Otros";
            if (!categories[label]) categories[label] = [];
            categories[label].push(emote);
        });
        
        for (let catName in categories) {
            let header = document.createElement('div');
            header.className = 'category-header';
            header.innerText = catName;
            header.setAttribute('data-category', catName);
            container.appendChild(header);
            
            categories[catName].forEach(emote => {
                let actionItem = createActionItem(
                    emote.label,
                    emote.name,
                    () => playEmote(emote.name, emote.category),
                    () => copyToClipboard(emote.name),
                    catName
                );
                container.appendChild(actionItem);
            });
        }
    }
}

const tokenTranslations = {
    es: {
        "amb": "Ambiente",
        "camp": "Campamento",
        "work": "Trabajo",
        "prop": "Objeto",
        "butcher": "Carnicero",
        "working": "Trabajando",
        "deer": "Ciervo",
        "female": "Mujer",
        "male": "Hombre",
        "script": "Script",
        "common": "Común",
        "wave": "Saludar",
        "combat": "Combate",
        "melee": "Melee",
        "weapon": "Arma",
        "aim": "Apuntar",
        "shoot": "Disparar",
        "sleep": "Dormir",
        "sit": "Sentarse",
        "ground": "Suelo",
        "chair": "Silla",
        "table": "Mesa",
        "fishing": "Pescar",
        "rod": "Caña",
        "knitting": "Tejer",
        "guitar": "Guitarra",
        "violin": "Violín",
        "banjo": "Banjo",
        "music": "Música",
        "drunk": "Borracho",
        "beer": "Cerveza",
        "whiskey": "Whiskey",
        "smoke": "Fumar",
        "cigar": "Puro",
        "cigarette": "Cigarrillo",
        "clean": "Limpiar",
        "sweep": "Barrer",
        "mop": "Trapear",
        "wash": "Lavar",
        "stew": "Guiso",
        "eat": "Comer",
        "drink": "Beber",
        "story": "Historia",
        "mission": "Misión",
        "player": "Jugador",
        "creature": "Criatura",
        "mammal": "Mamífero",
        "horse": "Caballo",
        "dog": "Perro",
        "cat": "Gato",
        "bird": "Ave",
        "carriage": "Carruaje",
        "train": "Tren",
        "boat": "Bote",
        "vehicle": "Vehículo",
        "action": "Acción",
        "reaction": "Reacción",
        "taunt": "Burla",
        "greet": "Saludo",
        "dance": "Baile",
        "idle": "Espera",
        "enter": "Entrar",
        "exit": "Salir",
        "loop": "Bucle",
        "intro": "Introducción",
        "outro": "Final",
        "normal": "Normal",
        "quick": "Rápido",
        "slow": "Lento",
        "low": "Bajo",
        "medium": "Medio",
        "high": "Alto",
        "snide": "Sarcástico",
        "fancy": "Elegante",
        "rough": "Rudo",
        "tough": "Fuerte",
        "subtle": "Sutil",
        "jovial": "Alegre",
        "sad": "Triste",
        "scared": "Asustado",
        "pain": "Dolor",
        "cheer": "Celebrar",
        "flirt": "Coquetear",
        "cower": "Encogerse",
        "lean": "Apoyarse",
        "wall": "Pared",
        "left": "Izquierda",
        "right": "Derecha",
        "front": "Frente",
        "back": "Atrás",
        "up": "Arriba",
        "down": "Abajo"
    },
    en: {
        "amb": "Ambient",
        "camp": "Camp",
        "work": "Work",
        "prop": "Prop",
        "butcher": "Butcher",
        "working": "Working",
        "deer": "Deer",
        "female": "Female",
        "male": "Male",
        "script": "Script",
        "common": "Common",
        "wave": "Wave",
        "combat": "Combat",
        "melee": "Melee",
        "weapon": "Weapon",
        "aim": "Aim",
        "shoot": "Shoot",
        "sleep": "Sleep",
        "sit": "Sit",
        "ground": "Ground",
        "chair": "Chair",
        "table": "Table",
        "fishing": "Fishing",
        "rod": "Rod",
        "knitting": "Knitting",
        "guitar": "Guitar",
        "violin": "Violin",
        "banjo": "Banjo",
        "music": "Music",
        "drunk": "Drunk",
        "beer": "Beer",
        "whiskey": "Whiskey",
        "smoke": "Smoke",
        "cigar": "Cigar",
        "cigarette": "Cigarette",
        "clean": "Clean",
        "sweep": "Sweep",
        "mop": "Mop",
        "wash": "Wash",
        "stew": "Stew",
        "eat": "Eat",
        "drink": "Drink",
        "story": "Story",
        "mission": "Mission",
        "player": "Player",
        "creature": "Creature",
        "mammal": "Mammal",
        "horse": "Horse",
        "dog": "Dog",
        "cat": "Cat",
        "bird": "Bird",
        "carriage": "Carriage",
        "train": "Train",
        "boat": "Boat",
        "vehicle": "Vehicle",
        "action": "Action",
        "reaction": "Reaction",
        "taunt": "Taunt",
        "greet": "Greet",
        "dance": "Dance",
        "idle": "Idle",
        "enter": "Enter",
        "exit": "Exit",
        "loop": "Loop",
        "intro": "Intro",
        "outro": "Outro",
        "normal": "Normal",
        "quick": "Quick",
        "slow": "Slow",
        "low": "Low",
        "medium": "Medium",
        "high": "High",
        "snide": "Snide",
        "fancy": "Fancy",
        "rough": "Rough",
        "tough": "Tough",
        "subtle": "Subtle",
        "jovial": "Jovial",
        "sad": "Sad",
        "scared": "Scared",
        "pain": "Pain",
        "cheer": "Cheer",
        "flirt": "Flirt",
        "cower": "Cower",
        "lean": "Lean",
        "wall": "Wall",
        "left": "Left",
        "right": "Right",
        "front": "Front",
        "back": "Back",
        "up": "Up",
        "down": "Down"
    }
};

function prettifyDictName(dict) {
    let lang = currentLanguage || 'es';
    let dictTrans = tokenTranslations[lang] || tokenTranslations['es'];
    
    let parts = dict.split('@');
    let prettyParts = [];
    let seenWords = new Set();
    
    parts.forEach((part) => {
        let subTokens = part.split('_');
        let translatedTokens = [];
        
        subTokens.forEach(token => {
            if (token === "prop" || token === "amb" || token === "script" || token === "cnv" || token === "world" || token === "human") return;
            
            let trans = dictTrans[token.toLowerCase()];
            let word = trans ? trans : (token.charAt(0).toUpperCase() + token.slice(1));
            
            let lowerWord = word.toLowerCase();
            if (!seenWords.has(lowerWord)) {
                translatedTokens.push(word);
                seenWords.add(lowerWord);
            }
        });
        
        if (translatedTokens.length > 0) {
            prettyParts.push(translatedTokens.join(' '));
        }
    });
    
    if (prettyParts.length === 0) return dict;
    
    let main = prettyParts[0] || "";
    let action = prettyParts[1] || "";
    let details = prettyParts.slice(2).join(', ');
    
    let finalLabel = "";
    if (main && action) {
        finalLabel = `${main} ➔ ${action}`;
    } else if (main) {
        finalLabel = `${main}`;
    } else {
        finalLabel = `${dict}`;
    }
    
    if (details) {
        finalLabel += ` (${details})`;
    }
    
    return finalLabel.charAt(0).toUpperCase() + finalLabel.slice(1);
}

// Renderiza un rango específico de diccionarios de animación (Versión unificada y sub-categorizada)
function renderAnimItems(start, end) {
    let container = document.getElementById('list-container');
    let lang = currentLanguage || 'es';
    
    const subCategoriesConfig = {
        es: {
            base: "🟩 Bucle / Base / Espera",
            enter: "🟦 Entrar / Inicio",
            exit: "🟪 Salir / Final",
            react: "🟧 Reacciones / Mirar",
            others: "⭐ Otros / Variaciones"
        },
        en: {
            base: "🟩 Loop / Base / Idle",
            enter: "🟦 Enter / Start",
            exit: "🟪 Exit / End",
            react: "🟧 Reactions / Look",
            others: "⭐ Others / Variations"
        }
    };
    
    let subLabels = subCategoriesConfig[lang] || subCategoriesConfig['es'];
    
    for (let i = start; i < end; i++) {
        let group = groupedAnimItems[i];
        if (!group) continue;
        
        let wrapper = document.createElement('div');
        wrapper.className = 'dict-wrapper';
        wrapper.style.marginBottom = '8px';
        
        // Botón principal del Grupo
        let groupBtn = document.createElement('button');
        groupBtn.className = 'list-item';
        groupBtn.style.padding = '12px 14px';
        groupBtn.style.display = 'flex';
        groupBtn.style.alignItems = 'center';
        groupBtn.style.justifyContent = 'space-between';
        
        // Mostrar la primera carpeta técnica como referencia
        let sampleDict = group.dictionaries[0] || "";
        let referenceLabel = group.dictionaries.length > 1 ? `${sampleDict} (+${group.dictionaries.length - 1} carpetas)` : sampleDict;
        
        groupBtn.innerHTML = `
            <div style="display:flex; flex-direction:column; gap:3px; max-width:75%; overflow:hidden;">
                <span style="font-weight:600; font-size:13px; color:var(--text-main); text-align:left; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">📁 ${group.name}</span>
                <span style="font-family:monospace; font-size:9.5px; color:var(--text-muted); opacity:0.65; text-align:left; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${referenceLabel}</span>
            </div>
            <span class="desc" style="font-size:10px; color:var(--gold); font-weight:700; flex-shrink:0;">${group.totalAnims} anims</span>
        `;
        
        // Contenedor principal de sub-carpetas (Bucle, Entrar, Salir, Reacciones, etc.)
        let subFolderContainer = document.createElement('div');
        subFolderContainer.className = 'sub-folders-container hidden';
        subFolderContainer.style.paddingLeft = '12px';
        subFolderContainer.style.marginTop = '4px';
        subFolderContainer.style.display = 'flex';
        subFolderContainer.style.flexDirection = 'column';
        subFolderContainer.style.gap = '4px';
        
        // Renderizar sub-carpetas de animación para cada sub-categoría que no esté vacía
        let activeExpandedSub = null;
        
        Object.keys(group.subCategories).forEach(subKey => {
            let itemsList = group.subCategories[subKey];
            if (itemsList.length === 0) return;
            
            let subFolderWrapper = document.createElement('div');
            subFolderWrapper.className = 'sub-folder-wrapper';
            
            // Botón de la sub-carpeta (ej: "🟩 Bucle / Base")
            let subFolderBtn = document.createElement('button');
            subFolderBtn.className = 'list-item';
            subFolderBtn.style.padding = '8px 12px';
            subFolderBtn.style.fontSize = '12px';
            subFolderBtn.style.marginBottom = '0';
            subFolderBtn.style.borderLeft = '3px solid var(--gold)';
            subFolderBtn.style.background = 'rgba(255, 255, 255, 0.03)';
            subFolderBtn.style.display = 'flex';
            subFolderBtn.style.justifyContent = 'space-between';
            subFolderBtn.style.alignItems = 'center';
            subFolderBtn.innerHTML = `
                <span>📁 ${subLabels[subKey]}</span>
                <span style="font-size:10px; opacity:0.8;">${itemsList.length}</span>
            `;
            
            // Contenedor de las animaciones reales
            let animsListContainer = document.createElement('div');
            animsListContainer.className = 'anims-list-container hidden';
            animsListContainer.style.paddingLeft = '12px';
            animsListContainer.style.marginTop = '2px';
            animsListContainer.style.display = 'flex';
            animsListContainer.style.flexDirection = 'column';
            animsListContainer.style.gap = '2px';
            
            itemsList.forEach(item => {
                let actionItem = createActionItem(
                    `▶️ ${item.animName}`,
                    item.dict,
                    () => playAnim(item.dict, item.animName),
                    () => {
                        copyToClipboard(`${item.dict}, ${item.animName}`);
                    }
                );
                
                // Aplicar el estilo del borde izquierdo y fondo dorado al botón de reproducir
                let playBtn = actionItem.querySelector('.action-play-btn');
                playBtn.style.borderLeft = '2px solid rgba(255, 215, 0, 0.4)';
                playBtn.style.background = 'rgba(0, 0, 0, 0.2)';
                playBtn.style.padding = '6px 10px';
                playBtn.style.fontSize = '11px';
                
                animsListContainer.appendChild(actionItem);
            });
            
            // Comportamiento del acordeón de sub-carpetas
            subFolderBtn.onclick = (e) => {
                e.stopPropagation();
                if (activeExpandedSub && activeExpandedSub !== animsListContainer) {
                    activeExpandedSub.classList.add('hidden');
                }
                
                if (animsListContainer.classList.contains('hidden')) {
                    animsListContainer.classList.remove('hidden');
                    activeExpandedSub = animsListContainer;
                } else {
                    animsListContainer.classList.add('hidden');
                    activeExpandedSub = null;
                }
            };
            
            subFolderWrapper.appendChild(subFolderBtn);
            subFolderWrapper.appendChild(animsListContainer);
            subFolderContainer.appendChild(subFolderWrapper);
        });
        
        // Comportamiento del acordeón del Grupo principal
        groupBtn.onclick = () => {
            if (activeExpandedDict && activeExpandedDict !== subFolderContainer) {
                activeExpandedDict.classList.add('hidden');
            }
            
            if (subFolderContainer.classList.contains('hidden')) {
                subFolderContainer.classList.remove('hidden');
                activeExpandedDict = subFolderContainer;
            } else {
                subFolderContainer.classList.add('hidden');
                activeExpandedDict = null;
            }
        };
        
        wrapper.appendChild(groupBtn);
        wrapper.appendChild(subFolderContainer);
        container.appendChild(wrapper);
    }
}

// Renderizar un rango específico de escenarios (Versión optimizada y lazy-loaded)
function renderScenarioItems(start, end) {
    let container = document.getElementById('list-container');
    
    for (let i = start; i < end; i++) {
        let scen = filteredScenarios[i];
        if (!scen) continue;
        
        let prettyLabel = prettifyScenarioName(scen.name, scen.label);
        let actionItem = createActionItem(
            prettyLabel,
            scen.name,
            () => playScenario(scen.name),
            () => copyToClipboard(scen.name),
            'general_scenarios'
        );
        container.appendChild(actionItem);
    }
}

// Evento de Scroll para Carga Infinita de Animaciones y Escenarios
document.getElementById('list-container').addEventListener('scroll', function(e) {
    let el = e.target;
    // Si falta poco para llegar al final del scroll, cargamos más items
    if (el.scrollHeight - el.scrollTop - el.clientHeight < 150) {
        if (currentTab === 'anims') {
            if (currentCategory === null && document.getElementById('search-input').value.trim() === "") return; // No hay scroll infinito en el menu de categorías
            if (loadedCount < groupedAnimItems.length) {
                let nextCount = Math.min(loadedCount + animLimit, groupedAnimItems.length);
                renderAnimItems(loadedCount, nextCount);
                loadedCount = nextCount;
            }
        } else if (currentTab === 'scenarios') {
            if (loadedScenariosCount < filteredScenarios.length) {
                let nextCount = Math.min(loadedScenariosCount + animLimit, filteredScenarios.length);
                renderScenarioItems(loadedScenariosCount, nextCount);
                loadedScenariosCount = nextCount;
            }
        }
    }
});

// Reproducir animación estándar
function playAnim(dict, name, upperOnly = false) {
    fetch(`https://${GetParentResourceName()}/playAnim`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ dict: dict, name: name, upperOnly: upperOnly })
    });
}

// Reproducir escenario
function playScenario(name) {
    fetch(`https://${GetParentResourceName()}/playScenario`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name })
    });
}

// Reproducir Kit Emote
function playEmote(name, category) {
    fetch(`https://${GetParentResourceName()}/playEmote`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name, category: category })
    });
}

// Detener cualquier acción actual
function stopAction() {
    fetch(`https://${GetParentResourceName()}/stopAction`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// Reproducir animación manual (Libre)
function playCustomAnim() {
    let dict = document.getElementById('custom-dict').value.trim();
    let name = document.getElementById('custom-name').value.trim();
    let upperOnly = document.getElementById('custom-upper').checked;
    
    if (dict === "" || name === "") {
        return;
    }
    
    playAnim(dict, name, upperOnly);
}

// Arrastre del ratón para rotar el personaje (capturado fuera del sidebar)
let isDragging = false;
let startX = 0;

document.addEventListener('mousedown', function(e) {
    let sidebar = document.getElementById('sidebar-container');
    if (sidebar && !sidebar.contains(e.target)) {
        isDragging = true;
        startX = e.clientX;
    }
});

document.addEventListener('mousemove', function(e) {
    if (isDragging) {
        let deltaX = e.clientX - startX;
        startX = e.clientX;
        
        let rotationFactor = 0.55; // Sensibilidad de rotación súper suave
        let rotationDelta = deltaX * rotationFactor;
        
        fetch(`https://${GetParentResourceName()}/rotatePlayer`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ delta: rotationDelta })
        });
    }
});

document.addEventListener('mouseup', function() {
    isDragging = false;
});

function goBackToCategories() {
    currentCategory = null;
    renderList();
}

function updateZoom(value) {
    fetch(`https://${GetParentResourceName()}/changeZoom`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ distance: parseFloat(value) })
    });
}

// Función para embellecer y traducir dinámicamente escenarios a nombres legibles
function prettifyScenarioName(name, defaultLabel) {
    let prefix = "";
    let upperName = name.toUpperCase();
    if (upperName.startsWith("WORLD_CAMP_")) prefix = "🏕️ ";
    else if (upperName.startsWith("WORLD_ANIMAL_")) prefix = "🐾 ";
    else if (upperName.startsWith("PROP_")) prefix = "📦 ";
    else prefix = "🚶 ";

    if (currentLanguage !== 'es') {
        return prefix + defaultLabel;
    }
    
    const translations = {
        "SMOKE": "Fumar",
        "SMOKE_CIGAR": "Fumar Puro",
        "SMOKE_CIGARETTE": "Fumar Cigarrillo",
        "DRINK": "Beber",
        "DRINK_WHISKEY": "Beber Whiskey",
        "DRINK_BEER": "Beber Cerveza",
        "DRINK_WINE": "Beber Vino",
        "COFFEE": "Café",
        "COFFEE_KETTLE": "Hacer Café",
        "COFFEE_DRINK": "Beber Café",
        "SIT": "Sentarse",
        "SIT_GROUND": "Sentarse en el Suelo",
        "SIT_CHAIR": "Sentarse en Silla",
        "SIT_BENCH": "Sentarse en Banco",
        "SLEEP": "Dormir",
        "SLEEP_BED": "Dormir en Cama",
        "SLEEP_GROUND": "Dormir en el Suelo",
        "LEAN": "Apoyarse",
        "LEAN_WALL": "Apoyarse en la Pared",
        "LEAN_RAILING": "Apoyarse en Barandilla",
        "CLEAN": "Limpiar",
        "CLEAN_GLASS": "Limpiar Vaso",
        "CLEAN_TABLE": "Limpiar Mesa",
        "WRITE": "Escribir",
        "WRITE_NOTEBOOK": "Escribir en Cuaderno",
        "WASH": "Lavarse",
        "WASH_FACE": "Lavarse la Cara",
        "WARM": "Calentarse",
        "WARM_HANDS": "Calentar Manos (Fuego)",
        "MUSICIAN": "Tocar Instrumento",
        "FIDDLE": "Violín",
        "GUITAR": "Guitarra",
        "BANJO": "Banjo",
        "TRUMPET": "Trompeta",
        "BROOM": "Barrer con Escoba",
        "MOP": "Trapear el Suelo",
        "BADASS": "Parado Imponente (Badass)",
        "PEE": "Orinar / Mear",
        "KNITTING": "Tejer",
        "FISHING": "Pescar",
        "POCKET_MIRROR": "Mirarse al Espejo",
        "CAMP_FIRE": "Fogata de Campamento",
        "CRAFT": "Craftear",
        "CHOP": "Cortar Leña",
        "WOOD": "Madera",
        "ANIMAL": "Animal",
        "DOG": "Perro",
        "HORSE": "Caballo",
        "COW": "Vaca",
        "SHEEP": "Oveja",
        "BUFFALO": "Búfalo",
        "PIG": "Cerdo",
        "CAT": "Gato",
        "BURIAL": "Entierro",
        "PREACHER": "Predicador",
        "GRAVE": "Tumba",
        "MOURNING": "Llorar en Tumba",
        "BARKEEP": "Tabernero",
        "BARTENDER": "Barman",
        "CHAIR": "Silla",
        "BENCH": "Banco",
        "WOOD_CHOP": "Cortar Madera",
        "WINDMILL": "Molino de Viento",
        "SPECTATE": "Observar / Espectar",
        "STAND": "Estar Parado",
        "WALK": "Caminar",
        "CROUCH": "Agacharse",
        "INSPECT": "Inspeccionar",
        "LOOK": "Mirar",
        "WAIT": "Esperar",
        "WAITING": "Esperando",
        "BAR": "Barra",
        "TABLE": "Mesa",
        "STARE": "Mirar Fijo",
        "BOTTLE": "Botella",
        "BOX": "Caja",
        "POT": "Olla",
        "STEW": "Guiso",
        "EAT": "Comer",
        "SOBER": "Sobrio",
        "DRUNK": "Borracho",
        "PASSED_OUT": "Inconsciente / Desmayado",
        "PITCH_FORK": "Bieldo / Horca",
        "SHOVEL": "Palear con Pala",
        "HAMMER": "Martillar con Martillo",
        "SAW": "Aserrar con Serrucho",
        "AXE": "Hacha",
        "PICKAXE": "Picar con Pico",
        "MINING": "Minería",
        "GOLD": "Oro",
        "PANNING": "Cribar Oro",
        "SEARCH": "Buscar",
        "PLAYER": "Jugador"
    };
    
    let tokens = upperName.replace("WORLD_HUMAN_", "").replace("PROP_HUMAN_", "").replace("WORLD_CAMP_", "").replace("WORLD_ANIMAL_", "").replace("WORLD_", "").replace("PROP_", "").split('_');
    let translatedTokens = [];
    
    for (let token of tokens) {
        if (translations[token]) {
            translatedTokens.push(translations[token]);
        } else {
            translatedTokens.push(token.charAt(0).toUpperCase() + token.slice(1).toLowerCase());
        }
    }
    
    return prefix + translatedTokens.join(' ');
}

// Renderizado inicial al cargar la web
document.addEventListener('DOMContentLoaded', () => {
    loadLocale('es').then(() => {
        switchTab('anims');
    });
});
