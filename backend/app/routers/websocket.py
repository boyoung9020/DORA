"""
WebSocket 라우터 - 실시간 동기화
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import List, Dict
import json
import asyncio

router = APIRouter()

# 연결된 클라이언트 관리
class ConnectionManager:
    def __init__(self):
        # 활성 연결: {user_id: [websocket1, websocket2, ...]}
        self.active_connections: Dict[str, List[WebSocket]] = {}
        # 모든 연결 (브로드캐스트용)
        self.all_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)
        self.all_connections.append(websocket)
        print(f"[WebSocket] 사용자 {user_id} 연결됨. 총 연결: {len(self.all_connections)}")

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        
        if websocket in self.all_connections:
            self.all_connections.remove(websocket)
        print(f"[WebSocket] 사용자 {user_id} 연결 해제됨. 총 연결: {len(self.all_connections)}")

    async def send_personal_message(self, message: dict, websocket: WebSocket):
        try:
            await websocket.send_json(message)
        except Exception as e:
            print(f"[WebSocket] 개인 메시지 전송 실패: {e}")

    async def send_to_user(self, message: dict, user_id: str):
        """특정 사용자에게만 메시지 전송 (타겟 전송)"""
        if user_id not in self.active_connections:
            return
        
        disconnected = []
        for websocket in self.active_connections[user_id][:]:
            try:
                await websocket.send_json(message)
            except Exception as e:
                print(f"[WebSocket] 사용자 {user_id} 전송 실패: {e}")
                disconnected.append(websocket)
        
        # 끊어진 연결 정리
        for ws in disconnected:
            self.active_connections[user_id].remove(ws)
            if ws in self.all_connections:
                self.all_connections.remove(ws)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_to_users(self, message: dict, user_ids: list, exclude_user_id: str = None):
        """여러 사용자에게 메시지 전송 (타겟 전송)"""
        for uid in user_ids:
            if exclude_user_id and uid == exclude_user_id:
                continue
            await self.send_to_user(message, uid)

    async def broadcast(self, message: dict, exclude_user_id: str = None):
        """모든 연결된 클라이언트에게 메시지 브로드캐스트"""
        if not self.all_connections:
            return
        
        disconnected = []
        for websocket in self.all_connections[:]:  # 복사본으로 순회
            # exclude_user_id가 지정된 경우 해당 사용자의 연결은 제외
            if exclude_user_id:
                should_exclude = False
                for user_id, connections in self.active_connections.items():
                    if user_id == exclude_user_id and websocket in connections:
                        should_exclude = True
                        break
                if should_exclude:
                    continue
            
            try:
                await websocket.send_json(message)
            except Exception as e:
                print(f"[WebSocket] 브로드캐스트 실패: {e}")
                disconnected.append(websocket)
        
        # 끊어진 연결 정리
        for ws in disconnected:
            if ws in self.all_connections:
                self.all_connections.remove(ws)
            # active_connections에서도 제거
            for user_id, connections in list(self.active_connections.items()):
                if ws in connections:
                    connections.remove(ws)
                    if not connections:
                        del self.active_connections[user_id]

# 전역 연결 관리자
manager = ConnectionManager()


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket 연결 엔드포인트"""
    from app.database import SessionLocal
    from app.utils.security import decode_access_token
    from app.models.user import User
    
    # 쿼리 파라미터에서 토큰 가져오기
    token = websocket.query_params.get("token")
    if not token:
        print("[WebSocket] 토큰이 없습니다")
        await websocket.close(code=1008, reason="토큰이 필요합니다")
        return
    
    print(f"[WebSocket] 토큰 수신: {token[:20]}...")  # 토큰 일부만 로그
    
    # 토큰 검증 및 사용자 조회
    payload = decode_access_token(token)
    if payload is None:
        print("[WebSocket] 토큰 검증 실패")
        await websocket.close(code=1008, reason="유효하지 않은 토큰입니다")
        return
    
    print(f"[WebSocket] 토큰 검증 성공, payload: {payload}")
    
    user_id = payload.get("sub")
    if not user_id:
        await websocket.close(code=1008, reason="토큰에서 사용자 정보를 찾을 수 없습니다")
        return
    
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            print(f"[WebSocket] 사용자를 찾을 수 없음: {user_id}")
            await websocket.close(code=1008, reason="사용자를 찾을 수 없습니다")
            return
        if not user.is_approved:
            print(f"[WebSocket] 사용자 승인되지 않음: {user_id}, is_approved: {user.is_approved}")
            await websocket.close(code=1008, reason="사용자가 승인되지 않았습니다")
            return
        
        await manager.connect(websocket, user.id)
        try:
            while True:
                # 클라이언트로부터 메시지 수신 (ping/pong 등)
                data = await websocket.receive_text()
                # 하트비트 응답
                if data == "ping":
                    await websocket.send_text("pong")
        except WebSocketDisconnect:
            manager.disconnect(websocket, user.id)
        except Exception as e:
            print(f"[WebSocket] 오류: {e}")
            manager.disconnect(websocket, user.id)
    finally:
        db.close()


def broadcast_event(event_type: str, data: dict, exclude_user_id: str = None):
    """이벤트 브로드캐스트 (동기 함수에서 호출)"""
    message = {
        "type": event_type,
        "data": data
    }
    # 비동기 함수를 동기적으로 실행
    asyncio.create_task(manager.broadcast(message, exclude_user_id))


def send_event_to_users(event_type: str, data: dict, user_ids: list, exclude_user_id: str = None):
    """특정 사용자들에게만 이벤트 전송 (동기 함수에서 호출)"""
    message = {
        "type": event_type,
        "data": data
    }
    asyncio.create_task(manager.send_to_users(message, user_ids, exclude_user_id))


def send_event_to_user(event_type: str, data: dict, user_id: str):
    """특정 사용자 1명에게 이벤트 전송 (동기 함수에서 호출)"""
    message = {
        "type": event_type,
        "data": data
    }
    asyncio.create_task(manager.send_to_user(message, user_id))

