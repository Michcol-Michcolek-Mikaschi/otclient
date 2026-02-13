# Loot Stats v1.3.0 - OTClient Redemption Update

## Aktualizacja dla OTClient - Redemption (2025)

### 🎉 Zmiany:

#### ✅ Architektura
- **Controller Pattern**: Moduł używa teraz nowoczesnego wzorca Controller z automatycznym zarządzaniem cyklem życia
- **Bezpieczne czyszczenie**: Wszystkie eventy i widgety są poprawnie czyszczone przy zamykaniu

#### ✅ Interfejs Użytkownika
- **Nowy system opcji**: Integracja z nowym menu opcji (Misc. > Loot Stats)
- **Nowe API przycisków**: Użycie `addRightGameToggleButton` zamiast starego API
- **Poprawiony styl**: Nowoczesne kolory, cienie i efekty hover
- **Lepsze zarządzanie oknami**: Okna poprawnie się podnoszą i fokusują

#### ✅ Poprawki Błędów
- **Bezpieczne sprawdzanie null**: Dodano sprawdzanie istnienia widgetów przed operacjami
- **Poprawione ścieżki**: Ikony ładowane ze ścieżki `/mods/loot_stats/`
- **Globalne zmienne**: Poprawne zarządzanie `saveOverWindow`
- **Marginy i odstępy**: Dostosowane do nowego layoutu

### 📋 Wymagania:
- OTClient - Redemption (wersja 2024+)
- Moduły: `game_interface`, `client_options`
- Pliki items.otb i items.xml dla twojej wersji protokołu

### 🚀 Instalacja:
1. Skopiuj folder `loot_stats` do katalogu `mods/`
2. Moduł załaduje się automatycznie
3. Ustawienia: **Opcje > Misc. > Loot Stats**
4. Przycisk okna: Prawy górny róg interfejsu

### 🔧 Funkcje:
- Statystyki zabitych potworów
- Loot ze wszystkich potworów
- Loot z konkretnego typu potwora
- Wyświetlanie lootu na ekranie (lewy górny róg)
- Szanse dropów w procentach
- Historia i statystyki

### ⚙️ Kompatybilność:
- ✅ Nowy system kategorii opcji
- ✅ Controller pattern
- ✅ Nowoczesne API przycisków
- ✅ Nowy system dialogów (displayGeneralBox)
- ✅ Responsywny layout

### 📝 Znane Ograniczenia:
- Wymaga włączonych powiadomień o loocie
- Działa tylko z "klasycznymi" powiadomieniami o loocie
- Potrzebne pliki items.otb i items.xml
- Możliwe dłuższe ładowanie przy dużej ilości danych

### 🐛 Zgłaszanie Błędów:
Jeśli znajdziesz błąd, zgłoś go na: https://github.com/EgzoT/-OTClient-Mod-loot_stats/issues

---

**Autor oryginalny**: EgzoT  
**Aktualizacja dla Redemption**: 2025  
**Wersja**: 1.3.0
