"""Locate the shells the recipes run on: bash (Git Bash on Windows, never the WSL stub) and PowerShell
(pwsh 7 everywhere it exists, plus Windows PowerShell 5.1 on Windows)."""
import os
import shutil


def bash_path():
    if os.name == "nt":
        for p in (r"C:\Program Files\Git\bin\bash.exe", r"C:\Program Files\Git\usr\bin\bash.exe"):
            if os.path.exists(p):
                return p
        git = shutil.which("git")
        if git:
            p = os.path.join(os.path.dirname(os.path.dirname(git)), "bin", "bash.exe")
            if os.path.exists(p):
                return p
        return None
    return shutil.which("bash")


def powershell_paths():
    found = []
    pwsh = shutil.which("pwsh")
    if pwsh:
        found.append(pwsh)
    if os.name == "nt":
        win = shutil.which("powershell")
        if win:
            found.append(win)
    return found


def shell_env(shell):
    """Windows PowerShell 5.1 started from a pwsh 7 process inherits pwsh's PSModulePath and then fails
    to load its own built-in modules (e.g. Get-FileHash). Without the variable it rebuilds its default."""
    env = dict(os.environ)
    if os.path.splitext(os.path.basename(shell))[0].lower() == "powershell":
        for k in [k for k in env if k.upper() == "PSMODULEPATH"]:
            del env[k]
    return env
