**Environment Audit—LUA** is a lightweight, strict, and accurate diagnostic suite designed to benchmark Luau execution environments, security boundaries, and API coverage. 

Unlike standard test suites that use weak wrappers to inflate compatibility scores, **Environment Audit—LUA** focuses on strict specification adherence and real execution integrity to give an honest assessment of what an executor can handle.

---

## 🚀 Quick Start

To run the audit directly in your executor, execute the following snippet:

loadstring(game:HttpGet("[https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/main.lua](https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/main.lua)"))()

📊 Audited Subsystems
⚙️ UNC Baseline: Environment table reflection (getgenv, getrenv, getreg), metatable hijacking (getrawmetatable, setrawmetatable), read-only state toggling, and standard file system I/O.

🛠️ Debug & Reflection: Proxy instance virtualization (cloneref), instance identity mapping (compareinstances), closure inspection (debug.getinfo), upvalue stack frame mutation, and constant preservation.

🎨 Extended APIs: Method interception (__namecall, getnamecallmethod), cryptography pipelines (crypt Base64), rendering (Drawing engine allocation), memory caching (cache.invalidate), and hidden GUI access (gethui).

🛡️ Execution Integrity & Sandboxing: Function hook parameter passing, game metatable write protection locks, call stack trace masking (debug.traceback), and directory traversal containment (../../).

💻 Sample Output

--------------------------------------------------
             EXECUTOR DIAGNOSTICS                
--------------------------------------------------
Executor : Velocity
Version  : 1.3.6
Thread ID: 8
--------------------------------------------------

Running tests...

--------------------------------------------------
                  DETAILED LOGS                   
--------------------------------------------------

--- [UNC Baseline] ---
   Environment Tables             : ✅ PASS
   getrawmetatable                : ✅ PASS
   setrawmetatable                : ✅ PASS
   ...

--- [Debug & Reflection] ---
   cloneref                       : ❌ FAIL
      ↳ Proxy equality check failed
   debug.getupvalues / setupvalue : ❌ FAIL
      ↳ setupvalue failed to change upvalue
   ...

--------------------------------------------------
                     SUMMARY                      
--------------------------------------------------
Executor : Velocity (1.3.6)
Passed   : 29
Failed   : 2
Total    : 31
Score    : 93.5%
--------------------------------------------------
🤝 Contributing
Contributions, bug reports, and additional subsystem test requests are welcome! Feel free to open an Issue or submit a Pull Request.

📜 License
Distributed under the MIT License. See the LICENSE file for more information.
