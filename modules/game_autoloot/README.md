# Auto Loot System - Naruto Server

## 🎯 Funkcje

### 4 Tryby Zbierania:
1. **Mode 1** - Wszystko oprócz food (🔹)
2. **Mode 2** - Wszystko + food (🔸)
3. **Mode 3** - Tylko food (🍖)
4. **Mode 4** - Wyłączony (⛔)

### Blacklista:
- Możliwość wykluczenia do 30 itemów
- Przycisk ON/OFF do aktywacji blacklisty
- Dynamiczne dodawanie/usuwanie itemów
- Synchronizacja z serwerem

## 🎮 Sterowanie

### Interfejs OTClient:
- **Ctrl+L** - Otwórz/zamknij okno Auto Loot
- **Przycisk w górnym menu** - Toggle okna

### Komendy serwera:
```
!autoloot - Wyświetl pomoc
!autoloot mode,<1-4> - Zmień tryb
!autoloot blacklist - Otwórz edytor blacklisty
!autoloot blacklist_toggle,<0/1> - Włącz/wyłącz blacklistę
!autoloot status - Pokaż aktualny status
!autoloot add,<item> - Dodaj item do listy (legacy)
!autoloot remove,<item> - Usuń item z listy (legacy)
!autoloot clear - Wyczyść listę (legacy)
!autoloot show - Pokaż listę (legacy)
```

## 💎 Design

### Kolory:
- **Tło główne**: #1e1e2e (ciemny fiolet)
- **Panele**: #2c2c3e (jaśniejszy fiolet)
- **Nagłówki**: #16161e (bardzo ciemny)
- **Mode 1**: #3498db (niebieski)
- **Mode 2**: #2ecc71 (zielony)
- **Mode 3**: #f39c12 (pomarańczowy)
- **Mode 4**: #95a5a6 (szary)
- **Blacklist ON**: #2ecc71 (zielony)
- **Blacklist OFF**: #95a5a6 (szary)
- **Przycisk Save**: #27ae60 (zielony)
- **Przycisk Clear**: #c0392b (czerwony)

### Features:
- Smooth animations
- Hover effects
- Modern flat design
- Responsive layout
- Icons i emoji dla lepszej czytelności

## 📝 Notatki

- System automatycznie wykrywa czy item to food (ITEM_GROUP_FOOD)
- Blacklista działa tylko gdy jest włączona (checkbox ON)
- Currency items (gold) automatycznie trafiają do banku
- System cache dla lepszej wydajności
- Pełna synchronizacja client-server

## 🔧 Instalacja

1. **OTClient**: Moduł `game_autoloot` jest już zainstalowany
2. **Server**: Skrypt `small_autoloot.lua` w `data/scripts/`
3. **Restart**: Zrestartuj klienta i serwer

## 🎨 Customizacja

Możesz edytować kolory w pliku `autoloot.otui`:
- Zmień `background-color` dla innych kolorów tła
- Zmień `color` dla kolorów tekstu
- Dostosuj `height` i `width` paneli

Enjoy! 🎉
