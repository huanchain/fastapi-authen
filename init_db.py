"""
Initialize the database with all tables
"""
from app.core.database import Base, engine
from app.models import user  # Import all models

def init_db():
    """Create all database tables"""
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("Database tables created successfully!")

if __name__ == "__main__":
    init_db()

