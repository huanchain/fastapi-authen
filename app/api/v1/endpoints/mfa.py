from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.user import MFASetup, MFAVerify
from app.models.user import User, MFASettings
from app.services.auth import AuthService
import pyotp
import qrcode
import io
import base64
from app.core.config import settings

router = APIRouter()

@router.post("/setup", response_model=MFASetup)
async def setup_mfa(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    auth_service = AuthService(db)
    mfa_data = auth_service.setup_mfa(current_user)
    
    # Save MFA settings to database
    mfa_settings = MFASettings(
        user_id=current_user.id,
        totp_secret=mfa_data["totp_secret"],
        is_enabled=False  # Will be enabled after verification
    )
    db.add(mfa_settings)
    db.commit()
    
    return mfa_data

@router.post("/verify")
async def verify_mfa(
    mfa_data: MFAVerify,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    auth_service = AuthService(db)
    
    if not auth_service.verify_mfa(current_user, mfa_data.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid MFA code"
        )
    
    # Enable MFA for the user
    mfa_settings = db.query(MFASettings).filter(
        MFASettings.user_id == current_user.id
    ).first()
    
    if mfa_settings:
        mfa_settings.is_enabled = True
        db.commit()
    
    return {"message": "MFA enabled successfully"}

@router.post("/disable")
async def disable_mfa(
    mfa_data: MFAVerify,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    auth_service = AuthService(db)
    
    if not auth_service.verify_mfa(current_user, mfa_data.code):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid MFA code"
        )
    
    # Disable MFA for the user
    mfa_settings = db.query(MFASettings).filter(
        MFASettings.user_id == current_user.id
    ).first()
    
    if mfa_settings:
        mfa_settings.is_enabled = False
        db.commit()
    
    return {"message": "MFA disabled successfully"}

@router.get("/status")
async def get_mfa_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    mfa_settings = db.query(MFASettings).filter(
        MFASettings.user_id == current_user.id
    ).first()
    
    return {
        "is_enabled": mfa_settings.is_enabled if mfa_settings else False,
        "has_backup_codes": bool(mfa_settings and mfa_settings.backup_codes)
    }
