# Interview Sandbox

The purpose of this repository is to make it easy to create/destroy safe,
ephemeral VMs for interviews and technical challenges without worrying about
any malicious code being hidden within. It should be noted that this is not bulletproof by any means (VM-specific exploits, and attacks targeting the
host's hardware can still be effective etc), however this is still a worthwhile safety measure for most normal use-cases.

---

## Requirements
- [Multipass](https://multipass.run/install) — run `./install.sh` if you're not sure whether it's installed
- `ssh`, `git`, `openssl` (already on macOS/Linux)

---

## Cross-Platform Notes

- **macOS / Linux**: nothing platform-specific — use your normal terminal.
- **Windows**: `cmd.exe` and PowerShell can't run these scripts directly. Use **Git Bash** (installed with [Git for Windows](https://git-scm.com/download/win), which also gives you `ssh` and `openssl`) — install [Multipass for Windows](https://multipass.run/install) separately, then run every `./interview-sandbox` command from a Git Bash terminal. WSL also works, but Multipass still has to be the native Windows build (it needs Hyper-V) — don't install it inside your WSL distro; WSL picks up `multipass.exe` from the Windows PATH on its own.

---

## Steps

With the required packages installed, all you should have to do is spin up the VM, open the project, and kill the VM once you're done.
1. `./install.sh` (first time only, ensures that Multipass is installed)
2. `./interview-sandbox up` to spin up the VM (takes a few minutes to complete)]
   - This will print a password in your terminal, which must be entered into your browser at http://localhost:8080
   - <img width="300" height="200" alt="IS_SS_1" src="https://github.com/user-attachments/assets/b7c4e2b6-09f5-4109-a111-e3e1e79f6fbd" />
   - <img width="300" height="200" alt="IS_SS_2" src="https://github.com/user-attachments/assets/703f57f6-a017-402d-9644-ca00192c4cf2" />

3. `./interview-sandbox open <PROJECT_URL>` to open up the given challenge/codebase (runs a heuristic scan and a ClamAV check against the project for any obvious red flags)
   - This command will add the project to your browser IDE and can be opened under `/home/ubuntu/workspace/<PROJECT_NAME>`
   - Command/Control+J will open a terminal window in the browser IDE for installing additional dependencies etc.
   - <img width="300" height="200" alt="IS_SS_5" src="https://github.com/user-attachments/assets/14d5a336-167b-4fb0-858b-ac1acb1ec2f3" />

4. `./interview-sandbox destroy` to irreversibly tear down the VM.
