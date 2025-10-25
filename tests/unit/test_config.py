"""Unit tests for configuration."""
import pytest
from app.core.config import Settings


@pytest.mark.unit
class TestSettings:
    """Test application settings."""
    
    def test_settings_defaults(self):
        """Test default settings values."""
        settings = Settings()
        
        assert settings.PROJECT_NAME == "FastAPI Authentication API"
        assert settings.PROJECT_VERSION == "1.0.0"
        assert settings.API_V1_STR == "/api/v1"
        assert settings.ACCESS_TOKEN_EXPIRE_MINUTES == 30
        assert settings.REFRESH_TOKEN_EXPIRE_DAYS == 7
        assert settings.ALGORITHM == "HS256"
    
    def test_settings_from_env(self, monkeypatch):
        """Test settings loaded from environment variables."""
        monkeypatch.setenv("PROJECT_NAME", "Custom API Name")
        monkeypatch.setenv("SECRET_KEY", "custom-secret-key")
        monkeypatch.setenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60")
        
        settings = Settings()
        
        assert settings.PROJECT_NAME == "Custom API Name"
        assert settings.SECRET_KEY == "custom-secret-key"
        assert settings.ACCESS_TOKEN_EXPIRE_MINUTES == 60
    
    def test_database_url_default(self):
        """Test default database URL."""
        settings = Settings()
        
        assert settings.DATABASE_URL is not None
        assert isinstance(settings.DATABASE_URL, str)

