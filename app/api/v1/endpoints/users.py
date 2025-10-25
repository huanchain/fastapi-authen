from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.user import User, UserUpdate, APIKeyCreate, APIKeyResponse
from app.models.user import User as UserModel, APIKey
from app.services.auth import AuthService
import secrets
import hashlib

router = APIRouter()

@router.get("/me", response_model=User)
async def read_users_me(current_user: UserModel = Depends(get_current_user)):
    return current_user

@router.put("/me", response_model=User)
async def update_user_me(
    user_update: UserUpdate,
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Update user fields
    for field, value in user_update.dict(exclude_unset=True).items():
        setattr(current_user, field, value)
    
    db.commit()
    db.refresh(current_user)
    return current_user

@router.post("/api-keys", response_model=APIKeyResponse)
async def create_api_key(
    api_key_data: APIKeyCreate,
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Generate API key
    api_key = secrets.token_urlsafe(32)
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()
    
    # Create API key record
    db_api_key = APIKey(
        user_id=current_user.id,
        key_name=api_key_data.key_name,
        key_hash=key_hash,
        scopes=",".join(api_key_data.scopes)
    )
    db.add(db_api_key)
    db.commit()
    db.refresh(db_api_key)
    
    # Return the API key (only shown once)
    return {
        "id": db_api_key.id,
        "key_name": db_api_key.key_name,
        "scopes": api_key_data.scopes,
        "is_active": db_api_key.is_active,
        "created_at": db_api_key.created_at,
        "expires_at": db_api_key.expires_at,
        "api_key": api_key  # Include the actual key in response
    }

@router.get("/api-keys", response_model=list[APIKeyResponse])
async def list_api_keys(
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    api_keys = db.query(APIKey).filter(APIKey.user_id == current_user.id).all()
    return api_keys

@router.delete("/api-keys/{key_id}")
async def revoke_api_key(
    key_id: int,
    current_user: UserModel = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    api_key = db.query(APIKey).filter(
        APIKey.id == key_id,
        APIKey.user_id == current_user.id
    ).first()
    
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="API key not found"
        )
    
    api_key.is_active = False
    db.commit()
    
    return {"message": "API key revoked successfully"}
