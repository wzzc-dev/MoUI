use anyhow::Result;
use std::path::PathBuf;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: moui <plugin.wasm>");
        std::process::exit(1);
    }

    let plugin_path = PathBuf::from(&args[1]);
    if !plugin_path.exists() {
        eprintln!("Plugin file not found: {}", plugin_path.display());
        std::process::exit(1);
    }

    moui_renderer::run(&plugin_path)
}
