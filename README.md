# RXIOM

Gra typu Trading na Roblox, synchronizowana do Studio przez [Rojo](https://rojo.space).

## Start

1. Zainstaluj [Rokit](https://github.com/rojo-rbx/rokit), potem w katalogu repo: `rokit install`
2. Zainstaluj plugin Rojo w Studio: `rojo plugin install`
3. Uruchom serwer: `rojo serve`, a w Studio kliknij **Connect** w pluginie Rojo.

Zbudowanie pliku miejsca bez Studio: `rojo build -o RXIOM.rbxl`

## Struktura

| Folder       | Trafia do                                   |
| ------------ | ------------------------------------------- |
| `src/server` | `ServerScriptService.Server`                |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared` | `ReplicatedStorage.Shared`                  |
