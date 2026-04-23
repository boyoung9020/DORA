---
name: ariel
description: "Ariel 미디어 처리 서버 API 레퍼런스 및 통합 가이드. Ariel API 호출, 트랜스코딩, 썸네일/카탈로그 추출, 메타데이터 추출, 오디오/비디오/이미지 처리, 콜백 구현, 파일 전송 등 Ariel 관련 작업을 할 때 반드시 이 스킬을 사용하세요. '트랜스코딩', '썸네일', '카탈로그', '미디어 처리', '프록시 영상', '메자닌', 'ariel', '콜백', '비디오 변환', '오디오 변환', '이미지 리사이즈' 등의 키워드가 포함된 요청에서 트리거됩니다."
---

# Ariel 미디어 처리 서버 통합 가이드

Ariel은 MyMy 프로젝트의 미디어 처리 및 트랜스코딩을 담당하는 외부 서버다. MyMy API가 Ariel에 작업(Task)을 요청하면, Ariel은 처리 완료 시 콜백(POST)으로 결과를 반환하는 **비동기 콜백 기반 구조**로 동작한다.

## 빠른 참조

- Swagger UI: `http://localhost:9300/manager/swagger-ui.html#/`
- 상세 API 레퍼런스: `docs/ariel/ariel-api-reference.md` — 작업 타입별 param 형식, 콜백 Body 구조, payload 생성 함수 목록 등 상세 정보가 담겨 있으므로 구현 전 반드시 읽을 것
- Java Agent 파라미터: `docs/ariel/Java agent 파라미터 정리.xlsx`

## 아키텍처 개요

```
파일 업로드 → Task 레코드 생성 → PostgreSQL 큐 등록
  → Worker가 큐에서 소비 → Ariel API에 POST 요청 (JWT)
  → Ariel 처리 → 콜백으로 진행상황/결과 전달
  → 콜백 컨트롤러가 Task 상태/메타데이터 업데이트
```

### Docker 구성

| 서비스 | 호스트 포트 | 설명 |
|--------|-----------|------|
| `ariel-agent` | 8080 | 미디어 처리 에이전트 |
| `ariel-manager` | 9300 | 작업 관리 API 서버 |
| `ariel-manager-ui` | 3300 | 관리 UI |

## 핵심 개념

### 작업 타입 (Task Type)

| type | 설명 |
|------|------|
| `10` | 썸네일/카탈로그 추출 |
| `20` | 비디오 트랜스코딩 |
| `22` | 이미지 트랜스코딩 |
| `60` | 파일 전송 |
| `70` | 오디오 트랜스코딩 |
| `71` | 오디오 커버 추출 |
| `130` | 메타데이터 추출 |

### 작업 상태 (Task Status)

| 값 | 설명 |
|----|------|
| 0 | ERROR |
| 1 | SUCCESS |
| 2 | PROCESSING |
| 4 | CANCELED |
| 100 | WAITING |

### 작업 큐

| 큐 이름 | 용도 |
|---------|------|
| `arielInfo` | 메타데이터 추출 |
| `arielTC` | 트랜스코딩 |

## API 호출 방법

### 설정값 접근

```typescript
import { getCachedSetting } from '@/services/settingCache';

const arielApiRoot = await getCachedSetting(db, 'ARIEL_PROXY_API_ROOT');
const arielApiKey = await getCachedSetting(db, 'ARIEL_PROXY_API_KEY');
```

- 기본 URL: `http://localhost:9300/manager/task`
- 인증: `Authorization` 헤더에 JWT 토큰

### 요청 엔드포인트

- 작업 생성: `POST {ARIEL_PROXY_API_ROOT}`
- 작업 재시작: `PUT {ARIEL_PROXY_API_ROOT}/{taskId}` (Body: `retry`, Content-Type: `text/plain`)

### Payload 공통 구조

모든 요청은 `src_path` (소스), `tgt_path` (대상), `type`, `param`, `callback` 필드를 포함한다. 스토리지 타입에 따라:
- **AWS S3 / CloudFront**: `src_region`, `tgt_region` 사용
- **MinIO S3**: `src_endPoint`, `tgt_endPoint` 사용

### 스토리지 타입

| 값 | 설명 |
|----|------|
| 1 | LOCAL |
| 4 | AWS S3 + CloudFront |
| 8 | AWS S3 |
| 9 | MinIO S3 |

## Payload 생성 함수

기존 유틸리티 함수를 활용하여 payload를 생성한다. 새로운 Ariel 작업을 구현할 때는 기존 함수를 참고하거나 확장하는 것이 좋다.

| 함수명 | type | 설명 |
|--------|------|------|
| `createArielExtractVideoInfoBody` | 130 | 비디오 메타데이터 추출 |
| `createArielExtractAudioInfoBody` | 130 | 오디오 메타데이터 추출 |
| `createArielExtractImageInfoBody` | 130 | 이미지 메타데이터 추출 |
| `createArielExtractVideoThumbBody` | 10 | 비디오 썸네일 추출 |
| `createArielExtractVideoCatalogBody` | 10 | 비디오 카탈로그 추출 |
| `createArielExtractAudioCoverBody` | 71 | 오디오 커버 추출 |
| `createArielTCVideoBody` | 20 | 비디오 트랜스코딩 |
| `createArielTCAudioBody` | 70 | 오디오 트랜스코딩 |
| `createArielTCVideoExtractAudio` | 70 | 비디오에서 오디오 추출 |
| `createArielTCImageBody` | 22 | 이미지 트랜스코딩 |
| `createArielFileTransferBody` | 60 | 파일 전송 |

소스: `refactoring_apps/api/src/utils/integrateAriel.util.js`

## 콜백 구현

Ariel이 작업 완료 시 MyMy API로 POST 콜백을 보낸다. 콜백 라우트는 `POST /api/v1/ariel_callbacks/{type}` 형식이다.

### 주요 콜백 라우트

| 라우트 | 설명 |
|--------|------|
| `video_extract_info` | 비디오 메타데이터 |
| `video_thumbnail` | 비디오 썸네일 |
| `video_proxy_tc` | 비디오 프록시 트랜스코딩 |
| `video_mezzanine_tc` | 비디오 메자닌 트랜스코딩 |
| `createCatalog` | 비디오 카탈로그 |
| `audio_extract_info` | 오디오 메타데이터 |
| `audio_proxy_tc` | 오디오 프록시 트랜스코딩 |
| `audio_cover` | 오디오 커버 |
| `image_extract_info` | 이미지 메타데이터 |
| `image_proxy_tc` | 이미지 프록시 트랜스코딩 |

### 콜백 Body 구조

```json
{
  "Request": {
    "Status": "ok",
    "Progress": 100,
    "TaskID": "ARL-20250918-0001",
    "TypeCode": "VIDEO_EXTRACT",
    "Request": {
      "RegistMeta": {
        "System": {
          "MetaCtrl": [
            { "name": "Resolution", "content": "1920x1080" },
            { "name": "DurationMS", "content": "123456" }
          ]
        }
      }
    }
  }
}
```

## 관련 소스 파일

| 파일 | 설명 |
|------|------|
| `refactoring_apps/api/src/utils/integrateAriel.util.js` | Payload 생성 + API 호출 |
| `refactoring_apps/api/src/routes/arielCallback.route.js` | 콜백 라우트 |
| `refactoring_apps/api/src/controllers/arielCallback.control.js` | 콜백 컨트롤러 |
| `refactoring_apps/api/src/config/common.config.js` | 콜백 라우트 설정 |
| `arielTCServer.js` | 트랜스코딩 Worker |
| `arielUploadInfoServer.js` | 메타데이터 추출 Worker |
| `refactoring_apps/ariel-bridge/` | Ariel 브리지 앱 |

## 구현 체크리스트

새로운 Ariel 연동 기능을 구현할 때:

1. `docs/ariel/ariel-api-reference.md`를 읽어 해당 작업 타입의 param 형식 확인
2. 기존 payload 생성 함수 패턴을 따라 구현 (스토리지 타입별 분기 포함)
3. 콜백 라우트와 컨트롤러 구현 (기존 패턴 참고)
4. 콜백에서 Task 상태 업데이트 로직 포함
5. 에러/재시도 처리 고려 (`restartTaskAsync` 활용)
