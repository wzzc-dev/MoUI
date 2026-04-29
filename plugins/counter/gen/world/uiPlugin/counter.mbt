let count : Ref[Int] = Ref::new(0)

pub fn render() -> @uiTypes.UiTree {
    let c = count.val
    @uiTypes.UiTree::{
        nodes: [
            @uiTypes.FlatNode::{
                id: 0U,
                parent_id: None,
                kind: @uiTypes.NodeKind::VIEW,
                props: @uiTypes.Props::{
                    width: Some(300.0),
                    height: Some(200.0),
                    padding: Some(16.0),
                    background_color: None,
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
                    text: Some("Count: \{c}"),
                    value: None,
                    on_click: None,
                    on_input: None,
                },
            },
            @uiTypes.FlatNode::{
                id: 2U,
                parent_id: Some(0U),
                kind: @uiTypes.NodeKind::BUTTON,
                props: @uiTypes.Props::{
                    width: None,
                    height: None,
                    padding: None,
                    background_color: None,
                    text: Some("+1"),
                    value: None,
                    on_click: Some(1U),
                    on_input: None,
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
                    text: Some("-1"),
                    value: None,
                    on_click: Some(2U),
                    on_input: None,
                },
            },
        ],
    }
}

pub fn handle_event(event_id : UInt, _payload : String?) -> @uiTypes.UiTree {
    match event_id {
        1U => count.val = count.val + 1
        2U => count.val = count.val - 1
        _ => ()
    }
    render()
}
