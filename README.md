# claude-shorts-windows

![claude-shorts header](claude-shorts-header.jpeg)

Creador interactivo de videos cortos a partir de videos largos, impulsado por [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Extrae clips verticales listos para viralizar usando Claude como orquestador inteligente, con subtítulos animados premium renderizados en Remotion.

> **Este es un fork adaptado a Windows** de [claude-shorts](https://github.com/AgriciDaniel/claude-shorts) de Agrici Daniel. Corre **nativo en Windows 10/11** (Git Bash + PowerShell), sin WSL: instalación en un solo paso, skill enlazada por junction (se actualiza con `git pull`) y correcciones de rutas MSYS, layout de venv y finales de línea.

## Cómo funciona

Claude Code te guía por un pipeline interactivo de 10 pasos:

1. **Preflight** — Valida el video de entrada, revisa espacio en disco, detecta GPU
2. **Transcripción** — Transcripción acelerada por GPU con timestamps por palabra (faster-whisper)
3. **Detección de contenido** — Clasifica automáticamente: talking-head, grabación de pantalla o podcast
4. **Análisis** — Claude lee el transcript completo y puntúa de 8 a 12 segmentos candidatos
5. **Presentación** — Muestra los candidatos en una tabla con puntajes, hooks y justificación
6. **Aprobación** — Eliges segmentos, ajustas los tiempos, seleccionas estilo de subtítulos y plataforma
7. **Ajuste de cortes** — Alinea los puntos de corte a límites de palabra, finales de oración y silencios
8. **Preparación** — Extrae los clips (FFmpeg stream copy) y calcula las coordenadas de reencuadre
9. **Render** — Remotion renderiza video vertical 1080x1920 con subtítulos animados
10. **Exportación** — Codificación optimizada por plataforma (YouTube Shorts, TikTok, Instagram Reels)

## Características

- **Puntuación de segmentos con Claude** — Rúbrica de 5 dimensiones (fuerza del hook, coherencia, emoción, densidad de valor, remate) con pesos. Sin heurísticas de palabras clave: Claude entiende arcos narrativos.
- **3 estilos de subtítulos** — Bold (MAYÚSCULAS, resaltado amarillo), Bounce (rebote con spring, colores rotativos), Clean (fade-in minimalista)
- **Seguimiento de cursor** — En grabaciones de pantalla, detecta el cursor por diferencia de frames y panea el recorte suavemente para seguirlo
- **Cortes conscientes del audio** — Nunca corta a media palabra ni a media oración. Extiende hasta finales naturales de oración y puntos de silencio.
- **Render con Remotion** — Render de una sola pasada basado en React con animaciones spring, resaltado karaoke por palabra, texto de hook y barras de progreso
- **Aceleración por GPU** — CUDA para transcripción, NVENC para exportación (con fallback limpio a CPU)

## Requisitos

Solo necesitas tres cosas — el resto (FFmpeg, jq, Python, Node.js) lo instala `setup.ps1` automáticamente con winget:

- **Windows 10/11**
- **[Git para Windows](https://git-scm.com/download/win)** (incluye Git Bash)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** (CLI)

GPU NVIDIA recomendada (transcripción CUDA + codificación NVENC); sin GPU funciona en CPU.

## Instalación

Abre una terminal (PowerShell) y pídele a Claude Code que lo haga todo:

```powershell
claude "Instala la skill claude-shorts-windows: clona https://github.com/Ivenaccip/claude-shorts-windows.git en mi carpeta de usuario y ejecuta su setup.ps1. Instala cualquier requisito que falte y si algo falla, resuélvelo."
```

Eso es todo. Claude clona el repo, corre el instalador y verifica que quedó funcionando. Al terminar tendrás la skill `/shorts` disponible.

<details>
<summary><b>Instalación manual (sin Claude Code de por medio)</b></summary>

```powershell
git clone https://github.com/Ivenaccip/claude-shorts-windows.git
cd claude-shorts-windows
powershell -ExecutionPolicy Bypass -File setup.ps1
```

Si `setup.ps1` instala requisitos nuevos (FFmpeg, Python, etc.), puede pedirte cerrar la terminal, abrir una nueva y volver a correrlo — el PATH nuevo solo aparece en terminales nuevas.

</details>

### Qué hace `setup.ps1`

- Detecta e **instala automáticamente** las dependencias que falten vía winget: FFmpeg, jq, Python 3.10 y Node.js LTS
- Crea un entorno virtual de Python en `%USERPROFILE%\.shorts-skill\` e instala dependencias **pinneadas** (`faster-whisper`, `mediapipe`, `numpy`, `opencv-python`)
- Instala PyTorch (variante CUDA si detecta `nvidia-smi`, CPU si no)
- Ejecuta `npm ci` en `remotion/` (solo cuando cambia el lockfile — reproducible e idempotente)
- Escribe la configuración central en `%APPDATA%\claude-shorts\env.json`
- Instala la skill como **junction**: `~/.claude/skills/shorts` → este repo

Es **idempotente**: puedes correrlo las veces que quieras sin romper nada.

### Actualizar

Como la skill es un enlace al repo (no una copia), actualizar es solo:

```bash
git pull
```

Si el `package-lock.json` o los `requirements.txt` cambiaron, vuelve a correr `setup.ps1` (detecta los cambios y solo reinstala lo necesario).

### Desinstalar

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

Borra solo el enlace de la skill y la configuración; el repo y el venv quedan intactos.

## Uso

En Claude Code, invoca la skill:

```
/shorts
```

Luego proporciona tu archivo de video cuando te lo pida. Claude va a:

1. Transcribir el video
2. Presentar los segmentos candidatos con su puntaje
3. Preguntarte qué segmentos renderizar, estilo de subtítulos y plataforma destino
4. Renderizar y exportar los shorts finales

### Ejemplo de interacción

```
Tú: /shorts C:\Videos\mi-charla.mp4
Claude: [Transcribe, detecta el tipo de contenido, puntúa segmentos]

| # | Tiempo        | Dur  | Puntaje | Hook                            |
|---|---------------|------|---------|---------------------------------|
| 1 | 04:22 - 05:01 | 39s  | 87      | "Nadie habla de esto..."        |
| 2 | 12:45 - 13:28 | 43s  | 82      | "Este es el framework exacto."  |
| 3 | 08:11 - 08:52 | 41s  | 79      | "Probé esto durante 6 meses."   |

Claude: ¿Qué segmentos? ¿Estilo de subtítulos? ¿Plataforma?
Tú: 1 y 3, estilo bounce, youtube

Claude: [Ajusta cortes, extrae clips, renderiza, exporta]
Salida: shorts/short_01_yt.mp4, shorts/short_03_yt.mp4
```

## Estructura del proyecto

```
claude-shorts-windows/
├── SKILL.md                           # Pipeline interactivo de 10 pasos (skill de Claude Code)
├── CLAUDE.md                          # Instrucciones a nivel de proyecto
├── setup.ps1                          # Instalador único e idempotente (Windows)
├── uninstall.ps1                      # Desinstalador (borra solo el enlace y la config)
│
├── scripts/
│   ├── transcribe.py                  # Transcripción GPU con faster-whisper
│   ├── detect_content.py              # Clasificador de tipo de contenido (MediaPipe)
│   ├── compute_reframe.py             # Seguimiento de rostro + cursor + recorte
│   ├── snap_boundaries.py             # Ajuste de cortes consciente del audio
│   ├── preflight.sh                   # Validación de entrada + espacio en disco
│   ├── detect_gpu.sh                  # Detección de NVENC (NVIDIA)
│   └── export.sh                      # Codificación FFmpeg por plataforma
│
├── remotion/
│   ├── package.json                   # Remotion v4 + React 19 + Zod
│   ├── render.mjs                     # Orquestador bundle-once-render-many
│   ├── remotion.config.ts
│   └── src/
│       ├── Root.tsx                   # Registro de composiciones
│       ├── ShortVideo.tsx             # Composición principal
│       ├── types.ts                   # Esquemas Zod para las props
│       ├── components/
│       │   ├── VideoFrame.tsx         # Video reencuadrado con paneo animado
│       │   ├── Captions.tsx           # Selector de estilo
│       │   ├── BoldCaptions.tsx       # MAYÚSCULAS bold, spring pop-in
│       │   ├── BounceCaptions.tsx     # Escala con rebote, colores vivos
│       │   ├── CleanCaptions.tsx      # Fade-in minimalista
│       │   ├── HookOverlay.tsx        # Texto de hook (primeros 3.5s)
│       │   └── ProgressBar.tsx        # Barra de progreso inferior
│       ├── hooks/
│       │   └── useCaptionPages.ts     # Páginas estilo TikTok (@remotion/captions)
│       └── styles/
│           ├── fonts.ts               # Declaraciones @font-face
│           └── theme.ts               # Paletas de color por estilo
│
└── references/
    ├── scoring-rubric.md              # Criterios de puntuación (5 dimensiones)
    ├── caption-styles.md              # Especificaciones visuales + configs de spring
    ├── platform-specs.md              # Codificación YouTube/TikTok/Instagram
    └── remotion-patterns.md           # Buenas prácticas de Remotion
```

## Estilos de subtítulos

| Estilo | Fuente | Animación | Ideal para |
|--------|--------|-----------|------------|
| **Bold** | Montserrat Bold | Spring pop-in, palabra activa en amarillo | Negocios, educación |
| **Bounce** | Bangers | Escala con rebote 70-120-100%, colores rotativos | Entretenimiento, energía |
| **Clean** | Inter Bold | Fade-in de opacidad, blanco + sombra | Profesional, entrevistas |

## Especificaciones de exportación por plataforma

| Plataforma | Códec | Bitrate | Audio |
|------------|-------|---------|-------|
| **YouTube Shorts** | H.264 High 4.2 | 12 Mbps | AAC 192k |
| **TikTok** | H.264 | CRF 18, -preset slow | AAC 128k |
| **Instagram Reels** | H.264 High 4.2 | 4.5 Mbps (máx 5000k) | AAC 128k |

## Estrategias por tipo de contenido

| Tipo de contenido | Estrategia de reencuadre | Zoom |
|-------------------|--------------------------|------|
| **Talking-head** | Recorte centrado con seguimiento de rostro (MediaPipe) | 9:16 exacto |
| **Grabación de pantalla** | Paneo con seguimiento de cursor y zoom moderado | 55% del ancho original |
| **Podcast** | Seguimiento del hablante dominante | 9:16 exacto |

## Dependencias

### Python (instaladas por `setup.ps1`)
- [faster-whisper](https://github.com/SYSTRAN/faster-whisper) — Whisper acelerado por GPU
- [mediapipe](https://mediapipe.dev/) — Detección de rostros para clasificación y reencuadre
- [numpy](https://numpy.org/) — Operaciones de arrays para suavizar el seguimiento de cursor
- [opencv-python](https://opencv.org/) — Diferencia de frames para detección de cursor

### Node.js (instaladas por `setup.ps1`)
- [Remotion v4](https://remotion.dev/) — Render de video basado en React
- [@remotion/captions](https://remotion.dev/docs/captions) — Subtítulos por palabra estilo TikTok
- [React 19](https://react.dev/) — Framework de componentes
- [Zod](https://zod.dev/) — Validación de tipos en runtime para las props

### Fuentes

Las fuentes de los subtítulos vienen de Google Fonts bajo la [SIL Open Font License](remotion/public/fonts/OFL.txt):
- Montserrat Bold (estilo Bold)
- Bangers Regular (estilo Bounce)
- Inter Bold (estilo Clean)

### Sistema
- [FFmpeg](https://ffmpeg.org/) — Extracción de audio, corte de segmentos, codificación de exportación
- [jq](https://jqlang.github.io/jq/) — Procesamiento de JSON en scripts de shell

## Cómo funciona la puntuación de segmentos

Claude puntúa cada candidato en 5 dimensiones con pesos:

| Dimensión | Peso | Qué busca Claude |
|-----------|------|------------------|
| Fuerza del hook | 0.30 | Afirmaciones audaces, brechas de curiosidad, promesas de valor, quiebres de patrón |
| Coherencia independiente | 0.25 | Se entiende completo sin contexto del resto del video |
| Intensidad emocional | 0.20 | Opiniones fuertes, revelaciones sorpresa, humor, pasión |
| Densidad de valor | 0.15 | Insights accionables, datos, frameworks por segundo |
| Calidad del remate | 0.10 | Conclusión satisfactoria: punchline, revelación, llamado a la acción |

Puntaje final = suma ponderada, escala 0-100. Umbral mínimo: 60.

## Soporte

- **Issues**: [GitHub Issues](https://github.com/Ivenaccip/claude-shorts-windows/issues)
- **Proyecto original** (macOS/Linux): [AgriciDaniel/claude-shorts](https://github.com/AgriciDaniel/claude-shorts)

## Licencia

[MIT](LICENSE)

---

## Créditos

Proyecto original creado por [Agrici Daniel](https://agricidaniel.com/about) — AI Workflow Architect.

- [Blog](https://agricidaniel.com/blog) — Análisis a fondo sobre automatización de marketing con IA
- [AI Marketing Hub](https://www.skool.com/ai-marketing-hub) — Comunidad gratuita, más de 2,800 miembros
- [YouTube](https://www.youtube.com/@AgriciDaniel) — Tutoriales y demos
- [Todas sus herramientas open-source](https://github.com/AgriciDaniel)

Adaptación a Windows por [Ivenaccip](https://github.com/Ivenaccip).
