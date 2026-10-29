# Immich photo library: build plan

Steps to build the design in [design.md](design.md). Each phase ends with a check, and the next phase starts only when it passes. Decision numbers (D1, D2, ...) refer to the design.

Commands below are sketches. Check `immich-go` flags against `--help` for the pinned version, and Immich settings against the docs for the pinned release, before running them.

## Phase 0: audit the laptop

- [ ] Confirm the laptop's management policies allow another VM.
- [ ] Confirm Hyper-V is enabled and BitLocker is on.
- [ ] Note which virtual switch the existing VM uses, and run `Get-NetNat`. Windows allows one NetNat, so if one exists, plan to reuse its subnet.
- [ ] Set power to never sleep, and set Windows Update active hours so restarts do not land during the upload.
- [ ] Confirm at least 300 GB free on the SSD.
- [ ] Save a copy of the current tailnet policy file, and list the connections other devices use today, so the new rules (D17) keep them working.

Check: no blocker from the audit.

## Phase 1: clean up on the Mac

- [ ] Review the two camera rolls and the Takeout exports, and delete what is not wanted. Deleted files go to the macOS Trash. Do not empty it yet.
- [ ] Leave `Recently Deleted`, Takeout trash, non-media files and `<other-exports>` alone. The upload skips or ignores them (D6, D7).
- [ ] Decide about `<unreviewed>` (design open question 1).

Check: the size of the upload sources, which should be about 135 GB.

## Phase 2: create the VM (`hyperv/new-vm.ps1`)

The script, run as administrator on the laptop:

```powershell
# Internal switch with a fixed NAT (D5)
New-VMSwitch -Name immich-nat -SwitchType Internal
New-NetIPAddress -IPAddress 192.168.250.1 -PrefixLength 24 -InterfaceAlias "vEthernet (immich-nat)"
New-NetNat -Name immich-nat -InternalIPInterfaceAddressPrefix 192.168.250.0/24

# VM (D3) with Disk A
New-VM -Name immich -Generation 2 -MemoryStartupBytes 6GB `
  -NewVHDPath "<vm-dir>\immich-a.vhdx" -NewVHDSizeBytes 60GB -SwitchName immich-nat
Set-VMMemory -VMName immich -DynamicMemoryEnabled $false
Set-VMProcessor -VMName immich -Count 6
Set-VMFirmware -VMName immich -SecureBootTemplate MicrosoftUEFICertificateAuthority
Set-VM -Name immich -AutomaticStartAction Start -AutomaticStopAction ShutDown

# Disk B (D4)
New-VHD -Path "<vm-dir>\immich-b.vhdx" -SizeBytes 220GB -Dynamic
Add-VMHardDiskDrive -VMName immich -Path "<vm-dir>\immich-b.vhdx"

# Installer
Add-VMDvdDrive -VMName immich -Path "<iso-dir>\debian-13-netinst.iso"
```

The script takes `<vm-dir>` and `<iso-dir>` as parameters, so no real paths are committed.

Check: the VM boots the Debian installer.

## Phase 3: set up Debian

- [ ] Install Debian 13 from the netinst image: SSH server and standard utilities, no desktop. Partition Disk A with the guided "encrypted LVM" option, ext4 for `/`, and store the passphrase in the password manager (D18).
- [ ] Static network: IP `192.168.250.10/24`, gateway `192.168.250.1`, a public DNS resolver.
- [ ] Disk B: create a LUKS volume with a random keyfile in `/etc/cryptsetup-keys.d/`, list it in `/etc/crypttab`, format it ext4, and mount it at `/srv/immich` by UUID in `/etc/fstab`.
- [ ] Remote unlock: install `dropbear-initramfs`, put your SSH public key in `/etc/dropbear/initramfs/authorized_keys`, give the initramfs the static IP (`IP=192.168.250.10::192.168.250.1:255.255.255.0::eth0:off` in `/etc/initramfs-tools/initramfs.conf`), and run `update-initramfs -u`.
- [ ] Firewall: nftables rule set that drops inbound traffic on `eth0` except established and related replies (D15).
- [ ] Install Docker Engine from Docker's apt repository. Turn on `unattended-upgrades` (D20).
- [ ] Tailnet policy: add `tag:immich`, the grants and the SSH rule from D17, plus grants for the connections listed in phase 0.
- [ ] Install Tailscale, then `tailscale up --ssh --hostname immich --advertise-tags=tag:immich` and `tailscale set --auto-update`.
- [ ] On Windows: `tailscale set --advertise-routes=192.168.250.10/32`, approve the route in the admin console, and turn on "Use Tailscale subnets" on the Mac.
- [ ] Once `tailscale ssh root@immich` works, remove `openssh-server` (D16).
- [ ] From the Mac, run `tailscale ping immich` and note whether the path is direct or relayed.

Check:

- [ ] Reboot the VM. From the Mac, `ssh root@192.168.250.10` reaches dropbear, and `cryptroot-unlock` boots the system.
- [ ] After boot, `tailscale ssh root@immich` works and `df -h` shows Disk B at `/srv/immich`.
- [ ] `ss -tlnp` shows nothing listening on `eth0` and no `sshd`.

## Phase 4: run Immich (`compose.yaml`, `.env.example`)

- [ ] Copy the official `docker-compose.yml` and `example.env` from the chosen release into `compose.yaml` and `.env.example`, and pin `IMMICH_VERSION`.
- [ ] `.env` values:
  - `UPLOAD_LOCATION=/srv/immich/library` (Disk B)
  - `DB_DATA_LOCATION=/var/lib/immich/postgres` (Disk A)
  - `DB_PASSWORD`: random, letters and digits only
- [ ] `chown root:root .env && chmod 600 .env`.
- [ ] In `compose.yaml`, publish the server as `127.0.0.1:2283:2283` (D15).
- [ ] Add bind mounts to the server service so thumbnails and transcodes stay on Disk A: `/var/lib/immich/thumbs` and `/var/lib/immich/encoded-video`, mounted over the matching folders under the container media path (`/data` in Immich v2; check for the pinned release).
- [ ] `docker compose up -d`, then `tailscale serve --bg 2283`. If the Phase 3 ping was relayed, use the Windows fallback in D5 instead.
- [ ] Open `https://immich.<tailnet>.ts.net`, create the admin user, and set:
  - Storage template on: `{{y}}/{{MM}}/{{filename}}` (D1)
  - Video transcoding: only videos not in an accepted format. Accepted codecs H.264 and HEVC, accepted containers MOV and MP4 (D9)
  - Machine learning: face recognition and smart search on. Lower the job concurrency for the first import (D10)
  - Database backup: nightly, keep 14 (D12)
- [ ] Store the admin password in the password manager (D19).
- [ ] Create an API key with only the upload permissions the release offers, and put it in the Mac's local `.env` with `chmod 600` (D19).

Check: from another tailnet device, `curl http://192.168.250.10:2283` fails, and `https://immich.<tailnet>.ts.net` loads. Upload one photo and one HEVC video from the web UI. Confirm the original lands under `/srv/immich/library/.../YYYY/MM/`, the thumbnail under `/var/lib/immich/thumbs`, and the video plays in the iPhone app. Delete both test assets.

## Phase 5: upload from the Mac (`upload.sh`)

`upload.sh` reads the server URL, API key and source paths from the Mac's `.env`, and runs each step under `caffeinate -i` through `nix run nixpkgs#immich-go --`.

Order:

1. `upload from-folder` on `<source-a>/Camera Roll`. Pointing at `Camera Roll` leaves out the sibling `Recently Deleted`.
2. `upload from-folder` on `<archive>/<source-b>/Camera Roll`.
3. `upload from-google-photos` on `<takeout-1>` and `<takeout-2>`, with trashed items excluded and album creation off (D8).

`<other-exports>` and `<unreviewed>` are not passed in, so they are not uploaded.

- [ ] Run all three with `--dry-run`. Read the report: counts of files to upload, duplicates, skipped trash, and Takeout files without a JSON match.
- [ ] Run them for real, while the other VM is idle. If a run stops, run it again. Files already uploaded are skipped.
- [ ] Wait for the thumbnail and ML jobs to finish (Administration, Jobs).

Check:

- [ ] Immich asset counts match the dry-run totals.
- [ ] 20 Takeout images that had no EXIF date show their real dates.
- [ ] A few Live Photos play as Live Photos, and a few HEVC videos play on the iPhone.
- [ ] Empty the macOS Trash from phase 1.
- [ ] Delete the upload API key in Immich and remove it from the Mac's `.env` (D19).

## Phase 6: phone backup

- [ ] Install the Immich iOS app and sign in at `https://immich.<tailnet>.ts.net`.
- [ ] Turn on background backup for Recents. Photos already uploaded match by checksum and are not sent again.
- [ ] Leave iCloud Photos on and do not use "free up space" (D11).
- [ ] Read the lost-phone runbook in the README once, so you know where the session list is.

Check: a new photo taken on the phone appears in Immich.

## Running it

- Upgrades: read the release notes, let the nightly dump run, bump `IMMICH_VERSION`, `docker compose pull && docker compose up -d`.
- Watch free space on Disk B and on the laptop SSD.
- After any Windows or VM reboot, unlock the disks (README runbook).

## Later

- Pick and set up the backup target (D12, design open question 2). It must be append-only from the VM's side.
- Move to the dedicated machine (D14): stand it up with the same `compose.yaml`, `rsync` `/srv/immich`, restore the latest dump, mount the originals at the same container path, move the Tailscale hostname `immich` to the new node, then retire the VM.
