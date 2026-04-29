use gpui::prelude::*;
use gpui::{
    AnyElement, Context, InteractiveElement, IntoElement, KeyDownEvent, SharedString,
    StatefulInteractiveElement, Stateful, Div, div, px, rgb, Keystroke,
};
use moui_host::{Node, NodeKind};

use crate::MoUIView;

pub fn render_node(node: &Node, cx: &mut Context<MoUIView>) -> AnyElement {
    match node.kind {
        NodeKind::View => render_view(node, cx).into_any_element(),
        NodeKind::Text => render_text(node).into_any_element(),
        NodeKind::Button => render_button(node, cx).into_any_element(),
        NodeKind::Input => render_input(node, cx).into_any_element(),
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

fn render_input(node: &Node, cx: &mut Context<MoUIView>) -> Stateful<Div> {
    let node_id = node.id;
    let value = node.props.value.clone().unwrap_or_default();
    let event_id = node.props.on_input;
    let input_id = SharedString::from(format!("input-{}", node_id));
    let placeholder = node.props.text.clone();

    let display_text = if value.is_empty() {
        if let Some(ref ph) = placeholder {
            ph.clone()
        } else {
            String::new()
        }
    } else {
        value.clone()
    };

    let mut el = div()
        .id(input_id)
        .px_2()
        .py_1()
        .border_1()
        .border_color(rgb(0x666666))
        .rounded_md()
        .min_w(px(100.0))
        .cursor_text()
        .focus(|s| s.border_color(rgb(0x4a9eff)))
        .child(if value.is_empty() && placeholder.is_some() {
            div()
                .text_color(rgb(0x888888))
                .child(SharedString::from(display_text))
        } else {
            div().child(SharedString::from(display_text))
        });

    if let Some(eid) = event_id {
        el = el.on_key_down(cx.listener(move |this, event: &KeyDownEvent, _window, cx| {
            let current_value = this.get_input_value(node_id).unwrap_or(&value).to_string();
            let keystroke = &event.keystroke;
            let new_value = handle_key_input(&current_value, keystroke);
            if new_value != current_value {
                this.set_input_value(node_id, new_value.clone());
                this.dispatch_event(eid, Some(new_value), cx);
            }
        }));
    }

    el
}

fn handle_key_input(current: &str, keystroke: &Keystroke) -> String {
    let key = keystroke.key.as_str();
    
    if key == "backspace" {
        let mut chars: Vec<char> = current.chars().collect();
        if !chars.is_empty() {
            chars.pop();
        }
        chars.into_iter().collect()
    } else if key == "enter" || key == "tab" || key == "escape" {
        current.to_string()
    } else if keystroke.modifiers.control || keystroke.modifiers.platform {
        current.to_string()
    } else if key.len() == 1 {
        let mut result = current.to_string();
        result.push_str(key);
        result
    } else {
        current.to_string()
    }
}
