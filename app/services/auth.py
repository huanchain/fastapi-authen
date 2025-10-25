from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session
from app.models.user import User, UserSession
from app.core.security import verify_password, get_password_hash, create_access_token, create_refresh_token
from app.core.config import settings
import secrets
import pyotp
import qrcode
import io
import base64

class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def authenticate_user(self, username: str, password: str) -> Optional[User]:
        user = self.db.query(User).filter(
            (User.username == username) | (User.email == username)
        ).first()
        if not user or not verify_password(password, user.hashed_password):
            return None
        return user

    def create_user(self, user_data: Dict[str, Any]) -> User:
        hashed_password = get_password_hash(user_data["password"])
        db_user = User(
            email=user_data["email"],
            username=user_data["username"],
            hashed_password=hashed_password
        )
        self.db.add(db_user)
        self.db.commit()
        self.db.refresh(db_user)
        return db_user

    def create_session(self, user: User, device_info: str = None, ip_address: str = None) -> UserSession:
        session_token = secrets.token_urlsafe(32)
        refresh_token = secrets.token_urlsafe(32)
        expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        
        session = UserSession(
            user_id=user.id,
            session_token=session_token,
            refresh_token=refresh_token,
            device_info=device_info,
            ip_address=ip_address,
            expires_at=expires_at
        )
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session

    def get_user_by_token(self, token: str) -> Optional[User]:
        session = self.db.query(UserSession).filter(
            UserSession.session_token == token,
            UserSession.is_active == True,
            UserSession.expires_at > datetime.utcnow()
        ).first()
        if not session:
            return None
        return session.user

    def revoke_session(self, token: str) -> bool:
        session = self.db.query(UserSession).filter(
            UserSession.session_token == token
        ).first()
        if session:
            session.is_active = False
            self.db.commit()
            return True
        return False

    def setup_mfa(self, user: User) -> Dict[str, str]:
        secret = pyotp.random_base32()
        totp = pyotp.TOTP(secret)
        qr_code = qrcode.make(totp.provisioning_uri(
            name=user.email,
            issuer_name=settings.PROJECT_NAME
        ))
        
        # Convert QR code to base64
        buffer = io.BytesIO()
        qr_code.save(buffer, format='PNG')
        qr_code_base64 = base64.b64encode(buffer.getvalue()).decode()
        
        return {
            "totp_secret": secret,
            "qr_code": f"data:image/png;base64,{qr_code_base64}"
        }

    def verify_mfa(self, user: User, code: str) -> bool:
        mfa_settings = user.mfa_settings
        if not mfa_settings or not mfa_settings.is_enabled:
            return False
        
        totp = pyotp.TOTP(mfa_settings.totp_secret)
        return totp.verify(code, valid_window=1)
