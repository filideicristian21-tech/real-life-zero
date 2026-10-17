#!/usr/bin/env bash
# Esegue i test automatici headless in due processi (il secondo verifica la riapertura) e controlla il log.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/workspace/tools/godot}"
LOG=tests/test_log.txt
rm -f tests/results.json
timeout 400 "$GODOT" --headless --path . res://tests/run_tests.tscn -- --phase=all > "$LOG" 2>&1; c1=$?
timeout 200 "$GODOT" --headless --path . res://tests/run_tests.tscn -- --phase=reopen >> "$LOG" 2>&1; c2=$?
# errori di script o del motore durante l'uso (esclusi i messaggi di leak in chiusura del processo headless)
grep -E "SCRIPT ERROR|^ERROR|USER ERROR" "$LOG" | grep -vE "resources still in use at exit|RID allocations of type|ObjectDB instances were leaked" > tests/errors.txt
nerr=$(wc -l < tests/errors.txt)
echo "processo 1 exit=$c1, processo 2 exit=$c2, errori nel log=$nerr"
grep -E "^\[(PASS|FAIL)\]|RESULT" "$LOG"
[ $c1 -eq 0 ] && [ $c2 -eq 0 ] && [ "$nerr" -eq 0 ]
