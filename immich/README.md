# Immich photo library

Self-hosted Immich for a photo and video library, reachable from the phone over Tailscale only.

Status: designed, not built. Nothing in this folder has been deployed yet.

- [design.md](design.md): the agreed decisions, the architecture, the storage budget, and the open questions.
- [plan.md](plan.md): the build steps, phase by phase, with a check at the end of each phase.

Files that will land here when the build starts:

| File | Purpose |
|---|---|
| `compose.yaml` | Immich's official compose file, pinned to one release |
| `.env.example` | Placeholder values for `.env`, which stays gitignored |
| `hyperv/new-vm.ps1` | Creates the NAT switch, the VM and its two disks |
| `upload.sh` | Runs `immich-go` from the Mac, dry run first |

## Runbooks

### Unlock after a reboot

The VM's disks are encrypted (design D18), so Immich stays offline after any Windows or VM reboot until they are unlocked.

1. From the Mac, with "Use Tailscale subnets" on: `ssh root@192.168.250.10`.
2. Run `cryptroot-unlock` and enter the passphrase from the password manager.
3. The VM finishes booting and Docker starts Immich. Open `https://immich.<tailnet>.ts.net` to confirm.

### Lost or stolen phone

1. In Immich, Account settings, Authorized devices: log out the phone's session.
2. In the Tailscale admin console: remove the phone from the tailnet.
3. If the phone had the Immich password saved, change it.

This repository is public. Committed files hold no tailnet name, no real paths, no personal names, and no secrets.
