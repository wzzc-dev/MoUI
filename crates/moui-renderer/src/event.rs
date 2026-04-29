use gpui::Context;

use crate::MoUIView;

impl MoUIView {
    pub fn dispatch_event(
        &mut self,
        event_id: u32,
        payload: Option<String>,
        cx: &mut Context<Self>,
    ) {
        self.clear_error();
        
        if let Some(ref mut runtime) = self.runtime {
            match runtime.handle_event(event_id, payload) {
                Ok(ui_tree) => {
                    self.root_node = ui_tree.build_node_tree();
                    cx.notify();
                }
                Err(e) => {
                    let error_msg = format!("Error handling event {}: {}", event_id, e);
                    eprintln!("{}", error_msg);
                    self.set_error(error_msg);
                    cx.notify();
                }
            }
        }
    }
}
