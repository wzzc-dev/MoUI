use std::collections::HashMap;

#[derive(Debug, Clone)]
pub enum NodeKind {
    View,
    Text,
    Button,
    Input,
}

#[derive(Debug, Clone)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: u8,
}

#[derive(Debug, Clone)]
pub struct Props {
    pub width: Option<f32>,
    pub height: Option<f32>,
    pub padding: Option<f32>,
    pub background_color: Option<Color>,
    pub text: Option<String>,
    pub value: Option<String>,
    pub on_click: Option<u32>,
    pub on_input: Option<u32>,
}

impl Default for Props {
    fn default() -> Self {
        Self {
            width: None,
            height: None,
            padding: None,
            background_color: None,
            text: None,
            value: None,
            on_click: None,
            on_input: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct FlatNode {
    pub id: u32,
    pub parent_id: Option<u32>,
    pub kind: NodeKind,
    pub props: Props,
}

#[derive(Debug, Clone)]
pub struct UiTree {
    pub nodes: Vec<FlatNode>,
}

impl UiTree {
    pub fn build_node_tree(&self) -> Option<Node> {
        let mut children_map: HashMap<u32, Vec<u32>> = HashMap::new();
        let mut node_map: HashMap<u32, &FlatNode> = HashMap::new();

        for node in &self.nodes {
            node_map.insert(node.id, node);
            if let Some(parent_id) = node.parent_id {
                children_map.entry(parent_id).or_default().push(node.id);
            }
        }

        let root = self.nodes.iter().find(|n| n.parent_id.is_none())?;
        Some(self.build_node_recursive(root.id, &node_map, &children_map))
    }

    fn build_node_recursive(
        &self,
        id: u32,
        node_map: &HashMap<u32, &FlatNode>,
        children_map: &HashMap<u32, Vec<u32>>,
    ) -> Node {
        let flat = node_map[&id];
        let children = children_map
            .get(&id)
            .map(|ids| {
                ids.iter()
                    .map(|cid| self.build_node_recursive(*cid, node_map, children_map))
                    .collect()
            })
            .unwrap_or_default();

        Node {
            id: flat.id,
            kind: flat.kind.clone(),
            props: flat.props.clone(),
            children,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Node {
    pub id: u32,
    pub kind: NodeKind,
    pub props: Props,
    pub children: Vec<Node>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_props_default() {
        let props = Props::default();
        assert!(props.width.is_none());
        assert!(props.height.is_none());
        assert!(props.padding.is_none());
        assert!(props.background_color.is_none());
        assert!(props.text.is_none());
        assert!(props.value.is_none());
        assert!(props.on_click.is_none());
        assert!(props.on_input.is_none());
    }

    #[test]
    fn test_uitree_empty() {
        let tree = UiTree { nodes: vec![] };
        assert!(tree.build_node_tree().is_none());
    }

    #[test]
    fn test_uitree_single_node() {
        let tree = UiTree {
            nodes: vec![FlatNode {
                id: 0,
                parent_id: None,
                kind: NodeKind::View,
                props: Props::default(),
            }],
        };

        let root = tree.build_node_tree();
        assert!(root.is_some());
        let root = root.unwrap();
        assert_eq!(root.id, 0);
        assert!(matches!(root.kind, NodeKind::View));
        assert!(root.children.is_empty());
    }

    #[test]
    fn test_uitree_simple_hierarchy() {
        let tree = UiTree {
            nodes: vec![
                FlatNode {
                    id: 0,
                    parent_id: None,
                    kind: NodeKind::View,
                    props: Props::default(),
                },
                FlatNode {
                    id: 1,
                    parent_id: Some(0),
                    kind: NodeKind::Text,
                    props: Props {
                        text: Some("Hello".to_string()),
                        ..Default::default()
                    },
                },
                FlatNode {
                    id: 2,
                    parent_id: Some(0),
                    kind: NodeKind::Button,
                    props: Props {
                        text: Some("Click".to_string()),
                        on_click: Some(1),
                        ..Default::default()
                    },
                },
            ],
        };

        let root = tree.build_node_tree();
        assert!(root.is_some());
        let root = root.unwrap();
        assert_eq!(root.id, 0);
        assert_eq!(root.children.len(), 2);

        let text_child = &root.children[0];
        assert_eq!(text_child.id, 1);
        assert!(matches!(text_child.kind, NodeKind::Text));
        assert_eq!(text_child.props.text, Some("Hello".to_string()));

        let button_child = &root.children[1];
        assert_eq!(button_child.id, 2);
        assert!(matches!(button_child.kind, NodeKind::Button));
        assert_eq!(button_child.props.on_click, Some(1));
    }

    #[test]
    fn test_uitree_nested_hierarchy() {
        let tree = UiTree {
            nodes: vec![
                FlatNode {
                    id: 0,
                    parent_id: None,
                    kind: NodeKind::View,
                    props: Props::default(),
                },
                FlatNode {
                    id: 1,
                    parent_id: Some(0),
                    kind: NodeKind::View,
                    props: Props::default(),
                },
                FlatNode {
                    id: 2,
                    parent_id: Some(1),
                    kind: NodeKind::Text,
                    props: Props {
                        text: Some("Nested".to_string()),
                        ..Default::default()
                    },
                },
            ],
        };

        let root = tree.build_node_tree();
        assert!(root.is_some());
        let root = root.unwrap();
        assert_eq!(root.id, 0);
        assert_eq!(root.children.len(), 1);

        let nested_view = &root.children[0];
        assert_eq!(nested_view.id, 1);
        assert_eq!(nested_view.children.len(), 1);

        let nested_text = &nested_view.children[0];
        assert_eq!(nested_text.id, 2);
        assert_eq!(nested_text.props.text, Some("Nested".to_string()));
    }

    #[test]
    fn test_uitree_no_root_returns_none() {
        let tree = UiTree {
            nodes: vec![
                FlatNode {
                    id: 1,
                    parent_id: Some(0),
                    kind: NodeKind::Text,
                    props: Props::default(),
                },
                FlatNode {
                    id: 2,
                    parent_id: Some(0),
                    kind: NodeKind::Button,
                    props: Props::default(),
                },
            ],
        };

        assert!(tree.build_node_tree().is_none());
    }

    #[test]
    fn test_color_struct() {
        let color = Color {
            r: 255,
            g: 128,
            b: 64,
            a: 200,
        };
        assert_eq!(color.r, 255);
        assert_eq!(color.g, 128);
        assert_eq!(color.b, 64);
        assert_eq!(color.a, 200);
    }

    #[test]
    fn test_nodekind_variants() {
        assert!(matches!(NodeKind::View, NodeKind::View));
        assert!(matches!(NodeKind::Text, NodeKind::Text));
        assert!(matches!(NodeKind::Button, NodeKind::Button));
        assert!(matches!(NodeKind::Input, NodeKind::Input));
    }
}
