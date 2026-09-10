use anyhow::{bail, Result};
use axum::{
    extract::FromRequestParts,
    http::{header, request::Parts, StatusCode},
};
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use std::sync::LazyLock;

type HmacSha256 = Hmac<Sha256>;

static JWT_SECRET: LazyLock<Vec<u8>> = LazyLock::new(|| {
    match std::env::var("JWT_SECRET") {
        Ok(secret) if !secret.trim().is_empty() => secret.into_bytes(),
        _ => {
            // Generate an ephemeral 256-bit cryptographic secret per process lifecycle
            // to prevent token forgery using publicly known static strings.
            use sha2::Digest;
            let mut hasher = Sha256::new();
            hasher.update(b"themis-statutory-inspection-salt-v1");
            hasher.update(std::process::id().to_ne_bytes());
            if let Ok(now) = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH) {
                hasher.update(now.as_nanos().to_ne_bytes());
            }
            let ptr = &hasher as *const _ as usize;
            hasher.update(ptr.to_ne_bytes());
            let ephemeral_key = hasher.finalize().to_vec();
            tracing::warn!(
                "SECURITY WARNING: 'JWT_SECRET' environment variable is unset. Generated ephemeral session key. Set JWT_SECRET in production to persist authentication across server restarts."
            );
            ephemeral_key
        }
    }
});

/// Statutory system roles for Legal Metrology enforcement
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum AuthRole {
    Inspector, // Standard field inspector: can upload panels, scan SKUs, view inspections, export notices
    Admin,     // Legal Metrology Officer: can reconfigure rules, purge audit logs, adjust compounding fines
}

impl std::fmt::Display for AuthRole {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Inspector => write!(f, "Inspector"),
            Self::Admin => write!(f, "Admin"),
        }
    }
}

/// Standard JWT payload claims
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,       // Subject username / badge ID
    pub role: AuthRole,    // Assigned role
    pub exp: u64,          // Expiration timestamp (seconds since Unix epoch)
    pub iat: u64,          // Issued at timestamp
}

#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub token_type: String,
    pub role: AuthRole,
    pub username: String,
    pub expires_in_secs: u64,
}

/// Issues a cryptographically signed HS256 JWT valid for 24 hours
pub fn generate_jwt(sub: &str, role: AuthRole) -> Result<String> {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    let exp = now + 86400; // 24 hours validity

    let header_json = serde_json::json!({
        "alg": "HS256",
        "typ": "JWT"
    });
    let claims = Claims {
        sub: sub.to_string(),
        role,
        exp,
        iat: now,
    };

    let encoded_header = URL_SAFE_NO_PAD.encode(serde_json::to_vec(&header_json)?);
    let encoded_claims = URL_SAFE_NO_PAD.encode(serde_json::to_vec(&claims)?);
    let signing_input = format!("{encoded_header}.{encoded_claims}");

    let mut mac = HmacSha256::new_from_slice(&JWT_SECRET)
        .map_err(|e| anyhow::anyhow!("HMAC key initialization failed: {e}"))?;
    mac.update(signing_input.as_bytes());
    let signature = mac.finalize().into_bytes();
    let encoded_signature = URL_SAFE_NO_PAD.encode(signature);

    Ok(format!("{signing_input}.{encoded_signature}"))
}

#[allow(dead_code)]
/// Verifies HS256 signature and validates expiration
pub fn verify_jwt(token: &str) -> Result<Claims> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        bail!("Invalid JWT format: expected 3 segment structure");
    }

    let signing_input = format!("{}.{}", parts[0], parts[1]);
    let sig_bytes = URL_SAFE_NO_PAD
        .decode(parts[2])
        .map_err(|e| anyhow::anyhow!("Invalid base64 signature: {e}"))?;

    let mut mac = HmacSha256::new_from_slice(&JWT_SECRET)
        .map_err(|e| anyhow::anyhow!("HMAC key error: {e}"))?;
    mac.update(signing_input.as_bytes());
    mac.verify_slice(&sig_bytes)
        .map_err(|_| anyhow::anyhow!("Cryptographic signature mismatch"))?;

    let claims_bytes = URL_SAFE_NO_PAD
        .decode(parts[1])
        .map_err(|e| anyhow::anyhow!("Invalid base64 claims: {e}"))?;
    let claims: Claims = serde_json::from_slice(&claims_bytes)
        .map_err(|e| anyhow::anyhow!("Failed to parse claims payload: {e}"))?;

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)?
        .as_secs();
    if claims.exp < now {
        bail!("Token has expired");
    }

    Ok(claims)
}

#[allow(dead_code)]
/// Axum extractor for authenticated requests (either Inspector or Admin)
pub struct AuthenticatedUser(pub Claims);

impl<S> FromRequestParts<S> for AuthenticatedUser
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, String);

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth_header = parts
            .headers
            .get(header::AUTHORIZATION)
            .and_then(|val| val.to_str().ok());

        let token = match auth_header {
            Some(h) if h.starts_with("Bearer ") => &h[7..],
            _ => {
                return Err((
                    StatusCode::UNAUTHORIZED,
                    "Missing or malformed Authorization header. Use 'Bearer <token>'.".to_string(),
                ));
            }
        };

        match verify_jwt(token) {
            Ok(claims) => Ok(AuthenticatedUser(claims)),
            Err(e) => Err((
                StatusCode::UNAUTHORIZED,
                format!("Unauthorized: Invalid or expired token: {e}"),
            )),
        }
    }
}

#[allow(dead_code)]
/// Axum extractor restricting routes strictly to Administrators (Legal Metrology Officers)
pub struct RequireAdmin(pub Claims);

impl<S> FromRequestParts<S> for RequireAdmin
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, String);

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let AuthenticatedUser(claims) = AuthenticatedUser::from_request_parts(parts, state).await?;
        if claims.role != AuthRole::Admin {
            return Err((
                StatusCode::FORBIDDEN,
                "Forbidden: This statutory operation requires Administrator privileges.".to_string(),
            ));
        }
        Ok(RequireAdmin(claims))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_jwt_generation_and_verification() {
        let token = generate_jwt("inspector_sharma", AuthRole::Inspector).expect("generate jwt");
        let claims = verify_jwt(&token).expect("verify valid jwt");
        assert_eq!(claims.sub, "inspector_sharma");
        assert_eq!(claims.role, AuthRole::Inspector);
        assert!(claims.exp > claims.iat);

        let admin_token = generate_jwt("dir_officer", AuthRole::Admin).expect("generate admin jwt");
        let admin_claims = verify_jwt(&admin_token).expect("verify admin jwt");
        assert_eq!(admin_claims.sub, "dir_officer");
        assert_eq!(admin_claims.role, AuthRole::Admin);
    }

    #[test]
    fn test_jwt_tampered_signature() {
        let token = generate_jwt("hacker", AuthRole::Inspector).expect("generate jwt");
        let mut tampered = token.clone();
        tampered.push('x'); // Corrupt signature
        assert!(verify_jwt(&tampered).is_err());
    }
}

