# Force of Will — Tabletop Simulator Plugin

A [Tabletop Simulator](https://www.tabletopsimulator.com/) plugin for playing **Force of Will (FoW)** online, with integrated deck import directly from [Force of Wind](https://www.forceofwind.online/).

Built by **Niebvelungen** and **Patrick Ogrenz** (FoW Judges).

---

## Features

- 🃏 Load and play Force of Will decks directly inside Tabletop Simulator
- 🔗 Direct deck import integration with [forceofwind.online](https://www.forceofwind.online/)
- 🖱️ In-game UI panel for easy deck loading without manual setup
- Automatic card image loading for a complete visual play experience

## Requirements

- [Tabletop Simulator](https://www.tabletopsimulator.com/) (available on Steam)
- A deck built and saved on [forceofwind.online](https://www.forceofwind.online/)

## Installation

1. Open **Tabletop Simulator**
2. Load or create a Force of Will game table
3. In the TTS scripting menu, import the contents of `FoW_Deck_Loader.lua` and `FoW_Deck_Loader.xml` into your game object's script and UI fields respectively
4. Save and reload the table

> For normal play the plugin is available on the Steam Workshop, simply subscribe and load it from there. https://steamcommunity.com/sharedfiles/filedetails/?id=3314023556

## How to Use

1. Once the table is loaded, the **Deck Loader panel** will appear in-game
2. Navigate to [forceofwind.online](https://www.forceofwind.online/), build or open your deck, and copy the deck URL or ID
3. Paste it into the Deck Loader input field and confirm
4. Your deck will be automatically spawned onto the table with all card images loaded

## File Overview

| File | Description |
|---|---|
| `FoW_Deck_Loader.lua` | Main plugin script — handles deck loading logic and card spawning |
| `FoW_Deck_Loader.xml` | In-game UI layout for the deck loader panel |
| `import.lua` | Import and parsing logic for Force of Wind deck data |
| `original.lua` | Original base script (kept for reference) |

## Contributing

Found a bug or want to add a feature? Issues and Pull Requests are welcome. If you're a FoW Judge or active community member and want to help maintain this, feel free to reach out.

## Credits

Developed by **Niebvelungen** and **Patrick Ogrenz**, both active Force of Will Judges and community members.

Deck data powered by [Force of Wind](https://www.forceofwind.online/).

---

*This is an unofficial fan project. Force of Will and all related assets are the property of Eye Spy Productions. This plugin is not affiliated with or endorsed by Tabletop Simulator or Krafton.*
