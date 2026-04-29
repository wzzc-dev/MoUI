mod app;
mod event;
mod renderer;

use gpui::prelude::*;
use gpui::{Context, IntoElement, Window, div, rgb};
use moui_host::{Node, PluginRuntime};

pub use app::run;

pub struct MoUIView {
    pub root_node: Option<Node>,
    pub runtime: Option<PluginRuntime>,
}

impl Render for MoUIView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let mut root = div().size_full().bg(rgb(0x1e1e2e)).p_4();

        if let Some(ref node) = self.root_node {
            root = root.child(renderer::render_node(node, cx));
        } else {
            root = root.child("No UI loaded");
        }

        root
    }
}
