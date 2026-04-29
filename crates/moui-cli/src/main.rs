use anyhow::Result;
use std::path::PathBuf;
use log::info;

const VERSION: &str = env!("CARGO_PKG_VERSION");

fn print_usage() {
    eprintln!("MoUI - WASM Plugin UI Framework v{}", VERSION);
    eprintln!();
    eprintln!("Usage: moui <plugin.wasm>");
    eprintln!();
    eprintln!("Arguments:");
    eprintln!("  <plugin.wasm>  Path to the WASM component file to load");
    eprintln!();
    eprintln!("Examples:");
    eprintln!("  moui plugins/counter/counter.component.wasm");
    eprintln!("  moui ./my-plugin.wasm");
    eprintln!();
    eprintln!("The WASM component must implement the ui-plugin WIT interface:");
    eprintln!("  - render() -> ui-tree");
    eprintln!("  - handle-event(event-id, payload) -> ui-tree");
}

fn main() -> Result<()> {
    // 初始化日志系统
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() < 2 {
        print_usage();
        std::process::exit(1);
    }

    if args[1] == "--help" || args[1] == "-h" {
        print_usage();
        std::process::exit(0);
    }

    if args[1] == "--version" || args[1] == "-v" {
        println!("moui v{}", VERSION);
        std::process::exit(0);
    }

    let plugin_path = PathBuf::from(&args[1]);
    
    if !plugin_path.exists() {
        eprintln!("Error: Plugin file not found: {}", plugin_path.display());
        eprintln!();
        eprintln!("Please ensure the WASM component file exists and the path is correct.");
        std::process::exit(1);
    }

    if plugin_path.extension().map(|e| e != "wasm").unwrap_or(true) {
        eprintln!("Warning: File does not have .wasm extension: {}", plugin_path.display());
    }

    info!("Loading plugin: {}", plugin_path.display());
    
    match moui_renderer::run(&plugin_path) {
        Ok(()) => Ok(()),
        Err(e) => {
            eprintln!();
            eprintln!("Error: Failed to run plugin");
            eprintln!("Details: {}", e);
            eprintln!();
            eprintln!("Common causes:");
            eprintln!("  - Invalid WASM component format");
            eprintln!("  - Missing WIT interface implementation");
            eprintln!("  - Incompatible component exports");
            std::process::exit(1);
        }
    }
}
