use tauri::{plugin::PluginApi, AppHandle, Runtime};

use crate::CloudPushRegistrationResult;

pub fn init<R: Runtime, C: serde::de::DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> tauri::Result<CloudPush<R>> {
    Ok(CloudPush(app.clone()))
}

pub struct CloudPush<R: Runtime>(#[allow(dead_code)] AppHandle<R>);

impl<R: Runtime> CloudPush<R> {
    pub fn request_registration(&self) -> tauri::Result<CloudPushRegistrationResult> {
        Err(tauri::Error::Anyhow(anyhow::anyhow!(
            "cloud push registration is only available on Android"
        )))
    }
}
