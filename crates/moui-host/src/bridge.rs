use crate::types::{Color, FlatNode, NodeKind, Props, UiTree};

pub(crate) mod bindings {
    wasmtime::component::bindgen!({
        path: "../../wit",
        world: "ui-plugin",
        async: false
    });
}

use bindings::moui::plugin::ui_types as wit_ui_types;

impl From<wit_ui_types::NodeKind> for NodeKind {
    fn from(value: wit_ui_types::NodeKind) -> Self {
        match value {
            wit_ui_types::NodeKind::View => NodeKind::View,
            wit_ui_types::NodeKind::Text => NodeKind::Text,
            wit_ui_types::NodeKind::Button => NodeKind::Button,
            wit_ui_types::NodeKind::Input => NodeKind::Input,
        }
    }
}

impl From<wit_ui_types::Color> for Color {
    fn from(value: wit_ui_types::Color) -> Self {
        Color {
            r: value.r,
            g: value.g,
            b: value.b,
            a: value.a,
        }
    }
}

impl From<wit_ui_types::Props> for Props {
    fn from(value: wit_ui_types::Props) -> Self {
        Props {
            width: value.width,
            height: value.height,
            padding: value.padding,
            background_color: value.background_color.map(Into::into),
            text: value.text,
            value: value.value,
            on_click: value.on_click,
            on_input: value.on_input,
        }
    }
}

impl From<wit_ui_types::FlatNode> for FlatNode {
    fn from(value: wit_ui_types::FlatNode) -> Self {
        FlatNode {
            id: value.id,
            parent_id: value.parent_id,
            kind: value.kind.into(),
            props: value.props.into(),
        }
    }
}

impl From<wit_ui_types::UiTree> for UiTree {
    fn from(value: wit_ui_types::UiTree) -> Self {
        UiTree {
            nodes: value.nodes.into_iter().map(Into::into).collect(),
        }
    }
}
