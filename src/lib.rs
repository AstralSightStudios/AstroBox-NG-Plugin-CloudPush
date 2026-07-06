use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

pub use models::*;

#[cfg(target_os = "android")]
mod mobile;
#[cfg(not(target_os = "android"))]
mod stub;

mod models;

#[cfg(target_os = "android")]
use mobile::CloudPush;
#[cfg(not(target_os = "android"))]
use stub::CloudPush;

pub trait CloudPushExt<R: Runtime> {
    fn cloud_push(&self) -> &CloudPush<R>;
}

impl<R: Runtime, T: Manager<R>> CloudPushExt<R> for T {
    fn cloud_push(&self) -> &CloudPush<R> {
        self.state::<CloudPush<R>>().inner()
    }
}

pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("cloud-push")
        .setup(|app, api| {
            #[cfg(target_os = "android")]
            let cloud_push = mobile::init(app, api)?;
            #[cfg(not(target_os = "android"))]
            let cloud_push = stub::init(app, api)?;
            app.manage(cloud_push);
            Ok(())
        })
        .build()
}
