# Přepínače, nečinnost a spořič obrazovky

Řadu funkcí během dne jen zapnete a později zase vypnete: noční světlo při práci do noci, režim nerušit při prezentaci nebo zákaz automatického zamykání při sledování obrazovky. Omarchy jim říká přepínače. Každý ovládáte stejně — klávesovou zkratkou, položkou nabídky nebo příkazem. Všechny tři možnosti mění tentýž stav.

### Menu přepínačů

`Super + Ctrl + O` otevře _Akce > Přepnout_. Do stejné nabídky se dostanete i přes nabídku Omarchy (`Super + Space`). Všechny uvedené funkce můžete rovnou zapnout nebo vypnout. Přepínače vzhledu plochy najdete vedle, v nabídce _Vzhled_.

Z terminálu jsou stejné přepínače `omarchy toggle <thing>`. Spusťte samotné `omarchy toggle` a uvidíte celou skupinu.

| Přepínač | Klávesová zkratka | Příkaz |
| ------ | ------ | ------- |
| Noční světlo | — | `omarchy toggle nightlight` |
| Ztišit oznámení | `Super + Ctrl + Alt + ,` | `omarchy toggle notification silencing` |
| Nezamykat při nečinnosti | `Super + Ctrl + I` | `omarchy toggle idle` |
| Záznam pádů | — | `omarchy toggle crash-capture` |
| Spořič obrazovky | — | `omarchy toggle screensaver` |
| Synchronizace motivu [Herdr](https://herdr.dev) | — | `omarchy toggle theme sync` |
| Lišta menu | `Super + Shift + Space` | `omarchy toggle bar` |
| Touchpad | `XF86TouchpadToggle` | `omarchy toggle touchpad` |
| Dotyková obrazovka | — | `omarchy toggle touchscreen` |
| Uspání | — | `omarchy toggle suspend` |
| Hybridní GPU | — | `omarchy toggle hybrid gpu` |

Přepínače touchpadu, dotykové obrazovky a hybridní GPU žijí pod _Trigger > Hardware_ (`Super + Ctrl + H`) spíše než pod Přepínači, protože se zobrazí jen tehdy, když takový hardware skutečně máte. Přepínače touchpadu a dotykové obrazovky přežijí opětovné načtení Hyprlandu — název zakázaného zařízení se uloží do malého stavového souboru, který Hyprland při spuštění přečte, aby ho znovu zakázal.

_Vzhled_ obsahuje lištu menu a animace plus pár věcí, které nejsou příkazy `omarchy toggle`, ale chovají se stejně: procenta baterie v liště, výchozí rozložení pracovní plochy a pod _Okny_ mezery oken (`Super + Shift + Backspace`) a čtvercový poměr stran pro 1 okno (`Super + Ctrl + Backspace`).

Většina z nich je jen soubor příznaku pod `~/.local/state/omarchy/toggles/`. Pokud na některý chcete ve skriptu větvit, `omarchy-toggle-enabled` vám dá návratový kód, místo abyste ho museli hledat:

```bash
omarchy-toggle-enabled screensaver-off && echo "screensaver is off"
```

Příznaky jsou pojmenované podle vypnutého stavu — `screensaver-off`, `suspend-off`, `bar-off` — takže jejich přítomnost znamená, že je funkce zakázaná.

### Indikátory v liště

Zapnutý režim poznáte podle malé ikony uprostřed horní lišty vedle hodin. Widget ukazatelů takto zobrazuje diktování, nahrávání obrazovky, čekající připomínky, noční světlo, režim nerušit a vypnuté automatické zamykání.

Neaktivní ukazatele jsou skryté. Najeďte kamkoli na lištu a objeví se ztlumené, takže na jeden můžete kliknout a zapnout ho, aniž byste znali jeho klávesovou zkratku. Kliknutím na aktivní ho zase vypnete. Pokud byste je raději viděli všechny neustále, nastavte `alwaysShow` na `true` u položky `omarchy.indicators` v `~/.config/omarchy/shell.json` — jak se widgety lišty konfigurují, viz [horní lišta](05-the-top-bar.md).

### Noční světlo

Noční světlo nastaví teplejší barvy obrazovky s barevnou teplotou 4000 K. Dalším přepnutím se vrátíte na 6500 K. Zapnete ho z nabídky přepínačů (`Super + Ctrl + O`) nebo příkazem `omarchy toggle nightlight`. Změnu zajišťuje hyprsunset, který přepínač v případě potřeby sám spustí.

Ve výchozím nastavení hyprsunset barevnou teplotu nemění. Profil v `~/.config/hypr/hyprsunset.conf` ponechává původní nastavení obrazovky, dokud noční světlo sami nezapnete. Pokud chcete teplotu měnit podle času, nahraďte ho časovým profilem:

```
profile {
    time = 20:00
    temperature = 4000
}
```

Pak hyprsunset spouštějte při přihlášení přidáním `o.launch_on_start("hyprsunset")` do `~/.config/hypr/autostart.lua`. Dvojice 4000K/6500K, kterou přepínač používá, je pevná, takže pokud chcete jinou teplotu, jdete do konfiguračního souboru.

### Nerušit

`Super + Ctrl + Alt + ,` ztiší oznámení. Dokud je tento režim zapnutý, oznámení nevyskakují na obrazovce. Přeškrtnutý zvonek na liště vám připomíná, proč je na ploše klid.

Nic se ale neztratí. Ztlumená oznámení se pozdrží: poslední pár jich vrátíte zpět na obrazovku pomocí `Super + Shift + Alt + ,`. Zbytek viz [oznámení](10-notices.md).

Dva druhy zpráv se stále dostanou skrz: vlastní potvrzovací vyskakovací zprávy Omarchy o tom, co jste právě udělali („Theme changed“, „Screenshot saved“), a kritické výstrahy odeslané z příkazového řádku. Chatovací aplikace, které označují všechno jako kritické, aby si vynutily cestu před vás, se nepočítají.

### Nečinnost

Prostředí Omarchy vlastní chování při nečinnosti a časování je blok `idle` na nejvyšší úrovni v `~/.config/omarchy/shell.json`:

```json
{
  "version": 1,
  "idle": {
    "screensaver": 150,
    "lock": 300
  }
}
```

Obě čísla jsou sekundy počítané od okamžiku, kdy jste přestali být aktivní — ne od sebe navzájem. Takže ve výchozím nastavení se spořič obrazovky objeví po dvou a půl minutách a zamykací obrazovka převezme vládu v pěti minutách, ať už spořič běžel, nebo ne. Uložte soubor a prostředí si nové časování převezme hned.

Pokud spořič odmítnete před termínem zamknutí, počítá se to jako aktivita a čekající zamknutí se zruší. Nezůstanete zamčeni venku za to, že jste se na svůj stroj jen podívali.

Automatické zamykání a spořič obrazovky vypnete pomocí `Super + Ctrl + I` nebo `omarchy toggle idle`. Na liště se objeví šálek kávy. Tento režim se hodí před dlouhou prezentací nebo sestavováním programu, jehož průběh chcete sledovat. Dalším stisknutím se vrátíte k běžnému chování. Pro použití ve skriptech vypíše `omarchy toggle idle status` aktuální stav jako JSON.

Tohle je o zamykání a spořiči obrazovky, ne o napájení. Uspání a hibernace mají vlastní nastavení v [uspávání systému](36-system-sleep.md).

### Spořič obrazovky

Spořič obrazovky Omarchy je ASCII art procházející náhodnými textovými efekty, jedna instance na monitor. Jakákoli klávesa nebo pohyb myši ho ukončí.

Můžete ho spustit na vyžádání ze _Systém > Spořič obrazovky_ (`Super + Esc`), což ho vynutí, i když jste spořič při nečinnosti vypnuli. Ve výchozím nastavení k němu není přiřazena žádná klávesová zkratka.

`omarchy toggle screensaver` je to, co vypne ten při nečinnosti, pokud chcete raději jít rovnou z práce do zamčeného stavu. Potřebuje terminál, který umí nakonfigurovat — Alacritty, Foot, Ghostty nebo Kitty — a řekne vám to, pokud je váš výchozí terminál něco jiného.

Logo, které kreslí, si můžete změnit v _Vzhled > Branding > Spořič obrazovky_. Nahrajte png nebo svg a Omarchy ho převede na ASCII. Viz [branding](41-branding.md).

### Zamykací obrazovka

`Super + Ctrl + L` zamkne stroj. To spustí zamykací obrazovku z prostředí Omarchy, zhasne displej, resetuje rozložení klávesnice na první, abyste nepsali heslo ve špatné abecedě, a — pokud ho máte spuštěný — cestou ven zamkne 1Password.

Zamykací obrazovka bere heslo a vezme i otisk prstu, jakmile si ho nastavíte. To a další způsoby ověření jsou popsány v [hardwarovém ověřování](37-hardware-authentication.md).
