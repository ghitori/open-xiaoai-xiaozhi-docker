# 本地构建验证记录

日期：2026-11-15（Asia/Shanghai）
上游 commit：`58089a43f864a1c35082819b007572794a2a9f6c`（`OwnDing/open-xiaoai` `main`，2026-11-08）
基础镜像：`python:3.12-slim`（`sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b`）

## 为什么用 chroot

当前开发沙箱没有 Docker 守护进程，并且内核禁止 `mount`、`unshare` 和 user
namespace，因此 `docker build` / BuildKit / Podman 都无法运行（是宿主限制，
不是文件权限问题）。

为了在本地确认构建配方，我导出了官方 `python:3.12-slim` 的根文件系统
（与 Dockerfile 的 `FROM` 一致），用 `chroot` 逐条执行
`examples/xiaozhi/Dockerfile` 的 builder 和 runtime 步骤。除容器隔离、镜像
分层和 `/proc` 挂载外，软件版本、源码路径、Rust/Python 依赖解析与真实
Docker 构建一致。

## Builder 阶段

按 Dockerfile 顺序执行：

1. `apt-get install build-essential curl libopus-dev`
2. `curl https://sh.rustup.rs | sh -s -- -y --no-modify-path`
   - 实际版本：`rustc 1.100.0 (0ef1bc386 2026-11-09)`
3. `python -m pip install "uv>=0.7,<0.8"`
   - 实际版本：`uv 0.7.22`
4. 复制构建上下文：`examples/xiaozhi/*` → `/app`，
   `packages/client-rust` → `/app/client-rust`，
   并执行 `sed` 修正 `Cargo.toml` 路径
5. 下载并解压上游 `models.zip` 到 `/app/xiaozhi/models`
6. `cargo build --release`
   - 成功，`open_xiaoai_server` 扩展编译完成
   - `Finished release profile ... in 8.82s`
7. `uv remove pyaudio`
8. `uv sync --locked --no-install-project --no-editable`
   - 解析并安装 23 个包（numpy、onnxruntime 1.23.2、sherpa-onnx、
     opuslib-next、sentencepiece 等）
   - venv 约 188 MB
9. `uv run maturin build --release`
   - 生成 `open_xiaoai_xiaozhi-1.0.0-cp38-abi3-manylinux_2_34_x86_64.whl`
   - SHA-256：`ccb5cb46c343a387c1a141e6d5d370f3caa33298653eaa0ace74dc884854da6a`

## Runtime 阶段

用干净的 `python:3.12-slim` 根文件系统按 runtime 阶段执行：

1. `apt-get install libopus-dev curl`
2. 只复制 `/app/.venv`、`/app/main.py`、`/app/xiaozhi`、`/app/config.py`
   （真实部署时 config.py 由用户挂载）
3. 下载 ONNX Runtime 1.23.2（linux-x64），安装
   `libonnxruntime.so.1.23.2`、建立 `libonnxruntime.so` 软链接并 `ldconfig`
4. 设置 `CLI=true` 和
   `LD_LIBRARY_PATH=/usr/local/lib:/app/.venv/lib/python3.12/site-packages/onnxruntime/capi`
5. 导入检查输出：

   `imports ok 1.23.2`

   覆盖 `open_xiaoai_server`、`onnxruntime`、`sherpa_onnx`、
   `opuslib_next`、`numpy`、`xiaozhi.services.audio.codec.AudioCodec`。
6. 执行镜像入口会运行的
   `python xiaozhi/services/audio/kws/keywords.py`，输出：

   `天 猫 精 灵 @天猫精灵`
   `小 度 小 度 @小度小度`
   `豆 包 豆 包 @豆包豆包`
   `你 好 小 智 @你好小智`
   `你 好 小 爱 @你好小爱`
   `▁HI ▁S I RI`
   `▁HE Y ▁S I RI`

   说明模型（tokens.txt、bpe.model、VAD/KWS/ASR）和 sherpa-onnx 的
   `text2token` 在运行镜像中可用。

## 模型校验

| 文件 | SHA-256 |
| --- | --- |
| `bpe.model` | `bcae393dbc5611be5ffa4c7ae0841558978a5a4f484008cb9dff3a2cc97ebe01` |
| `tokens.txt` | `a8e0e4ec53810e433789b54a5c0134a7eaa2ffca595a6334d54c00da858841d3` |
| `silero_vad.onnx` | `2623a2953f6ff3d2c1e61740c6cdb7168133479b267dfef114a4a3cc5bdd788f` |
| `encoder.onnx` | `f559f422d970323e0c266aaa3c56cf6d1a3a4bc0c0822124727686c1e43e9447` |
| `decoder.onnx` | `2e3b5ec371f8899ee6acd829fd753ba45772df57a91bdf37cde3136354e7db7d` |
| `joiner.onnx` | `1ed689c5ed19dbaa725d9d191bb4822b5f4855a39e1ffd28cbc1f340d25b2ee0` |

运行时目录（`.venv` + 源码 + 模型）约 310 MB。

## 沙箱适配（仅本地验证，不影响 CI）

由于没有 `/proc`：

- rustup 安装时需要 `/proc/self/exe`，本地用了指向 `/bin/bash` 的临时软链接；
  安装后直接调用工具链里的 `cargo`/`rustc` 真实二进制。
- Rust 1.100 默认的 bundled lld wrapper 需要 `/proc/self/exe`，本地用
  `cc-wrapper` 去掉 `-fuse-ld=lld`，改走 GNU ld。
- ONNX Runtime 的 cpuinfo 需要 `/proc/cpuinfo`，本地复制了宿主的
  `/proc/cpuinfo`。

GitHub Actions 的 ubuntu-latest 有正常 `/proc`，不需要这些 workaround，直接
使用上游 Dockerfile。

## 未在本地验证的部分

- 真正的 `docker buildx build`（沙箱没有 Docker daemon）。
- 镜像分层、BuildKit 缓存和 GHCR 推送。
- `linux/arm64`（默认只构建 `linux/amd64`，需要时用 `workflow_dispatch` 的
  `platforms` 输入开启，走 QEMU）。
- 容器内音频设备、音箱连接和实际对话（需要真实硬件）。

这些由上线的 GitHub Actions 工作流完成；工作流最后用 `crane` 校验
`:latest`、日期标签和 `sha-<短SHA>` 三个标签，并断言镜像的
`org.opencontainers.image.revision` 等于上游 commit。
