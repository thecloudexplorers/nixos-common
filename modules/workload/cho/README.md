# cho

Ollama model server and HTTPS reverse proxy (container `cho-1`).

## Access

- API endpoint: `https://ollama.raboes28.nl` (HTTPS on port `443`)
- Ollama listens only on `127.0.0.1:11434`; the container firewall opens only
  the HTTPS proxy port, `443`.
- The API has no user authentication. Keep this endpoint on your LAN/VPN and
  do not forward port `443` from the internet. This endpoint is served directly
  by `cho-1`, not through Baleroc.
- The router needs a DHCP reservation for MAC `02:38:9a:9f:02:ab`. Point the
  LAN DNS record for `ollama.raboes28.nl` at that reserved address.

## Handy commands

Run on the host.

```bash
# Shell / logs
sudo nixos-container root-login cho-1
sudo nixos-container run cho-1 -- journalctl -u ollama.service -f
sudo nixos-container run cho-1 -- journalctl -u nginx.service -f

# Models
sudo nixos-container run cho-1 -- ollama list
sudo nixos-container run cho-1 -- ollama run gemma4:e4b

# Check the HTTPS endpoint and certificate
curl -sS https://ollama.raboes28.nl/api/tags
echo | openssl s_client -connect ollama.raboes28.nl:443 -servername ollama.raboes28.nl 2>/dev/null | openssl x509 -noout -dates -subject

# Container lifecycle (avoid unless recovering)
sudo nixos-container restart cho-1
```

## What runs here

- Ollama listens on localhost port `11434`, so it is not directly exposed to
  the LAN.
- Nginx terminates TLS using the certificate issued by [medivh](../medivh/README.md)
  and proxies requests to Ollama on port `11434`.
- The models in `loadModels` (currently `qwen3.6:35b`, `laguna-xs-2.1`,
  `gemma4:26b`, `gemma4:e4b` and `qwen3.5:9b-q8_0`) are downloaded automatically.
  Choose one per request with
  the `model` field; Ollama loads it on demand and unloads idle models.
  `syncModels = true` keeps the installation synchronized with that list and
  removes any other model when the service restarts, so update
  [service-ollama.nix](service-ollama.nix) before adding other persistent models.

## Test the API

Run from any machine on the LAN/VPN that resolves `ollama.raboes28.nl`.

```bash
# List installed models
curl -sS https://ollama.raboes28.nl/api/tags

# Chat (single JSON response)
curl -sS https://ollama.raboes28.nl/api/chat -d '{
  "model": "qwen3.5:9b-q8_0",
  "messages": [{"role": "user", "content": "How old is your training data?"}],
  "stream": false
}'

# Chat (streamed, one JSON object per line; this is the default)
curl -sS https://ollama.raboes28.nl/api/chat -d '{
  "model": "qwen3.5:9b-q8_0",
  "messages": [{"role": "user", "content": "Say hello in one sentence."}]
}'

# Show only the answer text (requires jq)
curl -sS https://ollama.raboes28.nl/api/chat -d '{
  "model": "gemma4:e4b",
  "messages": [{"role": "user", "content": "Say hello in one sentence."}],
  "stream": false
}' | jq -r '.message.content'

# OpenAI compatible endpoint
curl -sS https://ollama.raboes28.nl/v1/chat/completions -d '{
  "model": "gemma4:e4b",
  "messages": [{"role": "user", "content": "Say hello in one sentence."}]
}'
```

The first request after a restart or idle period is slow because the model
must be loaded into GPU memory. Afterwards, check on the host that it runs on the
GPU with `sudo nixos-container run cho-1 -- ollama ps` (`PROCESSOR` should read
`100% GPU`).

The context window is set to 64k (`OLLAMA_CONTEXT_LENGTH`). Ollama's OpenAI
compatible endpoint ignores a client's context setting and otherwise uses a much
smaller default, which silently truncates long prompts such as Hermes' (the
agent then loses the earlier conversation). `ollama ps` shows the loaded
context in the `CONTEXT` column.

## GPU (NVIDIA CUDA)

Ollama runs the CUDA build (`pkgs.ollama-cuda`) on the host's NVIDIA GPU.

- [container-1/container-1.nix](container-1/container-1.nix) bind mounts
  `/dev/nvidia0`, `/dev/nvidiactl` and `/dev/nvidia-uvm` and allows them in the
  container's device cgroup (`allowedDevices`); both are required.
- The container reuses the host's pinned driver package
  (`config.hardware.nvidia.package`) for its userspace libraries, so they always
  match the host kernel driver. A separate driver from the container's nixpkgs
  causes `Driver/library version mismatch`. The `.out` output must be linked
  (it holds `libcuda`); the default `bin` output does not, and Ollama then
  silently falls back to the CPU.
- After a host driver update, restart the container so it picks up the new
  version: `sudo nixos-container restart cho-1`.

```bash
# Driver and GPU visible in the container
sudo nixos-container run cho-1 -- nvidia-smi

# Ollama should report library=CUDA and the VRAM size, not id=cpu
sudo nixos-container run cho-1 -- journalctl -u ollama.service -b --no-pager | grep -iE "inference compute|vram"

# After loading a model, PROCESSOR should read 100% GPU
sudo nixos-container run cho-1 -- ollama ps

# Watch GPU utilization and VRAM live while sending a request (Ctrl+C to stop)
watch -n 1 nvidia-smi

# The ollama process should be listed with its VRAM usage
sudo nixos-container run cho-1 -- nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
```

## Persistent data

- `/mnt/ssd/cho/1/var/lib/ollama` stores Ollama service state.
- `/mnt/ssd/cho/1/var/lib/ollama/models` stores downloaded models. They are on
  the SSD (not the `zdata` pool) so loading a model into VRAM is fast. Models
  can be downloaded again, so they are not backed up.
- `/mnt/ssd/medivh/1/var/lib/acme/ollama.raboes28.nl` provides the read-only TLS
  certificate.
