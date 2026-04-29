let todos : Ref[Array[(String, Bool)]] = Ref::new([])
let input_value : Ref[String] = Ref::new("")

pub fn render() -> @uiTypes.UiTree {
    @uiTypes.UiTree::{
        nodes: [
            @uiTypes.FlatNode::{
                id: 0U,
                parent_id: None,
                kind: @uiTypes.NodeKind::VIEW,
                props: @uiTypes.Props::{
                    width: Some(400.0),
                    height: None,
                    padding: Some(16.0),
                    background_color: Some(@uiTypes.Color::{
                        r: 30,
                        g: 30,
                        b: 46,
                        a: 255,
                    }),
                    text: None,
                    value: None,
                    on_click: None,
                    on_input: None,
                },
            },
            @uiTypes.FlatNode::{
                id: 1U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::TEXT,
                props: @uiTypes.Props::{
                    width: None,
                    height: None,
                    padding: None,
                    background_color: None,
                    text: Some("Todo List"),
                    value: None,
                    on_click: None,
                    on_input: None,
                },
            },
            @uiTypes.FlatNode::{
                id: 2U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::INPUT,
                props: @uiTypes.Props::{
                    width: None,
                    height: None,
                    padding: None,
                    background_color: None,
                    text: Some("Add new task..."),
                    value: Some(input_value.val),
                    on_click: None,
                    on_input: Some(1U),
                },
            },
            @uiTypes.FlatNode::{
                id: 3U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::BUTTON,
                props: @uiTypes.Props::{
                    width: None,
                    height: None,
                    padding: None,
                    background_color: None,
                    text: Some("Add"),
                    value: None,
                    on_click: Some(2U),
                    on_input: None,
                },
            },
        ],
    }
}

pub fn handle_event(event_id : UInt, payload : String?) -> @uiTypes.UiTree {
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
        _ => ()
    }
    render()
}