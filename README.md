# 📌 Environment Audit — LUA

**Environment Audit — LUA** is a lightweight, strict, and accurate diagnostic suite designed to benchmark Luau execution environments, security boundaries, and API coverage.

Unlike standard test suites that use weak wrappers to inflate compatibility scores, **Environment Audit — LUA** focuses on strict specification adherence and real execution integrity to give an honest assessment of what an executor can handle — and now, an honest *record* of that assessment you can compare across executors and over time.

---

## 🚀 Quick Start

To run the audit directly in your executor, execute the following snippet:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/SadManic/Environment-Audit--LUA-/refs/heads/main/main.lua"))()
```

---

## 📊 Audited Subsystems

- **⚙️ UNC Baseline** — Environment table reflection (`getgenv`, `getrenv`, `getreg`), metatable hijacking (`getrawmetatable`, `setrawmetatable`), read-only state toggling, closure/cclosure inspection, GC/instance enumeration, and standard file system I/O.
- **🛠️ Debug & Reflection** — Proxy instance virtualization (`cloneref`), instance identity mapping (`compareinstances`), closure inspection (`debug.getinfo`), upvalue mutation, and constant preservation.
- **🎨 Extended APIs** — Method interception (`__namecall`, `getnamecallmethod`), cryptography pipelines (`crypt` Base64), rendering (`Drawing` engine allocation), memory caching (`cache.invalidate`), and hidden GUI access (`gethui`).
- **🛡️ Execution Integrity & Sandboxing** — Function hook parameter passing, `game` metatable write-protection locks, call stack trace masking, and directory traversal containment.

Each test is scored **PASS/FAIL** via `pcall` — a test that errors, times out, or returns an unexpected value fails outright. There are no partial credits or soft fallbacks that quietly assume a broken API "probably works."

---

## ⚖️ Weighted Scoring

Not all subsystems matter equally for real-world script compatibility. Alongside the raw pass/fail percentage, results are also scored with per-category weights, so an executor that nails the core UNC baseline but is missing a couple of "nice to have" extras scores appropriately higher than one that's the reverse:

| Category | Weight |
|---|---|
| UNC Baseline | 3× |
| Debug & Reflection | 2× |
| Integrity & Sandbox | 2× |
| Extra APIs | 1× |

Both scores are printed in the summary:

```
Raw Score : 92.3%
Weighted  : 89.7%  🟡 GOOD
```

---

## 🔒 Hardened Security Checks

Two of the integrity tests were deliberately broadened beyond a single literal check, since narrow checks are easy for a leaky sandbox to accidentally pass:

- **Traceback filtering** no longer just searches for the word `"exploit"`. It checks `debug.traceback()` output against several patterns that indicate leaked internals — DLL/SO module names, absolute Windows/Unix paths, raw `[C]` stack frames, internal source directory naming, and bytecode leakage — and reports exactly which pattern matched on failure.
- **File system jail test** no longer tries a single `../../` traversal string. It attempts six variants — classic relative traversal, backslash traversal, absolute Unix paths, absolute Windows paths, doubled-dot-slash tricks, and URL-encoded traversal — and requires **all** of them to be blocked for a pass. Any that succeed are named individually in the failure message.

---

## 📤 CSV / JSON Export

Every run can now log its results to disk, so you can compare multiple executors — or track drift in the same executor across updates — instead of eyeballing console output each time.

Export is automatic: if `writefile`/`readfile` exist on the executor, both log files are written after every run. If they don't exist, the audit still runs and prints results normally — export is just skipped, and the summary's `Export:` line will say so.

### `unc_results_log.csv`

One row per test, per run — ideal for spreadsheets (sort, filter, pivot by executor or category):

```
timestamp,executor,version,test_name,category,status,error,raw_score_pct,weighted_score_pct
2026-08-04 14:32:10,SomeExecutor,3.1.2,hookfunction,UNC Baseline,PASS,,92.3,89.7
2026-08-04 14:32:10,SomeExecutor,3.1.2,getgc,UNC Baseline,FAIL,Missing getgc,92.3,89.7
```

New runs are appended below existing rows; the header is only written once.

### `unc_results_log.json`

A single JSON array where each element is one full run, with the complete per-test breakdown nested inside:

```json
[
  {
    "timestamp": "2026-08-04 14:32:10",
    "executor": "SomeExecutor",
    "version": "3.1.2",
    "passed": 24,
    "failed": 2,
    "total": 26,
    "raw_score_pct": 92.3,
    "weighted_score_pct": 89.7,
    "tests": [
      { "name": "hookfunction", "category": "UNC Baseline", "status": "PASS", "error": null },
      { "name": "getgc", "category": "UNC Baseline", "status": "FAIL", "error": "Missing getgc" }
    ]
  }
]
```

Unlike the CSV, the JSON log preserves nesting and types (numbers stay numbers), making it the better format if you want to feed results into a script or dashboard for programmatic comparison.

#### How the JSON export stays safe to append to

Since no JSON library ships with Luau/UNC executors, this script includes a **small hand-rolled JSON codec** (`JSON.encode` / `JSON.decode`) used specifically so the log file is never blindly string-spliced:

1. On each run, the existing log file (if any) is **actually parsed** with `JSON.decode`, not just pattern-matched.
2. The new run's results are appended to the resulting Lua table in memory.
3. The whole array is **re-encoded from scratch** with `JSON.encode` and written back.

If the existing file fails to parse as a JSON array (corrupted, manually edited, or from an incompatible tool), it is **not silently discarded**. It's copied to `unc_results_log.json.bak` first, and a fresh array is started — so a bad file becomes a recoverable backup instead of lost data.

The codec itself supports the full JSON value set (objects, arrays, strings with escapes including `\uXXXX`, numbers, booleans, null) and is covered by round-trip tests during development, including malformed-input handling (`JSON.decode` returns `nil, errorMessage` on bad input rather than throwing, so callers can fall back gracefully).

---

## 🖥️ Live-Animated Console Output

If a `DevConsoleMaster` CoreGui element is present, headers and the summary line are rendered with an animated rainbow gradient (`RenderStepped`-driven, throttled to ~30fps) and locked against external text overwrites. This is purely cosmetic and has no effect on scoring or export.

---

## 🤝 Contributing

Contributions, bug reports, and additional subsystem test requests are welcome! Feel free to open an Issue or submit a Pull Request.

## 📜 License

Distributed under the MIT License. See the `LICENSE` file for more information.
