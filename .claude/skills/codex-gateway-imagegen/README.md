# codex-gateway-imagegen

`codex-gateway-imagegen` 是一个面向 Codex CLI 的图像生成 skill。它通过当前机器上已经配置好的 Responses-compatible gateway 调用 `image_generation` 工具，把文本生成图像或参考图编辑结果保存为本地图片文件。

## 适用场景

当用户在 Codex CLI 中提出以下需求时，可以使用这个 skill：

- 根据文本提示生成一张新的 raster image。
- 基于一张或多张参考图进行图像编辑。
- 内置图像生成路径不可用，需要直接调用已配置的 gateway。
- 希望把最终图片明确保存到当前 workspace，而不是只保存在临时目录。

## 目录结构

```text
codex-gateway-imagegen/
├── SKILL.md
├── README.md
├── agents/
│   └── openai.yaml
├── references/
│   └── troubleshooting.md
└── scripts/
    └── generate_gateway_image.py
```

核心文件说明：

- `SKILL.md`：Codex 触发并执行该 skill 时读取的主要流程说明。
- `scripts/generate_gateway_image.py`：实际调用 gateway 的 Python helper script。
- `references/troubleshooting.md`：网络、TLS、HTTP error、尺寸错误等常见问题的处理决策树。
- `agents/openai.yaml`：面向 UI 或 skill list 的展示元数据。

## 工作原理

helper script 会读取本机 Codex 配置：

- `~/.codex/config.toml`：读取当前 model provider 的 `base_url`。
- `~/.codex/auth.json`：优先读取 `OPENAI_API_KEY`，也支持读取 `tokens.access_token` 并走默认 Codex backend URL。

随后脚本会向 `${base_url}/responses` 发起 streaming 请求，并在 payload 中声明：

- `model`: 默认 `gpt-5.5`
- `tools`: `image_generation`
- `action`: `auto`、`generate` 或 `edit`
- `size`: 默认 `1024x1024`

返回结果中包含 `image_generation_call.result` 时，脚本会将 base64 图片解码并写入 `--out` 指定路径。

## 常用命令

文本生成图像：

```bash
python scripts/generate_gateway_image.py \
  --prompt "A clean product hero image of a compact mechanical keyboard on a walnut desk, soft studio lighting, photorealistic" \
  --out "./keyboard-hero.png" \
  --size 1024x1024 \
  --action generate
```

基于本地参考图编辑：

```bash
python scripts/generate_gateway_image.py \
  --prompt "Keep the original product shape and perspective, replace the background with a bright modern studio, preserve realistic shadows" \
  --image "./reference.png" \
  --out "./product-studio.png" \
  --size 1024x1536 \
  --action edit
```

使用多张参考图编辑：

```bash
python scripts/generate_gateway_image.py \
  --prompt "Combine the subject from the first image with the color palette and lighting style from the second image" \
  --image "./subject.png" \
  --image "./style.png" \
  --out "./combined-result.png" \
  --size 1024x1536 \
  --action edit
```

## 参数说明

| 参数 | 说明 |
| --- | --- |
| `--prompt` | 必填。图像生成或编辑提示词。 |
| `--out` | 必填。输出图片路径。父目录不存在时会自动创建。 |
| `--size` | 可选。默认 `1024x1024`，常用值包括 `1024x1024`、`1024x1536`、`1536x1024`。 |
| `--action` | 可选。`auto`、`generate` 或 `edit`，默认 `auto`。提供参考图时建议显式使用 `edit`。 |
| `--image` | 可选。本地参考图路径，可重复传入。 |
| `--image-url` | 可选。远程参考图 URL，可重复传入。 |
| `--mask` | 可选。局部编辑 mask 图片路径。 |
| `--model` | 可选。Responses model，默认 `gpt-5.5`。 |
| `--timeout` | 可选。HTTP timeout 秒数，默认 `600`。 |

## 提示词建议

提示词应该像 production spec，而不是短关键词。通常需要包含：

- 主体和场景。
- 视觉风格，例如 `photorealistic`、`poster`、`mobile screenshot`。
- 构图和画幅，例如 `centered composition`、`9:16 vertical`。
- 光线、材质、背景和输出用途。
- 如果是编辑任务，明确说明哪些内容必须保留、哪些内容需要改变。

编辑任务中，建议使用更明确的约束：

```text
Preserve the subject identity, camera angle, product shape, and main proportions. Change only the background and lighting.
```

## 常见故障处理

优先阅读 `references/troubleshooting.md`。简要规则如下：

- 如果是 TLS、schannel、read timeout 等网络路径问题，优先保持 prompt 和参数不变，换宿主网络路径重试。
- 如果 gateway 返回 HTTP error body，先阅读 body，再调整请求参数或认证配置。
- 如果提示 `Invalid size` 或像素预算不足，增大 `--size`，不要重复请求同一个非法尺寸。
- 如果参考图保留不充分，优先把 `--action` 改成 `edit`，并在 prompt 中明确 preservation constraints。

## 维护注意事项

- `SKILL.md` 应保持精简，只保留 Codex 执行任务所需的核心流程。
- 详细排障内容应放在 `references/troubleshooting.md`，避免让主 skill 文档膨胀。
- 脚本输出保持 JSON，方便 Codex 或其他自动化流程解析成功路径和错误信息。
- 修改 `scripts/generate_gateway_image.py` 后，至少用 `--help` 验证 CLI 参数解析没有损坏。

```bash
python scripts/generate_gateway_image.py --help
```
