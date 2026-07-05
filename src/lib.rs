use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

pub use models::*;

#[cfg(mobile)]
mod mobile;
#[cfg(not(mobile))]
mod stub;

mod models;

#[cfg(mobile)]
use mobile::CloudPush;
#[cfg(not(mobile))]
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
            #[cfg(mobile)]
            let cloud_push = mobile::init(app, api)?;
            #[cfg(not(mobile))]
            let cloud_push = stub::init(app, api)?;
            app.manage(cloud_push);
            Ok(())
        })
        .build()
}
