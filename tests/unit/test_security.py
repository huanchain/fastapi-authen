"""Unit tests for security module."""
import pytest
from datetime import timedelta
from jose import jwt
from app.core.security import (
    create_access_token,
    create_refresh_token,
    verify_password,
    get_password_hash,
    verify_token,
)
from app.core.config import settings


@pytest.mark.unit
class TestPasswordHashing:
    """Test password hashing functions."""
    
    def test_hash_password(self):
        """Test password hashing."""
        password = "TestPassword123!"
        hashed = get_password_hash(password)
        
        assert hashed != password
        assert len(hashed) > 0
        assert hashed.startswith("$2b$")  # bcrypt hash
    
    def test_verify_password_correct(self):
        """Test password verification with correct password."""
        password = "TestPassword123!"
        hashed = get_password_hash(password)
        
        assert verify_password(password, hashed) is True
    
    def test_verify_password_incorrect(self):
        """Test password verification with incorrect password."""
        password = "TestPassword123!"
        wrong_password = "WrongPassword456!"
        hashed = get_password_hash(password)
        
        assert verify_password(wrong_password, hashed) is False
    
    def test_same_password_different_hashes(self):
        """Test that same password generates different hashes (salt)."""
        password = "TestPassword123!"
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)
        
        assert hash1 != hash2
        assert verify_password(password, hash1) is True
        assert verify_password(password, hash2) is True


@pytest.mark.unit
class TestTokenGeneration:
    """Test JWT token generation."""
    
    def test_create_access_token(self):
        """Test access token creation."""
        user_id = 123
        token = create_access_token(subject=user_id)
        
        assert token is not None
        assert isinstance(token, str)
        assert len(token) > 0
        
        # Decode and verify
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["sub"] == str(user_id)
        assert payload["type"] == "access"
        assert "exp" in payload
    
    def test_create_access_token_with_custom_expiry(self):
        """Test access token with custom expiration."""
        user_id = 123
        expires_delta = timedelta(minutes=15)
        token = create_access_token(subject=user_id, expires_delta=expires_delta)
        
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["type"] == "access"
    
    def test_create_refresh_token(self):
        """Test refresh token creation."""
        user_id = 123
        token = create_refresh_token(subject=user_id)
        
        assert token is not None
        assert isinstance(token, str)
        
        # Decode and verify
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["sub"] == str(user_id)
        assert payload["type"] == "refresh"
        assert "exp" in payload
    
    def test_create_refresh_token_with_custom_expiry(self):
        """Test refresh token with custom expiration."""
        user_id = 123
        expires_delta = timedelta(days=14)
        token = create_refresh_token(subject=user_id, expires_delta=expires_delta)
        
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert payload["type"] == "refresh"


@pytest.mark.unit
class TestTokenVerification:
    """Test JWT token verification."""
    
    def test_verify_valid_access_token(self):
        """Test verification of valid access token."""
        user_id = 123
        token = create_access_token(subject=user_id)
        
        result = verify_token(token, token_type="access")
        assert result == str(user_id)
    
    def test_verify_valid_refresh_token(self):
        """Test verification of valid refresh token."""
        user_id = 123
        token = create_refresh_token(subject=user_id)
        
        result = verify_token(token, token_type="refresh")
        assert result == str(user_id)
    
    def test_verify_token_wrong_type(self):
        """Test verification fails with wrong token type."""
        user_id = 123
        access_token = create_access_token(subject=user_id)
        
        result = verify_token(access_token, token_type="refresh")
        assert result is None
    
    def test_verify_invalid_token(self):
        """Test verification of invalid token."""
        invalid_token = "invalid.token.string"
        
        result = verify_token(invalid_token)
        assert result is None
    
    def test_verify_expired_token(self):
        """Test verification of expired token."""
        user_id = 123
        # Create token with negative expiry (already expired)
        expired_token = create_access_token(
            subject=user_id,
            expires_delta=timedelta(seconds=-1)
        )
        
        result = verify_token(expired_token)
        assert result is None
    
    def test_verify_token_tampered(self):
        """Test verification of tampered token."""
        user_id = 123
        token = create_access_token(subject=user_id)
        
        # Tamper with the token
        tampered_token = token[:-10] + "tampered00"
        
        result = verify_token(tampered_token)
        assert result is None

