# Qwen3.8 vLLM switching

The PC serves two local vLLM backends through llama-swap:

| Model ID | Legacy alias | Checkpoint directory |
|---|---|---|
| `qwen3.8-27b` | `qwen3.8:27b-q5` | `/var/lib/club-3090-vllm/models/qwen3.8-27b-autoround-int4` |
| `qwen3.8-27b-uncensored` | `qwen3.8:27b-q5-abliterated-mtp` | `/var/lib/club-3090-vllm/models/qwen3.8-27b-huihui-autoround` |

Both projects use the draft model at
`/var/lib/club-3090-vllm/models/qwen3.8-27b-dflash2-w4a16`. The files must
already exist; startup is offline and refuses missing configuration or weight
files. `/home/basnijholt/.local/bin/cf` must also exist and remain executable.

llama-swap owns at most one of these GPU projects. The persistent embedding
group remains separate. A first request starts the selected container and can
take several minutes while vLLM loads weights and prepares its caches. `ttl: 0`
keeps that backend resident until another incompatible model is requested or it
is explicitly unloaded. Measured cold first responses were 315.6 seconds for
normal and 341.2 seconds for uncensored. Set client HTTP and SDK timeouts to at
least 600 seconds for requests that can trigger a load or swap. Switching back
can still take minutes even when compilation artifacts are cached.

## Required migration before merge or activation

The PC follows the `main` branch through comin, so complete this migration
before merging a change that enables these units. A later manual rebuild is not
guaranteed to be the first activation.

The generated recipes use `pull_policy: never` so an API request cannot trigger
an image download. Pre-pull both exact pinned images on the PC before merging or
activating this configuration:

```bash
docker image pull \
  vllm/vllm-openai:v0.29.0@sha256:c2914767605584b6d8f45686b82de173ecc99e781897aa3d0a66dacd72c51ae1
docker image pull \
  ghcr.io/antonprokopyev/fa2-fp8kv-sm86@sha256:da040941fa048fd5fdfce520503341c0beda4ce41436a1c1fecaf3f8a99777c7
```

These explicit pulls are the only image-fetch step. Confirm both commands
complete before continuing with the routing migration below.

The global Compose Farm registry currently owns `club-3090-vllm`. Removing that
entry also removes its generated Traefik routers. First create a separate static
file on the NAS at
`/opt/stacks/traefik/dynamic.d/llama-swap-qwen38.yml`:

```yaml
http:
  routers:
    llama-swap-qwen38-secure:
      rule: Host(`club-3090-vllm.lab.nijho.lt`)
      middlewares:
        - local-ips-only@file
      entryPoints:
        - websecure
      service: llama-swap-qwen38
      tls:
        certResolver: le
    llama-swap-qwen38-local:
      rule: Host(`club-3090-vllm.local`)
      entryPoints:
        - web
      service: llama-swap-qwen38
  services:
    llama-swap-qwen38:
      loadBalancer:
        servers:
          - url: http://192.168.1.5:8010
```

Confirm Traefik loaded both static routers. Then remove only this line from
`/opt/stacks/compose-farm.yaml`:

```yaml
  club-3090-vllm: pc
```

Regenerate the global Traefik fragment without applying the global farm:

```bash
cf traefik-file --all \
  --config /opt/stacks/compose-farm.yaml \
  --output /opt/stacks/traefik/dynamic.d/compose-farm.yml
```

Do not use a global `cf apply` for this rollout. The two new projects use their
own `/etc/llama-swap/compose-farm.yaml` and are intentionally absent from the
global registry. Removing the legacy registry entry prevents a future global
reconcile from relaunching it.

Activation runs `llama-swap-vllm-retire-legacy.service`. It inspects only the
`club-3090-vllm` container, changes that container's restart policy to `no`, and
stops it if it is running. Unknown Docker errors fail the migration. The port
8010 socket starts only after that unit succeeds and forwards to llama-swap on
port 9292.

## Build and activate

From the dotfiles repository root, build the focused artifact without root:

```bash
nix build \
  'path:./configs/nixos#nixosConfigurations.pc.config.system.build.llama-swap-vllm'
```

The result contains `bin/vllm-swap` and the complete generated tree under
`etc/llama-swap/`. Inspect either recipe without starting a container by
pointing the dedicated configuration at the materialized bundle:

```bash
bundle=$(readlink -f result)
LLAMA_SWAP_PORT=18080 cf compose \
  --config <(sed \
    "s#/etc/llama-swap/stacks#$bundle/etc/llama-swap/stacks#" \
    "$bundle/etc/llama-swap/compose-farm.yaml") \
  qwen38-normal config
```

After the model directories, Compose Farm retirement, and static Traefik routes
are ready, activate the host configuration:

```bash
sudo nixos-rebuild switch --flake 'path:./configs/nixos#pc'
systemctl status llama-swap.service llama-swap-port-8010.socket
curl --fail http://127.0.0.1:9292/v1/models
curl --fail http://club-3090-vllm.local/v1/models
```

A successful model-list response confirms the proxy configuration, but does not
prove that model weights are loaded. Before relying on normal clients, complete
a synthetic chat request over loopback with a timeout that covers startup:

```bash
curl --fail-with-body --silent --show-error --max-time 600 \
  http://127.0.0.1:9292/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.8-27b","messages":[{"role":"user","content":"Reply with READY."}],"max_tokens":8,"temperature":0}'
```

Only a completed chat response proves that the selected backend is ready. Use
the uncensored model ID in the same request when that backend must be prewarmed;
doing so swaps out normal because the two GPU projects are exclusive.

## Roll back

Stop the proxy and return to the previous NixOS generation before restarting
the legacy stack, so only one process can bind port 8010:

```bash
sudo systemctl stop llama-swap-port-8010.socket llama-swap.service
sudo nixos-rebuild switch --rollback
```

Restore `club-3090-vllm: pc` in `/opt/stacks/compose-farm.yaml`, regenerate the
global Traefik fragment with the command above, and then restart only the old
stack:

```bash
docker update --restart=unless-stopped club-3090-vllm
cf up --config /opt/stacks/compose-farm.yaml club-3090-vllm
```

After confirming the generated `club-3090-vllm` routers work, remove the static
`llama-swap-qwen38.yml` file. Avoid a global `cf apply` during rollback as well.

## Pinned provenance

- Recipe assets: `noonghunna/club-3090` revision
  `9abbf961602e6a0bd4920d606f78a6b99826e195`, derived from
  `models/qwen3.8-27b/vllm/compose/dual/autoround-int4/dflash2.yml`.
- vLLM image: `vllm/vllm-openai:v0.29.0` at digest
  `sha256:c2914767605584b6d8f45686b82de173ecc99e781897aa3d0a66dacd72c51ae1`.
- FA2 artifact image: `ghcr.io/antonprokopyev/fa2-fp8kv-sm86` at digest
  `sha256:da040941fa048fd5fdfce520503341c0beda4ce41436a1c1fecaf3f8a99777c7`,
  artifact ID `731d1942112a7cf35be4f0add0919072c06cac47e3bad4f674ff0157edad0e3f`.
- Normal checkpoint: `Frozenlock/Qwen3.8-27B-int4-AutoRound`, cached revision
  `b4c61732c4f2d8af323d75ba5702b5c7f3361539`.
- Uncensored checkpoint:
  `ababaka/Huihui-Qwen3.8-27B-Abliterated-W4A16-AutoRound`, revision
  `c20530baefe3e77ccfc6891c2b50cce7ea28bf1e`.
- Draft checkpoint: `syvai/Qwen3.8-27B-DFlash2-W4A16`; downloaded metadata
  records revision `4d30ec736ffc6b8688dc2ae2b502d9b48bdec279`.
- The uncensored project applies HyperQwen's
  `qwen3_5-embed-quant.patch` from revision
  `c0c81bbbbf91f11b54af7b95f49bd6d1570c2ba0`, SHA-256
  `85ef4089c09cd478e44fc96175de8e69ccd1e16fa8ee895942a4d8a4137d51fd`.

The configuration fixes TP2, BF16 activations, FP8 e4m3 KV, a 60,000-token
context, DFlash2 width 7, maximum sequence count 1, GPU utilization 0.65, and
thinking disabled by default. Prior isolated probes established that these
specific checkpoints can start and answer selected requests. They do not
establish general model equivalence, unrestricted behavior, or broad accuracy.
