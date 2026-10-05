"""Hello webhook. Later tickets replace this with the sheet upsert."""

import modal

app = modal.App("missb-listener")

# fastapi_endpoint needs FastAPI inside the container. It is an image
# dependency, not a listener dependency — the project itself depends on modal.
image = modal.Image.debian_slim().pip_install("fastapi[standard]")


@app.function(image=image)
@modal.fastapi_endpoint(method="GET")
def hello() -> dict:
    return {"ok": True}
