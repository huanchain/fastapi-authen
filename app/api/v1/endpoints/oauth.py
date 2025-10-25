from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import RedirectResponse
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.config import settings
from app.core.security import create_access_token, create_refresh_token
from app.schemas.user import Token
from app.services.auth import AuthService
from app.models.user import User
import httpx
import secrets

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@router.get("/google")
async def google_login():
    """Generate Google OAuth2 login URL"""
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google OAuth2 is not configured"
        )
    
    # Generate state for CSRF protection
    state = secrets.token_urlsafe(32)
    
    # Google OAuth2 URL
    redirect_uri = f"{settings.API_V1_STR}/oauth/google/callback"
    google_auth_url = (
        f"https://accounts.google.com/o/oauth2/v2/auth?"
        f"client_id={settings.GOOGLE_CLIENT_ID}&"
        f"redirect_uri={redirect_uri}&"
        f"response_type=code&"
        f"scope=openid%20email%20profile&"
        f"state={state}"
    )
    
    return {"auth_url": google_auth_url, "state": state}

@router.get("/google/callback")
async def google_callback(
    code: str,
    state: str,
    db: Session = Depends(get_db)
):
    """Handle Google OAuth2 callback"""
    if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google OAuth2 is not configured"
        )
    
    # Exchange code for access token
    token_url = "https://oauth2.googleapis.com/token"
    redirect_uri = f"{settings.API_V1_STR}/oauth/google/callback"
    
    token_data = {
        "code": code,
        "client_id": settings.GOOGLE_CLIENT_ID,
        "client_secret": settings.GOOGLE_CLIENT_SECRET,
        "redirect_uri": redirect_uri,
        "grant_type": "authorization_code"
    }
    
    async with httpx.AsyncClient() as client:
        token_response = await client.post(token_url, data=token_data)
        
        if token_response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to exchange code for token"
            )
        
        token_info = token_response.json()
        access_token = token_info.get("access_token")
        
        # Get user info from Google
        user_info_url = "https://www.googleapis.com/oauth2/v2/userinfo"
        headers = {"Authorization": f"Bearer {access_token}"}
        user_response = await client.get(user_info_url, headers=headers)
        
        if user_response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to get user info from Google"
            )
        
        user_info = user_response.json()
    
    # Create or get user
    auth_service = AuthService(db)
    email = user_info.get("email")
    username = user_info.get("name", "").replace(" ", "_").lower()
    
    # Check if user exists
    user = db.query(User).filter(User.email == email).first()
    
    if not user:
        # Create new user
        user_data = {
            "email": email,
            "username": username,
            "password": secrets.token_urlsafe(32),  # Random password
            "is_verified": True,
            "is_active": True
        }
        user = auth_service.create_user(user_data)
    
    # Create session
    session = auth_service.create_session(user)
    
    # Create tokens
    jwt_access_token = create_access_token(subject=user.id)
    jwt_refresh_token = create_refresh_token(subject=user.id)
    
    return {
        "access_token": jwt_access_token,
        "refresh_token": jwt_refresh_token,
        "token_type": "bearer"
    }

@router.get("/github")
async def github_login():
    """Generate GitHub OAuth2 login URL"""
    if not settings.GITHUB_CLIENT_ID:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GitHub OAuth2 is not configured"
        )
    
    # Generate state for CSRF protection
    state = secrets.token_urlsafe(32)
    
    # GitHub OAuth2 URL
    redirect_uri = f"{settings.API_V1_STR}/oauth/github/callback"
    github_auth_url = (
        f"https://github.com/login/oauth/authorize?"
        f"client_id={settings.GITHUB_CLIENT_ID}&"
        f"redirect_uri={redirect_uri}&"
        f"scope=user:email&"
        f"state={state}"
    )
    
    return {"auth_url": github_auth_url, "state": state}

@router.get("/github/callback")
async def github_callback(
    code: str,
    state: str,
    db: Session = Depends(get_db)
):
    """Handle GitHub OAuth2 callback"""
    if not settings.GITHUB_CLIENT_ID or not settings.GITHUB_CLIENT_SECRET:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="GitHub OAuth2 is not configured"
        )
    
    # Exchange code for access token
    token_url = "https://github.com/login/oauth/access_token"
    redirect_uri = f"{settings.API_V1_STR}/oauth/github/callback"
    
    token_data = {
        "code": code,
        "client_id": settings.GITHUB_CLIENT_ID,
        "client_secret": settings.GITHUB_CLIENT_SECRET,
        "redirect_uri": redirect_uri
    }
    
    async with httpx.AsyncClient() as client:
        token_response = await client.post(
            token_url,
            data=token_data,
            headers={"Accept": "application/json"}
        )
        
        if token_response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to exchange code for token"
            )
        
        token_info = token_response.json()
        access_token = token_info.get("access_token")
        
        # Get user info from GitHub
        user_info_url = "https://api.github.com/user"
        headers = {"Authorization": f"Bearer {access_token}"}
        user_response = await client.get(user_info_url, headers=headers)
        
        if user_response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to get user info from GitHub"
            )
        
        user_info = user_response.json()
        
        # Get email from GitHub
        email_url = "https://api.github.com/user/emails"
        email_response = await client.get(email_url, headers=headers)
        emails = email_response.json() if email_response.status_code == 200 else []
        primary_email = next((e["email"] for e in emails if e.get("primary")), None)
    
    # Create or get user
    auth_service = AuthService(db)
    email = primary_email or user_info.get("email")
    username = user_info.get("login", "")
    
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not retrieve email from GitHub"
        )
    
    # Check if user exists
    user = db.query(User).filter(User.email == email).first()
    
    if not user:
        # Create new user
        user_data = {
            "email": email,
            "username": username,
            "password": secrets.token_urlsafe(32),  # Random password
            "is_verified": True,
            "is_active": True
        }
        user = auth_service.create_user(user_data)
    
    # Create session
    session = auth_service.create_session(user)
    
    # Create tokens
    jwt_access_token = create_access_token(subject=user.id)
    jwt_refresh_token = create_refresh_token(subject=user.id)
    
    return {
        "access_token": jwt_access_token,
        "refresh_token": jwt_refresh_token,
        "token_type": "bearer"
    }