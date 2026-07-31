

# 🎨 pix-MCP

> **Para los que pueden imaginarlo pero no dibujarlo.**

![Moneda generada por IA en Pixelorama](coin.png)

pix-MCP es un servidor de [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) que conecta asistentes de IA (Claude, GPT, Gemini, etc.) con [Pixelorama](https://www.pixelorama.org/), el editor de arte pixelado gratuito y de código abierto.

Tú describes lo que quieres. La IA se encarga del resto: formas, colores, sombreado, capas, animaciones y sprites completos, dibujados en tiempo real dentro de Pixelorama.

---

## ✨ Dos formas de crear

### 🤖 Opción 1 — Describe lo que quieres y la IA lo dibuja
Conéctate a Claude o cualquier cliente MCP y describe tu sprite en lenguaje natural:
> *"Dibuja una moneda dorada con una estrella 3D y una sombra proyectada en un lienzo de 64x64"*

La IA calcula la geometría, el sombreado y los contornos, y luego lo dibuja píxel por píxel dentro de Pixelorama.

### 🖼️ Opción 2 — Importa cualquier imagen como arte pixelado
¿Ya tienes una imagen de referencia (generada por IA o dibujada a mano)? Impórtala directamente:
```bash
node docs/examples/import_universal_asset.js
```
El importador detecta automáticamente el fondo, lo elimina y transmite el activo con precisión de píxeles a Pixelorama con transparencia total.

---

## 🗂️ ¿Por dónde empezar?

| Si quieres… | Ve a |
|---|---|
| Instalar y conectar con Claude/Cursor | [Guía de inicio rápido](docs/getting-started.md) |
| Ejecutar manualmente un script de dibujo JS | [Guía de scripts personalizados](docs/getting-started.md#manual-scripts) |
| Importar una imagen existente a Pixelorama | [Guía de importación de imágenes](docs/getting-started.md#image-import) |
| Ver todas las herramientas disponibles | [Referencia de herramientas](docs/tool-reference.md) |
| Compilar o reparar el plugin de Pixelorama | [Configuración del plugin](docs/plugin-setup.md) |
| Crear un agente de IA que dibuje | [Playbook de dibujo con agentes](AGENTIC_DRAWING_PLAYBOOK.md) |
| Ver ejemplos prácticos | [docs/examples/](docs/examples/) |

---

## 🏗️ Arquitectura

```
AI Client (Claude / Cursor / any MCP client)
        │  MCP — JSON-RPC over stdio
        ▼
   pix-MCP Server  (TypeScript / Node.js)
        │  HTTP REST — localhost:7373
        ▼
   Pixelorama Bridge Plugin  (GDScript)
        │  ExtensionsApi v8
        ▼
   Pixelorama v1.1.10
```

---

## ⚡ Inicio rápido

### Requisitos previos
- [Node.js](https://nodejs.org/) ≥ 18
- [Pixelorama](https://www.pixelorama.org/) v1.1.10

### 1. Instalar el servidor MCP
```bash
git clone https://github.com/abidoo22/Pixelorama-MCP.git
cd Pixelorama-MCP/mcp-server
npm install && npm run build
```

### 2. Instalar el plugin de Pixelorama
1. Abre Pixelorama → **Editar → Preferencias → Extensiones**
2. Haz clic en **Añadir extensión** y selecciona `pixelorama-plugin/PixMcpBridge.pck`
3. Actívala y reinicia Pixelorama

### 3. Conectar Claude Desktop
Añade lo siguiente a `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "pix-mcp": {
      "command": "node",
      "args": ["/absolute/path/to/pix-MCP/mcp-server/dist/index.js"]
    }
  }
}
```

Luego pide a Claude: *"Crea un lienzo de 64×64 y dibuja una manzana roja brillante con sombra proyectada"*

---

## 🎮 Galería de ejemplos

| Sprite | Método | Script |
|---|---|---|
| 🪙 Moneda dorada | Dibujado por agente IA | `docs/examples/draw_coin.js` |
| 🥔 Patata | Dibujado por agente IA | `docs/examples/draw_potato.js` |
| 🍌 Plátano | Dibujado por agente IA | `docs/examples/draw_banana.js` |
| 🌲 Árbol | Dibujado por agente IA | `docs/examples/draw_tree.js` |
| 💪 Hombre musculoso | Importado desde imagen IA | `docs/examples/import_universal_asset.js` |
| Cualquier imagen | Importado desde imagen IA | `docs/examples/import_universal_asset.js` |

---

## 📖 Documentación

- [Inicio rápido](docs/getting-started.md) — Configuración, requisitos previos, integración de clientes e importación de imágenes
- [Referencia de herramientas](docs/tool-reference.md) — Más de 35 herramientas MCP con parámetros y formatos de retorno
- [Configuración del plugin](docs/plugin-setup.md) — Compilación del plugin GDScript y solución de problemas de cuarentena
- [Playbook de dibujo con agentes](AGENTIC_DRAWING_PLAYBOOK.md) — Matemáticas de sombreado, recetas de geometría y optimización por lotes para agentes de IA

---

## 🛠️ Desarrollo

```bash
cd mcp-server
npm install
npm run dev   # watch mode

# Test with MCP Inspector
npx @modelcontextprotocol/inspector node dist/index.js
```

---

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Lee [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar un PR.

## 📄 Licencia

[MIT](LICENSE) — explícate.

## 🙏 Créditos

- [Pixelorama](https://www.pixelorama.org/) por Orama Interactive
- [Model Context Protocol](https://modelcontextprotocol.io/) por Anthropic
