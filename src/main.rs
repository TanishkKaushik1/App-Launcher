mod desktop;
mod usage;
mod ipc;
 
fn main() {
    // Scan all .desktop files once at startup
    let mut apps = desktop::scan();
    apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
 
    println!("[app-launcher] Loaded {} apps", apps.len());
 
    // Start IPC server — blocks forever serving requests
    ipc::serve(apps);
}