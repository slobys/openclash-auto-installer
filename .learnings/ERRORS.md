# Errors

Command failures and integration errors.

---

## 2026-04-29 - GitHub raw branch cache served stale child script

Context: After pushing a SmartDNS uninstall fix, `raw.githubusercontent.com/.../main/uninstall.sh` still returned the old file while the commit-specific raw URL returned the fixed file. The menu downloaded child scripts from the branch URL, so the user kept receiving the stale uninstall logic.

Fix: Resolve the latest commit SHA via the GitHub commits API in `menu.sh`, then download child scripts from the immutable commit URL. README one-line command was switched to jsDelivr to reduce raw cache exposure.
