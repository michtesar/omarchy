# Plan: Utter — local text-to-speech for Omarchy

Revision 1. Derived from the PRD "Utter — PRD: hlasový výstup pro Omarchy" (Michael Tesař, 2026-10-23) after reading how Voxtype dictation is wired into this repo. The PRD is the interface contract (CLI, socket protocol, event format, config). Where this plan deviates from the PRD, the deviation and its reason are listed in the next section, as the PRD asks. This document is written to be handed to an AI agent and executed top to bottom.

## How to execute this plan

- Read `AGENTS.md`, then `agents/skills/command-metadata.md`, `agents/skills/shell-dev.md`, and `docs/testing.md` before touching the Omarchy repo. Phases 1–3 are pure Python and run anywhere; phases 4 onward need an Omarchy (Arch) machine with PipeWire.
- Utter is a separate repository and a separate Arch package. Only phase 10 touches this repo, and that diff must stay as small as the Voxtype one it copies. Create the `utter` repository as a sibling checkout of this one unless the operator names another path.
- Work phase by phase, in the order below. Each phase ends with its listed checks passing. Do not start phase N+1 with a failing check in phase N.
- Commit atomically in both repos. Commit messages are short and describe the change.
- Implement v1 only. Leave v2/v3 hooks (`words` field, Kokoro, cloud backends) as unimplemented interface points, never as code paths.
- When you change anything listed under "Interface contract", append the change and its reason to the "Contract changes" section of this file in the same commit.

## Deviations from the PRD and decisions taken

1. **No Waybar. The bar is Quickshell.** Omarchy's bar is the Quickshell desktop under `shell/`; the Dictation indicator is `shell/plugins/bar/indicators/Dictation.qml`, fed by `bin/omarchy-voxtype-status`, which streams one JSON object per line (`{"alt","class","tooltip"}`) that `BarIndicator.extractData()` parses (last line wins, see `shell/Commons/Util.qml` `parseModuleJson`). Utter copies that: `utter --events --bar` emits the same shape, `bin/omarchy-utter-status` wraps it, and a new `Speech.qml` indicator renders it. The PRD flag `--waybar` is renamed `--bar`; the output stays Waybar-custom-module compatible so the name is the only difference.
2. **Command names are `omarchy-utter-*`, not `omarchy-cmd-speak-*`.** Voxtype's scripts are `bin/omarchy-voxtype-{install,remove,status,config,model}` with `GROUP_DESCRIPTIONS[voxtype]="Voxtype dictation"` in `bin/omarchy`. The `cmd-` group is for command-presence helpers. Utter gets its own group the same way.
3. **Keybinds move to `Super + Ctrl + U` / `Super + Ctrl + Shift + U`.** `Super + Ctrl + S` is taken by the Share menu (`default/hypr/bindings/utilities.lua:84`). Free `Super + Ctrl + <letter>` combinations are G, J, M, U, Y; U matches the name. `Super + Ctrl + Shift + U` has no conflicts either. `test/shell.d/hyprland-binding-conflicts-test.sh` will catch any collision.
4. **Bar status must not wake the daemon.** With socket activation, any connection to `utter.sock` starts `utterd`, so a permanently subscribed bar client would defeat the 10-minute idle shutdown and the 0 % idle CPU target. The daemon therefore also publishes its coarse state to `$XDG_RUNTIME_DIR/utter/state` (`idle` or `speaking`, like Voxtype's `state_file`), and `utter --events --bar` watches that file with inotify (Python `ctypes`, no polling, no new dependency) instead of holding a socket. `utter --stop`, `--toggle` on an idle daemon, and `--status` consult the state file first and only connect when there is something running, so they never start the daemon just to tell it to stop. Full-fidelity `utter --events` (no `--bar`) still subscribes over the socket and is for debugging and tests.
5. **Backend binding and license.** Utter imports the `piper` Python package from the `piper-tts` AUR package (piper1-gpl 1.8.x, GPL-3.0-or-later) in-process. Its `PiperVoice.synthesize()` yields audio per sentence, keeps the model loaded, and lets us cancel between chunks, which a `piper` subprocess cannot do within the 100 ms stop budget. Consequence: Utter is licensed GPL-3.0-or-later. This does not touch Omarchy (MIT), which only ships thin shell scripts that call `utter`. **Confirmed by the operator on 2026-10-23.** The rejected alternative was spawning `piper --json-input --output-raw` as a long-lived subprocess with Utter under MIT, at the cost of killing and respawning the process (model reload) on every interrupt.
6. **Packaging goes through `omarchy-pkgs`.** `omarchy-pkg-add` is plain `pacman -S`; Omarchy is package-backed and ships third-party tools like `voxtype-bin` through its own pacman repository, with PKGBUILDs in the separate `omarchy-pkgs` repo under `pkgbuilds/`. `utter` and its dependency `piper-tts` (and any of its dependencies not in the official Arch repos, verify `onnxruntime` with `pacman -Si`) must be built and published there. This is a hosting commitment the operator has to accept. Until published, test with a locally built package (`makepkg -si`).
7. **The default config file is owned by the `utter` package, not by this repo.** `utterd` writes `~/.config/utter/config.toml` from its packaged commented template on first start if the file is missing. Omarchy's install script does not copy a config. Keeps the Omarchy diff smaller than Voxtype's.
8. **No first-run invitation hook and no migration.** The PRD says opt-in, nothing by default. Voxtype's `install/user/first-run/install-voxtype.hook` is an invitation toast; Utter does not get one in v1. There is no existing state to repair, so no `migrations/` entry.
9. **Indicator clicks.** While speaking, a click runs `omarchy-utter-stop` (PRD). While idle, the indicator is only visible on hover like the others; a click then runs `omarchy-utter-doctor`, which opens `utter doctor` in a floating terminal, mirroring how Dictation opens its config.

## Integration map found in the repo

| Concern | Voxtype today | Utter will be |
|---|---|---|
| Menu install | `default/omarchy/omarchy-menu.jsonc` key `install.ai.dictation`, `disabled: omarchy-pkg-present voxtype-bin`, action opens `omarchy-voxtype-install` in a floating terminal | key `install.ai.text-to-speech`, label "Text to Speech", `disabled: omarchy-pkg-present utter`, action `omarchy-launch-floating-terminal-with-presentation omarchy-utter-install`, placed right after `install.ai.dictation` |
| Menu remove | key `remove.ai.dictation`, `when: omarchy-pkg-present voxtype-bin` | key `remove.ai.text-to-speech`, `when: omarchy-pkg-present utter`, action `omarchy-utter-remove` |
| Install script | `bin/omarchy-voxtype-install`: `gum confirm`, `omarchy-pkg-add`, config copy, service setup, `hyprctl reload`, `omarchy-restart-shell`, `omarchy-notification-send` | `bin/omarchy-utter-install`, same skeleton (see phase 10) |
| Remove script | `bin/omarchy-voxtype-remove` | `bin/omarchy-utter-remove` |
| Bar status feed | `bin/omarchy-voxtype-status`: prints idle JSON and exits 0 when the command is missing, otherwise `exec setpriv --pdeathsig TERM voxtype status --follow ... --format json` | `bin/omarchy-utter-status`, same two branches around `utter --events --bar` |
| Indicator | `shell/plugins/bar/indicators/Dictation.qml`, listed in `defaultIndicatorEntries` in `shell/plugins/bar/widgets/Indicators.qml` | `shell/plugins/bar/indicators/Speech.qml`, added to `defaultIndicatorEntries` |
| Keybinds | `default/hypr/bindings/voxtype.lua`, guarded by `o.cmd_present("voxtype")`, required from `default/hypr/omarchy.lua` | `default/hypr/bindings/utter.lua`, guarded by `o.cmd_present("utter")`, required next to the voxtype line |
| CLI group | `GROUP_DESCRIPTIONS[voxtype]="Voxtype dictation"` in `bin/omarchy` | `GROUP_DESCRIPTIONS[utter]="Utter text to speech"` |
| Tests | `test/shell.d/hyprland-default-config-test.sh` (conditional bindings), `test/shell.d/fixtures/indicator-contract/shell.qml` (indicator clicks), `test/cli` metadata lint | same three, plus `test/shell.d/utter-commands-test.sh` for the speak scripts |
| Manual | `manual/11-text-extraction-dictation.md`, `manual/07-hotkeys.md` rows, `manual/05-the-top-bar.md` indicator list | same three files extended |
| OCR (v2 input) | `bin/omarchy-capture-text` already copies OCR text to the clipboard | v2 `omarchy-utter-speak-ocr` is `omarchy-capture-text && omarchy-utter-speak-clipboard`; not built in v1 |

## Interface contract (from the PRD, with the changes above applied)

### CLI

```text
utter [OPTIONS] [TEXT...]      # without TEXT reads stdin to EOF, streaming
utter --stop                   # stop everything speaking and queued; never starts the daemon
utter --status                 # daemon state as JSON; never starts the daemon
utter --events [--bar]         # event stream as JSON lines; --bar = bar-module shape via the state file
utter voices [list|install NAME|set NAME [--lang LANG]]
utter bench                    # measure engine RTF on this machine
utter doctor                   # check audio, voices, socket, config; print problems
```

Options: `-i/--interrupt`, `-q/--queue` (default), `--toggle`, `--voice NAME`, `--lang LANG`, `--rate N` (0.5–2.0), `--raw`, `--wait`. Exit codes: 0 delivered (with `--wait`: finished), 1 general error, 2 usage, 3 daemon unreachable and could not be started, 4 engine or audio error, 5 cancelled by another utterance (only with `--wait`). Empty input after normalization exits 0 and plays nothing.

### Socket protocol

Unix socket `$XDG_RUNTIME_DIR/utter.sock`, mode 0600, newline-delimited JSON, one connection per utterance or command. Client → daemon ops: `speak` (`id`, `mode`, `voice`, `lang`, `rate`, `raw`), `text` (`id`, `chunk`), `end` (`id`), `stop`, `toggle`, `status`, `subscribe`. Unknown op → `error` with code `bad_request`, connection stays open. Client disconnect during `speak` without `end` counts as `end`.

### Events

All events carry `"v":1`. Types: `accepted` (`id`, `mode`, `queue`), `speaking` (`id`), `sentence` (`id`, `index`, `text`, `duration_ms`, emitted when the sentence starts to sound), `degraded` (`id`, `from`, `to`), `done` (`id`), `cancelled` (`id`, `by`), `idle`, `error` (`id`, `code`, `message`). A new subscriber immediately receives the current state (`speaking` or `idle`). `words` is reserved for v3 and absent in v1. The journal logs only `id`, length, and event type, never text.

### Modes

`queue` appends; `interrupt` cancels the current utterance and the whole queue and starts now; `toggle` stops everything if anything is sounding, otherwise behaves as `interrupt`; `stop` cancels everything. Cancel discards buffered audio, aborts in-flight synthesis, closes the player; sound must end within 100 ms. Two simultaneous `interrupt` requests: the later one wins.

### State file (contract change 4)

`$XDG_RUNTIME_DIR/utter/state` contains `idle` or `speaking`, written atomically (write temp, rename) on every change and set to `idle` on daemon exit. Absent file means idle.

### Config

`~/.config/utter/config.toml`:

```toml
[engine]
backend = "piper"        # piper | espeak (v2: kokoro)
device  = "cpu"          # cpu | auto
threads = 2

[voice]
default = "en_US-lessac-medium"
[voice.lang]
cs = "cs_CZ-jirka-medium"

[speech]
rate = 1.0

[normalize]
enabled = true

[bench]
fast = 0.3
slow = 0.8
```

Paths: voices in `~/.local/share/utter/voices/`, bench results in `~/.local/state/utter/bench.json`, logs in the user journal (`journalctl --user -u utterd`). Config changes apply after `systemctl --user restart utterd` or the next start after idle exit.

## Utter repository layout

```text
utter/
  pyproject.toml              # package "utter", console scripts utter and utterd, GPL-3.0-or-later
  utter/
    cli.py                    # client; imports only socket, json, sys, os at module import time
    protocol.py               # dataclasses + encode/decode for ops and events, shared by client and daemon
    segment.py                # pure sentence segmenter over a buffer (phase 1)
    normalize.py              # stateful markdown filter (phase 2)
    i18n/{en,cs}.toml         # phrases "code sample", "table", "link to" per voice language
    abbreviations/{en,cs}.txt # abbreviation lists for the segmenter
    daemon/
      main.py                 # utterd entry: socket activation (sd_listen_fds), idle timer, state file
      server.py               # asyncio connection handling, op dispatch
      queue.py                # utterance queue, modes, cancellation
      pipeline.py             # normalize → segment → synth (prefetch 2) → play, per utterance
      events.py               # event bus, subscribers, journal-safe logging
      state.py                # state file writer
      config.py               # TOML loading with defaults, threshold values
    backends/
      base.py                 # Backend protocol from the PRD, VoiceInfo, registry
      piper.py
      espeak.py
      fake.py                 # silence of a given duration per sentence; used by tests and bench self-check
    audio/
      pipewire.py             # pw-cat playback, device follows default sink
    voices.py                 # list/install/set; downloads from rhasspy/piper-voices with checksum
    bench.py
    doctor.py
  tests/
    test_segment.py
    test_normalize.py
    test_daemon.py            # fake backend, fake audio, real socket in a temp XDG_RUNTIME_DIR
    test_cli.py
    fixtures/markdown/*.md + *.expected
  systemd/utterd.socket, systemd/utterd.service
  packaging/config.toml.default
  README.md
```

## Phase 0 — Scaffolding

- Create the repository with the layout above, `pyproject.toml` (PEP 621, `[project.scripts] utter = "utter.cli:main"`, `utterd = "utter.daemon.main:main"`), Python ≥ 3.12 (Arch ships 3.14; do not use anything removed there), `pytest`, `ruff`.
- Check the package name: on an Omarchy machine run `pacman -Ss '^utter$'` and `yay -Ss utter` (or query `https://aur.archlinux.org/rpc/v5/info/utter`). This could not be verified while writing the plan. If the name is taken, use the PRD's fallbacks in order: `hark`, `murmur`, `parley`, and apply the rename everywhere before phase 10.
- Checks: `pytest` runs (zero tests is fine), `ruff check` clean.

## Phase 1 — Segmentation (pure function + tests)

Implement `segment.py` as a pure function over a buffer: `feed(buffer: str, *, eof: bool, first: bool) -> tuple[list[str], str]` returning completed segments and the remaining buffer. The 700 ms timeout rule is the only time-dependent part and lives in the pipeline, not here (`flush_partial(buffer, min_chars=40)`).

Rules to implement, each with its own test:

1. A boundary is `.`, `!`, `?`, or `…` followed by whitespace plus an uppercase letter, a newline, or end of input.
2. A blank line is always a boundary. Each list item is its own segment.
3. Never split inside numbers (`3.14`, `1.5.2026`), versions (`v2.1`), URLs, or language-specific abbreviations (`např.`, `tzv.`, `e.g.`, `Mr.`) loaded from `abbreviations/<lang>.txt`.
4. Segments over 300 characters split at the nearest comma, semicolon, or colon, otherwise at a space.
5. The first segment of an utterance splits at the first comma once it exceeds 80 characters.
6. Segments under 20 characters merge with the next unless input has ended.

Property test: for each fixture text, feeding it in random 1–10 character chunks produces the same segment list as feeding it whole. Seed the RNG and run several seeds.

Checks: `pytest tests/test_segment.py` green.

## Phase 2 — Normalization (stateful filter + tests)

Implement `normalize.py` as a class with `feed(chunk) -> str` and `finish() -> str`, states `normal`, `code_fence`, `table`, `html_block`. Structural decisions happen at line start and hold back at most the first 4 characters of a line; the rest of the line streams through. Inline constructs split across chunks (`[text](` without the closing paren) are buffered until closed or until end of line, then emitted as plain text.

Mapping (from the PRD): fenced code → one phrase "code sample" in the voice language, content skipped to the closing fence; inline code → content without backticks, or "code" if longer than 40 characters; headings → heading text as its own sentence; bold/italic/strike → text only; list items → one segment each; tables → one phrase "table", rows skipped; `[text](url)` → text; bare URL → "link to" + domain; blockquote → text without `>`; HTML tags removed, content kept; emoji removed; `---`/`***` → segment boundary, nothing read. Phrases come from `i18n/<lang>.toml` (en, cs in v1). `--raw` bypasses the filter entirely.

Tests: a fixture directory of markdown inputs with expected outputs, each run whole and in random 1–10 character chunks; the results must match. Include an LLM-style answer with headings, list, code block, table, and links, and assert no `*`, `` ` ``, `#`, `|`, `[`, `](` reach the output.

Checks: `pytest tests/test_normalize.py` green.

## Phase 3 — Daemon with the fake backend

- `protocol.py`: typed ops and events, strict decoding, unknown op → `bad_request`.
- `backends/fake.py`: `synthesize()` yields silence (`sample_rate` 22050, s16le mono) sized by text length at a configurable RTF, in chunks, honouring `cancel()` within 50 ms.
- `audio/` gets a `FakePlayer` that consumes PCM and records timing; the real player comes in phase 5. The pipeline takes the player as a dependency.
- `queue.py` + `pipeline.py`: per-utterance pipeline normalize → segment → synth (prefetch 2 sentences ahead) → play; queue modes; cancellation that aborts synth, drops buffered audio, stops the player; `sentence` event fired when playback of that sentence starts; `degraded` hook present but only triggered by the adaptation rule in phase 7.
- `server.py` + `main.py`: asyncio Unix socket server; accept `LISTEN_FDS` from systemd (socket activation) or bind the socket itself with mode 0600; concurrent connections (status/subscribe during speech); 700 ms partial-flush timer per utterance; 10-minute idle timer counting speech activity only; state file writer; journal logging without text.
- Idle exit: when the timer fires, write `idle` to the state file, send `idle` to subscribers, close the socket listener (unless inherited from systemd), exit 0.

Integration tests (`tests/test_daemon.py`), all with a temp `XDG_RUNTIME_DIR`, the fake backend, and the fake player, no audio device, no voices:

- queue order: two `speak` utterances in `queue` mode play back to back; events `accepted, speaking, sentence…, done` in order.
- interrupt: second utterance in `interrupt` mode cancels the first within 100 ms of request receipt (measure via the fake player), first connection receives `cancelled` with `by: interrupt`.
- toggle: while speaking → everything stops, nothing new starts; while idle → acts as interrupt.
- streaming: text sent in 1–10 character chunks with 20–200 ms pauses; the first `sentence` event arrives before the client sends `end`.
- disconnect without `end` is treated as `end`.
- unknown op → `error bad_request`, connection still usable.
- new subscriber gets current state immediately.
- state file flips `idle → speaking → idle`.
- idle timer (shortened via config/env for the test) exits the daemon and leaves `idle` in the state file.

Checks: `pytest tests/test_daemon.py` green and runnable headless.

## Phase 4 — Piper backend

Requires an Arch machine with `piper-tts` installed (AUR, piper1-gpl ≥ 1.8; note the AUR comments: the source build fails from a long build path such as paru's cache, build from a short path like `~/piper-tts/`). The license decision (deviation 5) is confirmed; proceed without asking.

- `backends/piper.py`: `load(voice, device, threads)` loads `~/.local/share/utter/voices/<name>.onnx` (+ `.onnx.json`) with `PiperVoice.load`, passing onnxruntime session options for `intra_op_num_threads = threads` and CPU/CUDA provider per `device` (verify the exact API of the installed piper version first; adapt if `load()` takes no session options by constructing the `InferenceSession` yourself). `synthesize(text, rate)` maps `rate` to `length_scale = 1/rate` and yields `audio_int16_bytes` per chunk, checking a cancel flag between chunks. `voices()` lists installed and known voices.
- `voices.py`: `install NAME` downloads `NAME.onnx` and `NAME.onnx.json` from the `rhasspy/piper-voices` Hugging Face tree (path derived from the name: `<lang>/<locale>/<speaker>/<quality>/`), verifies size/sha256 from the model card where available, writes atomically; `list` shows name, language, size, installed; `set NAME [--lang LANG]` edits `[voice]` / `[voice.lang]` in the config with a TOML writer that preserves comments (if no suitable library is packaged in Arch, rewrite only the affected key lines textually).
- Missing voice for `--lang`: daemon sends `error` with code `voice_missing` and a message naming the `utter voices install NAME` command; client prints it and exits 4.

Checks: with the English voice installed, `echo "Hello from Utter." | utterd-dev-harness` produces non-silent PCM; unit tests still green with the fake backend; `pytest -m piper` optional tests skip cleanly when piper or the voice is missing.

## Phase 5 — PipeWire playback

- `audio/pipewire.py`: one `pw-cat --playback --rate <sr> --channels 1 --format s16 --latency 20ms -` (or `pw-play`) subprocess per utterance, PCM written to its stdin from the pipeline; stop = close stdin and `SIGKILL` within the same tick, then `wait()`. Verify on the machine that killing pw-cat silences within 100 ms; if the server-side buffer keeps playing, lower `--latency` or send a short zero-fill before kill and measure again.
- Device follows the default sink because pw-cat connects to the default target; test by switching outputs mid-utterance.
- Inter-sentence gap: keep writing into the same pw-cat process across sentences; the pipeline's prefetch keeps the buffer fed. Measure the gap with `pw-top` or by recording the sink monitor.

Checks: manual listening test; gap ≤ 150 ms at RTF ≤ 0.8; stop ≤ 100 ms (measure with timestamps logged by the daemon around the kill and the `pw-cat` exit).

## Phase 6 — Client

- `cli.py` with minimal import footprint (argparse is acceptable; defer json/socket imports until needed is not necessary, but import nothing heavy). Measure `utter --help` wall time; target under 60 ms.
- Behaviour: read TEXT args or stream stdin in chunks as they arrive (`os.read` on fd 0, not line-buffered), send `speak` immediately with options, `text` per chunk, `end` at EOF; exit 0 right after `end` unless `--wait`, in which case wait for `done` (0), `cancelled` (5), or `error` (4).
- Daemon unreachable: if `systemctl --user is-enabled utterd.socket` succeeds, connecting is enough (socket activation); otherwise spawn `utterd` detached and wait up to 2 s for the socket; failing that exit 3 with a one-line hint pointing at `utter doctor`.
- `--stop`, `--toggle`, `--status` read the state file first; with no file or `idle`, `--stop` and `--status` return without connecting, `--toggle` proceeds as `--interrupt`.
- `--events`: subscribe over the socket and print events; `--events --bar`: inotify watch on the state file, print `{"alt":"speaking","class":"speaking","tooltip":"Speaking · click to stop"}` or `{"alt":"","class":"idle","tooltip":""}` on each change and once at start; never connects to the socket.
- Exit codes exactly as the contract. `tests/test_cli.py` runs the client against the phase 3 test daemon.

Checks: PRD acceptance items 5, 6, 7 reproduced as tests (`seq 1 5 | utter` then `echo Second. | utter` queues; same with `--interrupt` and `--wait` gives exit 5 on the first).

## Phase 7 — espeak-ng fallback and runtime adaptation

- `backends/espeak.py`: `espeak-ng --stdout` (or `-b 1 -q` with raw output) per sentence into PCM, resampled or declared at its native rate; `cancel()` kills the process.
- Fallback: when `load` or `synthesize` of the primary backend raises, the daemon emits `error` with code `backend_failed`, logs the reason to the journal, switches the rest of the utterance to espeak-ng, and continues. Covered by a test that uses a fake backend configured to fail on sentence 2.
- Adaptation: for each sentence compare the predicted completion of the next synthesis with the end of current playback; when synthesis loses twice in a row and a smaller model of the same language is installed, switch the rest of the utterance to it and emit `degraded`; the next utterance starts fresh with the configured voice. Test with the fake backend at RTF > 1 and a fake "low" voice registered.

Checks: PRD acceptance item 9 (simulated Piper failure) as a test; the two new tests green.

## Phase 8 — bench, doctor, config template

- `bench.py`: synthesize three sentences (short, medium, long) with every installed voice, discard the first run, store median RTF per voice in `~/.local/state/utter/bench.json`; print a one-line recommendation using the `[bench]` thresholds (fast < 0.3, slow > 0.8); with `--apply` set the default voice to the medium or low variant accordingly (installing the low variant if needed). Thresholds are config values, not constants.
- `doctor.py`: checks `pw-cat` presence and a default sink, `utterd.socket` enabled/active, socket path and mode, voices installed and readable, config parse, espeak-ng presence, state file; prints problems with the fixing command; exit 1 if anything is wrong.
- `packaging/config.toml.default`: the commented template; `utterd` copies it to `~/.config/utter/config.toml` on first start if missing (deviation 7).

Checks: `utter bench` and `utter doctor` run on the dev machine; `doctor` exit codes tested with stubs.

## Phase 9 — systemd units and packaging

- `systemd/utterd.socket`: `ListenStream=%t/utter.sock`, `SocketMode=0600`, `[Install] WantedBy=sockets.target`. `systemd/utterd.service`: `ExecStart=/usr/bin/utterd`, `Type=notify` or `simple` (match what `main.py` implements), `MemoryMax` not set (PRD target ≤ 250 MB is a measurement, not a kill limit), `Slice=app.slice`.
- PKGBUILD in `omarchy-pkgs/pkgbuilds/utter/`: `depends=(python piper-tts espeak-ng pipewire-audio)` plus whatever `pacman -Si piper-tts` says is not in the official repos; installs units to `/usr/lib/systemd/user/`, the config template to `/usr/share/utter/config.toml`, license file. Build `piper-tts` into the Omarchy repo the same way `voxtype-bin` is built (follow the existing pattern in `omarchy-pkgs`; ask the operator if that pattern is not obvious from the repo).
- Measure and record in the Utter README: memory of `utterd` idle with one voice loaded (`systemctl --user status utterd`), CPU idle (`top` over one minute must show 0.0), cold start keybind → first sound, warm start keybind → first sound, stop → silence, inter-sentence gap. Method: timestamps in the journal with `UTTER_TRACE=1`, plus sink-monitor recording for the audio side.

Checks: `makepkg -si` installs; `systemctl --user enable --now utterd.socket`; `echo Ready. | utter` speaks on a fresh login; after 10 idle minutes `systemctl --user is-active utterd.service` is `inactive` and the next `utter` call speaks again.

## Phase 10 — Omarchy integration (this repo)

Keep the diff to the files below. Follow `agents/skills/command-metadata.md` for every script in `bin/` (summary header, `requires-sudo` on install/remove). Shebang `#!/bin/bash`. Two-space indentation, bash 5 conditionals.

1. `bin/omarchy` — add `GROUP_DESCRIPTIONS[utter]="Utter text to speech"` in alphabetical position.
2. `bin/omarchy-utter-install` — copy `omarchy-voxtype-install`'s shape: `gum confirm "Install Utter text to speech (~100MB voice)?"`; `omarchy-pkg-add utter`; `utter voices install en_US-lessac-medium`; `systemctl --user enable --now utterd.socket`; `utter bench --apply`; `hyprctl reload >/dev/null`; `omarchy-restart-shell`; `utter --wait "Utter is ready. Select text and press Super Control U to hear it."`; `omarchy-notification-send -g <glyph> "Utter Text to Speech Ready" "Select text and press Super + Ctrl + U (press again to stop)." -t 10000`.
3. `bin/omarchy-utter-remove` — mirror `omarchy-voxtype-remove`: `systemctl --user disable --now utterd.socket utterd.service`; `daemon-reload`; `omarchy-pkg-drop utter`; keep `~/.config/utter` and `~/.local/share/utter/voices` (PRD: uninstall leaves voices and config); `hyprctl reload`; `omarchy-restart-shell`.
4. `bin/omarchy-utter-status` — mirror `omarchy-voxtype-status`: idle JSON and exit 0 when `omarchy-cmd-missing utter`; otherwise `exec setpriv --pdeathsig TERM utter --events --bar`. Keep the comment explaining why `exec setpriv` (direct child of the bar).
5. `bin/omarchy-utter-speak-selection` — `wl-paste --primary --no-newline | utter --toggle`.
6. `bin/omarchy-utter-speak-clipboard` — `wl-paste --no-newline | utter --toggle`.
7. `bin/omarchy-utter-stop` — `utter --stop`.
8. `bin/omarchy-utter-doctor` — `omarchy-launch-floating-terminal-with-presentation "utter doctor"`.
9. `default/hypr/bindings/utter.lua`:

   ```lua
   if o.cmd_present("utter") then
     o.bind("SUPER + CTRL + U", "Speak selected text (press again to stop)", "omarchy-utter-speak-selection")
     o.bind("SUPER + CTRL + SHIFT + U", "Speak clipboard (press again to stop)", "omarchy-utter-speak-clipboard")
   end
   ```

   and `require("default.hypr.bindings.utter")` in `default/hypr/omarchy.lua` right after the voxtype line.
10. `default/omarchy/omarchy-menu.jsonc` — add `install.ai.text-to-speech` after `install.ai.dictation` and `remove.ai.text-to-speech` after `remove.ai.dictation`, same shape as the dictation rows. Pick a Nerd Font speaker glyph (e.g. the `nf-md-volume_high` or `nf-fa-volume_up` codepoint) and insert it with a Python `chr(0x...)` script as `agents/skills/shell-dev.md` warns; do not retype glyphs by hand. Validate with the menu test in `test/shell.d/` if one exists, and with `omarchy-menu --print` otherwise.
11. `shell/plugins/bar/indicators/Speech.qml` — copy `Dictation.qml`: `state` from `data.alt || data.class`, `active: state === "speaking"`, active glyph speaker, inactive glyph muted speaker, tooltips "Speaking · click to stop" / "Text to speech"; `Process` running `omarchy-utter-status`; `onPressed`: `root.bar.run(root.active ? "omarchy-utter-stop" : "omarchy-utter-doctor")`. Add `"Speech"` to `defaultIndicatorEntries` in `shell/plugins/bar/widgets/Indicators.qml` after `"Dictation"` (targeted edit, glyph warning applies to that file).
12. Tests in this repo:
    - `test/shell.d/hyprland-default-config-test.sh`: add the `utter` counterpart of the voxtype block (stub `utter` on PATH → both bindings present; missing → absent).
    - `test/shell.d/fixtures/indicator-contract/shell.qml`: add a `Speech` block asserting idle click runs `omarchy-utter-doctor` and, after setting `state = "speaking"`, click runs `omarchy-utter-stop`.
    - New `test/shell.d/utter-commands-test.sh` sourcing `base-test.sh`: with stub `wl-paste` and `utter` on PATH, assert `omarchy-utter-speak-selection` calls `wl-paste --primary --no-newline` and `utter --toggle`, `omarchy-utter-speak-clipboard` omits `--primary`, `omarchy-utter-status` prints the idle JSON and exits 0 when `utter` is missing.
    - `./test/all` green (the CLI metadata lint covers the new `bin/` files automatically; the binding-conflicts test covers the new keys).
13. Manual: extend `manual/11-text-extraction-dictation.md` with a "Text to Speech" section (install path, keybinds, `cmd | utter`, `utter voices install cs_CZ-jirka-medium`, config path); add the two hotkey rows to `manual/07-hotkeys.md` next to dictation; add "text to speech" to the indicator list in `manual/05-the-top-bar.md`; one sentence in `manual/17-ai.md` if dictation is mentioned there. Full lines, no hard wrapping.
14. Visual verification per `agents/skills/visual-verification.md`: indicator appears only while speaking, disappears after `done`, click stops. Attach a screenshot to the PR.

Checks: `./test/all` green; `omarchy-restart-shell` and the manual scenario in the running UI; the full PRD acceptance list below walked through on a clean install.

## Phase 11 — Measurements and PR

- Fill the PRD non-functional table with measured values from phase 9 on a 4-core laptop CPU without a dedicated GPU and attach it to the Omarchy PR description together with a short screen recording ("select, press, it speaks" and `claude -p … | utter --interrupt`).
- PR to Omarchy contains only phase 10 files. The Utter repo and `omarchy-pkgs` changes are linked from the description.

## Acceptance criteria (v1 done)

All PRD items, restated with the deviations applied:

1. Install > AI > Text to Speech completes without user input and ends with a spoken confirmation.
2. Selected text in a browser + `Super + Ctrl + U`: sound within 300 ms (daemon running), within 1.5 s (cold start).
3. Second `Super + Ctrl + U` while speaking: silence within 100 ms, nothing new starts.
4. `echo "Ahoj." | utter --lang cs` speaks Czech when the voice is installed, otherwise prints the `utter voices install` hint and exits 4.
5. `seq 1 5 | utter` then `echo Second. | utter`: second utterance plays after the first.
6. Same with `--interrupt`: first falls silent, second starts immediately, first client with `--wait` exits 5.
7. Streamed input (1–10 characters, 20–200 ms pauses): first sentence sounds before the input ends.
8. LLM answer with headings, list, code block, table, links: no syntax characters are spoken, code block only as "code sample".
9. Simulated Piper failure: espeak-ng finishes the utterance, reason in the journal.
10. `utter --events` prints `accepted, speaking, sentence…, done` in order.
11. Bar indicator visible only while speaking; click stops.
12. After 10 idle minutes the daemon is not running; the next keypress starts it.
13. Idle daemon: 0 % CPU, ≤ 250 MB RSS.
14. Unit and integration tests pass without an audio device and without downloaded voices.
15. Menu removal removes the package and units; keybinds and indicator disappear because they are guarded by command presence.

## Open items for the operator (do not block phases 1–3)

- Confirm deviation 6 (publishing `utter` and `piper-tts` through `omarchy-pkgs`) before phase 9.
- Package name collision check result for `utter` (phase 0) — rename to `hark`/`murmur`/`parley` if taken.
- Default English voice: listening test of `en_US-lessac-medium`, `en_US-ryan-medium`, `en_US-amy-medium`; `lessac` is the working default until decided.
- Keybind choice `Super + Ctrl + U` / `Super + Ctrl + Shift + U` (deviation 3) if a different free key is preferred.

## Contract changes

Record every change to the interface contract here with the reason, in the commit that makes it.

- 2026-10-23: `--waybar` renamed `--bar`; output shape unchanged. Reason: Omarchy's bar is Quickshell; the flag name should not claim a toolkit that is not in use.
- 2026-10-23: added the state file `$XDG_RUNTIME_DIR/utter/state` and made `--stop`, `--status`, `--toggle`, and `--events --bar` consult it before connecting. Reason: socket activation would otherwise let the bar indicator keep the daemon alive forever and break the idle-exit and 0 % CPU requirements.
- 2026-10-23: `utterd` creates `~/.config/utter/config.toml` from its packaged template on first start. Reason: keeps the Omarchy integration diff to shell scripts only.
- 2026-10-23: `status` op is answered with a `status` event (`state`, `id`, `queue`, `backend`, `voice`, `loaded`, `pid`, `version`); `stop` and `toggle` ops are answered with `idle`. Reason: the PRD listed the ops but not their replies, and the client needs one to know the command landed.
- 2026-10-23: `error` events carry `fatal` (true when the utterance ended, false for a recovered fallback), and the error codes are `bad_request`, `voice_missing`, `backend_failed`, `audio_failed`. Reason: a client with `--wait` must know whether to keep waiting for `done` after an error; a missing voice needs its own code for the install hint.
- 2026-10-23: a `speak` in `toggle` mode that only stops speech gets `cancelled` with `by: "toggle"` for its own id, and the client exits 0 for it. Reason: stopping by toggle is the caller's own intent, not a cancellation by another utterance (exit 5).
- 2026-10-23: the state file is removed when the daemon exits; absent means not running. `utter --status` prints `{"v":1,"event":"status","state":"inactive"}` then. Reason: `--status` must not start the daemon, so it needs to tell "idle" from "not running" without connecting.
- 2026-10-23: config gains `[daemon] idle_timeout = 600`. Reason: the 10-minute idle exit from the PRD becomes a tunable default, like the bench thresholds.
- 2026-10-23: when the client starts `utterd` itself (no systemd), the daemon log goes to `~/.local/state/utter/utterd.log`. Reason: there is no journal for a self-spawned process; the log carries the same text-free lines.
- 2026-10-23: the bench `--apply` flag switches the default voice to the low model only when the machine is slow; `fast` machines are told a richer voice comes in v2. Reason: Kokoro is out of scope for v1.

## Implementation status (2026-10-23)

- Utter repository: phases 0–9 implemented with 212 passing tests (segmentation, normalization, daemon, client, commands, Piper backend against stand-in modules). Not verified on real hardware: Piper synthesis, PipeWire playback, systemd socket activation, and every latency and memory figure in the PRD table. The development host could not download the onnxruntime Python package or Piper voices and runs no PipeWire server.
- Omarchy integration: phase 10 implemented. The indicator contract QML test needs Quickshell and a compositor and was not run; visual verification of the indicator is still open.
- Open for the operator: publish `utter` and `piper-tts` through `omarchy-pkgs`, create the upstream `utter` repository the PKGBUILD points at, confirm the name is free on the AUR, run the listening test for the default voice, and measure the PRD table on a 4-core laptop (phase 11).
