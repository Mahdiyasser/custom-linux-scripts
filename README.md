# 🛠️ My Bash Toolkit

This repository contains a collection of scripts I built to make my daily workflow on **Linux Mint Cinnamon** (Ubuntu-based) a bit smoother. They might not change the world, but they certainly save me some keystrokes. Feel free to use them as-is or tweak them to fit your own needs.

> **Note:** Since these were made for my personal setup, I haven't written exhaustive documentation—just a quick "how-to" for each tool.

---

## 🚀 1. Push
**The "Lazy Git" Tool**

I made this to simplify the process of publishing changes to a repository without typing the same three commands every time.

### 🛠️ How to use it:
* Copy the file into your repository and make it executable.
* **Standard usage:** Run the script, and it will execute `git add . && git commit && git push` automatically.
* **Commit Messages:**
    * It uses a default message (set to "Update" by default).
    * You can change the default by editing this line in the script: `commit_msg="Update"`.
    * Or, provide a custom message on the fly: `./push "YourCommitMessageHere"`.

---

## ⚡ 2. Start
**The Morning Ritual Automator**

I have a specific routine when I open my laptop: mounting disks, applying keyboard layouts, and starting services like MySQL and Apache. Doing this manually every day was annoying, so I automated it.

### 🛠️ How to use it:
* Move the file to `/usr/local/bin` to use it as a standard command and make it executable.
* **Configuration:** You *must* edit the following variables inside the script to match your system:

| Variable | Description |
| :--- | :--- |
| `XMOD_FILE` | Path to your custom `.Xmodmap` layout file |
| `MOUNT_DEV` | The device identifier (e.g., `/dev/sda4`) |
| `MOUNT_POINT` | Where you want the drive mounted (e.g., `/media/mahdi/D-drive`) |
| `LOG_FILE` | Where to save logs (default is `~/startup.log`) |
| `START_SERVICES_CMD`| The command to start your services |

* **Logs:** You can check your logs using `nano ~/startup.log` or your favorite GUI text editor.

---

## 🌐 3. Webuild
**The Instant Scaffolder**

I built this one day when I was bored and wanted a way to instantly generate essential website files so I wouldn't have to create them manually every time.

### 🛠️ How to use it:
* Move the file to `/usr/local/bin` and make it executable.
* You can run it in your current directory or provide a path (relative or absolute).
* The script will even create the directory for you if it doesn't exist.

| Command | Files Created |
| :--- | :--- |
| `webuild static` | `index.html`, `style.css`, `script.js` |
| `webuild dynamic` | `index.html`, `style.css`, `script.js`, `server.php` |
| `webuild platform`| `index.html`, `style.css`, `script.js`, `server.php`, `data.json` |

**Example Usage:**
* `webuild static ./new-page`
* `webuild dynamic /var/www/html`

---

## 🖱️ 4. Open In Browser
**The Nemo Context Menu Mapper**

I made this great Nemo action to instantly map my local development directories to their respective network URLs. It adds a handy right-click option in the Nemo file manager to open a local path directly in the browser with the correct IP and port routing.

### 🛠️ How to use it:
You can find the necessary files for this tool in the `Open-In-Browser` folder in this repository.

**Installation:**
1. **The Script:** Copy `open-in-browser.sh` to your local bin and make it executable:
   `cp Open-In-Browser/open-in-browser.sh ~/.local/bin/`
   `chmod +x ~/.local/bin/open-in-browser.sh`
2. **The Action:** Copy the Nemo action file (e.g., `open-in-browser.nemo_action`) to your Nemo actions directory:
   `cp Open-In-Browser/*.nemo_action ~/.local/share/nemo/actions/`
3. **Restart Nemo:** Apply the changes by running `nemo -q` in your terminal. 

**Configuration:**
This action is hardcoded to specific network IPs and drive paths. You will need to edit both files to match your environment:
* **open-in-browser.sh:** Change the `/media/mahdi/D-drive/` paths to your actual working directories. Update the IPs (`192.168.1.32`) and ports (`6060`, `6061`, `60`) to match your local server setups.
* **.nemo_action file:** Update the `Exec=` line to point to your correct home folder path. You should also update the `Conditions=path:` line to match the drive you want this right-click option to appear in.

---

## That's it for now
