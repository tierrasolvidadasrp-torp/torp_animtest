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
let currentSearchAnims = [];
let activePlayingElement = null;

// Función para resaltar visualmente la animación/escenario que se está reproduciendo
function highlightPlayingElement(element) {
    if (activePlayingElement) {
        activePlayingElement.classList.remove('playing');
    }
    if (element) {
        element.classList.add('playing');
        activePlayingElement = element;
    } else {
        activePlayingElement = null;
    }
}

// Función para copiar texto de manera robusta al portapapeles en CEF
function copyToClipboard(text) {
    let el = document.createElement('textarea');
    el.value = text;
    el.setAttribute('readonly', '');
    el.style.position = 'absolute';
    el.style.left = '-9999px';
    el.style.top = '-9999px';
    document.body.appendChild(el);
    el.select();
    el.setSelectionRange(0, 99999);
    
    let success = false;
    try {
        success = document.execCommand('copy');
    } catch (err) {
        console.error('Fallo al copiar texto al portapapeles:', err);
    }
    document.body.removeChild(el);
    return success;
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
    
    playBtn.onclick = (e) => {
        highlightPlayingElement(container);
        onPlayClick(e);
    };
    
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
    cat_carry: { icon: "💪", prefix: ["mech_carry", "mech_loco_m@generic@carry", "mech_loco_f@generic@carry", "mech_weapons_shortarms@base@sweep_rf_carry_ped", "mech_weapons_shortarms@loco@arthur@carry_ped", "mech_weapons_shortarms@loco@john@carry_ped"], keywords: ["carry", "carrying", "carried", "pickup", "putdown", "drop", "dump", "grab"] },
    cat_work: { icon: "💼", prefix: ["amb_work", "script_work"], keywords: ["work", "clean", "sweep", "chop", "dig"] },
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

    // 1b. Carga y Transporte
    for (let p of categoriesConfig.cat_carry.prefix) {
        if (lowerDict.startsWith(p)) return 'cat_carry';
    }
    for (let kw of categoriesConfig.cat_carry.keywords) {
        if (lowerDict.includes(kw)) return 'cat_carry';
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
    document.getElementById('tab-visuals').innerText = t('tab_visuals', '👁️ Visuales');
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
                // Restablecer posiciones de arrastre al abrir para asegurar la transición de entrada
                sidebar.style.left = "";
                sidebar.style.top = "";
                
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

// Cerrar el menú con Escape, Backspace o F9
document.addEventListener('keydown', function(event) {
    let isInput = event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA";
    
    // Prevenir el comportamiento por defecto de "Atrás" en CEF que destruye la página NUI y deja el mouse bloqueado
    if (event.key === "Backspace" && !isInput) {
        event.preventDefault();
        closeMenu();
    }
    
    if (event.key === "Escape" || (!isInput && event.key === "F9")) {
        closeMenu();
    }
});

function closeMenu() {
    // Desenfocar cualquier elemento activo (como el input de búsqueda) para liberar el foco del CEF
    if (document.activeElement && typeof document.activeElement.blur === 'function') {
        document.activeElement.blur();
    }
    highlightPlayingElement(null);
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
    let visualsContainer = document.getElementById('visuals-container');
    let searchBox = document.getElementById('search-box-container');
    
    if (tabId === 'custom') {
        listContainer.classList.add('hidden');
        customContainer.classList.remove('hidden');
        if (visualsContainer) visualsContainer.classList.add('hidden');
        searchBox.classList.add('hidden');
        document.getElementById('back-nav-container').classList.add('hidden');
    } else if (tabId === 'visuals') {
        listContainer.classList.add('hidden');
        customContainer.classList.add('hidden');
        if (visualsContainer) visualsContainer.classList.remove('hidden');
        searchBox.classList.add('hidden');
        document.getElementById('back-nav-container').classList.add('hidden');
        renderVisualsTab(); // Rellena la lista de efectos si es necesario
    } else {
        listContainer.classList.remove('hidden');
        customContainer.classList.add('hidden');
        if (visualsContainer) visualsContainer.classList.add('hidden');
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

let searchDebounceTimeout = null;

// Filtrar la lista actual basada en la búsqueda (Llamado en oninput en index.html)
function filterList() {
    let query = document.getElementById('search-input').value.trim();
    
    // Si el usuario borra todo, limpiamos y renderizamos al instante sin retardo para que se sienta reactivo
    if (query === "") {
        if (searchDebounceTimeout) clearTimeout(searchDebounceTimeout);
        executeActualFilter();
        return;
    }
    
    // Si es pestaña de animaciones y escribe solo 1 caracter, no realizamos la pesada búsqueda aún
    if (currentTab === 'anims' && query.length < 2) {
        return;
    }
    
    // Limpiar temporizador previo para evitar ejecuciones intermedias
    if (searchDebounceTimeout) {
        clearTimeout(searchDebounceTimeout);
    }
    
    // Debounce de 250ms para una fluidez óptima
    searchDebounceTimeout = setTimeout(() => {
        executeActualFilter();
    }, 250);
}

function executeActualFilter() {
    if (currentTab === 'anims' || currentTab === 'scenarios') {
        renderList(); // Re-renderizado paginado optimizado
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
    
    let queryWords = query.split(/\s+/).filter(w => w.length > 0);
    
    // Ocultar/Mostrar elementos según la coincidencia (Pestañas de Escenarios y Gestos)
    items.forEach(el => {
        let text = el.innerText.toLowerCase();
        let name = el.getAttribute('data-name') ? el.getAttribute('data-name').toLowerCase() : '';
        
        let matches = queryWords.every(word => text.includes(word) || name.includes(word));
        if (matches) {
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
        
        // 1. Caso A: Hay búsqueda de texto activa -> Hacemos bypass del menú de carpetas y mostramos lista plana de animaciones
        if (query !== "") {
            document.getElementById('back-nav-container').classList.add('hidden');
            
            let queryWords = query.split(/\s+/).filter(w => w.length > 0);
            let flatResults = [];
            Object.keys(AllAnimations).forEach(dict => {
                let subAnims = AllAnimations[dict] || [];
                let dictLower = dict.toLowerCase();
                
                subAnims.forEach(animName => {
                    let animLower = animName.toLowerCase();
                    let descActionName = getDescriptiveActionName(dict, animName).toLowerCase();
                    let matches = queryWords.every(word => dictLower.includes(word) || animLower.includes(word) || descActionName.includes(word));
                    if (matches) {
                        flatResults.push({ dict: dict, anim: animName });
                    }
                });
            });
            
            // Ordenar alfabéticamente por nombre de animación, luego por diccionario
            flatResults.sort((a, b) => {
                let comp = a.anim.localeCompare(b.anim);
                if (comp !== 0) return comp;
                return a.dict.localeCompare(b.dict);
            });
            
            currentSearchAnims = flatResults;
            
            // Cabecera Informativa de Búsqueda
            let header = document.createElement('div');
            header.className = 'category-header';
            header.innerText = `${t('search_placeholder', 'Buscar')}: ${flatResults.length} ${t('anims_found', 'animaciones encontradas')}`;
            container.appendChild(header);
            
            // Cargar primer bloque plano de animaciones
            loadedCount = Math.min(animLimit, flatResults.length);
            renderSearchFlatItems(0, loadedCount);
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
            let queryWords = query.split(/\s+/).filter(w => w.length > 0);
            filteredScenarios = Scenarios.filter(scen => {
                let scenNameLower = scen.name.toLowerCase();
                let prettyLabel = prettifyScenarioName(scen.name, scen.label).toLowerCase();
                return queryWords.every(word => scenNameLower.includes(word) || prettyLabel.includes(word));
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

// Genera un nombre de acción descriptivo en español o inglés para animaciones genéricas (como 'base' o 'idle')
function getDescriptiveActionName(dict, animName) {
    let lang = currentLanguage || 'es';
    let lowerDict = dict.toLowerCase();
    let lowerAnim = animName.toLowerCase();
    
    // Si la animación no es genérica (ej: "base", "idle", etc.), usamos su nombre original formateado
    let isGenericAnim = ["base", "idle", "loop", "action", "clip", "enter", "exit", "intro", "outro", "start", "end", "default", "trigger"].includes(lowerAnim);
    
    let action = "";
    let object = "";
    
    // 1. Identificar el Objeto
    if (lowerDict.includes("box")) {
        object = lang === 'es' ? "Caja" : "Box";
    } else if (lowerDict.includes("bale")) {
        object = lang === 'es' ? "Fardo" : "Bale";
    } else if (lowerDict.includes("lockbox")) {
        object = lang === 'es' ? "Caja Fuerte" : "Lockbox";
    } else if (lowerDict.includes("hay")) {
        object = lang === 'es' ? "Heno" : "Hay";
    } else if (lowerDict.includes("cotton")) {
        object = lang === 'es' ? "Algodón" : "Cotton";
    } else if (lowerDict.includes("lumber") || lowerDict.includes("wood") || lowerDict.includes("log")) {
        object = lang === 'es' ? "Tronco / Madera" : "Log / Wood";
    } else if (lowerDict.includes("body") || lowerDict.includes("corpse")) {
        object = lang === 'es' ? "Cuerpo / Cadáver" : "Body / Corpse";
    } else if (lowerDict.includes("chair")) {
        object = lang === 'es' ? "Silla" : "Chair";
    } else if (lowerDict.includes("bench")) {
        object = lang === 'es' ? "Banco" : "Bench";
    } else if (lowerDict.includes("ground")) {
        object = lang === 'es' ? "Suelo" : "Ground";
    }
    
    // 2. Identificar la Acción Principal
    if (lowerDict.includes("pickup") || lowerDict.includes("grab") || lowerDict.includes("lift")) {
        action = lang === 'es' ? "Levantando" : "Lifting";
    } else if (lowerDict.includes("putdown") || lowerDict.includes("put_down") || lowerDict.includes("drop") || lowerDict.includes("dump") || lowerDict.includes("place")) {
        action = lang === 'es' ? "Dejando en el suelo" : "Putting on the ground";
    } else if (lowerDict.includes("carry") || lowerDict.includes("carrying") || lowerDict.includes("carried")) {
        action = lang === 'es' ? "Cargando" : "Carrying";
    } else if (lowerDict.includes("ransack")) {
        action = lang === 'es' ? "Saqueando / Registrando" : "Ransacking / Searching";
    } else if (lowerDict.includes("open")) {
        action = lang === 'es' ? "Abriendo" : "Opening";
    } else if (lowerDict.includes("close")) {
        action = lang === 'es' ? "Cerrando" : "Closing";
    } else if (lowerDict.includes("sit")) {
        action = lang === 'es' ? "Sentado" : "Sitting";
    } else if (lowerDict.includes("sleep") || lowerDict.includes("rest")) {
        action = lang === 'es' ? "Descansando" : "Resting";
    } else if (lowerDict.includes("sweep") || lowerDict.includes("broom")) {
        action = lang === 'es' ? "Barriendo" : "Sweeping";
    } else if (lowerDict.includes("clean") || lowerDict.includes("wipe")) {
        action = lang === 'es' ? "Limpiando" : "Cleaning";
    } else if (lowerDict.includes("smoke")) {
        action = lang === 'es' ? "Fumando" : "Smoking";
    } else if (lowerDict.includes("drink")) {
        action = lang === 'es' ? "Bebiendo" : "Drinking";
    } else if (lowerDict.includes("eat")) {
        action = lang === 'es' ? "Comiendo" : "Eating";
    } else if (lowerDict.includes("chop")) {
        action = lang === 'es' ? "Cortando" : "Chopping";
    }
    
    // Si encontramos una frase hermosa basada en el diccionario, la retornamos
    if (action && object) {
        if (lang === 'es') {
            if (action === "Levantando") return `Levantando ${object}`;
            if (action === "Dejando en el suelo") return `Dejando ${object} en el suelo`;
            if (action === "Cargando") return `Cargando ${object}`;
            if (action === "Saqueando / Registrando") return `Registrando ${object}`;
            if (action === "Sentado") return `Sentado en ${object}`;
            return `${action} ${object}`;
        } else {
            if (action === "Putting on the ground") return `Putting ${object} on the ground`;
            if (action === "Sitting") return `Sitting on ${object}`;
            return `${action} ${object}`;
        }
    } else if (action) {
        return action;
    } else if (object) {
        return object;
    }
    
    // 3. Fallback inteligente: si no es una frase específica pero la animación es genérica
    if (isGenericAnim) {
        // Obtenemos la última palabra descriptiva del diccionario
        let parts = dict.split('@');
        let mainPart = parts[parts.length - 1] || parts[0];
        let subTokens = mainPart.split('_').filter(t => !["prop", "amb", "script", "cnv", "world", "human", "base", "idle"].includes(t));
        if (subTokens.length > 0) {
            let prettyTokens = subTokens.map(token => {
                let dictTrans = tokenTranslations[lang] || tokenTranslations['es'];
                let trans = dictTrans[token.toLowerCase()];
                return trans ? trans : (token.charAt(0).toUpperCase() + token.slice(1));
            });
            return prettyTokens.join(' ');
        }
    }
    
    // Si la animación no es genérica, la formateamos bien
    return animName.charAt(0).toUpperCase() + animName.slice(1).replace(/_/g, ' ');
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
                let prettyAnim = getDescriptiveActionName(item.dict, item.animName);
                let actionItem = createActionItem(
                    `▶️ ${prettyAnim}`,
                    `${item.dict} (${item.animName})`,
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

// Renderiza un rango específico de resultados planos de búsqueda de animaciones
function renderSearchFlatItems(start, end) {
    let container = document.getElementById('list-container');
    
    for (let i = start; i < end; i++) {
        let item = currentSearchAnims[i];
        if (!item) continue;
        
        let prettyDict = prettifyDictName(item.dict);
        let prettyAnim = getDescriptiveActionName(item.dict, item.anim);
        let actionItem = createActionItem(
            `▶️ ${prettyAnim}`,
            `${prettyDict} (${item.dict}, ${item.anim})`,
            () => playAnim(item.dict, item.anim),
            () => {
                copyToClipboard(`${item.dict}, ${item.anim}`);
            }
        );
        
        // Estilo premium para reproducción directa
        let playBtn = actionItem.querySelector('.action-play-btn');
        playBtn.style.borderLeft = '3px solid var(--gold)';
        playBtn.style.background = 'rgba(255, 255, 255, 0.02)';
        playBtn.style.padding = '10px 14px';
        playBtn.style.fontSize = '12.5px';
        
        container.appendChild(actionItem);
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
            let query = document.getElementById('search-input').value.trim();
            if (query !== "") {
                if (loadedCount < currentSearchAnims.length) {
                    let nextCount = Math.min(loadedCount + animLimit, currentSearchAnims.length);
                    renderSearchFlatItems(loadedCount, nextCount);
                    loadedCount = nextCount;
                }
            } else {
                if (currentCategory === null) return; // No hay scroll infinito en el menu de categorías
                if (loadedCount < groupedAnimItems.length) {
                    let nextCount = Math.min(loadedCount + animLimit, groupedAnimItems.length);
                    renderAnimItems(loadedCount, nextCount);
                    loadedCount = nextCount;
                }
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
    highlightPlayingElement(null);
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
    
    highlightPlayingElement(null);
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

    const fullTranslations = {
        "WORLD_HUMAN_BALE_PICKUP_1": "Recoger Fardo de Heno 1",
        "WORLD_HUMAN_BALE_PICKUP_2": "Recoger Fardo de Heno 2",
        "WORLD_HUMAN_BALE_PUT_DOWN_1": "Dejar Fardo de Heno 1",
        "WORLD_HUMAN_BALE_PUT_DOWN_2": "Dejar Fardo de Heno 2",
        "WORLD_HUMAN_BOX_PICKUP_1": "Recoger Caja 1",
        "WORLD_HUMAN_BOX_PICKUP_2": "Recoger Caja 2",
        "WORLD_HUMAN_BOX_PICKUP_3": "Recoger Caja 3",
        "WORLD_HUMAN_BOX_PUT_DOWN_1": "Dejar Caja 1",
        "WORLD_HUMAN_BOX_PUT_DOWN_2": "Dejar Caja 2",
        "WORLD_HUMAN_BOX_PUT_DOWN_3": "Dejar Caja 3",
        "WORLD_HUMAN_PITCH_HAY_SCOOP": "Palear Heno (Recoger)",
        "WORLD_HUMAN_PITCH_HAY_SCOOP_WITH_HAYPILE": "Palear Heno desde Pila",
        "WORLD_HUMAN_PITCH_HAY_SPREAD": "Esparcir Heno",
        "WORLD_HUMAN_COTTONBALE_PICKUP_1": "Recoger Fardo de Algodón 1",
        "WORLD_HUMAN_COTTONBALE_PICKUP_2": "Recoger Fardo de Algodón 2",
        "WORLD_HUMAN_COTTONBOX_PICKUP_1_RAW": "Recoger Caja de Algodón en Bruto 1",
        "WORLD_HUMAN_COTTONBOX_PICKUP_2_RAW": "Recoger Caja de Algodón en Bruto 2",
        "WORLD_HUMAN_COTTONBOX_PICKUP_3_RAW": "Recoger Caja de Algodón en Bruto 3",
        "WORLD_HUMAN_COTTONBOX_PICKUP_1_GINNED": "Recoger Caja de Algodón Limpio 1",
        "WORLD_HUMAN_COTTONBOX_PICKUP_2_GINNED": "Recoger Caja de Algodón Limpio 2",
        "WORLD_HUMAN_COTTONBOX_PICKUP_3_GINNED": "Recoger Caja de Algodón Limpio 3",
        "WORLD_HUMAN_COTTONBOX_DUMP": "Vaciar Caja de Algodón",
        "WORLD_PLAYER_CHORES_BALE_PICKUP_1": "Tarea: Recoger Fardo 1",
        "WORLD_PLAYER_CHORES_BALE_PUT_DOWN_1": "Tarea: Dejar Fardo 1",
        "WORLD_PLAYER_CHORES_VEHICLE_BOX_LOAD": "Tarea: Cargar Caja en Vehículo"
    };

    if (fullTranslations[upperName]) {
        return prefix + fullTranslations[upperName];
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
        "PLAYER": "Jugador",
        "BALE": "Fardo",
        "COTTONBALE": "Fardo de Algodón",
        "COTTONBOX": "Caja de Algodón",
        "PICKUP": "Recoger",
        "PUT": "Dejar / Poner",
        "DOWN": "Abajo",
        "LOAD": "Cargar",
        "UNLOAD": "Descargar",
        "PITCH": "Palear / Esparcir",
        "HAY": "Heno",
        "HAYPILE": "Pila de Heno",
        "SCOOP": "Palear",
        "SPREAD": "Esparcir",
        "CARRYING": "Cargando",
        "CHORES": "Tareas",
        "LUMBER": "Madera / Tronco"
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

// ============================================================================
// 👁️ SECCIÓN VISUALES, TIMERS Y DESARROLLADORES
// ============================================================================

const animPostFXCategories = {
    'folder-focus': [
        { name: "DEADEYE", label: "🎯 Deadeye Clásico" },
        { name: "EagleEye", label: "🦅 Eagle Eye" },
        { name: "DeadeyeWithReverb", label: "🎯 Deadeye con Eco" }
    ],
    'folder-states': [
        { name: "PlayerDrunk01", label: "🍺 Borrachera" },
        { name: "PlayerHealthPoor", label: "❤️ Salud Crítica" },
        { name: "PlayerDrugsPoisonWell", label: "🧪 Envenenamiento" },
        { name: "PlayerWakeUpKnockout", label: "💤 Despertar Inconsciente" },
        { name: "CameraTransitionBlinkSick", label: "🤢 Parpadeo Enfermo" }
    ],
    'folder-cinematic': [
        { name: "death01", label: "💀 Pantalla de Muerte" },
        { name: "killCam", label: "🎬 Sepia (KillCam)" },
        { name: "PauseMenuIn", label: "🌫️ Fondo Desenfocado" },
        { name: "PhotoMode_FilterVintage01", label: "🎞️ Filtro Vintage" },
        { name: "CameraTransitionFlash", label: "📸 Destello de Cámara" },
        { name: "KingCastleRed", label: "🔴 Aura Roja" },
        { name: "KingCastleBlue", label: "🔵 Aura Azul" }
    ],
    'folder-chapters': [
        // --- CHAPTER INTROS (CINEMATIC TITLES) ---
        { name: "ChapterTitle_IntroCh01", label: "❄️ Cap 1: Entrada a Colter (Cinemático)" },
        { name: "ChapterTitle_IntroCh02", label: "⛰️ Cap 2: Entrada a Horseshoe Overlook (Cinemático)" },
        { name: "ChapterTitle_IntroCh03", label: "🏖️ Cap 3: Entrada a Clemens Point (Cinemático)" },
        { name: "ChapterTitle_IntroCh04", label: "🎭 Cap 4: Entrada a Saint Denis (Cinemático)" },
        { name: "ChapterTitle_IntroCh05", label: "🌴 Cap 5: Entrada a Guarma (Cinemático) 🌟" },
        { name: "ChapterTitle_IntroCh06", label: "🪵 Cap 6: Entrada a Beaver Hollow (Cinemático)" },
        { name: "ChapterTitle_IntroCh08Epi01", label: "🏡 Epíl 1: Entrada a Rancho Pronghorn (Cinemático)" },
        { name: "ChapterTitle_IntroCh09Epi02", label: "🏡 Epíl 2: Entrada a Beecher's Hope (Cinemático)" },

        // --- CHAPTER TITLE CARDS ---
        { name: "title_ch01_colter", label: "❄️ Cap 1: Colter (Título)" },
        { name: "title_ch02_horseshoeoverlook", label: "⛰️ Cap 2: Horseshoe Overlook (Título)" },
        { name: "Title_Ch03_ClemensPoint", label: "🏖️ Cap 3: Clemens Point (Título)" },
        { name: "title_ch04_saintdenis", label: "🎭 Cap 4: Saint Denis (Título)" },
        { name: "title_ch05_guarma", label: "🌴 Cap 5: Guarma (Título)" },
        { name: "title_ch06_beaverhollow", label: "🪵 Cap 6: Beaver Hollow (Título)" },
        { name: "title_ep01_pronghornranch", label: "🏡 Epíl 1: Rancho Pronghorn (Título)" },
        { name: "title_ep02_beechershope", label: "🏡 Epíl 2: Beecher's Hope (Título)" }
    ],
    'folder-timecards': [
        { name: "Title_Gen_FewHoursLater", label: "⏳ Carta: Unas horas más tarde..." },
        { name: "Title_Gen_daylater", label: "⏳ Carta: Un día más tarde..." },
        { name: "Title_Gen_coupledayslater", label: "⏳ Carta: Un par de días después..." },
        { name: "Title_Gen_FewDaysLater", label: "⏳ Carta: Unos días más tarde..." },
        { name: "Title_Gen_somedaysLater", label: "⏳ Carta: Algunos días después..." },
        { name: "Title_Gen_FewWeeksLater", label: "⏳ Carta: Unas semanas más tarde..." },
        { name: "Title_Gen_coupleweekslater", label: "⏳ Carta: Un par de semanas después..." },
        { name: "Title_Gen_FewMonthsLater", label: "⏳ Carta: Unos meses más tarde..." },
        { name: "Title_Gen_couplemonthslater", label: "⏳ Carta: Un par de meses después..." },
        { name: "Title_Gen_SomeMonthsLater", label: "⏳ Carta: Algunos meses después..." },
        { name: "Title_Gen_someyearsLater", label: "⏳ Carta: Unos años más tarde..." }
    ],
    'folder-cutscenes': [
        // --- INTROS & MAIN TITLES ---
        { name: "Title_GameIntro", label: "🎬 RDR2: Presentación General (Intro)" },
        { name: "Title_MP_RDROnline", label: "🎬 RDR Online: Título Oficial" },
        { name: "Cutscene_MpIntro", label: "🎞️ RDR2: Introducción Multijugador" },
        { name: "Cutscene_MP_LOM_INTRO", label: "🎞️ Intro: Oportunidades (Sisika)" },
        { name: "Title_MP_SisakaMale", label: "⛓️ Sisika: Intro Personaje Masculino" },
        { name: "Title_MP_SisakaFemale", label: "⛓️ Sisika: Intro Personaje Femenino" },
        { name: "Cutscene_MP_MoonshineIntro", label: "🥃 Licoristas: Intro Destilería" },
        { name: "Cutscene_MP_LOM_RHO", label: "🚂 Intro: Misiones en Rhodes" },
        { name: "Cutscene_MP_LOM_TRAIN", label: "🚂 Intro: Asalto al Tren (LOM)" },
        { name: "Cutscene_MP_LOM_IND", label: "🤠 Intro: Industrias (Misiones LOM)" },
        { name: "cutscene_mar6_train", label: "🚂 Intro: Asalto al Tren (Capítulo 6)" },

        // --- GAME ENDINGS & SPECIAL RIDES ---
        { name: "Mission_FIN1_RideGood", label: "🌅 Cabalgar Final: Alto Honor (Arthur)" },
        { name: "Mission_FIN1_RideBad", label: "💀 Cabalgar Final: Bajo Honor (Arthur)" },
        { name: "Mission_GNG0_Ride", label: "🐎 Cabalgar en Banda / Pandilla" },
        { name: "Mission_EndCredits", label: "📜 Créditos de Fin de Juego" },

        // --- LEGENDARY BOUNTIES ---
        { name: "Cutscene_MP_LegBounty_Barbarella", label: "💃 Fugitiva Leyenda: Barbarella" },
        { name: "Cutscene_MP_LegBounty_Cecil", label: "🔥 Fugitivo Leyenda: Cecil C." },
        { name: "Cutscene_MP_LegBounty_EttaDoyle", label: "👠 Fugitiva Leyenda: Etta Doyle" },
        { name: "Cutscene_MP_LegBounty_OwlHoot", label: "🦉 Fugitivos Leyenda: Owl Hoot" },
        { name: "Cutscene_MP_LegBounty_PhilipCarlier", label: "🐊 Fugitivo Leyenda: Philip Carlier" },
        { name: "Cutscene_MP_LegBounty_RedBenClempson", label: "🚂 Fugitivo Leyenda: Red Ben" },
        { name: "Cutscene_MP_LegBounty_Sergio", label: "🎖️ Fugitivo Leyenda: Sergio" },
        { name: "Cutscene_MP_LegBounty_TobinWinfield", label: "💰 Fugitivo Leyenda: Tobin" },
        { name: "Cutscene_MP_LegBounty_YukonNik", label: "🐻 Fugitivo Leyenda: Yukon Nik" },
        { name: "Cutscene_MP_LegBounty_WolfMan", label: "🐺 Fugitivo Leyenda: Wolf Man" },

        // --- MISC / FAIL SCREENS ---
        { name: "MissionChoice", label: "⚖️ Transición: Decisión Crítica" },
        { name: "MissionFail01", label: "❌ Misión Fallida: Modo Historia" },
        { name: "DeathFailMP01", label: "💀 Misión Fallida: Red Dead Online" }
    ],
    'folder-special': [
        // --- ARTHUR ILLNESS & SPECIAL VISIONS ---
        { name: "PlayerSickDoctorsOpinion", label: "🤢 Arthur: Diagnóstico de Tuberculosis" },
        { name: "PlayerSickDoctorsOpinionOutGood", label: "🌅 Arthur: Tuberculosis (Buen Honor)" },
        { name: "PlayerSickDoctorsOpinionOutBad", label: "💀 Arthur: Tuberculosis (Mal Honor)" },
        { name: "PlayerWakeUpAberdeen", label: "🐷 Aberdeen: Despertar en la Fosa" },
        { name: "PlayerDrunkAberdeen", label: "🐷 Aberdeen: Borrachera Especial" },

        // --- DEHYDRATION / BEACH ENTRANCE ---
        { name: "PlayerHealthPoorGuarma", label: "🌴 Guarma: Deshidratación y Fiebre 🌟" },
        { name: "PlayerHealthPoorCS", label: "❤️ Arthur: Salud Crítica (Cinemática)" },
        { name: "PlayerHealthPoorMOB3", label: "❤️ Arthur: Salud Crítica (Misión MOB3)" },

        // --- SPIRIT ANIMALS ---
        { name: "Spirit_Buck07_GUA2", label: "🦌 Ciervo Espiritual: Arthur (Visión Especial)" },
        { name: "Spirit_Buck06_FIN1", label: "🦌 Ciervo Espiritual: Arthur (Destino Final)" },
        { name: "Spirit_Coyote07_GUA2", label: "🐺 Coyote Espiritual: Arthur (Visión Especial)" },
        { name: "Spirit_Coyote06_FIN1", label: "🐺 Coyote Espiritual: Arthur (Destino Final)" }
    ]
};

function renderVisualsTab() {
    // Llenar cada carpeta dinámicamente
    for (let catId in animPostFXCategories) {
        let folder = document.getElementById(catId);
        if (!folder || folder.children.length > 0) continue; // Ya cargada
        
        animPostFXCategories[catId].forEach(effect => {
            let item = document.createElement('div');
            item.className = 'effect-item';
            item.style.display = 'flex';
            item.style.alignItems = 'center';
            item.style.justifyContent = 'space-between';
            item.style.padding = '6px 8px';
            item.style.background = 'rgba(255,255,255,0.02)';
            item.style.border = '1px solid rgba(255,255,255,0.04)';
            item.style.borderRadius = '5px';
            item.style.marginBottom = '4px';
            
            let labelSpan = document.createElement('span');
            labelSpan.innerText = effect.label;
            labelSpan.style.fontSize = '11.5px';
            labelSpan.style.color = '#fff';
            labelSpan.title = effect.name;
            
            let btnGroup = document.createElement('div');
            btnGroup.style.display = 'flex';
            btnGroup.style.gap = '4px';
            btnGroup.style.alignItems = 'center';
            
            let playBtn = document.createElement('button');
            playBtn.className = 'effect-btn play';
            playBtn.innerHTML = '▶️';
            playBtn.onclick = () => playPostFX(effect.name);
            
            let stopBtn = document.createElement('button');
            stopBtn.className = 'effect-btn stop';
            stopBtn.innerHTML = '⏹️';
            stopBtn.onclick = () => stopPostFX(effect.name);
            
            let copyBtn = document.createElement('button');
            copyBtn.className = 'copy-btn';
            copyBtn.innerHTML = '📋';
            copyBtn.style.fontSize = '11px';
            copyBtn.onclick = () => {
                copyToClipboard(`AnimpostfxPlay("${effect.name}")`);
                copyBtn.innerHTML = '✔️';
                setTimeout(() => { copyBtn.innerHTML = '📋'; }, 1000);
            };
            
            btnGroup.appendChild(playBtn);
            btnGroup.appendChild(stopBtn);
            btnGroup.appendChild(copyBtn);
            
            item.appendChild(labelSpan);
            item.appendChild(btnGroup);
            folder.appendChild(item);
        });
    }
}

// Control de Acordeones
function toggleFolder(folderId) {
    let content = document.getElementById(folderId);
    let wrapper = document.getElementById(folderId + '-wrapper');
    if (content && wrapper) {
        let isOpen = content.classList.contains('open-content');
        if (isOpen) {
            content.classList.remove('open-content');
            wrapper.classList.remove('open');
        } else {
            content.classList.add('open-content');
            wrapper.classList.add('open');
        }
    }
}

// NUI Fetches de PostFX
function playPostFX(effectName) {
    fetch(`https://${GetParentResourceName()}/playPostFX`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ effect: effectName })
    });
}

function stopPostFX(effectName) {
    fetch(`https://${GetParentResourceName()}/stopPostFX`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ effect: effectName })
    });
}

function stopAllPostFX() {
    fetch(`https://${GetParentResourceName()}/stopAllPostFX`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// Leyes y Wanted
let wantedActive = false;
function toggleWanted(active) {
    wantedActive = active;
    let reason = document.getElementById('wanted-reason').value;
    fetch(`https://${GetParentResourceName()}/testWanted`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: active, reason: reason })
    });
}

// Banners y Shards
function updateShardDurVal(val) {
    document.getElementById('shard-dur-val').innerText = (val / 1000).toFixed(1) + 's';
}

function triggerTestShard(type) {
    let title = document.getElementById('shard-title').value;
    let subtitle = document.getElementById('shard-subtitle').value;
    let duration = document.getElementById('shard-duration').value;
    
    fetch(`https://${GetParentResourceName()}/testShard`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            type: type,
            title: title,
            subtitle: subtitle,
            duration: duration
        })
    });
}

// Helper Text Fields
function triggerHelperText(active) {
    let fields = [];
    if (active) {
        fields.push({ label: document.getElementById('helper-lbl-1').value, value: document.getElementById('helper-val-1').value });
        fields.push({ label: document.getElementById('helper-lbl-2').value, value: document.getElementById('helper-val-2').value });
    }
    fetch(`https://${GetParentResourceName()}/testHelperText`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: active, fields: fields })
    });
}

// Countdown Timer
function updateCountdownDurVal(val) {
    document.getElementById('countdown-dur-val').innerText = val + 's';
}

function triggerCountdown(active) {
    let duration = document.getElementById('countdown-duration').value;
    fetch(`https://${GetParentResourceName()}/testCountdown`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: active, duration: duration })
    });
}

// Passive Icon
function triggerPassiveIcon(active) {
    fetch(`https://${GetParentResourceName()}/testPassiveIcon`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ active: active })
    });
}

// UI Apps
function triggerUiApp(name, active) {
    fetch(`https://${GetParentResourceName()}/testUiApp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name, active: active })
    });
}

function updateUiAppSnippet(val) {
    document.getElementById('uiapp-snippet').innerText = `LaunchUiappByHash(joaat("${val}"))`;
}

function triggerSelectedUiApp(active) {
    let select = document.getElementById('uiapp-select');
    let val = select.value;
    triggerUiApp(val, active);
}

// Utilidades del Portapapeles
function copySnippetText(elementId) {
    let text = document.getElementById(elementId).innerText;
    copyToClipboard(text);
    showCopyFeedback(elementId);
}

function showCopyFeedback(elementId) {
    let box = document.getElementById(elementId).parentElement;
    let btn = box.querySelector('.copy-btn');
    let oldHTML = btn.innerHTML;
    btn.innerHTML = '✔️';
    btn.classList.add('copied');
    setTimeout(() => {
        btn.innerHTML = oldHTML;
        btn.classList.remove('copied');
    }, 1500);
}

function copyShardSnippet() {
    let title = document.getElementById('shard-title').value;
    let subtitle = document.getElementById('shard-subtitle').value;
    let duration = document.getElementById('shard-duration').value;
    let code = `-- Shard de Tarea / Ubicación\nlocal d = DataView.ArrayBuffer(104)\nd:SetInt32(0, ${duration})\nlocal i = DataView.ArrayBuffer(64)\ni:SetInt64(8, CreateVarString(10, "LITERAL_STRING", "${title}"))\ni:SetInt64(16, CreateVarString(10, "LITERAL_STRING", "${subtitle}"))\nCitizen.InvokeNative(0xD05590C1AB38F068, d:Buffer(), i:Buffer(), true)`;
    copyToClipboard(code);
    showCopyFeedback('shard-snippet');
}

function copyHelperSnippet() {
    let lbl1 = document.getElementById('helper-lbl-1').value;
    let val1 = document.getElementById('helper-val-1').value;
    let lbl2 = document.getElementById('helper-lbl-2').value;
    let val2 = document.getElementById('helper-val-2').value;
    
    let code = `-- ==========================================================\n` +
               `-- REDM HUD HELPER FIELDS (helperTextfields)\n` +
               `-- ==========================================================\n` +
               `-- To make this HUD element work, you MUST create the data container\n` +
               `-- AND enable the HUD context (-66088566) EVERY FRAME inside a thread!\n\n` +
               `-- 1. Create the data binding container (Call this ONCE)\n` +
               `local helperRoot = DatabindingAddDataContainerFromPath("", "helperTextfields")\n` +
               `DatabindingAddDataString(helperRoot, "rawLabel0", "${lbl1}")\n` +
               `DatabindingAddDataString(helperRoot, "rawValue0", "${val1}")\n` +
               `DatabindingAddDataString(helperRoot, "rawLabel1", "${lbl2}")\n` +
               `DatabindingAddDataString(helperRoot, "rawValue1", "${val2}")\n\n` +
               `-- 2. Keep the HUD Context enabled every frame (Put this inside a thread)\n` +
               `Citizen.CreateThread(function()\n` +
               `    local isHudVisible = true -- Toggle this variable to show/hide the HUD\n` +
               `    while isHudVisible do\n` +
               `        -- Use _ENABLE_HUD_CONTEXT_THIS_FRAME (0xC9CAEAEEC1256E54) to keep it visible\n` +
               `        Citizen.InvokeNative(0xC9CAEAEEC1256E54, -66088566)\n` +
               `        Wait(0)\n` +
               `    end\n` +
               `end)`;
               
    copyToClipboard(code);
    showCopyFeedback('helper-snippet');
}

function copyCountdownSnippet() {
    let duration = document.getElementById('countdown-duration').value;
    let code = `-- Iniciar Barra de Countdown\nlocal c = DatabindingAddDataContainerFromPath("", "MPCountdown")\nlocal s = DatabindingAddDataString(c, "Timer", "${duration}")\nlocal b = DatabindingAddDataBool(c, "showTimer", true)`;
    copyToClipboard(code);
    showCopyFeedback('countdown-snippet');
}

function copyWantedSnippet() {
    let reason = document.getElementById('wanted-reason').value;
    let code = `-- Sistema de Búsqueda (Wanted) RDR2 estilo torp_weed\nlocal w = DatabindingAddDataContainerFromPath("", "wanted")\nlocal m = DatabindingAddDataContainer(w, "firstMessage")\nDatabindingAddDataString(m, "lowerRawText0", "${reason}")\nDatabindingAddDataBool(m, "showMessage", true)`;
    copyToClipboard(code);
    showCopyFeedback('wanted-snippet');
}

// Arrastrabilidad inmersiva de la barra lateral
function setupDraggableSidebar() {
    const sidebar = document.getElementById('sidebar-container');
    const header = document.querySelector('.header');
    if (!sidebar || !header) return;
    
    let isDragging = false;
    let startX, startY;
    let initialLeft, initialTop;
    
    header.addEventListener('mousedown', function(e) {
        // Evitar arrastrar si se hace clic en botones, inputs, etc.
        if (e.target.tagName === 'INPUT' || e.target.tagName === 'BUTTON' || e.target.closest('.tabs-nav') || e.target.closest('.search-box')) return;
        
        isDragging = true;
        sidebar.classList.add('no-transition');
        
        // Obtener la posición inicial exacta
        const rect = sidebar.getBoundingClientRect();
        initialLeft = rect.left;
        initialTop = rect.top;
        
        startX = e.clientX;
        startY = e.clientY;
        
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);
        
        header.style.cursor = 'grabbing';
    });
    
    function onMouseMove(e) {
        if (!isDragging) return;
        
        const deltaX = e.clientX - startX;
        const deltaY = e.clientY - startY;
        
        let newLeft = initialLeft + deltaX;
        let newTop = initialTop + deltaY;
        
        // Limitadores de pantalla inteligentes para evitar perder el menú
        const minLeft = -sidebar.offsetWidth + 80;
        const maxLeft = window.innerWidth - 80;
        const minTop = 0;
        const maxTop = window.innerHeight - 80;
        
        newLeft = Math.max(minLeft, Math.min(newLeft, maxLeft));
        newTop = Math.max(minTop, Math.min(newTop, maxTop));
        
        sidebar.style.left = `${newLeft}px`;
        sidebar.style.top = `${newTop}px`;
    }
    
    function onMouseUp() {
        if (!isDragging) return;
        isDragging = false;
        sidebar.classList.remove('no-transition');
        header.style.cursor = 'grab';
        
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
    }
}

// Renderizado inicial al cargar la web
document.addEventListener('DOMContentLoaded', () => {
    loadLocale('es').then(() => {
        switchTab('anims');
        setupDraggableSidebar();
        // Forzar el cierre de la interfaz y la desactivación del foco NUI / ratón al primer inicio o reinicio del script
        setTimeout(() => {
            closeMenu();
        }, 100);
    });
});
