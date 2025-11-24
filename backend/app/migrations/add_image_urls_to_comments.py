"""
comments 테이블에 image_urls 컬럼 추가 마이그레이션
"""
from sqlalchemy import text
from app.database import engine

def add_image_urls_column():
    """comments 테이블에 image_urls 컬럼 추가"""
    with engine.connect() as conn:
        try:
            # 컬럼이 이미 존재하는지 확인
            result = conn.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name='comments' AND column_name='image_urls'
            """))
            
            if result.fetchone() is None:
                # image_urls 컬럼 추가
                conn.execute(text("""
                    ALTER TABLE comments 
                    ADD COLUMN image_urls VARCHAR[] DEFAULT '{}' NOT NULL
                """))
                conn.commit()
                print("✅ image_urls 컬럼이 추가되었습니다.")
            else:
                print("✅ image_urls 컬럼이 이미 존재합니다.")
        except Exception as e:
            print(f"❌ 오류 발생: {e}")
            conn.rollback()
            raise

if __name__ == "__main__":
    add_image_urls_column()

