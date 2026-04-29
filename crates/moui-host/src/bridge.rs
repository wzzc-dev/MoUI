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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_nodekind_conversion() {
        assert!(matches!(
            NodeKind::from(wit_ui_types::NodeKind::View),
            NodeKind::View
        ));
        assert!(matches!(
            NodeKind::from(wit_ui_types::NodeKind::Text),
            NodeKind::Text
        ));
        assert!(matches!(
            NodeKind::from(wit_ui_types::NodeKind::Button),
            NodeKind::Button
        ));
        assert!(matches!(
            NodeKind::from(wit_ui_types::NodeKind::Input),
            NodeKind::Input
        ));
    }

    #[test]
    fn test_color_conversion() {
        let wit_color = wit_ui_types::Color {
            r: 100,
            g: 150,
            b: 200,
            a: 255,
        };
        let rust_color: Color = wit_color.into();
        assert_eq!(rust_color.r, 100);
        assert_eq!(rust_color.g, 150);
        assert_eq!(rust_color.b, 200);
        assert_eq!(rust_color.a, 255);
    }

    #[test]
    fn test_props_conversion_full() {
        let wit_props = wit_ui_types::Props {
            width: Some(300.0),
            height: Some(200.0),
            padding: Some(16.0),
            background_color: Some(wit_ui_types::Color {
                r: 255,
                g: 0,
                b: 0,
                a: 255,
            }),
            text: Some("Hello".to_string()),
            value: Some("test".to_string()),
            on_click: Some(1),
            on_input: Some(2),
        };
        let rust_props: Props = wit_props.into();
        assert_eq!(rust_props.width, Some(300.0));
        assert_eq!(rust_props.height, Some(200.0));
        assert_eq!(rust_props.padding, Some(16.0));
        assert!(rust_props.background_color.is_some());
        let bg = rust_props.background_color.unwrap();
        assert_eq!(bg.r, 255);
        assert_eq!(bg.g, 0);
        assert_eq!(bg.b, 0);
        assert_eq!(bg.a, 255);
        assert_eq!(rust_props.text, Some("Hello".to_string()));
        assert_eq!(rust_props.value, Some("test".to_string()));
        assert_eq!(rust_props.on_click, Some(1));
        assert_eq!(rust_props.on_input, Some(2));
    }

    #[test]
    fn test_props_conversion_empty() {
        let wit_props = wit_ui_types::Props {
            width: None,
            height: None,
            padding: None,
            background_color: None,
            text: None,
            value: None,
            on_click: None,
            on_input: None,
        };
        let rust_props: Props = wit_props.into();
        assert!(rust_props.width.is_none());
        assert!(rust_props.height.is_none());
        assert!(rust_props.padding.is_none());
        assert!(rust_props.background_color.is_none());
        assert!(rust_props.text.is_none());
        assert!(rust_props.value.is_none());
        assert!(rust_props.on_click.is_none());
        assert!(rust_props.on_input.is_none());
    }

    #[test]
    fn test_flat_node_conversion() {
        let wit_node = wit_ui_types::FlatNode {
            id: 42,
            parent_id: Some(0),
            kind: wit_ui_types::NodeKind::Button,
            props: wit_ui_types::Props {
                width: None,
                height: None,
                padding: None,
                background_color: None,
                text: Some("Click me".to_string()),
                value: None,
                on_click: Some(10),
                on_input: None,
            },
        };
        let rust_node: FlatNode = wit_node.into();
        assert_eq!(rust_node.id, 42);
        assert_eq!(rust_node.parent_id, Some(0));
        assert!(matches!(rust_node.kind, NodeKind::Button));
        assert_eq!(rust_node.props.text, Some("Click me".to_string()));
        assert_eq!(rust_node.props.on_click, Some(10));
    }

    #[test]
    fn test_uitree_conversion() {
        let wit_tree = wit_ui_types::UiTree {
            nodes: vec![
                wit_ui_types::FlatNode {
                    id: 0,
                    parent_id: None,
                    kind: wit_ui_types::NodeKind::View,
                    props: wit_ui_types::Props {
                        width: None,
                        height: None,
                        padding: None,
                        background_color: None,
                        text: None,
                        value: None,
                        on_click: None,
                        on_input: None,
                    },
                },
                wit_ui_types::FlatNode {
                    id: 1,
                    parent_id: Some(0),
                    kind: wit_ui_types::NodeKind::Text,
                    props: wit_ui_types::Props {
                        width: None,
                        height: None,
                        padding: None,
                        background_color: None,
                        text: Some("Test".to_string()),
                        value: None,
                        on_click: None,
                        on_input: None,
                    },
                },
            ],
        };
        let rust_tree: UiTree = wit_tree.into();
        assert_eq!(rust_tree.nodes.len(), 2);
        assert_eq!(rust_tree.nodes[0].id, 0);
        assert!(rust_tree.nodes[0].parent_id.is_none());
        assert_eq!(rust_tree.nodes[1].id, 1);
        assert_eq!(rust_tree.nodes[1].parent_id, Some(0));
    }
}
