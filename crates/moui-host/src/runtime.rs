use anyhow::Result;
use std::path::Path;
use wasmtime::component::{Component, Linker, ResourceTable};
use wasmtime::{Engine, Store};
use wasmtime_wasi::{IoView, WasiCtx, WasiCtxBuilder, WasiView};

use crate::bridge::bindings;
use crate::types::UiTree;

struct PluginState {
    table: ResourceTable,
    ctx: WasiCtx,
}

impl PluginState {
    fn new() -> Self {
        let table = ResourceTable::new();
        let ctx = WasiCtxBuilder::new().build();
        Self { table, ctx }
    }
}

impl IoView for PluginState {
    fn table(&mut self) -> &mut ResourceTable {
        &mut self.table
    }
}

impl WasiView for PluginState {
    fn ctx(&mut self) -> &mut WasiCtx {
        &mut self.ctx
    }
}

pub struct PluginRuntime {
    engine: Engine,
    store: Store<PluginState>,
    component: Option<Component>,
}

impl PluginRuntime {
    pub fn new() -> Result<Self> {
        let mut config = wasmtime::Config::new();
        config.wasm_component_model(true);
        let engine = Engine::new(&config)?;
        let state = PluginState::new();
        let store = Store::new(&engine, state);
        Ok(Self {
            engine,
            store,
            component: None,
        })
    }

    pub fn load(&mut self, path: &Path) -> Result<()> {
        let component = Component::from_file(&self.engine, path)?;
        self.component = Some(component);
        Ok(())
    }

    pub fn render(&mut self) -> Result<UiTree> {
        let component = self
            .component
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("No component loaded"))?;

        let mut linker = Linker::new(&self.engine);
        wasmtime_wasi::add_to_linker_sync(&mut linker)?;

        let instance = bindings::UiPlugin::instantiate(&mut self.store, component, &linker)?;

        let wit_tree = instance.call_render(&mut self.store)?;
        Ok(wit_tree.into())
    }

    pub fn handle_event(&mut self, event_id: u32, payload: Option<String>) -> Result<UiTree> {
        let component = self
            .component
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("No component loaded"))?;

        let mut linker = Linker::new(&self.engine);
        wasmtime_wasi::add_to_linker_sync(&mut linker)?;

        let instance = bindings::UiPlugin::instantiate(&mut self.store, component, &linker)?;

        let wit_tree = instance.call_handle_event(&mut self.store, event_id, payload.as_deref())?;
        Ok(wit_tree.into())
    }
}
