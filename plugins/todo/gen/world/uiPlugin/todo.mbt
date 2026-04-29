let todos: Ref[Array[(String, Bool)]] = Ref::new([])
let input_value: Ref[String] = Ref::new("")
let next_id: Ref[UInt] = Ref::new(10U)

fn default_props() -> @uiTypes.Props {
    @uiTypes.Props::{
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

pub fn render() -> @uiTypes.UiTree {
    let mut nodes: Array[@uiTypes.FlatNode] = []
    
    nodes.push(@uiTypes.FlatNode::{
        id: 0U,
        parent_id: None,
        kind: @uiTypes.NodeKind::VIEW,
        props: @uiTypes.Props::{
            width: Some(400.0),
            padding: Some(16.0),
            background_color: Some(@uiTypes.Color::{
                r: 30b,
                g: 30b,
                b: 46b,
                a: 255b,
            }),
            ..default_props()
        },
    })

    nodes.push(@uiTypes.FlatNode::{
        id: 1U,
        parent_id: Some(0U),
        kind: @uiTypes.NodeKind::TEXT,
        props: @uiTypes.Props::{
            text: Some("📝 Todo List"),
            ..default_props()
        },
    })

    nodes.push(@uiTypes.FlatNode::{
        id: 2U,
        parent_id: Some(0U),
        kind: @uiTypes.NodeKind::INPUT,
        props: @uiTypes.Props::{
            text: Some("Add new task..."),
            value: Some(input_value.val),
            on_input: Some(1U),
            ..default_props()
        },
    })

    nodes.push(@uiTypes.FlatNode::{
        id: 3U,
        parent_id: Some(0U),
        kind: @uiTypes.NodeKind::BUTTON,
        props: @uiTypes.Props::{
            text: Some("Add"),
            on_click: Some(2U),
            ..default_props()
        },
    })

    if todos.val.length() == 0 {
        nodes.push(@uiTypes.FlatNode::{
            id: 4U,
            parent_id: Some(0U),
            kind: @uiTypes.NodeKind::TEXT,
            props: @uiTypes.Props::{
                text: Some("No tasks yet. Add one above!"),
                ..default_props()
            },
        })
    } else {
        let mut item_id: UInt = 100U
        let mut delete_id: UInt = 3U
        for (index, (text, completed)) in todos.val.enumerate() {
            let status = if completed { "✓ " } else { "○ " }
            let display_text = "\{status}\{text}"
            
            nodes.push(@uiTypes.FlatNode::{
                id: item_id,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::TEXT,
                props: @uiTypes.Props::{
                    text: Some(display_text),
                    ..default_props()
                },
            })

            nodes.push(@uiTypes.FlatNode::{
                id: item_id + 1U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::BUTTON,
                props: @uiTypes.Props::{
                    text: Some("Delete"),
                    on_click: Some(delete_id + index as UInt),
                    ..default_props()
                },
            })
            
            nodes.push(@uiTypes.FlatNode::{
                id: item_id + 2U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::BUTTON,
                props: @uiTypes.Props::{
                    text: Some(if completed { "Undo" } else { "Done" }),
                    on_click: Some(delete_id + todos.val.length() as UInt + index as UInt),
                    ..default_props()
                },
            })
            
            item_id = item_id + 10U
        }
    }

    @uiTypes.UiTree::{ nodes: nodes }
}

pub fn handle_event(event_id: UInt, payload: String?) -> @uiTypes.UiTree {
    match event_id {
        1U => {
            input_value.val = payload.unwrap_or("")
        }
        2U => {
            if input_value.val != "" {
                todos.val.push((input_value.val, false))
                input_value.val = ""
            }
        }
        _ => {
            let total = todos.val.length() as UInt
            if event_id >= 3U && event_id < 3U + total {
                let index = (event_id - 3U) as Int
                todos.val = todos.val.filter_with_index(fn(i, _) { i != index })
            } else if event_id >= 3U + total && event_id < 3U + 2U * total {
                let index = (event_id - 3U - total) as Int
                if index >= 0 && index < todos.val.length() {
                    let (text, completed) = todos.val[index]
                    todos.val[index] = (text, !completed)
                }
            }
        }
    }
    render()
}