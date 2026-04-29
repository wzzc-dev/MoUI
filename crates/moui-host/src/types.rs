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
