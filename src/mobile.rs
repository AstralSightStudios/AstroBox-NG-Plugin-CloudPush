use serde::de::DeserializeOwned;
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

use crate::CloudPushRegistrationResult;

#[cfg(target_os = "ios")]
tauri::ios_plugin_binding!(init_plugin_cloud_push);

pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> tauri::Result<CloudPush<R>> {
    #[cfg(target_os = "ios")]
    let handle = api.register_ios_plugin(init_plugin_cloud_push)?;

    #[cfg(target_os = "android")]
    let handle = api.register_android_plugin(
        "moe.astralsight.astrobox.plugin.cloud_push",
        "CloudPushPlugin",
    )?;

    Ok(CloudPush(handle))
}

pub struct CloudPush<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> CloudPush<R> {
    pub fn request_registration(&self) -> tauri::Result<CloudPushRegistrationResult> {
        self.0
            .run_mobile_plugin("requestRegistration", ())
            .map_err(Into::into)
    }
}
