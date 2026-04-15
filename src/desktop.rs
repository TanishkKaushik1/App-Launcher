use std::fs;
use std::path::PathBuf;
use serde::Serialize;

#[derive(Serialize, Clone, Debug)]
pub struct App {
    pub name:    String,
    pub exec:    String,
    pub icon:    String,   // resolved absolute path or empty
    pub comment: String,
}

/// Scan all known .desktop locations and return deduplicated app list
pub fn scan() -> Vec<App> {
    let dirs = vec![
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/usr/local/share/applications"),
        home().join(".local/share/applications"),
    ];

    let mut apps: Vec<App> = Vec::new();

    for dir in &dirs {
        if !dir.exists() { continue; }
        let Ok(entries) = fs::read_dir(dir) else { continue };

        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) != Some("desktop") {
                continue;
            }
            if let Some(app) = parse(&path) {
                // Deduplicate by name — user ~/.local takes priority (added last wins)
                apps.retain(|a| a.name != app.name);
                apps.push(app);
            }
        }
    }

    apps
}

fn parse(path: &PathBuf) -> Option<App> {
    let content = fs::read_to_string(path).ok()?;

    let mut name    = String::new();
    let mut exec    = String::new();
    let mut icon    = String::new();
    let mut comment = String::new();
    let mut in_entry   = false;
    let mut no_display = false;
    let mut terminal   = false;

    for line in content.lines() {
        let line = line.trim();
        if line == "[Desktop Entry]"              { in_entry = true;  continue; }
        if line.starts_with('[') && in_entry      { break; }  // next section
        if !in_entry                              { continue; }

        match line.split_once('=') {
            Some(("Name",      v)) if name.is_empty()    => name    = v.to_string(),
            Some(("Exec",      v)) if exec.is_empty()    => exec    = clean_exec(v),
            Some(("Icon",      v)) if icon.is_empty()    => icon    = resolve_icon(v),
            Some(("Comment",   v)) if comment.is_empty() => comment = v.to_string(),
            Some(("Type",      v)) if v != "Application" => return None,
            Some(("NoDisplay", v)) if v == "true"        => no_display = true,
            Some(("Hidden",    v)) if v == "true"        => no_display = true,
            Some(("Terminal",  v)) if v == "true"        => terminal   = true,
            _ => {}
        }
    }

    if no_display || terminal || name.is_empty() || exec.is_empty() {
        return None;
    }

    Some(App { name, exec, icon, comment })
}

/// Strip %f %F %u %U etc. field codes from Exec value
fn clean_exec(exec: &str) -> String {
    exec.split_whitespace()
        .filter(|p| !p.starts_with('%'))
        .collect::<Vec<_>>()
        .join(" ")
}

/// Try to resolve icon name to an absolute file path.
/// Returns empty string if not resolvable (QML will show letter fallback).
fn resolve_icon(name: &str) -> String {
    // Already absolute
    if name.starts_with('/') {
        return if std::path::Path::new(name).exists() {
            name.to_string()
        } else {
            String::new()
        };
    }

    let themes = ["Papirus", "Papirus-Dark", "hicolor", "breeze", "Adwaita"];
    let sizes   = ["48x48", "64x64", "32x32", "scalable", "128x128", "256x256", "22x22"];
    let exts    = ["png", "svg", "xpm"];
    let base    = "/usr/share/icons";

    for theme in &themes {
        for size in &sizes {
            for ext in &exts {
                let p = format!("{}/{}/{}/apps/{}.{}", base, theme, size, name, ext);
                if std::path::Path::new(&p).exists() {
                    return p;
                }
            }
        }
    }

    // pixmaps fallback
    for ext in &exts {
        let p = format!("/usr/share/pixmaps/{}.{}", name, ext);
        if std::path::Path::new(&p).exists() {
            return p;
        }
    }
    // pixmaps without extension (some icons have no ext)
    let p = format!("/usr/share/pixmaps/{}", name);
    if std::path::Path::new(&p).exists() {
        return p;
    }

    String::new()
}

fn home() -> PathBuf {
    std::env::var("HOME").map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/root"))
}