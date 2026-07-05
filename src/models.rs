use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CloudPushRegistrationResult {
    pub platform: String,
    pub status: String,
    pub token: Option<String>,
    pub environment: Option<String>,
    pub device_id: String,
    pub bundle_id: Option<String>,
    pub error: Option<String>,
}
