use std::fs;
use std::io::{Read, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::process::Command;
use serde::Deserialize;
use crate::desktop::App;
use crate::usage;

pub const SOCKET: &str = "/tmp/app-launcher.sock";

#[derive(Deserialize)]
struct Request {
    command: String,
    name:    Option<String>,   // app name (for launch + record)
    exec:    Option<String>,   // exec string (for launch)
    n:       Option<usize>,    // how many top apps to return
}

pub fn serve(apps: Vec<App>) {
    let _ = fs::remove_file(SOCKET);
    let listener = UnixListener::bind(SOCKET)
        .expect("Failed to bind IPC socket");

    println!("[app-launcher] Listening on {}", SOCKET);

    for stream in listener.incoming() {
        match stream {
            Ok(s) => handle(s, &apps),
            Err(e) => eprintln!("[app-launcher] Connection error: {}", e),
        }
    }
}

fn handle(mut stream: UnixStream, apps: &[App]) {
    let mut buf = vec![0u8; 65536];
    let n = match stream.read(&mut buf) { Ok(n) => n, Err(_) => return };
    let msg = String::from_utf8_lossy(&buf[..n]);

    let req: Request = match serde_json::from_str(&msg) {
        Ok(r) => r,
        Err(e) => {
            let _ = stream.write_all(
                format!("{{\"error\":\"bad json: {}\"}}", e).as_bytes()
            );
            return;
        }
    };

    let response = match req.command.as_str() {

        // Return full app list as JSON array
        "list" => {
            serde_json::to_string(apps).unwrap_or_else(|_| "[]".into())
        }

        // Launch an app by exec string, record usage by name
        "launch" => {
            if let (Some(exec), Some(name)) = (req.exec, req.name) {
                usage::record(&name);
                let _ = Command::new("sh")
                    .arg("-c")
                    .arg(format!("{} &", exec))
                    .spawn();
                r#"{"status":"ok"}"#.into()
            } else {
                r#"{"error":"launch requires exec and name"}"#.into()
            }
        }

        // Return top N most-used app names
        "top" => {
            let n = req.n.unwrap_or(5);
            let names = usage::top(n);
            serde_json::to_string(&names).unwrap_or_else(|_| "[]".into())
        }

        other => format!("{{\"error\":\"unknown command: {}\"}}", other),
    };

    let _ = stream.write_all(response.as_bytes());
}