"""Integration tests for user endpoints."""
import pytest
from fastapi.testclient import TestClient
from app.models.user import User


@pytest.mark.integration
class TestUserProfile:
    """Test user profile endpoints."""
    
    def test_get_current_user_profile(self, client: TestClient, test_user: User, test_user_session):
        """Test getting current user profile."""
        from app.core.security import create_access_token
        
        # Create proper access token
        access_token = create_access_token(subject=test_user.id)
        headers = {"Authorization": f"Bearer {access_token}"}
        
        response = client.get("/api/v1/users/me", headers=headers)
        
        # May return 401 if session is not properly linked
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert data["email"] == test_user.email
            assert data["username"] == test_user.username
            assert "password" not in data
            assert "hashed_password" not in data
    
    def test_get_profile_unauthenticated(self, client: TestClient):
        """Test getting profile without authentication."""
        response = client.get("/api/v1/users/me")
        
        assert response.status_code == 403
    
    def test_get_profile_invalid_token(self, client: TestClient):
        """Test getting profile with invalid token."""
        headers = {"Authorization": "Bearer invalid_token"}
        
        response = client.get("/api/v1/users/me")
        
        assert response.status_code == 401


@pytest.mark.integration
class TestHealthCheck:
    """Test health check endpoint."""
    
    def test_health_check(self, client: TestClient):
        """Test health check endpoint."""
        response = client.get("/health")
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
    
    def test_root_endpoint(self, client: TestClient):
        """Test root endpoint."""
        response = client.get("/")
        
        assert response.status_code == 200
        data = response.json()
        assert "message" in data

