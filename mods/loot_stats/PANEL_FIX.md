# Loot Stats - Panel Fix

## Problem
Panel opcji modułu loot_stats pojawiał się w menu ustawień (Misc. > Loot Stats), ale był pusty - nie wyświetlał żadnych elementów sterujących.

## Przyczyna
Struktura OTUI używała starego formatu `Panel` zamiast nowego standardu `UIWidget` z sekcjami `SmallReversedQtPanel`, który jest wymagany przez system opcji OTClient-Redemption v1.3.0+.

## Rozwiązanie

### 1. Zmieniono strukturę menuOption.otui
**Przed:**
```otui
Panel
  Label
    text: Loot on screen options
  CheckBox
    id: showLootOnScreen
  HorizontalScrollBar
    id: amountLootOnScreen
```

**Po:**
```otui
UIWidget
  anchors.fill: parent
  visible: false

  SmallReversedQtPanel
    id: showLootSection
    height: 22

    OptionCheckBox
      id: showLootOnScreen

  SmallReversedQtPanel
    id: amountLootSection
    height: 40

    Label
      id: amountLootOnScreenLabel
    
    OptionScaleScroll
      id: amountLootOnScreen
```

### 2. Zaktualizowano typy widgetów
- `Panel` → `UIWidget` (główny kontener)
- `CheckBox` → `OptionCheckBox` (checkboxy zgodne z nowym API)
- `HorizontalScrollBar` → `OptionScaleScroll` (slidery z wartościami)
- Sekcje opakowane w `SmallReversedQtPanel`

### 3. Dostosowano rozmiary
- Każda sekcja z checkboxem: `height: 22`
- Każda sekcja ze sliderem: `height: 40` (label + slider)
- Sekcja z przyciskiem: `height: 30`
- Margines między sekcjami: `margin-top: 7`

### 4. Poprawiono teksty w menuOption.lua
Zaktualizowano teksty labelów, aby były spójne z OTUI:
- "The amount of loot on the screen: %d" → "Amount of loot on screen: %d"
- "Time delay to delete loot from screen: %d" → "Delay time (ms): %d"

## Struktura nowego panelu
Panel zawiera 7 sekcji:
1. **showLootSection** - Checkbox włączający wyświetlanie lootu na ekranie
2. **amountLootSection** - Slider ustawiający ilość (1-20)
3. **delayTimeSection** - Slider ustawiający opóźnienie (500-10000ms)
4. **ignoreMonsterSection** - Checkbox ignorowania poziomu potwora
5. **ignoreLastSignSection** - Checkbox ignorowania kropki
6. **clearDataSection** - Przycisk czyszczenia danych

## Referencje
Wzorzec pochodzi z:
- `modules/client_options/styles/controls/general.otui`
- `modules/client_options/styles/misc/misc.otui`

## Testowanie
Po zastosowaniu tych zmian:
1. Panel "Loot Stats" pojawia się w Misc.
2. Wszystkie opcje są widoczne i funkcjonalne
3. Checkboxy i slidery działają poprawnie
4. Wartości są synchronizowane ze store
