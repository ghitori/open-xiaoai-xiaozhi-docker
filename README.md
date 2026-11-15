# Open-XiaoAI x 小智 AI · Docker 自动构建

[![Build and publish](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/actions/workflows/docker.yml/badge.svg)](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/actions/workflows/docker.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-open--xiaoai--xiaozhi--docker-2496ed?logo=docker&logoColor=white)](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/pkgs/container/open-xiaoai-xiaozhi-docker)

跟随 [OwnDing/open-xiaoai](https://github.com/OwnDing/open-xiaoai) 的
[`examples/xiaozhi`](https://github.com/OwnDing/open-xiaoai/tree/main/examples/xiaozhi)
自动构建并公开发布的 Docker 镜像。构建、版本号、标签全部由 GitHub Actions
完成，不需要本地推镜像。

> [!IMPORTANT]
> 这是非官方构建。镜像内的代码、模型和文档均来自上游
> [OwnDing/open-xiaoai](https://github.com/OwnDing/open-xiaoai)（MIT），
> 本项目只包含构建自动化。请遵守上游的免责声明，建议只在局域网内使用。

## 镜像

```text
ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:latest
```

| 标签 | 含义 |
| --- | --- |
| `2026.11.15` | 构建日期（Asia/Shanghai，`YYYY.MM.DD`） |
| `latest` | 最近一次成功构建 |
| `sha-58089a4` | 构建所对应的上游 commit 短 SHA |

首个公开版本为 `2026.11.15`（上游 `58089a4`），构建记录见
[Actions run 43684637007](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/actions/runs/43684637007)，
镜像包页面见
[GHCR](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/pkgs/container/open-xiaoai-xiaozhi-docker)。

镜像内置上游发布的 VAD + KWS + ASR 模型（
[`vad-kws-models`](https://github.com/idootop/open-xiaoai/releases/tag/vad-kws-models)），
因此不需要再单独下载模型或挂载 `xiaozhi/models`。配置仍然通过挂载
`config.py` 提供。

## 快速开始

### 1. 准备 config.py

```shell
mkdir -p open-xiaoai-xiaozhi && cd open-xiaoai-xiaozhi
curl -fsSL https://raw.githubusercontent.com/OwnDing/open-xiaoai/main/examples/xiaozhi/config.py -o config.py
# 按需修改唤醒词、OTA_URL、WEBSOCKET_URL、TTS 模式等
```

### 2. 运行

```shell
docker run -d --name open-xiaoai-xiaozhi --restart unless-stopped \
  -p 4399:4399 \
  -p 4400:4400 \
  -v "$PWD/config.py:/app/config.py" \
  -e XIAOZHI_TTS_OUTPUT_MODE=native_xiaomi \
  ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:latest
```

- `4399`：小智 WebSocket / OTA 协议端口（音箱连接这个端口）。
- `4400`：小七本地音乐的 HTTP 端口（音箱从这里拉歌，按需保留）。
- `XIAOZHI_TTS_OUTPUT_MODE`：`native_xiaomi`（小爱原生音色）或
  `sherpa`（服务端流式音频）。不设置时使用 `config.py` 里的值。

也可以使用仓库里的 [`docker-compose.yml`](docker-compose.yml)：

```shell
cp config.py .          # 或在 compose 中改成自己的路径
docker compose up -d
```

> [!NOTE]
> 第一次启动需要加载 ONNX 模型，约 30 秒后才能稳定唤醒；第一次对话时按提示
> 到 [xiaozhi.me](https://xiaozhi.me/) 输入验证码绑定设备。

## 自动构建规则

工作流：[`.github/workflows/docker.yml`](.github/workflows/docker.yml)

1. **每天检测一次**：`cron: "17 19 * * *"`（UTC），即北京时间每天
   **03:17**。
2. 用 `git ls-remote` 读取上游 `OwnDing/open-xiaoai` 的 `main` 最新
   commit。
3. 读取已发布镜像 `:latest` 的 OCI 标签
   `org.opencontainers.image.revision`（使用
   [crane](https://github.com/google/go-containerregistry) 读取）。
4. 如果上游 commit 与镜像标签**不一致**，就重新构建；一致则跳过，不产生
   空跑构建。
5. 构建成功后最终会发布三个标签（`latest` 在 smoke test 通过后才提升）：

   ```text
   ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:<构建日期>
   ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:latest
   ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:sha-<上游短SHA>
   ```

6. 构建失败时不会更新任何标签；smoke test 失败时日期/sha 标签保留用于排查，
   但 `latest` 不动，第二天的定时任务会自动重试。
7. 手动触发 `workflow_dispatch` 时：
   - `force=true`：即使上游没变也强制重建；
   - `platforms`：可改 `linux/amd64` 或 `linux/amd64,linux/arm64`
     （arm64 走 QEMU，构建时间更长）。
8. 构建完成后会先跑冒烟测试（导入 ONNX Runtime / Opus / 项目扩展，并运行
   `keywords.py`）；只有测试通过才把 `latest` 移到新镜像。失败时 `latest`
   保留上一个可用版本，第二天的检测会重试。

检测状态保存在**镜像自身的标签**里，不需要往仓库提交状态文件，因此定时任务
只需要仓库的只读权限。

### 上游目录与子模块

仓库里的 [`open-xiaoai/`](open-xiaoai) 是指向
`https://github.com/OwnDing/open-xiaoai.git` 的 git submodule，作为构建
基线。定时任务检测到上游 `main` 有新 commit 时，会把子模块检出到该
commit 再构建，因此构建内容始终是最新的上游代码，而不是仓库里固定的旧
指针。

## 构建内容

构建上下文是 `open-xiaoai/`，使用上游自带的
`examples/xiaozhi/Dockerfile`：

- `examples/xiaozhi`：Python 服务端、Rust 扩展、`config.py`、`uv.lock`；
- `packages/client-rust`：Rust 协议库；
- `examples/xiaozhi/xiaozhi/models`：构建前由
  [`scripts/prepare-models.sh`](scripts/prepare-models.sh) 下载并解压的
  VAD/KWS/ASR 模型。

镜像沿用上游 Dockerfile 的两阶段构建：builder 阶段安装 Rust、uv，编译
Rust 扩展并安装 Python 依赖；runtime 阶段只保留 venv、源码和
ONNX Runtime 动态库。入口为 `main.py`（`CLI=true`）。

## 本地构建

需要 Docker + Buildx：

```shell
git clone --recursive https://github.com/ghitori/open-xiaoai-xiaozhi-docker.git
cd open-xiaoai-xiaozhi-docker

# 拉取上游最新 main，下载模型，构建并加载到本机 Docker
./scripts/build-local.sh
```

常用环境变量：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `IMAGE` | `ghcr.io/ghitori/open-xiaoai-xiaozhi-docker` | 镜像名 |
| `VERSION` | 当天日期（Asia/Shanghai） | 日期标签 |
| `PLATFORMS` | `linux/amd64` | 构建平台，多平台需配合 `PUSH=1` |
| `PUSH` | `0` | `1` 推送到 registry，否则 `--load` 到本机 |
| `SUBMODULE_PIN` | `0` | `1` 构建子模块固定 commit，而不是上游最新 |

等价的原始命令：

```shell
./scripts/prepare-models.sh open-xiaoai
docker buildx build \
  --platform linux/amd64 \
  -f open-xiaoai/examples/xiaozhi/Dockerfile \
  -t ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:$(TZ=Asia/Shanghai date +%Y.%m.%d) \
  -t ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:latest \
  --load \
  open-xiaoai
```

## 目录结构

```text
.
├── .github/workflows/docker.yml   # 每日检测 + 构建 + 发布
├── scripts/
│   ├── prepare-models.sh          # 下载并校验 VAD/KWS/ASR 模型
│   └── build-local.sh             # 本地 Buildx 构建
├── docker-compose.yml             # 运行示例
├── open-xiaoai/                   # 上游仓库 submodule（构建基线）
└── README.md
```

## 权限与公开

- 镜像发布在 GitHub Container Registry，包名为
  `open-xiaoai-xiaozhi-docker`，**公开可见**，可匿名拉取。
- 镜像名与仓库名保持一致（`ghcr.io/<owner>/<repo>`）：GitHub Actions 的
  `GITHUB_TOKEN` 只能向与仓库同名/关联的 GHCR 包推送，镜像名不同会报
  `permission_denied`。
- Fork 后无需改工作流：`IMAGE_NAME: ${{ github.repository }}` 会自动使用
  fork 的 owner/repo；如要公开发布，请在 fork 的 Packages 设置里把包改为
  public。
- 工作流声明了 `packages: write`（构建）和 `packages: read`（检测），
  不需要额外 secret。
- 已验证匿名拉取：`crane digest ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:latest`
  无需登录即可成功。

## 本地验证

当前开发沙箱没有 Docker 守护进程，也没有 mount / user namespace 权限，
无法真正执行 `docker build`。为了在本地确认构建，使用官方
`python:3.12-slim` 根文件系统 + `chroot`，按上游 Dockerfile 的步骤
逐条执行（apt 依赖、Rust、uv、`cargo build`、`uv sync`、`maturin`
构建、ONNX Runtime 安装、模型下载与导入检查）。

本地验证已通过：Rust 1.100.0 编译成功，uv 0.7.22 安装了 23 个依赖，
`maturin` 生成 `manylinux_2_34` wheel，runtime 阶段导入和
`keywords.py` 均成功。发布后的镜像也用 `crane export` 导出到本地根文件系统
复测：449 MB，7 个模型文件齐全，导入与 `keywords.py` 均通过。详细命令、
哈希与限制见 [VERIFY.md](VERIFY.md)。

最终的真实 Docker 构建由 GitHub Actions 在 ubuntu-latest 上完成，工作流
会校验推送后的 `revision` 标签。

## 免责声明

- 本项目不是小米、小爱音箱或小智 AI 官方项目。
- 镜像只适合在可信局域网内使用；公网部署的流量、安全与合规风险请自行评估。
- 上游代码和模型版权归各自作者所有，遵循其 MIT 许可与免责声明。

## 鸣谢

- [OwnDing/open-xiaoai](https://github.com/OwnDing/open-xiaoai)
- [78/xiaozhi-esp32](https://github.com/78/xiaozhi-esp32)
- [Huang-junsen/py-xiaozhi](https://github.com/Huang-junsen/py-xiaozhi)
