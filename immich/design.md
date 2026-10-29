# Immich photo library: design

Agreed on 2026-10-29. Not built yet; [plan.md](plan.md) has the build steps.

## Goal

Merge two phone camera-roll exports and two Google Takeout exports into one Immich library, with correct dates, and browse it from the iPhone over Tailscale. Keep storage use low, keep the host responsive, and make a later move to a dedicated machine a copy-and-restore job.

## Sources

Measured on the Mac on 2026-10-28. Folder names are placeholders.

| Source | Size | Contents | Decision |
|---|---|---|---|
| `<source-a>/Camera Roll` | 46 GB | iPhone export, mostly HEIC and MOV | Upload |
| `<source-a>/Recently Deleted` | 8.2 GB | Phone trash | Skip |
| `<archive>/<source-b>/Camera Roll` | 69 GB | Second iPhone export | Upload |
| `<archive>/<takeout-1>`, `<takeout-2>` | 15 GB, 1.4 GB | Google Photos Takeout with 7,093 JSON sidecars | Upload with `immich-go` |
| `<archive>/<other-exports>` | 10 GB | Data exports from other services | Ignore, kept as a separate data backup |
| `<archive>/<unreviewed>` | 2.2 GB | Not reviewed | Open question |
| Non-media files | about 1,000 files | html, docx, pdf, source code, zip | Skip |

About 3,250 of the 6,083 Takeout images (53%) carry no EXIF taken date. Their only date is in the Google JSON sidecar, which is why the uploader matters (D6). The count comes from a byte scan for the EXIF `DateTimeOriginal` tag, so treat it as an estimate.

Files are culled by hand before the upload, aiming to drop about 10%, which leaves about 135 GB.

## Decisions

**D1. Immich owns the folder layout.** Files are uploaded into Immich, and the storage template files them as `{{y}}/{{MM}}/{{filename}}`. No hand-made folder tree and no external library. Moving the library later means moving one directory and one database dump.

**D2. Host is a Hyper-V Debian VM on an always-on Windows laptop, as a temporary home.** The laptop has spare CPU and RAM for the VM and 300 GB of free SSD. It already hosts another VM with a fixed memory cap, and it is a shared machine, so it gets audited before anything is installed (plan phase 0). Immich runs only on Linux and WSL is ruled out, so Immich gets its own VM. The VM also keeps the photo data apart from the other VM.

**D3. VM sizing.** Generation 2, 6 vCPUs, 6 GB of static RAM. Dynamic memory is off because Postgres performs badly when its memory is taken back. The VM starts when Windows boots and shuts down cleanly when Windows stops.

**D4. Two virtual disks, both dynamic VHDX on the laptop SSD, both ext4 inside.**

| Disk | Size | Mount | Holds |
|---|---|---|---|
| A | 60 GB | `/` | Debian, Docker, Postgres data, ML model cache, thumbnails, transcoded video |
| B | 220 GB | `/srv/immich` | Originals and Immich's nightly database dumps, nothing else |

Disk B alone rebuilds the library: originals plus a database dump. Thumbnails can be regenerated from it.

**D5. Network: internal switch with a fixed NAT, Tailscale inside the VM.** Every device is on Wi-Fi, and Hyper-V cannot bridge a VM over Wi-Fi reliably. The built-in Default Switch can change its subnet after a Windows restart. So `new-vm.ps1` creates an internal switch with a fixed `New-NetNat` subnet (for example `192.168.250.0/24`) and the VM gets a static IP. Tailscale runs in the VM with the hostname `immich`, and `tailscale serve` publishes Immich over the tailnet's HTTPS certificate at `https://immich.<tailnet>.ts.net`. No Funnel, no open ports. The phone URL survives the move to a new machine. If `tailscale ping immich` shows a relayed path instead of a direct one, Tailscale on Windows (which already connects directly) runs `tailscale serve` against the VM's fixed IP instead.

**D6. Uploader is `immich-go`, run once from the Mac.** `nix run nixpkgs#immich-go` (0.32.0 when checked) fetches it into the Nix store for the run without adding it to a profile. It reads the Takeout JSON for dates and GPS, skips Takeout trash, pairs Live Photo HEIC and MOV files, and skips files Immich already has by checksum. Every run starts with `--dry-run`. Rejected: the official Immich CLI and web uploader, which ignore the Takeout JSON and would file about 3,250 images under the export date.

**D7. Clean-up is manual, on the Mac, before upload.** No clean-up script. Trash folders, non-media files and exact duplicates need no manual work because the uploader skips them. Deleted files go to the macOS Trash, which is emptied only after the upload is verified.

**D8. One Immich user, no albums.** Both camera rolls and Takeout merge into one user's timeline. Takeout albums are not recreated.

**D9. Transcode only what the phone cannot play.** Viewing happens on the iPhone only. The transcode policy is "only videos not in an accepted format", with H.264 and HEVC as accepted codecs and MOV and MP4 as accepted containers. Almost nothing gets transcoded, which saves 20 to 40 GB against an "always" policy.

**D10. Face recognition and smart search stay on, on CPU.** The first pass over about 40,000 assets takes hours of CPU. Run it when the other VM is idle and lower the job concurrency until it finishes. After that the cost is small.

**D11. The iPhone backs up to Immich; nothing on the phone changes.** The Immich app backs up new photos in the background. iCloud Photos stays on and "free up space" stays unused until a real backup exists (D12).

**D12. Backup is deferred.** Until a backup target is chosen, the Mac's original folders are the fallback copy and stay in place. Immich's built-in nightly database dump writes to Disk B. Candidates for later: the Mac, a second USB drive, or `restic` to Backblaze B2 (about USD 1 a month for 150 GB). Whatever is chosen, the VM must not be able to delete or overwrite old backups: an append-only `restic` key, or B2 with Object Lock. Immich's 30-day trash covers accidental deletes, not someone with admin access.

**D13. Config lives in this public repository.** `immich/` holds the compose file, `.env.example`, the VM script, the upload script and these docs. The database password and the API key live only in `.env`, which `**/.env` in the root `.gitignore` already excludes. Committed files use placeholders for the tailnet name, paths and names.

**D14. Moving to a dedicated machine is copy and restore.** On the new Linux host, `rsync` the originals from Disk B and restore the latest database dump. Mount the originals at the same path inside the container as before, because the database stores container paths. If the new host runs VMs, `qemu-img convert -f vhdx -O qcow2` converts Disk B, and Proxmox `qm importdisk` takes VHDX directly. `qemu-nbd -f vhdx` mounts the file on any Linux machine if the laptop is gone. With D18, the disks are LUKS volumes, so the passphrase is needed to read them after any of these.

**D15. Immich listens only on the VM's loopback.** `compose.yaml` publishes the server as `127.0.0.1:2283:2283`, not `2283:2283`. Docker's published ports skip the host firewall, so a firewall rule cannot stand in for this. Only `tailscale serve` reaches Immich. Postgres and Valkey are never published. An nftables rule drops all inbound traffic on the NAT interface except replies. The Windows NAT gets no static mapping (`Add-NetNatStaticMapping`), so nothing on the LAN can reach the VM.

**D16. Admin access is Tailscale SSH only.** `tailscale up --ssh` handles logins, authenticated by tailnet identity. OpenSSH is removed once Tailscale SSH works. The only other SSH server is dropbear in the initramfs, used to unlock the disks (D18).

**D17. Tailnet access rules (proposed, confirm before the build).** The VM joins as `tag:immich`. Only your user can reach it, on 443 and SSH, and nothing is granted from the VM to other devices:

```json
"tagOwners": { "tag:immich": ["autogroup:admin"] },
"grants": [
  { "src": ["<your-user>"], "dst": ["tag:immich"], "ip": ["443"] },
  { "src": ["<your-user>"], "dst": ["192.168.250.10/32"], "ip": ["22"] }
],
"ssh": [
  { "action": "accept", "src": ["<your-user>"], "dst": ["tag:immich"], "users": ["root"] }
]
```

Tagged nodes have no key expiry, so no manual key-expiry setting is needed. If the tailnet still runs the default allow-all policy, replacing it changes access for every device, so the connections other devices rely on get listed first and added as grants (plan phase 0).

**D18. Both disks are encrypted inside the VM (proposed, confirm before the build).** BitLocker only helps if the laptop is stolen. Anyone with admin rights on Windows can copy the VHDX files, and thumbnails on Disk A show the photos as well as the originals on Disk B. So:

- Disk A uses Debian's guided "encrypted LVM" install, unlocked by a passphrase kept only in your password manager.
- Disk B is LUKS with a random keyfile stored on the encrypted root (`/etc/cryptsetup-keys.d/`), so it opens on its own once root is unlocked.
- After every boot, `dropbear-initramfs` listens on `192.168.250.10:22` and you unlock with `cryptroot-unlock`. You reach it from the Mac through Tailscale on Windows advertising the subnet route `192.168.250.10/32`. The same route is the D5 fallback.
- The cost: after any Windows or VM reboot, Immich stays offline until you unlock it. Windows Update reboots cause this.

**D19. Accounts, keys and sessions.** The admin password is long, unique, and kept in a password manager. The upload API key gets only the upload permissions the pinned release offers, and is deleted after the import (plan phase 5). The Mac's `.env` is `chmod 600`. Sensitive photos go in Immich's locked folder. No shared links are created. The README has a lost-phone runbook: revoke the phone's session in Immich and remove the phone from the tailnet.

**D20. Patching.** `unattended-upgrades` applies Debian security updates, and `tailscale set --auto-update` keeps Tailscale current. Immich stays pinned and is upgraded about monthly, after reading the release notes and after a nightly dump. No Watchtower or other automatic container updater. On the VM, `.env` is owned by root with mode `600`, and `DB_PASSWORD` is random.

## Architecture

```text
 Mac (Wi-Fi)                       Windows laptop (Wi-Fi), Hyper-V
 originals, fallback copy (D12)    +-----------------------------------------+
                                   |  tailscale (Windows): subnet route      |
                                   |    192.168.250.10/32 (D18, D5 fallback) |
                                   | internal switch + NetNat 192.168.250/24 |
        |                          |                                         |
        | immich-go upload         |  VM "immich", Debian, 6 vCPU, 6 GB      |
        | over Tailscale           |   tailscale (tag:immich, SSH on)        |
        +------------------------->|     serve :443 -> 127.0.0.1:2283        |
                                   |   docker compose: server, ML,           |
 iPhone (Immich app) ------------->|     Postgres, Valkey                    |
   browse + background backup      |   Disk A, LUKS: OS, Postgres, thumbs    |
                                   |   Disk B, LUKS: originals, DB dumps     |
                                   |                                         |
                                   |  other VM (existing, fixed memory cap)  |
                                   +-----------------------------------------+
```

## Storage budget

| Item | Size | Location |
|---|---|---|
| Originals after clean-up | about 135 GB | Disk B |
| Room for phone growth | about 85 GB | Disk B |
| Thumbnails and previews | about 13 GB for 40,000 assets | Disk A |
| Postgres | about 2 GB | Disk A |
| ML model cache | 1 to 2 GB | Disk A |
| Transcoded video | close to zero (D9) | Disk A |
| Total VHDX on the laptop | up to 280 GB of the 300 GB free | Laptop SSD |

The VHDX files are dynamic, so they only take what is written. When Disk B runs low, grow the VHDX or move to the new machine.

## Performance

- The first upload over Wi-Fi on both ends takes about 1 to 3 hours for 135 GB, if Tailscale connects directly. `caffeinate -i` keeps the Mac awake, and a re-run resumes.
- Thumbnail generation and the ML pass after the upload take several hours of CPU in the VM.
- After the first pass, browsing reads thumbnails from Disk A and only opens originals on demand.
- The other VM and the Immich VM have fixed memory, so neither can starve the other of RAM. They share CPU.

## Security

Immich is reachable only on the tailnet, with no Funnel and no port forwarding, so the remaining threats come from inside the setup.

| Threat | Control |
|---|---|
| Another device on the LAN or tailnet reaches Immich or its database | Loopback-only port and nftables (D15), tailnet rules (D17) |
| Someone logs in to the VM | Tailscale SSH only, OpenSSH removed (D16) |
| An admin on the shared laptop copies the VHDX files | LUKS inside the VM (D18). BitLocker only covers theft. |
| Workloads in the other VM | Separate VM with its own disks |
| Lost or stolen phone | Revoke its Immich session and remove it from the tailnet (D19, README runbook) |
| Leaked API key or `.env` | Scoped upload key deleted after import, `chmod 600` files, secrets never committed (D13, D19, D20) |
| Unpatched software | `unattended-upgrades`, Tailscale auto-update, pinned Immich upgraded monthly (D20) |
| Deletion by someone with admin access | Append-only backup once chosen (D12) |

The laptop is a shared machine. If it is wiped or repurposed, the library goes with it. This is accepted as temporary until D14.

## Risks

| Risk | Effect | Mitigation |
|---|---|---|
| Laptop disk failure before a backup exists | Library and phone uploads since setup are lost | Mac originals stay (D12), iCloud stays on (D11), pick a backup soon |
| Tailscale connection is relayed | Upload and browsing are slow | D5 fallback through Tailscale on Windows |
| Windows already has a `NetNat` | `New-NetNat` fails, since Windows allows only one | Check `Get-NetNat` in phase 0 and reuse or adjust |
| Immich release with breaking changes | Upgrade fails | Pin `IMMICH_VERSION`, read release notes, upgrade after a nightly dump |
| Takeout JSON not matched to a file | Some photos get the wrong date | Check the dry-run report and spot-check dates (plan phase 5) |
| Windows reboots for updates | Immich stays offline until the disks are unlocked (D18) | Windows Update active hours, unlock runbook in the README |
| LUKS passphrase lost | The library cannot be read, only re-imported from the Mac originals | Keep it in the password manager, test it in phase 3 |
| New tailnet rules miss a connection another device needs | That device loses access | List current connections in phase 0 and keep a copy of the old policy |

## Open questions

1. What is in `<archive>/<unreviewed>` (2.2 GB), and does it get uploaded? If it does, should it go into Immich's locked folder?
2. Which backup target (D12)?
3. What hardware is the dedicated machine (D14)? Any always-on box with room for the disks works.
4. Which Immich release to pin when the build starts.
5. Confirm D17 (tailnet rules) and D18 (disk encryption with manual unlock), both proposed.
