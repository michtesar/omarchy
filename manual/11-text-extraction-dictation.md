# Text Extraction & Dictation

### Text Extraction

Hit `Super + Ctrl + PrtScr` to select a region on the screen for text extraction. The tesseract open source OCR model will then quickly convert that selection into text and place it on the clipboard. Then you just hit `Super + V` to paste.

This is very helpful for grabbing addresses out of image footers or phone numbers embedded in website headlines.

 ![text-extraction](images/text-extraction.webp)

### Dictation

Omarchy offers AI dictation via [Voxtype](https://voxtype.io/). You install it via _Install > AI > Dictation_ through the Omarchy menu. By default, it'll load a base English model that takes up 150MB. But you can tweak which model you'd like to use by running `voxtype setup model` in the terminal. And you can tweak all the settings via `~/.config/voxtype/config.toml`.

Once installed, you dictate by holding down `F9` or by toggling with `Super + Ctrl + X`, and the dictated text will appear in the focused input area.

### Text to Speech

Omarchy can also read text aloud via [Utter](https://github.com/michtesar/utter). You install it via _Install > AI > Text to Speech_ through the Omarchy menu. It downloads an English voice of about 65MB, measures how fast your machine synthesizes speech, and picks a smaller voice if it needs to. Everything runs locally on the CPU, so it works offline and leaves your GPU to any local AI models.

Once installed, select text anywhere and hit `Super + Ctrl + U` to hear it. Hit it again to stop. `Super + Ctrl + Shift + U` reads the clipboard instead. While Utter is speaking, a speaker glyph shows in the top bar, and clicking it stops the reading.

You can also pipe anything into `utter` from the terminal, and it starts speaking after the first sentence, even while the text is still arriving:

```bash
echo "Hello from Omarchy" | utter
claude -p "Explain socket activation" | utter --interrupt
```

Utter skips markdown syntax, so code blocks are announced rather than read character by character. For other languages, install a voice, e.g. `utter voices install cs_CZ-jirka-medium`, and use `utter --lang cs`. Run `utter voices list` to see the choices, `utter doctor` if something stays silent, and tweak settings in `~/.config/utter/config.toml`.
