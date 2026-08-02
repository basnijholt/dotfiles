# GCE agent box

Generic NixOS configuration for a private Google Compute Engine workstation.
Cloud resources remain outside this public repository.

The VM must initially run x86_64 Ubuntu, allow passwordless sudo for the configured SSH user, expose SSH through IAP, and attach a blank persistent disk with device name `agent-work`.

Install NixOS:

```bash
./deploy.py --project PROJECT --zone ZONE --instance INSTANCE deploy
```

Initialize or unlock the encrypted work disk.
Passphrase input stays attached to the remote terminal and is never passed as a command argument:

```bash
./deploy.py --project PROJECT --zone ZONE --instance INSTANCE unlock-work
```

Open a shell or inspect VM status:

```bash
./deploy.py --project PROJECT --zone ZONE --instance INSTANCE ssh
./deploy.py --project PROJECT --zone ZONE --instance INSTANCE status
```

Run coding agents and keep credentials under `/work`.
The boot disk is not guest-encrypted.
Lock the work disk before stopping the VM when practical:

```bash
sudo agent-work-disk lock
```
