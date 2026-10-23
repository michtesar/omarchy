#!/bin/bash

source "$(dirname "$0")/base-test.sh"

test_bin=$(mktemp -d)
log_file=$(mktemp)

cleanup() {
  rm -rf "$test_bin"
  rm -f "$log_file"
}
trap cleanup EXIT

cat >"$test_bin/wl-paste" <<'STUB'
#!/bin/bash
echo "wl-paste:$*" >>"$TEST_LOG"
printf 'Selected text'
STUB

cat >"$test_bin/utter" <<'STUB'
#!/bin/bash
echo "utter:$*:$(cat)" >>"$TEST_LOG"
STUB

chmod +x "$test_bin/wl-paste" "$test_bin/utter"

run_command() {
  : >"$log_file"
  PATH="$test_bin:$ROOT/bin:$PATH" TEST_LOG="$log_file" "$ROOT/bin/$1" </dev/null
}

run_command omarchy-utter-speak-selection
grep -qx 'wl-paste:--primary --no-newline' "$log_file" || fail "speak-selection reads the primary selection" "$(cat "$log_file")"
grep -qx 'utter:--toggle:Selected text' "$log_file" || fail "speak-selection toggles Utter with the selection" "$(cat "$log_file")"
pass "speak-selection pipes the primary selection into utter --toggle"

run_command omarchy-utter-speak-clipboard
grep -qx 'wl-paste:--no-newline' "$log_file" || fail "speak-clipboard reads the clipboard" "$(cat "$log_file")"
grep -qx 'utter:--toggle:Selected text' "$log_file" || fail "speak-clipboard toggles Utter with the clipboard" "$(cat "$log_file")"
pass "speak-clipboard pipes the clipboard into utter --toggle"

run_command omarchy-utter-stop
grep -qx 'utter:--stop:' "$log_file" || fail "stop calls utter --stop" "$(cat "$log_file")"
pass "stop calls utter --stop"

# Without Utter the bar indicator still needs one idle line, then the script ends.
missing_bin=$(mktemp -d)
for tool in bash cat; do
  ln -s "$(command -v "$tool")" "$missing_bin/$tool"
done
status_output=$(PATH="$missing_bin:$ROOT/bin" "$ROOT/bin/omarchy-utter-status")
rm -rf "$missing_bin"
[[ $status_output == '{"alt": "", "class": "idle", "tooltip": ""}' ]] ||
  fail "status reports idle when Utter is missing" "$status_output"
pass "status reports idle when Utter is missing"

grep -q 'utter --events --bar' "$ROOT/bin/omarchy-utter-status" ||
  fail "status follows the state file, never the socket"
pass "status follows the state file instead of the socket"
