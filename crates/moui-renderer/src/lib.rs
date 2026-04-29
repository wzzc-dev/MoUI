mod app;
mod event;
mod renderer;

use std::collections::HashMap;
use gpui::prelude::*;
use gpui::{Context, IntoElement, Window, div, rgb};
use moui_host::{Node, PluginRuntime};

pub use app::run;

pub struct MoUIView {
    pub root_node: Option<Node>,
    pub runtime: Option<PluginRuntime>,
    pub input_states: HashMap<u32, String>,
    pub last_error: Option<String>,
}

impl MoUIView {
    pub fn get_input_value(&self, node_id: u32) -> Option<&str> {
        self.input_states.get(&node_id).map(|s| s.as_str())
    }
    
    pub fn set_input_value(&mut self, node_id: u32, value: String) {
        self.input_states.insert(node_id, value);
    }
    
    pub fn set_error(&mut self, error: String) {
        self.last_error = Some(error);
    }
    
    pub fn clear_error(&mut self) {
        self.last_error = None;
    }
}

impl Render for MoUIView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let mut root = div().size_full().bg(rgb(0x1e1e2e)).p_4();

        if let Some(ref error) = self.last_error {
            root = root.child(
                div()
                    .mb_4()
                    .p_4()
                    .bg(rgb(0xff4444))
                    .text_color(rgb(0xffffff))
                    .rounded_md()
                    .child(format!("Error: {}", error))
            );
        }

        if let Some(ref node) = self.root_node {
            root = root.child(renderer::render_node(node, cx));
        } else {
            root = root.child("No UI loaded");
        }

        root
    }
}
