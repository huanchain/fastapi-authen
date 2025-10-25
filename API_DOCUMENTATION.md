# API Documentation

Complete API documentation for FastAPI Authentication API.

## Table of Contents

- [Overview](#overview)
- [Authentication](#authentication)
- [Rate Limiting](#rate-limiting)
- [Error Handling](#error-handling)
- [Endpoints](#endpoints)

## Overview

Base URL: `http://localhost:8000`

API Version: `v1`

All API endpoints are prefixed with `/api/v1`

## Authentication

This API uses JWT (JSON Web Tokens) for authentication.

### Authentication Flow

1. **Register** a new user account
2. **Login** to receive access and refresh tokens
3. Include the access token in the `Authorization` header for protected endpoints

### Token Format

```
Authorization: Bearer <your_access_token>
```

### Token Expiration

- **Access Token**: 30 minutes
- **Refresh Token**: 7 days

## Rate Limiting

API requests are rate-limited to prevent abuse:

- **Limit**: 60 requests per minute per IP address
- **Headers returned**:
  - `X-RateLimit-Limit`: Maximum requests allowed
  - `X-RateLimit-Remaining`: Requests remaining
  - `X-RateLimit-Reset`: Time when limit resets (Unix timestamp)

## Error Handling

The API uses standard HTTP status codes and returns errors in this format:

```json
{
  "detail": "Error message description"
}
```

### Status Codes

- `200 OK` - Successful request
- `201 Created` - Resource successfully created
- `400 Bad Request` - Invalid request data
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `409 Conflict` - Resource already exists
- `422 Unprocessable Entity` - Validation error
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

## Endpoints

### Health Check

#### GET /health

Check API health status.

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

---

### Authentication Endpoints

#### POST /api/v1/auth/register

Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "username": "username",
  "password": "SecurePassword123!"
}
```

**Response:** `200 OK`
```json
{
  "message": "User created successfully",
  "user_id": 1
}
```

**Errors:**
- `400` - User already exists
- `422` - Validation error

---

#### POST /api/v1/auth/login

Login to get access tokens.

**Request Body:**
```json
{
  "username": "username",  // Can also use email
  "password": "SecurePassword123!"
}
```

**Response:** `200 OK`
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "token_type": "bearer"
}
```

**Errors:**
- `401` - Invalid credentials
- `400` - Inactive user

---

#### POST /api/v1/auth/logout

Logout current user session.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "message": "Successfully logged out"
}
```

**Errors:**
- `401` - Invalid token
- `403` - No authentication provided

---

#### POST /api/v1/auth/change-password

Change user password.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "current_password": "OldPassword123!",
  "new_password": "NewPassword123!"
}
```

**Response:** `200 OK`
```json
{
  "message": "Password changed successfully"
}
```

**Errors:**
- `400` - Incorrect current password
- `401` - Invalid token

---

### User Management Endpoints

#### GET /api/v1/users/me

Get current user profile.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "id": 1,
  "email": "user@example.com",
  "username": "username",
  "is_active": true,
  "is_verified": false,
  "created_at": "2024-01-01T00:00:00Z"
}
```

**Errors:**
- `401` - Invalid token

---

#### PUT /api/v1/users/me

Update current user profile.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "email": "newemail@example.com",
  "username": "newusername"
}
```

**Response:** `200 OK`
```json
{
  "id": 1,
  "email": "newemail@example.com",
  "username": "newusername",
  "is_active": true
}
```

---

### MFA (Multi-Factor Authentication) Endpoints

#### POST /api/v1/mfa/setup

Setup MFA for current user.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "totp_secret": "JBSWY3DPEHPK3PXP",
  "qr_code": "data:image/png;base64,iVBOR..."
}
```

**Usage:**
1. Scan the QR code with an authenticator app (Google Authenticator, Authy, etc.)
2. Verify the setup using the `/api/v1/mfa/verify` endpoint

---

#### POST /api/v1/mfa/verify

Verify MFA code and enable MFA.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "code": "123456"
}
```

**Response:** `200 OK`
```json
{
  "message": "MFA enabled successfully"
}
```

**Errors:**
- `400` - Invalid MFA code

---

#### POST /api/v1/mfa/disable

Disable MFA for current user.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Request Body:**
```json
{
  "code": "123456"
}
```

**Response:** `200 OK`
```json
{
  "message": "MFA disabled successfully"
}
```

---

#### GET /api/v1/mfa/status

Get MFA status for current user.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response:** `200 OK`
```json
{
  "is_enabled": true,
  "has_backup_codes": false
}
```

---

### OAuth2 Endpoints

#### GET /api/v1/oauth/google

Initiate Google OAuth2 login.

**Response:** `200 OK`
```json
{
  "message": "Redirect to Google OAuth2"
}
```

**Note:** In production, this would redirect to Google's OAuth2 consent screen.

---

#### GET /api/v1/oauth/google/callback

Google OAuth2 callback endpoint.

**Query Parameters:**
- `code`: Authorization code from Google

**Response:** `200 OK`
```json
{
  "message": "Google OAuth2 callback"
}
```

**Note:** In production, this would exchange the code for tokens and return JWT tokens.

---

#### GET /api/v1/oauth/github

Initiate GitHub OAuth2 login.

**Response:** `200 OK`
```json
{
  "message": "Redirect to GitHub OAuth2"
}
```

---

#### GET /api/v1/oauth/github/callback

GitHub OAuth2 callback endpoint.

**Query Parameters:**
- `code`: Authorization code from GitHub

**Response:** `200 OK`
```json
{
  "message": "GitHub OAuth2 callback"
}
```

---

## Code Examples

### Python (requests)

```python
import requests

# Register
response = requests.post(
    "http://localhost:8000/api/v1/auth/register",
    json={
        "email": "user@example.com",
        "username": "testuser",
        "password": "SecurePass123!"
    }
)

# Login
response = requests.post(
    "http://localhost:8000/api/v1/auth/login",
    json={
        "username": "testuser",
        "password": "SecurePass123!"
    }
)
token = response.json()["access_token"]

# Get profile
response = requests.get(
    "http://localhost:8000/api/v1/users/me",
    headers={"Authorization": f"Bearer {token}"}
)
```

### JavaScript (fetch)

```javascript
// Register
const registerResponse = await fetch('http://localhost:8000/api/v1/auth/register', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    email: 'user@example.com',
    username: 'testuser',
    password: 'SecurePass123!'
  })
});

// Login
const loginResponse = await fetch('http://localhost:8000/api/v1/auth/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    username: 'testuser',
    password: 'SecurePass123!'
  })
});
const { access_token } = await loginResponse.json();

// Get profile
const profileResponse = await fetch('http://localhost:8000/api/v1/users/me', {
  headers: {
    'Authorization': `Bearer ${access_token}`
  }
});
```

### cURL

```bash
# Register
curl -X POST "http://localhost:8000/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","username":"testuser","password":"SecurePass123!"}'

# Login
curl -X POST "http://localhost:8000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"SecurePass123!"}'

# Get profile
curl -X GET "http://localhost:8000/api/v1/users/me" \
  -H "Authorization: Bearer <your_token>"
```

## Interactive Documentation

Visit these URLs when the server is running:

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

These provide interactive API documentation where you can test endpoints directly from your browser.

