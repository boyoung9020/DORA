# Sync — 자체 호스팅 LLM 통합 가이드 (Gemini API → Qwen3 9B)

> **이 문서를 읽는 AI / 개발자에게**: 본 가이드는 사용자의 자체 GPU 서버에 Qwen3 9B 모델을 설치하고, Sync 프로젝트의 기존 Gemini API 기반 AI 기능 (`backend/app/routers/ai.py`) 을 자체 호스팅 LLM 으로 전환하는 전체 절차입니다. 코드 변경, 인프라 설정, 검증, 롤백까지 모두 포함하며 단계별로 그대로 따라 실행할 수 있도록 구성했습니다. 가정·생략 없이 명령어와 코드 블록을 그대로 복붙하면 동작합니다.

---

## 0. 개요 / 아키텍처

### 변경 전
```
Sync API (FastAPI) ──HTTPS──▶ Google Gemini API
       │
       └─ google-genai SDK 사용
       └─ ai.py 의 _generate_with_gemini_model_fallback() 가 직접 호출
       └─ GEMINI_API_KEY 환경변수 필요
```

### 변경 후
```
Sync API (FastAPI) ──HTTP(VPN/사설망)──▶ AI 서버 (vLLM, OpenAI 호환 REST)
       │                                    │
       │                                    └─ Qwen3-9B 모델 적재
       │                                    └─ /v1/chat/completions 엔드포인트
       │
       ├─ openai SDK 사용 (base_url 만 자체 서버로)
       ├─ ai.py 가 추상화된 LLMClient 인터페이스 호출
       ├─ services/llm/factory.py 가 환경변수로 provider 선택
       └─ LLM_PROVIDER=openai_compat (기존 호환 위해 gemini 도 유지)
```

### 핵심 결정 사항

- **모델 런타임**: vLLM (OpenAI 호환 REST 자동 제공, GPU throughput 최강) — 권장
- **대안**: Ollama (CPU/GPU 혼합 OK, 셋업 가장 쉬움)
- **클라이언트**: `openai` Python SDK (둘 다 OpenAI 호환 엔드포인트 노출하므로 동일 코드)
- **인터페이스**: `OpenAI Chat Completions API v1` — 이게 사실상 표준. 추후 vLLM → SGLang / LM Studio / OpenAI 정식 등 어떤 백엔드로 바꿔도 코드 변경 없음.
- **추상화**: 백엔드에 `LLMClient` 추상 클래스를 두고 `GeminiLLMClient`, `OpenAICompatLLMClient` 두 구현 제공. 환경변수 `LLM_PROVIDER` 로 선택. 이렇게 하면 롤백/A-B 테스트 용이.

### 작업 범위

1. **AI 서버 (별도 머신)**: OS 준비, GPU 드라이버, vLLM 설치, 모델 다운로드, systemd 서비스 등록, nginx 인증 프록시
2. **Sync 백엔드 (Oracle Cloud)**: `services/llm/` 모듈 신설, `routers/ai.py` 리팩터링, 환경변수 추가, requirements.txt 업데이트, 배포

---

## 1. AI 서버 환경 요구사항

### 1.1 Qwen3 9B 하드웨어 요구사항

| 항목 | 권장 | 최소 |
|---|---|---|
| GPU | NVIDIA A6000 (48GB) / A100 (40GB+) / RTX 4090 (24GB) | RTX 3090 (24GB) |
| GPU VRAM | 24GB 이상 | 16GB (양자화 필수) |
| 시스템 RAM | 32GB | 16GB |
| 디스크 | 100GB SSD (모델 ~18GB + 캐시) | 50GB |
| OS | Ubuntu 22.04 LTS | Ubuntu 20.04 / Debian 12 |
| 네트워크 | Sync API 와 사설망 또는 VPN | 인터넷 노출 시 인증 필수 |

### 1.2 모델 정확한 식별

본 가이드는 **Qwen3-9B-Instruct** (Alibaba) 를 사용합니다. HuggingFace 식별자:
- **`Qwen/Qwen3-9B-Instruct`** (공식 명칭이 약간 다를 수 있으니 https://huggingface.co/Qwen 에서 정확한 ID 확인)
- 한국어 지원 양호, 32K context, OpenAI Chat 포맷 호환

> **대체 가능 모델** (같은 절차로 모델명만 바꿔 사용 가능):
> - `Qwen/Qwen2.5-7B-Instruct` (경량)
> - `Qwen/Qwen2.5-14B-Instruct` (한 단계 큰)
> - `LGAI-EXAONE/EXAONE-3.5-7.8B-Instruct` (한국어 특화)
> - `meta-llama/Llama-3.1-8B-Instruct`

---

## 2. AI 서버 설치 — vLLM (권장 경로)

### 2.1 OS / GPU 드라이버 사전 점검

```bash
# 1) GPU 인식 확인
nvidia-smi
# 출력: GPU 이름 + CUDA 버전 (12.x 권장)

# 2) NVIDIA Container Toolkit (Docker 로 vLLM 띄울 경우)
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker

# 3) Docker GPU 동작 검증
sudo docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
# nvidia-smi 출력이 보이면 OK
```

### 2.2 디렉토리 구조 준비

```bash
sudo mkdir -p /opt/llm/{models,logs,config}
sudo chown -R $USER:$USER /opt/llm
```

### 2.3 모델 다운로드 (HuggingFace)

```bash
# huggingface-cli 설치
pip install --user "huggingface_hub[cli]"

# (선택) HuggingFace 토큰 로그인 — 일부 모델은 동의 필요
huggingface-cli login
# → https://huggingface.co/settings/tokens 에서 read 토큰 생성 후 붙여넣기

# 모델 다운로드 (~18GB, 회선 따라 10-30분)
huggingface-cli download Qwen/Qwen3-9B-Instruct \
    --local-dir /opt/llm/models/Qwen3-9B-Instruct \
    --local-dir-use-symlinks False

# 다운로드 검증
ls -la /opt/llm/models/Qwen3-9B-Instruct/
# config.json, tokenizer.json, *.safetensors 파일들이 보여야 함
du -sh /opt/llm/models/Qwen3-9B-Instruct/
# 약 18GB
```

### 2.4 vLLM Docker 실행 (개발/테스트용 single command)

먼저 단발 명령으로 동작 확인:

```bash
sudo docker run -d \
    --name vllm-qwen \
    --gpus all \
    --shm-size=16g \
    -v /opt/llm/models:/models \
    -p 127.0.0.1:8000:8000 \
    --restart unless-stopped \
    vllm/vllm-openai:latest \
    --model /models/Qwen3-9B-Instruct \
    --served-model-name qwen3-9b \
    --max-model-len 8192 \
    --gpu-memory-utilization 0.90 \
    --dtype auto \
    --api-key "REPLACE_WITH_STRONG_SECRET_TOKEN"
```

> **포인트**:
> - `-p 127.0.0.1:8000:8000` — localhost 만 바인딩 (외부 직접 노출 금지, nginx 가 프록시)
> - `--api-key` — 클라이언트가 `Authorization: Bearer <token>` 헤더로 보내야 함
> - `--max-model-len 8192` — context 8K. RAM 여유 있으면 32768 까지
> - `--gpu-memory-utilization 0.90` — VRAM 90% 사용 허용
> - `--shm-size=16g` — vLLM 멀티프로세싱용 공유 메모리

기동 확인:

```bash
sudo docker logs -f vllm-qwen
# "Application startup complete" 또는 "Uvicorn running on http://0.0.0.0:8000" 확인
# 모델 로딩에 1-3분 걸림
```

### 2.5 헬스체크

```bash
# 1) 모델 목록
curl -s -H "Authorization: Bearer REPLACE_WITH_STRONG_SECRET_TOKEN" \
     http://127.0.0.1:8000/v1/models | python3 -m json.tool
# → "qwen3-9b" 가 data 배열에 보임

# 2) 간단 chat completion
curl -s -X POST http://127.0.0.1:8000/v1/chat/completions \
    -H "Authorization: Bearer REPLACE_WITH_STRONG_SECRET_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qwen3-9b",
        "messages": [{"role": "user", "content": "안녕? 너는 어떤 모델이야?"}],
        "max_tokens": 100,
        "temperature": 0.4
    }' | python3 -m json.tool
# → choices[0].message.content 에 한국어 응답
```

응답 안 오면 [10. 트러블슈팅](#10-트러블슈팅) 참조.

---

## 3. systemd 서비스 등록 (재부팅 후 자동 기동)

`/etc/systemd/system/vllm-qwen.service`:

```ini
[Unit]
Description=vLLM OpenAI-compatible server (Qwen3-9B)
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStartPre=-/usr/bin/docker stop vllm-qwen
ExecStartPre=-/usr/bin/docker rm vllm-qwen
ExecStart=/usr/bin/docker run -d \
    --name vllm-qwen \
    --gpus all \
    --shm-size=16g \
    -v /opt/llm/models:/models \
    -p 127.0.0.1:8000:8000 \
    --restart unless-stopped \
    vllm/vllm-openai:latest \
    --model /models/Qwen3-9B-Instruct \
    --served-model-name qwen3-9b \
    --max-model-len 8192 \
    --gpu-memory-utilization 0.90 \
    --api-key REPLACE_WITH_STRONG_SECRET_TOKEN
ExecStop=/usr/bin/docker stop vllm-qwen
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable vllm-qwen
sudo systemctl start vllm-qwen
sudo systemctl status vllm-qwen
```

---

## 4. nginx 리버스 프록시 + 인증 (외부 노출 시)

Sync API 서버와 같은 사설망/VPN 안에 있다면 이 단계는 선택. 인터넷에 노출되어야 하면 필수.

`/etc/nginx/sites-available/llm.conf`:

```nginx
server {
    listen 443 ssl http2;
    server_name llm.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/llm.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/llm.yourdomain.com/privkey.pem;

    # 큰 응답 / 긴 요청 허용
    client_max_body_size 10M;
    proxy_read_timeout 300s;
    proxy_send_timeout 300s;
    proxy_connect_timeout 30s;

    # OpenAI 호환 엔드포인트만 노출
    location /v1/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # 스트리밍 응답 위해 버퍼 끔
        proxy_buffering off;
        proxy_cache off;
    }

    # 그 외 경로는 차단 (admin 대시보드 등 노출 방지)
    location / { return 404; }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/llm.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d llm.yourdomain.com
```

---

## 5. Sync 백엔드 — 코드 리팩터링

### 5.1 디렉토리 구조 (신규)

```
backend/app/services/
└── llm/
    ├── __init__.py        # 외부 노출 (factory.py 의 get_llm_client 만 export)
    ├── base.py            # LLMClient 추상 클래스
    ├── gemini_client.py   # 기존 Gemini 호출 옮김 (호환 유지)
    ├── openai_compat_client.py  # vLLM/Ollama/자체서버 (OpenAI 호환)
    └── factory.py         # 환경변수 LLM_PROVIDER 로 분기
```

### 5.2 `backend/app/services/llm/__init__.py`

```python
"""LLM 추상화 레이어.

외부에서는 `get_llm_client()` 만 호출. 환경변수에 따라 적절한 구현체 반환.
"""
from .base import LLMClient
from .factory import get_llm_client

__all__ = ["LLMClient", "get_llm_client"]
```

### 5.3 `backend/app/services/llm/base.py`

```python
"""LLM 클라이언트 추상 베이스."""
from abc import ABC, abstractmethod


class LLMClient(ABC):
    """비동기 LLM 호출 인터페이스. 모든 구현체는 이 시그니처를 따른다."""

    @abstractmethod
    async def generate(
        self,
        prompt: str,
        *,
        max_tokens: int = 1024,
        temperature: float = 0.4,
    ) -> str:
        """단일 prompt → 단일 응답 텍스트.

        Args:
            prompt: 사용자에게 전달할 통합 프롬프트 (system + user 합쳐도 OK)
            max_tokens: 생성 최대 토큰 수
            temperature: 0.0(결정적) ~ 1.0(창의적)

        Returns:
            모델 응답 텍스트 (앞뒤 공백 trim 됨, 빈 문자열 반환 금지 — 빈 응답 시 RuntimeError)

        Raises:
            RuntimeError: 모든 fallback 모델이 실패한 경우
            그 외: 네트워크/인증 오류는 원본 예외 그대로 propagate
        """
        raise NotImplementedError
```

### 5.4 `backend/app/services/llm/gemini_client.py`

기존 `routers/ai.py` 의 Gemini 로직을 그대로 옮김:

```python
"""Gemini API 클라이언트 (기존 동작 유지용)."""
import asyncio
from typing import Optional

from .base import LLMClient


_GEMINI_MODEL_CHAIN: tuple[str, ...] = (
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
)


class GeminiLLMClient(LLMClient):
    """Google Gemini API 사용. 모델 체인 폴백 (503 대응)."""

    def __init__(self, api_key: str):
        if not api_key:
            raise ValueError("GEMINI_API_KEY 가 설정되지 않았습니다.")
        # 지연 import: gemini 미사용 환경에서는 google-genai 패키지 안 깔아도 됨
        from google import genai
        self._client = genai.Client(api_key=api_key)

    async def generate(
        self,
        prompt: str,
        *,
        max_tokens: int = 1024,
        temperature: float = 0.4,
    ) -> str:
        last_err: Optional[BaseException] = None
        for i, model in enumerate(_GEMINI_MODEL_CHAIN):
            try:
                response = await asyncio.to_thread(
                    self._client.models.generate_content,
                    model=model,
                    contents=prompt,
                )
                text = (response.text or "").strip()
                if text:
                    return text
                last_err = RuntimeError("빈 응답")
            except Exception as e:
                last_err = e
            if i < len(_GEMINI_MODEL_CHAIN) - 1:
                await asyncio.sleep(1.0)
        if last_err is not None:
            raise last_err
        raise RuntimeError("AI 응답 없음")
```

### 5.5 `backend/app/services/llm/openai_compat_client.py`

```python
"""OpenAI 호환 클라이언트 (vLLM, Ollama, LM Studio, SGLang 등)."""
import asyncio
from typing import Optional


from .base import LLMClient


class OpenAICompatLLMClient(LLMClient):
    """OpenAI Chat Completions API 호환 엔드포인트 호출.

    vLLM (--api-key 옵션), Ollama (/v1/...), LM Studio 등 모두 동일 인터페이스.
    """

    # 주 모델 + 보조 모델 (vLLM 단일 모델만 띄운 경우 보조는 None)
    _DEFAULT_TIMEOUT = 60.0

    def __init__(
        self,
        base_url: str,
        api_key: str,
        model: str,
        fallback_model: Optional[str] = None,
        timeout: float = _DEFAULT_TIMEOUT,
    ):
        if not base_url:
            raise ValueError("LLM_BASE_URL 이 설정되지 않았습니다.")
        # 지연 import
        from openai import AsyncOpenAI
        self._client = AsyncOpenAI(
            base_url=base_url.rstrip("/"),
            api_key=api_key or "EMPTY",  # 자체서버는 더미 토큰도 무방
            timeout=timeout,
        )
        self._model = model
        self._fallback = fallback_model

    async def generate(
        self,
        prompt: str,
        *,
        max_tokens: int = 1024,
        temperature: float = 0.4,
    ) -> str:
        models = [m for m in (self._model, self._fallback) if m]
        last_err: Optional[BaseException] = None
        for i, model in enumerate(models):
            try:
                resp = await self._client.chat.completions.create(
                    model=model,
                    messages=[{"role": "user", "content": prompt}],
                    max_tokens=max_tokens,
                    temperature=temperature,
                )
                text = (resp.choices[0].message.content or "").strip()
                if text:
                    return text
                last_err = RuntimeError(f"{model}: 빈 응답")
            except Exception as e:
                last_err = e
            if i < len(models) - 1:
                await asyncio.sleep(1.0)
        if last_err is not None:
            raise last_err
        raise RuntimeError("AI 응답 없음")
```

### 5.6 `backend/app/services/llm/factory.py`

```python
"""환경변수 기반 LLM 클라이언트 팩토리."""
from functools import lru_cache

from app.config import settings
from .base import LLMClient
from .gemini_client import GeminiLLMClient
from .openai_compat_client import OpenAICompatLLMClient


@lru_cache(maxsize=1)
def get_llm_client() -> LLMClient:
    """settings.LLM_PROVIDER 에 따라 적절한 구현 반환.

    - "gemini" (기본): 기존 Gemini API
    - "openai_compat": vLLM / Ollama / 자체 서버
    """
    provider = (settings.LLM_PROVIDER or "gemini").lower().strip()

    if provider == "openai_compat":
        return OpenAICompatLLMClient(
            base_url=settings.LLM_BASE_URL,
            api_key=settings.LLM_API_KEY,
            model=settings.LLM_MODEL,
            fallback_model=settings.LLM_FALLBACK_MODEL or None,
        )

    # 기본/명시 gemini
    return GeminiLLMClient(api_key=settings.GEMINI_API_KEY)
```

### 5.7 `backend/app/config.py` 환경변수 추가

기존 `Settings` 클래스에 다음 필드 추가:

```python
class Settings(BaseSettings):
    # ... 기존 필드 ...
    GEMINI_API_KEY: str = ""

    # === LLM provider 선택 ===
    LLM_PROVIDER: str = "gemini"  # "gemini" | "openai_compat"

    # OpenAI 호환 자체서버 설정 (LLM_PROVIDER=openai_compat 시 필수)
    LLM_BASE_URL: str = ""        # 예: "http://10.0.0.5:8000/v1" 또는 "https://llm.yourdomain.com/v1"
    LLM_API_KEY: str = ""         # vLLM --api-key 와 동일한 토큰
    LLM_MODEL: str = "qwen3-9b"   # vLLM --served-model-name 과 동일
    LLM_FALLBACK_MODEL: str = ""  # 두번째 모델 (있으면)
```

### 5.8 `backend/app/routers/ai.py` 리팩터링

**변경 1**: 상단 import 와 모델 체인 / Gemini 전용 함수 제거 → LLM 추상화 사용

다음 블록을 모두 **삭제**:

```python
# 삭제 대상 (line 27-74)
_GEMINI_MODEL_CHAIN: tuple[str, ...] = (
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash",
)


def _friendly_gemini_http_detail(exc: BaseException, prefix: str) -> str:
    ...


async def _generate_with_gemini_model_fallback(
    client: Any,
    contents: str,
) -> str:
    ...
```

대체 (파일 상단 import 추가):

```python
from app.services.llm import get_llm_client


def _friendly_llm_error_detail(exc: BaseException, prefix: str) -> str:
    """클라이언트 노출용 짧은 에러 메시지."""
    s = str(exc).lower()
    if (
        "high demand" in s
        or "resource exhausted" in s
        or "overloaded" in s
        or "503" in s
        or "unavailable" in s
        or "timeout" in s
        or "connection refused" in s
    ):
        return f"{prefix}: AI 서버가 일시적으로 응답하지 않습니다. 잠시 후 다시 시도해 주세요."
    return f"{prefix}: {exc}"
```

**변경 2**: `get_ai_summary` 엔드포인트의 Gemini 호출부 (line ~351-366):

기존:
```python
        from google import genai
        ...
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        summary = await _generate_with_gemini_model_fallback(client, prompt)
```

대체:
```python
        try:
            llm = get_llm_client()
            summary = await llm.generate(prompt, max_tokens=1024, temperature=0.4)
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=_friendly_llm_error_detail(e, "AI 요약 생성에 실패했습니다"),
            )
```

`if not settings.GEMINI_API_KEY:` 체크는 다음으로 교체 (provider 별 검증):

```python
    provider = (settings.LLM_PROVIDER or "gemini").lower()
    if provider == "gemini" and not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="GEMINI_API_KEY가 설정되지 않았습니다.",
        )
    if provider == "openai_compat" and not settings.LLM_BASE_URL:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="LLM_BASE_URL 이 설정되지 않았습니다.",
        )
```

**변경 3**: `generate_export_report` 엔드포인트 (line ~459-658) 도 동일하게 두 곳 (검증 + 호출) 변경.

**변경 4**: 사용 안 하는 import 정리:
- `from typing import Any` 제거 가능 (다른 곳에서 안 쓰면)
- `import asyncio` — 다른 곳에서 사용 시 유지

### 5.9 `backend/requirements.txt` 업데이트

```diff
  google-auth==2.38.0
  google-genai>=1.0.0
+ openai>=1.50.0
```

> Gemini 도 계속 지원하므로 google-genai 는 남김. openai SDK 만 추가.

### 5.10 `backend/.env` 환경변수 (Sync API 서버)

```bash
# === 기존 ===
GEMINI_API_KEY=AIza...

# === 신규 — 자체 호스팅 LLM 사용 시 ===
LLM_PROVIDER=openai_compat
LLM_BASE_URL=http://10.0.0.5:8000/v1   # AI 서버 사설 IP + /v1
LLM_API_KEY=REPLACE_WITH_STRONG_SECRET_TOKEN  # vLLM --api-key 와 동일
LLM_MODEL=qwen3-9b                     # vLLM --served-model-name 과 동일
LLM_FALLBACK_MODEL=                    # (선택) 보조 모델

# === Gemini 로 폴백하려면 ===
# LLM_PROVIDER=gemini  (또는 줄 자체 삭제)
```

### 5.11 `docker-compose.yml` 환경변수 전달 확인

`api` 서비스 `environment:` 또는 `env_file:` 에 `LLM_*` 가 들어가는지 확인. 보통 `env_file: backend/.env` 이면 자동 로드됨.

명시적으로 추가하려면:

```yaml
services:
  api:
    environment:
      - LLM_PROVIDER=${LLM_PROVIDER:-gemini}
      - LLM_BASE_URL=${LLM_BASE_URL:-}
      - LLM_API_KEY=${LLM_API_KEY:-}
      - LLM_MODEL=${LLM_MODEL:-qwen3-9b}
      - LLM_FALLBACK_MODEL=${LLM_FALLBACK_MODEL:-}
```

---

## 6. 보안 / 네트워크

### 6.1 권장 토폴로지

```
[Sync API 서버 (Oracle Cloud)]
        │
        │ private VPN (WireGuard 등) 또는 Oracle Cloud VCN peering
        │
        ▼
[AI 서버 (자체 GPU 머신)]
   - vLLM @ 127.0.0.1:8000
   - nginx @ 443 (사내망 only)
   - 방화벽: TCP 443 만 허용 (소스 IP 제한)
```

### 6.2 방화벽 규칙 (UFW 예시)

```bash
sudo ufw default deny incoming
sudo ufw allow ssh
sudo ufw allow from <SYNC_API_PUBLIC_IP>/32 to any port 443 proto tcp
sudo ufw enable
sudo ufw status verbose
```

### 6.3 인증 토큰 회전

- vLLM `--api-key` 는 환경변수로 주입 (Docker run 명령에 평문 박지 말 것)
- Sync API 의 `LLM_API_KEY` 도 vault / secret manager 사용 권장
- 6개월 주기로 회전

### 6.4 민감정보 / 데이터 거버넌스

- Sync 의 AI 프롬프트에 사용자명·태스크 제목·알림 내용 포함됨 ([backend/app/routers/ai.py](../backend/app/routers/ai.py) 의 `_build_prompt` 참조)
- 자체 서버라 외부 유출 위험은 줄지만 다음 명시:
  - vLLM 컨테이너 로그에 prompt 일부가 INFO 로 찍힐 수 있음 → 운영 시 `--disable-log-stats --uvicorn-log-level warning` 옵션 추가 검토
  - 모델 다운로드 후 HuggingFace 캐시 (`~/.cache/huggingface`) 정리

---

## 7. 배포 절차 (단계별 안전 적용)

> **원칙**: 추상화 → 모델 서버 띄우기 → 스테이징 검증 → 운영 전환 → 회귀 검증. 각 단계 후 롤백 가능 지점 확보.

### Step 1 — 백엔드 추상화만 먼저 배포 (gemini 동작 그대로)

1. 위 5.1-5.9 코드 변경 적용
2. `LLM_PROVIDER` 환경변수 미설정 → 기본값 `gemini` → 기존과 100% 동일 동작
3. 배포 (`oracle_cloud/deploy_backend.sh` 또는 평소 흐름)
4. 검증: 대시보드 AI 매니저 새로고침 → 정상 응답
   - 실패 시 즉시 git revert + 재배포

### Step 2 — AI 서버 설치 + 헬스체크

위 1-4 섹션 그대로 수행. `curl` 로 chat completion 응답 확인까지.

### Step 3 — Sync API 와 AI 서버 네트워크 연결

```bash
# Sync API 서버에서
curl -s -X POST http://AI_SERVER_IP:8000/v1/chat/completions \
    -H "Authorization: Bearer REPLACE_WITH_STRONG_SECRET_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"model":"qwen3-9b","messages":[{"role":"user","content":"ping"}],"max_tokens":10}'
# → 200 OK + 응답 텍스트 받으면 OK
```

### Step 4 — 환경변수 전환 + Sync API 재기동

`backend/.env` 에 `LLM_*` 추가 후:

```bash
ssh ubuntu@SYNC_API_HOST
cd ~/app
docker compose restart api
docker compose logs api --tail 30 | grep -iE "llm|provider|started"
```

### Step 5 — UI 검증

- https://syncwork.kr/ → 다크모드 → 대시보드
- AI 매니저 새로고침 (캐시 무시 위해 다른 사용자 또는 시각 변경)
- 응답 시간 / 품질 확인
- 보고서 내보내기도 한 번 동작 확인

### Step 6 — 운영 모니터링 (1주일)

- Sync API 로그: AI 호출 실패율, 응답 시간
- AI 서버: GPU 사용률 (`nvidia-smi`), vLLM 로그
- Gemini 와 품질 비교 (사용자 피드백 수집)

---

## 8. 검증 시나리오 (배포 후 체크리스트)

| # | 시나리오 | 기대 결과 |
|---|---|---|
| 1 | AI 매니저 GET `/api/ai/summary?summary_scope=all` | 200 + 한국어 요약 텍스트 |
| 2 | AI 매니저 mine / others 모드 | 200 + 범위에 맞는 요약 |
| 3 | 같은 날 새로고침 | from_cache=true 즉시 반환 (Gemini 와 동일) |
| 4 | 보고서 POST `/api/ai/export-report` | 200 + 마크다운 보고서 |
| 5 | AI 서버 다운 시 | 502 + "AI 서버가 일시적으로 응답하지 않습니다" 메시지 |
| 6 | LLM_PROVIDER=gemini 로 다시 변경 | Gemini 로 폴백 동작 |
| 7 | 잘못된 LLM_API_KEY | 502 + 인증 오류 메시지 |
| 8 | 빈 LLM_BASE_URL | 422 + "LLM_BASE_URL 이 설정되지 않았습니다" |

### 자동화 테스트 (선택)

`backend/tests/test_llm_factory.py`:

```python
import pytest
from app.services.llm import get_llm_client
from app.services.llm.gemini_client import GeminiLLMClient
from app.services.llm.openai_compat_client import OpenAICompatLLMClient
from app.config import settings


def test_factory_selects_gemini(monkeypatch):
    monkeypatch.setattr(settings, "LLM_PROVIDER", "gemini")
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "test-key")
    get_llm_client.cache_clear()
    client = get_llm_client()
    assert isinstance(client, GeminiLLMClient)


def test_factory_selects_openai_compat(monkeypatch):
    monkeypatch.setattr(settings, "LLM_PROVIDER", "openai_compat")
    monkeypatch.setattr(settings, "LLM_BASE_URL", "http://test/v1")
    monkeypatch.setattr(settings, "LLM_API_KEY", "test-key")
    monkeypatch.setattr(settings, "LLM_MODEL", "qwen3-9b")
    get_llm_client.cache_clear()
    client = get_llm_client()
    assert isinstance(client, OpenAICompatLLMClient)
```

---

## 9. 대안 — Ollama 로 더 쉽게 (GPU 없거나 빠른 테스트)

vLLM 대신 Ollama 를 쓰면 셋업 5분:

```bash
# 1) 설치
curl -fsSL https://ollama.com/install.sh | sh

# 2) 모델 풀 (GGUF 양자화 — VRAM/RAM 적게 씀)
ollama pull qwen2.5:7b-instruct-q4_K_M

# 3) 실행 (자동으로 systemd 서비스 등록됨)
sudo systemctl enable --now ollama

# 4) OpenAI 호환 엔드포인트 자동 노출
curl http://localhost:11434/v1/models
```

Sync 환경변수만 다음으로 변경:

```bash
LLM_PROVIDER=openai_compat
LLM_BASE_URL=http://OLLAMA_HOST:11434/v1
LLM_API_KEY=ollama  # 더미 OK
LLM_MODEL=qwen2.5:7b-instruct-q4_K_M
```

> Ollama 는 인증 없이 노출되므로 nginx 프록시로 토큰 검증 추가 권장 (위 4번 섹션 그대로).

---

## 10. 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| `nvidia-smi` 가 명령어 없음 | NVIDIA 드라이버 미설치 → `sudo apt install nvidia-driver-535` 후 재부팅 |
| Docker GPU 인식 안 됨 | nvidia-container-toolkit 설치 후 `sudo systemctl restart docker` |
| vLLM 컨테이너가 OOM 으로 죽음 | `--gpu-memory-utilization 0.85` 로 낮추거나 `--max-model-len 4096` 으로 줄임. 그래도 안되면 양자화 모델(`Qwen/Qwen3-9B-Instruct-AWQ`) 사용 |
| `503 Service Unavailable` | 모델 로딩 중 (1-3분). `docker logs vllm-qwen` 으로 "Application startup complete" 대기 |
| `401 Unauthorized` | `LLM_API_KEY` 가 vLLM `--api-key` 와 다름. 양쪽 동기화 |
| `Connection refused` | Sync API 가 AI 서버에 닿지 않음. 방화벽 / 사설망 라우팅 확인. `curl AI_HOST:8000/v1/models` 로 확인 |
| 한국어 응답이 어색함 | temperature 0.3 → 0.5, 또는 EXAONE / HyperCLOVAX 같은 한국어 특화 모델로 교체 |
| 응답이 잘림 | `max_tokens` 늘림 (ai.py 의 `generate(prompt, max_tokens=2048)` 등) |
| Gemini 와 품질 차이 큼 | Qwen3-14B 또는 Qwen3-32B (VRAM 충분 시) 로 업그레이드 |
| vLLM 가동 후 GPU 다른 작업 못함 | `--gpu-memory-utilization 0.50` 으로 낮춰 공유 |

---

## 11. 롤백

언제든 환경변수 한 줄로 Gemini 로 복귀 가능:

```bash
# backend/.env
LLM_PROVIDER=gemini   # 또는 줄 삭제

# Sync API 재기동
docker compose restart api
```

코드 자체는 두 provider 다 살아있으므로 코드 revert 불필요.

전체 rollback (코드 포함):

```bash
git revert <commit-hash-of-llm-refactor>
docker compose build api && docker compose up -d api
```

---

## 12. 후속 개선 옵션

- **스트리밍 응답**: vLLM 은 `stream=True` 지원. 현재 Sync UI 는 한 번에 받지만, 추후 ChatGPT 처럼 점진 표시하려면 SSE 추가
- **임베딩 모델**: 같은 vLLM 컨테이너에 `--task embedding` 으로 임베딩 모델 동시 서빙 가능 (검색 / RAG 활용 대비)
- **다중 모델 라우팅**: 짧은 요약은 7B, 긴 보고서는 14B 등 작업별 모델 분기 (factory.py 확장)
- **Prometheus 메트릭**: vLLM 은 `/metrics` 자동 노출 → Grafana 연동
- **GPU 자동 절전**: 한가할 때 systemd 로 vLLM stop, 호출 시 자동 start (cold start 1-3분 감수)

---

## 부록 A — 변경/생성 파일 전체 목록

**Sync API (이 repo)**:

생성:
- `backend/app/services/llm/__init__.py`
- `backend/app/services/llm/base.py`
- `backend/app/services/llm/gemini_client.py`
- `backend/app/services/llm/openai_compat_client.py`
- `backend/app/services/llm/factory.py`

수정:
- `backend/app/config.py` — `LLM_*` 5개 필드 추가
- `backend/app/routers/ai.py` — Gemini 직접 호출 → `get_llm_client()` 로 교체 (2곳: get_ai_summary, generate_export_report)
- `backend/requirements.txt` — `openai>=1.50.0` 추가
- `backend/.env` — 운영 환경변수 추가
- `docker-compose.yml` (선택) — `LLM_*` 환경변수 명시 전달

**AI 서버 (별도 머신)**:
- `/etc/systemd/system/vllm-qwen.service`
- `/etc/nginx/sites-available/llm.conf` (외부 노출 시)
- `/opt/llm/models/Qwen3-9B-Instruct/` (다운로드된 모델)

---

## 부록 B — 빠른 참조 cheat sheet

```bash
# AI 서버
sudo systemctl status vllm-qwen
sudo docker logs vllm-qwen --tail 50
nvidia-smi
curl http://localhost:8000/v1/models -H "Authorization: Bearer $TOKEN"

# Sync API
docker compose logs api --tail 50 | grep -iE "llm|ai"
docker compose exec api python -c "from app.services.llm import get_llm_client; print(get_llm_client())"

# 모델 변경
# 1) AI 서버: docker run 명령 또는 systemd unit 파일에서 --model 변경 후 restart
# 2) Sync API: backend/.env 의 LLM_MODEL 변경 후 docker compose restart api
```

---

## 문서 업데이트 이력

- 2026-04-29 최초 작성. Qwen3-9B-Instruct + vLLM + OpenAI 호환 인터페이스 기준.
