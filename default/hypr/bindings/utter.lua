if o.cmd_present("utter") then
  o.bind("SUPER + CTRL + U", "Speak selected text (press again to stop)", "omarchy-utter-speak-selection")
  o.bind("SUPER + CTRL + SHIFT + U", "Speak clipboard (press again to stop)", "omarchy-utter-speak-clipboard")
end
