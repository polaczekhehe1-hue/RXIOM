# RXIOM

Gra typu Trading na Roblox wzorowana na [axiom.trade](https://axiom.trade), synchronizowana do Studio przez [Rojo](https://rojo.space).

## Start

1. Zainstaluj [Rokit](https://github.com/rojo-rbx/rokit), potem w katalogu repo: `rokit install`
2. Zainstaluj plugin Rojo w Studio: `rojo plugin install`
3. Uruchom serwer: `rojo serve`, a w Studio kliknij **Connect** w pluginie Rojo.

Zbudowanie pliku miejsca bez Studio: `rojo build -o RXIOM.rbxlx`

Zapis postępu (DataStore) działa w opublikowanej grze. W Studio trzeba włączyć
**Game Settings → Security → Enable Studio Access to API Services**; bez tego gracz dostaje tymczasowy profil, który nie jest zapisywany.

## Jak działa handel

- Każdy coin ma pulę płynności `x * y = k` (jak pump.fun). Kupno dodaje RXI do puli i podnosi cenę, sprzedaż ją obniża.
- Prowizja 1% od transakcji plus wybrany priority fee i tip.
- Serwer wykonuje wszystkie transakcje. Klient wysyła oczekiwany wynik, a serwer odrzuca transakcję, jeśli cena uciekła bardziej niż ustawiony slippage.
- Boty symulują innych traderów, więc ceny, wolumen i wykresy żyją także przy jednym graczu. Przy starcie serwer symuluje ostatnią godzinę historii.
- Zlecenia **Limit** wykonują się, gdy market cap dojdzie do celu. **Advanced Trading Strategy** dokłada do kupna take profit i stop loss.
- **Deposit** daje darmowe RXI co 5 minut.

Ustawienia ekonomii są w `src/shared/Config.luau`, a lista coinów w `src/shared/Coins.luau`.

## Struktura

| Folder                    | Trafia do                                   | Co zawiera                                       |
| ------------------------- | ------------------------------------------- | ------------------------------------------------ |
| `src/server`              | `ServerScriptService.Server`                | rynek, boty, dane graczy, obsługa transakcji     |
| `src/client/State`        | `StarterPlayerScripts.Client.State`         | stan rynku i portfela po stronie klienta, akcje  |
| `src/client/UI`           | `StarterPlayerScripts.Client.UI`            | interfejs: Discover, strona coina, Portfolio     |
| `src/shared`              | `ReplicatedStorage.Shared`                  | konfiguracja, coiny, matematyka puli, typy       |
