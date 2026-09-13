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

- **macOS / Linux**: Nothing platform-specific — use your normal terminal.
- **Windows**: There are a handful Windows-specific hurdles to deal with:
  - Windows shell cannot run these scripts out of the box; you'll have to install [Git for Windows](https://git-scm.com/download/win), which also gives you `ssh` and `openssl`). You'll need to run these scripts using a Git-Bash terminal session, and the session needs to be run as administrator.
  - [Multipass for Windows](https://multipass.run/install) needs to be installed manually; the default driver of it should be VirtualBox, but if it isn't you can set it via `multipass set local.driver=virtualbox` (certain versions of Windows will only support VirtualBox as the driver). If you don't have VirtualBox on your machine already, you can get it [here](https://www.virtualbox.org/wiki/Downloads).
  - [PsExec](https://learn.microsoft.com/en-us/sysinternals/downloads/pstools) will also need to be installed separately, and added to your [PATH](https://learn.microsoft.com/en-us/previous-versions/office/developer/sharepoint-2010/ee537574(v=office.14)).

---

## Steps

With the required packages installed, all you should have to do is spin up the VM, open the project, and kill the VM once you're done.
1. `./install.sh` (first time only, ensures that Multipass is installed).
2. `./interview-sandbox up` to spin up the VM (takes a few minutes to complete); when this is finished an IDE connected to your VM will be hosted at [http://localhost:8080](http://localhost:8080).
    - <img width="300" height="200" alt="1a" src="https://github.com/user-attachments/assets/79c17d13-0427-4278-bd10-d4f0b51e882f" />
    - <img width="300" height="200" alt="1b" src="https://github.com/user-attachments/assets/85ce9daf-97f6-45fa-9fe3-5274544c8d34" />
3. `./interview-sandbox open <PROJECT_URL>` to open up the given challenge/codebase - this runs a heuristic scan and a ClamAV check against the project for any obvious red flags, and (assuming no flags are raised) makes the project available to your browser IDE under `/home/ubuntu/workspace/<PROJECT_NAME>`. Command+J (Control+J on Windows/Linux) will open a terminal window in the browser IDE for installing additional dependencies etc.
    - <img width="300" height="200" alt="2a" src="https://github.com/user-attachments/assets/5adbf174-381d-4481-99bc-14dc13dbbaff" />
    - <img width="300" height="200" alt="2b" src="https://github.com/user-attachments/assets/fa2e60f9-b44b-4f70-b159-b3441c08f751" />
4. `./interview-sandbox destroy` to irreversibly tear down the VM.
