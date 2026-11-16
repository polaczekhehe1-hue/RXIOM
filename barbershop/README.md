# +1 Barber Shop

Gra „+1” na Robloxie: masz własny salon fryzjerski, golisz klientów, a każdy zgolony włos to **+1**. Zarobione pieniądze wydajesz na ulepszenia salonu, a rebirth resetuje postęp w zamian za stały mnożnik. Projekt synchronizuje się ze Studio przez Rojo.

## Uruchomienie

1. W tym folderze uruchom `rokit install` (Rojo 7.7.1).
2. Zainstaluj plugin Rojo w Studio: `rojo plugin install`.
3. Uruchom `rojo serve` i połącz Studio przez plugin, albo zbuduj plik: `rojo build -o BarberShop.rbxl`.
4. Żeby postęp się zapisywał w Studio, włącz *Game Settings → Security → Enable Studio Access to API Services*. Bez tego gra działa, tylko bez zapisu.

## Rozgrywka

- Każdy gracz dostaje jeden z 6 salonów wokół placu, z szyldem podpisanym jego nickiem.
- Klienci sami przychodzą i siadają w fotelach. Podejdź do klienta i naciśnij **E** — kamera robi zbliżenie na jego głowę.
- Przytrzymaj LPM (albo palec) i jedź po włosach. Każdy woksel to +1 × ulepszenia × rebirth. Za ogolenie wszystkich włosów dostajesz napiwek.
- Głowę obracasz klawiszami **A/D**, strzałkami albo przyciskami ◀ ▶. Wychodzisz przez **Q** albo przycisk „Wyjdź”.

Ulepszenia (`src/shared/Config.luau`): Maszynka (+1 za włos), Fotele (do 6 stanowisk), Szeroka maszynka (kilka włosów naraz), Wystrój (5 poziomów dekoracji, częstsi klienci i większe napiwki), Bujne fryzury (więcej włosów) i Pomocnik (goli za ciebie).

## Struktura

- `src/server`: mapa (`World`), salon z klocków (`ShopBuilder`), klienci z wokselowymi włosami (`Customer`), logika i walidacja golenia (`ShopService`), zapis danych (`PlayerData`).
- `src/client`: tryb strzyżenia z kamerą (`ShaveController`) i UI w stylu kafelków (`UI/`).
- `src/shared`: balans (`Config`) i formatowanie liczb.

Cała grafika powstaje z klocków (studsy, woksele, low poly), a UI jest rysowane z ramek — bez zewnętrznych assetów.
