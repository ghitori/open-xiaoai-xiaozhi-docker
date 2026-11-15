# Open-XiaoAI x 小智 AI Docker 镜像

[![Build and publish](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/actions/workflows/docker.yml/badge.svg)](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/actions/workflows/docker.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-open--xiaoai--xiaozhi--docker-2496ed?logo=docker&logoColor=white)](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/pkgs/container/open-xiaoai-xiaozhi-docker)

自动跟随 [OwnDing/open-xiaoai](https://github.com/OwnDing/open-xiaoai) 的
[`examples/xiaozhi`](https://github.com/OwnDing/open-xiaoai/tree/main/examples/xiaozhi)
构建并发布到 GitHub Container Registry。非官方构建，代码和模型来自上游（MIT）。

## 镜像

`ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:latest`

| 标签 | 说明 |
| --- | --- |
| `2026.11.15` | 构建日期（Asia/Shanghai，`YYYY.MM.DD`） |
| `latest` | 最近一次通过冒烟测试的构建 |
| `sha-58089a4` | 上游 commit 短 SHA |

镜像已内置 VAD/KWS/ASR 模型，只需提供 `config.py`。

## 运行

```shell
curl -fsSL https://raw.githubusercontent.com/OwnDing/open-xiaoai/main/examples/xiaozhi/config.py -o config.py
# 按需修改 config.py

docker run -d --name open-xiaoai-xiaozhi --restart unless-stopped \
  -p 4399:4399 -p 4400:4400 \
  -v "$PWD/config.py:/app/config.py" \
  -e XIAOZHI_TTS_OUTPUT_MODE=native_xiaomi \
  ghcr.io/ghitori/open-xiaoai-xiaozhi-docker:latest
```

- `4399`：小智协议端口；`4400`：本地音乐 HTTP 端口。
- `XIAOZHI_TTS_OUTPUT_MODE`：`native_xiaomi` 或 `sherpa`。

也可以使用仓库里的 [`docker-compose.yml`](docker-compose.yml)：

```shell
docker compose up -d
```

## 自动构建

- 每天北京时间 **03:17** 检查上游 `main` 的最新 commit。
- 与镜像标签 `org.opencontainers.image.revision` 比较，不一致才重新构建。
- 版本按构建日期命名：`YYYY.MM.DD`。
- 构建完成后跑冒烟测试（依赖导入 + `keywords.py`），通过后才更新
  `latest`；失败保留上一个可用版本，次日自动重试。
- 工作流：[`.github/workflows/docker.yml`](.github/workflows/docker.yml)；
  构建记录：[Actions](https://github.com/ghitori/open-xiaoai-xiaozhi-docker/actions)。

## 本地构建

需要 Docker + Buildx：

```shell
git clone --recursive https://github.com/ghitori/open-xiaoai-xiaozhi-docker.git
cd open-xiaoai-xiaozhi-docker
./scripts/build-local.sh
```

默认构建 `linux/amd64` 并加载到本机；可用 `PLATFORMS`、`PUSH`、
`SUBMODULE_PIN` 调整，详见脚本。

## 说明

- 镜像名与仓库同名（`-docker` 后缀）：`GITHUB_TOKEN` 只能推送同名 GHCR 包。
- 默认只构建 `linux/amd64`；需要 arm64 时手动触发工作流，把 `platforms`
  设为 `linux/amd64,linux/arm64`。
- 本地构建验证记录见 [VERIFY.md](VERIFY.md)。
- 建议仅在可信局域网使用。

## 鸣谢

- [OwnDing/open-xiaoai](https://github.com/OwnDing/open-xiaoai)
- [78/xiaozhi-esp32](https://github.com/78/xiaozhi-esp32)
- [Huang-junsen/py-xiaozhi](https://github.com/Huang-junsen/py-xiaozhi)
