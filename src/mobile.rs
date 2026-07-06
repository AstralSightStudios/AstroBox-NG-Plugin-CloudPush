use serde::de::DeserializeOwned;
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

use crate::CloudPushRegistrationResult;

// cloud-push's native registration is gated to Android only: on iOS the build
// falls back to the desktop stub (see the cfg gating in lib.rs), so this module
// is compiled only on Android. The iOS Swift implementation under ios/ is left
// in place but is intentionally not wired into the Rust plugin.
pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> tauri::Result<CloudPush<R>> {
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
