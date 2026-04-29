use anyhow::Result;
use std::path::Path;
use log::{info, debug};
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
    linker: Option<Linker<PluginState>>,
    instance: Option<bindings::UiPlugin>,
}

impl PluginRuntime {
    pub fn new() -> Result<Self> {
        info!("Initializing WASM runtime with Component Model support");
        let mut config = wasmtime::Config::new();
        config.wasm_component_model(true);
        let engine = Engine::new(&config)?;
        let state = PluginState::new();
        let store = Store::new(&engine, state);
        Ok(Self {
            engine,
            store,
            component: None,
            linker: None,
            instance: None,
        })
    }

    pub fn load(&mut self, path: &Path) -> Result<()> {
        info!("Loading WASM component from: {}", path.display());
        let component = Component::from_file(&self.engine, path)?;
        self.component = Some(component);
        
        debug!("Preparing WASI linker");
        let mut linker = Linker::new(&self.engine);
        wasmtime_wasi::add_to_linker_sync(&mut linker)?;
        self.linker = Some(linker);
        
        debug!("Instantiating component");
        self.instantiate()?;
        
        info!("Component loaded and instantiated successfully");
        Ok(())
    }

    fn instantiate(&mut self) -> Result<()> {
        let component = self
            .component
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("No component loaded"))?;
        let linker = self
            .linker
            .as_ref()
            .ok_or_else(|| anyhow::anyhow!("No linker prepared"))?;
        
        let instance = bindings::UiPlugin::instantiate(&mut self.store, component, linker)?;
        self.instance = Some(instance);
        Ok(())
    }

    pub fn render(&mut self) -> Result<UiTree> {
        debug!("Calling render() on plugin");
        let instance = self
            .instance
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("No component loaded"))?;

        let wit_tree = instance.call_render(&mut self.store)?;
        debug!("render() completed successfully");
        Ok(wit_tree.into())
    }

    pub fn handle_event(&mut self, event_id: u32, payload: Option<String>) -> Result<UiTree> {
        debug!("Calling handle_event(event_id={}, payload={:?}) on plugin", event_id, payload);
        let instance = self
            .instance
            .as_mut()
            .ok_or_else(|| anyhow::anyhow!("No component loaded"))?;

        let wit_tree = instance.call_handle_event(&mut self.store, event_id, payload.as_deref())?;
        debug!("handle_event() completed successfully");
        Ok(wit_tree.into())
    }
}
