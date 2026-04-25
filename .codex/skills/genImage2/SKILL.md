---
name: genImage2
description: Generate images through the current Codex-compatible Responses gateway using the image_generation tool. Use when the user wants to create an image with the current configured gateway, save a PNG in the current working directory, or override the current model for a one-off image generation request.
---

# genImage2

Use this skill when the user wants to generate an image through the current Codex gateway configuration instead of calling the official OpenAI endpoint directly.

Do not hardcode credentials, gateway URLs, or machine-specific paths. Read them at runtime from the current Codex configuration:

- the active Codex config file for `base_url` and the current default `model`
- the active Codex auth file for `OPENAI_API_KEY`

Use the bundled script:

```bash
scripts/generate_response_image.sh \
  --prompt "生成一张仙侠女主图片"
```

Override the model when the user asks for a specific one:

```bash
scripts/generate_response_image.sh \
  --prompt "Generate a cinematic poster of a gray tabby cat hugging an otter" \
  --model gpt-5.4
```

Write to a specific file when the user wants a named output:

```bash
scripts/generate_response_image.sh \
  --prompt "生成一张国风海报" \
  --output ./poster.png
```

Notes:

- This skill uses `POST {base_url}/responses` with `tools: [{"type":"image_generation"}]`.
- If the request returns a base64 image result, the script decodes it into a local PNG.
- Without `--output`, the script writes the PNG into the current working directory, which is typically the current conversation directory.
- If the current gateway responds slowly, allow a longer timeout instead of assuming the request failed immediately.
