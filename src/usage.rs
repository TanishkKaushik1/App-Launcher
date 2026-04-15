use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use serde::{Deserialize, Serialize};

const FILE: &str = ".cache/app-launch-counts.json";

#[derive(Serialize, Deserialize, Default)]
struct Counts {
    counts: HashMap<String, u32>,
}

fn path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/root".into());
    PathBuf::from(home).join(FILE)
}

/// Increment the launch count for an app name and persist
pub fn record(name: &str) {
    let mut data = load();
    *data.counts.entry(name.to_string()).or_insert(0) += 1;
    save(&data);
}

/// Return top N app names by launch count
pub fn top(n: usize) -> Vec<String> {
    let data = load();
    let mut pairs: Vec<(String, u32)> = data.counts.into_iter().collect();
    pairs.sort_by(|a, b| b.1.cmp(&a.1));
    pairs.into_iter().take(n).map(|(name, _)| name).collect()
}

fn load() -> Counts {
    let p = path();
    if !p.exists() { return Counts::default(); }
    let text = fs::read_to_string(&p).unwrap_or_default();
    serde_json::from_str(&text).unwrap_or_default()
}

fn save(data: &Counts) {
    let p = path();
    if let Some(parent) = p.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(data) {
        let _ = fs::write(p, json);
    }
}