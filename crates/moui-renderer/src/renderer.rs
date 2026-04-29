use gpui::prelude::*;
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, SharedString,
    StatefulInteractiveElement, Stateful, Div, div, px, rgb,
};
use moui_host::{Node, NodeKind};

use crate::MoUIView;

pub fn render_node(node: &Node, cx: &mut Context<MoUIView>) -> AnyElement {
    match node.kind {
        NodeKind::View => render_view(node, cx).into_any_element(),
        NodeKind::Text => render_text(node).into_any_element(),
        NodeKind::Button => render_button(node, cx).into_any_element(),
        NodeKind::Input => render_input(node).into_any_element(),
    }
}

fn render_view(node: &Node, cx: &mut Context<MoUIView>) -> Div {
    let mut el = div().flex().flex_col().gap_2();

    if let Some(width) = node.props.width {
        el = el.w(px(width));
    }
    if let Some(height) = node.props.height {
        el = el.h(px(height));
    }
    if let Some(padding) = node.props.padding {
        el = el.p(px(padding));
    }
    if let Some(ref bg) = node.props.background_color {
        el = el.bg(rgb((bg.r as u32) << 16 | (bg.g as u32) << 8 | (bg.b as u32)));
    }

    for child in &node.children {
        el = el.child(render_node(child, cx));
    }

    el
}

fn render_text(node: &Node) -> Div {
    let mut el = div();
    if let Some(ref text) = node.props.text {
        el = el.child(SharedString::from(text.clone()));
    }
    el
}

fn render_button(node: &Node, cx: &mut Context<MoUIView>) -> Stateful<Div> {
    let event_id = node.props.on_click;
    let label = node.props.text.clone().unwrap_or_default();
    let btn_id = SharedString::from(format!("btn-{}", node.id));

    let mut el = div()
        .id(btn_id)
        .px_4()
        .py_1()
        .bg(rgb(0x4a9eff))
        .rounded_md()
        .cursor_pointer()
        .text_color(rgb(0xffffff))
        .active(|s| s.opacity(0.8))
        .child(SharedString::from(label));

    if let Some(eid) = event_id {
        el = el.on_click(cx.listener(move |this, _, _window, cx| {
            this.dispatch_event(eid, None, cx);
        }));
    }

    el
}

fn render_input(node: &Node) -> Stateful<Div> {
    let value = node.props.value.clone().unwrap_or_default();
    let input_id = SharedString::from(format!("input-{}", node.id));

    div()
        .id(input_id)
        .px_2()
        .py_1()
        .border_1()
        .border_color(rgb(0xcccccc))
        .rounded_sm()
        .child(SharedString::from(value))
}
