### 1. Tools importing other tools
```python
# BAD: tools/analyze.py importing tools/health.py
from tools.health import check_service

# GOOD: shared logic in a service module, or call via coordinator
```

### 2. Raw dicts instead of Pydantic models
```python
# BAD
@mcp.tool()
async def analyze(data: dict) -> dict:
    return {"result": "..."}

# GOOD
@mcp.tool()
async def analyze(data: AnalyzeInput) -> AnalyzeOutput:
    return AnalyzeOutput(result="...")
```

### 3. Blocking calls in async functions
```python
# BAD
@mcp.tool()
async def fetch_data(url: str) -> str:
    import requests
    return requests.get(url).text

# GOOD
@mcp.tool()
async def fetch_data(url: str) -> str:
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.text
```

### 4. Missing error handling in tools
```python
# BAD
@mcp.tool()
async def call_api(endpoint: str) -> ApiResponse:
    response = await client.get(endpoint)
    return ApiResponse.model_validate(response.json())

# GOOD
@mcp.tool()
async def call_api(endpoint: str) -> ApiResponse:
    try:
        response = await client.get(endpoint)
        response.raise_for_status()
        return ApiResponse.model_validate(response.json())
    except httpx.HTTPError as exc:
        raise ValueError(f"API call failed: {exc}") from exc
```
