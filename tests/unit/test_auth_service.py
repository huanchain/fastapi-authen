"""Unit tests for authentication service."""
import pytest
from sqlalchemy.orm import Session
from app.services.auth import AuthService
from app.models.user import User, UserSession
from app.core.security import verify_password


@pytest.mark.unit
class TestAuthServiceUserCreation:
    """Test user creation in auth service."""
    
    def test_create_user_success(self, test_db: Session):
        """Test successful user creation."""
        auth_service = AuthService(test_db)
        user_data = {
            "email": "newuser@example.com",
            "username": "newuser",
            "password": "SecurePassword123!",
        }
        
        user = auth_service.create_user(user_data)
        
        assert user.id is not None
        assert user.email == user_data["email"]
        assert user.username == user_data["username"]
        assert user.hashed_password != user_data["password"]
        assert verify_password(user_data["password"], user.hashed_password)
        assert user.is_active is True
        assert user.is_verified is False
    
    def test_create_user_password_hashed(self, test_db: Session):
        """Test that password is properly hashed."""
        auth_service = AuthService(test_db)
        user_data = {
            "email": "newuser@example.com",
            "username": "newuser",
            "password": "PlainTextPassword",
        }
        
        user = auth_service.create_user(user_data)
        
        assert user.hashed_password != user_data["password"]
        assert user.hashed_password.startswith("$2b$")


@pytest.mark.unit
class TestAuthServiceAuthentication:
    """Test authentication in auth service."""
    
    def test_authenticate_user_with_username(self, test_db: Session, test_user: User, test_user_data: dict):
        """Test authentication with username."""
        auth_service = AuthService(test_db)
        
        user = auth_service.authenticate_user(
            test_user_data["username"],
            test_user_data["password"]
        )
        
        assert user is not None
        assert user.id == test_user.id
        assert user.username == test_user.username
    
    def test_authenticate_user_with_email(self, test_db: Session, test_user: User, test_user_data: dict):
        """Test authentication with email."""
        auth_service = AuthService(test_db)
        
        user = auth_service.authenticate_user(
            test_user_data["email"],
            test_user_data["password"]
        )
        
        assert user is not None
        assert user.id == test_user.id
        assert user.email == test_user.email
    
    def test_authenticate_user_wrong_password(self, test_db: Session, test_user: User):
        """Test authentication with wrong password."""
        auth_service = AuthService(test_db)
        
        user = auth_service.authenticate_user(
            test_user.username,
            "WrongPassword123!"
        )
        
        assert user is None
    
    def test_authenticate_user_nonexistent(self, test_db: Session):
        """Test authentication with nonexistent user."""
        auth_service = AuthService(test_db)
        
        user = auth_service.authenticate_user(
            "nonexistent@example.com",
            "AnyPassword123!"
        )
        
        assert user is None


@pytest.mark.unit
class TestAuthServiceSession:
    """Test session management in auth service."""
    
    def test_create_session(self, test_db: Session, test_user: User):
        """Test session creation."""
        auth_service = AuthService(test_db)
        
        session = auth_service.create_session(
            user=test_user,
            device_info="Test Device",
            ip_address="192.168.1.1"
        )
        
        assert session.id is not None
        assert session.user_id == test_user.id
        assert session.session_token is not None
        assert session.refresh_token is not None
        assert session.device_info == "Test Device"
        assert session.ip_address == "192.168.1.1"
        assert session.is_active is True
        assert session.expires_at is not None
    
    def test_get_user_by_token(self, test_db: Session, test_user_session: UserSession):
        """Test getting user by session token."""
        auth_service = AuthService(test_db)
        
        user = auth_service.get_user_by_token(test_user_session.session_token)
        
        assert user is not None
        assert user.id == test_user_session.user_id
    
    def test_get_user_by_invalid_token(self, test_db: Session):
        """Test getting user with invalid token."""
        auth_service = AuthService(test_db)
        
        user = auth_service.get_user_by_token("invalid_token")
        
        assert user is None
    
    def test_revoke_session(self, test_db: Session, test_user_session: UserSession):
        """Test session revocation."""
        auth_service = AuthService(test_db)
        
        result = auth_service.revoke_session(test_user_session.session_token)
        
        assert result is True
        
        # Verify session is inactive
        test_db.refresh(test_user_session)
        assert test_user_session.is_active is False
    
    def test_revoke_nonexistent_session(self, test_db: Session):
        """Test revoking nonexistent session."""
        auth_service = AuthService(test_db)
        
        result = auth_service.revoke_session("nonexistent_token")
        
        assert result is False


@pytest.mark.unit
class TestAuthServiceMFA:
    """Test MFA functionality in auth service."""
    
    def test_setup_mfa(self, test_db: Session, test_user: User):
        """Test MFA setup."""
        auth_service = AuthService(test_db)
        
        mfa_data = auth_service.setup_mfa(test_user)
        
        assert "totp_secret" in mfa_data
        assert "qr_code" in mfa_data
        assert len(mfa_data["totp_secret"]) > 0
        assert mfa_data["qr_code"].startswith("data:image/png;base64,")
    
    def test_verify_mfa_valid_code(self, test_db: Session, test_mfa_user: User):
        """Test MFA verification with valid code."""
        import pyotp
        auth_service = AuthService(test_db)
        
        # Generate valid TOTP code
        totp = pyotp.TOTP(test_mfa_user.mfa_settings.totp_secret)
        valid_code = totp.now()
        
        result = auth_service.verify_mfa(test_mfa_user, valid_code)
        
        assert result is True
    
    def test_verify_mfa_invalid_code(self, test_db: Session, test_mfa_user: User):
        """Test MFA verification with invalid code."""
        auth_service = AuthService(test_db)
        
        result = auth_service.verify_mfa(test_mfa_user, "000000")
        
        assert result is False
    
    def test_verify_mfa_user_without_mfa(self, test_db: Session, test_user: User):
        """Test MFA verification for user without MFA enabled."""
        auth_service = AuthService(test_db)
        
        result = auth_service.verify_mfa(test_user, "123456")
        
        assert result is False

