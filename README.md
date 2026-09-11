# InterviewSandbox

Run untrusted take-home / live-coding interview challenges in a disposable,
isolated VM — never on your host machine, never touching your host filesystem.

One command spins up an Ubuntu VM (via [Multipass](https://multipass.run))
with Python, Ruby, Node, and Neovim preinstalled, running
[code-server](https://github.com/coder/code-server) so you work entirely from
your browser. Another command destroys it, along with everything in it.

## Requirements

- [Multipass](https://multipass.run/install) — run `./install.sh` if you're not sure whether it's installed
- `ssh`, `git`, `openssl` (already on macOS/Linux)

## Usage

```
./interview-sandbox up
./interview-sandbox open https://github.com/example/challenge-repo
./interview-sandbox destroy
```

- **`up`** launches the VM, waits for provisioning, opens an SSH tunnel to
  code-server, and opens it in your browser.
- **`open <repo-url>`** clones the repo *inside the VM* (never on your host),
  runs it through ClamAV plus a few heuristic checks for obviously sketchy
  patterns (curl-pipe-to-shell, base64-decoded-and-executed, etc.), and only
  then moves it into your workspace folder.
- **`scan <repo-url>`** runs the same checks without adding the repo to your
  workspace, if you just want a read before deciding.
- **`code`** reopens the browser tunnel if you closed it without destroying
  the VM.
- **`status`** shows whether a sandbox VM currently exists and its state.
- **`destroy`** deletes the VM and all local sandbox state (SSH keys, config,
  tunnel). Nothing persists between sessions by design.

## How isolation works

- Challenge code is cloned *inside* the VM's own disk — never mounted from or
  written to your host filesystem.
- code-server is only reachable via an SSH tunnel bound to `localhost` — it's
  never exposed on the VM's network interface.
- SSH access uses a dedicated keypair and a scoped known_hosts file, generated
  fresh per session and wiped on `destroy` — nothing touches your normal
  `~/.ssh/config` beyond a single `Include` line pointing at `~/.ssh/config.d/`.

## What this doesn't protect against

- The scan is a heuristic aid, not a guarantee — always review code you don't
  trust before running it, even inside the sandbox.
- Multipass VMs share your machine's CPU and network interface at the
  hypervisor level; this is VM-grade isolation, not an air-gapped machine.

## License

MIT
