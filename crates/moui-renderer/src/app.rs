use anyhow::Result;
use std::collections::HashMap;
use gpui::prelude::*;
use gpui::{App, Application, Bounds, WindowBounds, WindowOptions, px, size};
use moui_host::PluginRuntime;

use crate::MoUIView;

pub fn run(plugin_path: &std::path::Path) -> Result<()> {
    let mut runtime = PluginRuntime::new()?;
    runtime.load(plugin_path)?;

    let ui_tree = runtime.render()?;
    let root_node = ui_tree.build_node_tree();

    Application::new().run(move |cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(800.), px(600.)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                ..Default::default()
            },
            |_, cx| {
                cx.new(|_| MoUIView {
                    root_node,
                    runtime: Some(runtime),
                    input_states: HashMap::new(),
                    last_error: None,
                })
            },
        )
        .unwrap();
        cx.activate(true);
    });

    Ok(())
}
