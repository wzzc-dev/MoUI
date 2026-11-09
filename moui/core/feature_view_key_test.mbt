///|
#derive(Eq, Debug)
struct ViewKeyModel {
  value : Int32
  caption : String
}

///|
struct ViewKeyTestNode {
  label : String
}

///|
impl @core.ViewNode for ViewKeyTestNode with fn identity(self) {
  @core.ViewIdentity::new(kind="feature-view-key-test", key=Some(self.label))
}

///|
impl @core.ViewNode for ViewKeyTestNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=4.0, height=4.0)),
  )
}

///|
fn view_key_environment(width~ : Double = 100.0) -> @core.ViewEnvironment {
  @core.ViewEnvironment::new(
    viewport_size=@core.Size::new(width~, height=50.0),
    environment=@core.Environment::neutral(),
  )
}

///|
fn view_key_builder(id : String) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag="feature-view-key-test.builder", fields=[
    ("id", @core.DeclarationKey::string(id)),
  ])
}

///|
/// A feature whose view records how often it ran and declares a key covering
/// both the model fields and the viewport it reads.
fn view_key_feature(builds : Ref[Int32]) -> @core.Feature[ViewKeyModel, String] {
  @core.Feature::new_with_environment(
    init=() => ({ value: 0, caption: "init", }, @core.Effect::none()),
    update=(model, caption) => ({ ..model, caption, }, @core.Effect::none()),
    view=(model, environment) => {
      builds.val = builds.val + 1
      @core.View::from_node(ViewKeyTestNode::{
        label: "\{model.caption}/\{model.value}/\{environment.viewport_size().width}",
      })
    },
  ).with_view_key(view_key=(model, environment) => {
    @core.DeclarationKey::record(type_tag="feature-view-key-test.content", fields=[
      ("caption", @core.DeclarationKey::string(model.caption)),
      ("value", @core.DeclarationKey::int(model.value)),
      (
        "viewport",
        @core.DeclarationKey::double(environment.viewport_size().width),
      ),
    ])
  })
}

///|
test "feature view key skips construction while the key is unchanged" {
  let builds = Ref(0)
  let feature = view_key_feature(builds)
  let cache = @core.ViewBuilderCache::new()
  let model : ViewKeyModel = { value: 1, caption: "a", }
  let environment = view_key_environment()
  let builder_key = view_key_builder("mount")
  let first = feature.runtime_view_cached(
    model,
    environment,
    cache~,
    builder_key~,
  )
  let second = feature.runtime_view_cached(
    model,
    environment,
    cache~,
    builder_key~,
  )
  inspect(builds.val, content="1")
  inspect(cache.stats().hit_count(), content="1")
  inspect(physical_equal(first, second), content="true")
}

///|
test "feature view key rebuilds when a declared model input changes" {
  let builds = Ref(0)
  let feature = view_key_feature(builds)
  let cache = @core.ViewBuilderCache::new()
  let environment = view_key_environment()
  let builder_key = view_key_builder("mount")
  ignore(
    feature.runtime_view_cached(
      { value: 1, caption: "a", },
      environment,
      cache~,
      builder_key~,
    ),
  )
  ignore(
    feature.runtime_view_cached(
      { value: 2, caption: "a", },
      environment,
      cache~,
      builder_key~,
    ),
  )
  inspect(builds.val, content="2")
  inspect(cache.stats().entry_count(), content="1")
}

///|
test "feature view key rebuilds when a declared environment input changes" {
  let builds = Ref(0)
  let feature = view_key_feature(builds)
  let cache = @core.ViewBuilderCache::new()
  let model : ViewKeyModel = { value: 1, caption: "a", }
  let builder_key = view_key_builder("mount")
  ignore(
    feature.runtime_view_cached(
      model,
      view_key_environment(),
      cache~,
      builder_key~,
    ),
  )
  ignore(
    feature.runtime_view_cached(
      model,
      view_key_environment(width=200.0),
      cache~,
      builder_key~,
    ),
  )
  inspect(builds.val, content="2")
}

///|
test "sibling mounts of one feature keep independent cache entries" {
  let builds = Ref(0)
  let feature = view_key_feature(builds)
  let cache = @core.ViewBuilderCache::new()
  let environment = view_key_environment()
  let left = feature.runtime_view_cached(
    { value: 1, caption: "left", },
    environment,
    cache~,
    builder_key=view_key_builder("left"),
  )
  let right = feature.runtime_view_cached(
    { value: 9, caption: "right", },
    environment,
    cache~,
    builder_key=view_key_builder("right"),
  )
  inspect(builds.val, content="2")
  inspect(cache.stats().entry_count(), content="2")
  inspect(physical_equal(left, right), content="false")
  // Each mount still hits its own entry rather than the sibling's.
  let left_again = feature.runtime_view_cached(
    { value: 1, caption: "left", },
    environment,
    cache~,
    builder_key=view_key_builder("left"),
  )
  inspect(physical_equal(left, left_again), content="true")
  inspect(builds.val, content="2")
}

///|
test "a feature without a view key builds every time and caches nothing" {
  let builds = Ref(0)
  let feature = @core.Feature::new(
    init=() => (0, @core.Effect::none()),
    update=(_model, message) => (message, @core.Effect::none()),
    view=_model => {
      builds.val = builds.val + 1
      @core.View::from_node(ViewKeyTestNode::{ label: "unkeyed", })
    },
  )
  let cache = @core.ViewBuilderCache::new()
  let environment = view_key_environment()
  let builder_key = view_key_builder("mount")
  ignore(feature.runtime_view_cached(0, environment, cache~, builder_key~))
  ignore(feature.runtime_view_cached(0, environment, cache~, builder_key~))
  inspect(builds.val, content="2")
  inspect(cache.stats().entry_count(), content="0")
}

///|
#derive(Eq, Debug)
struct ViewKeyParent {
  title : String
  child : ViewKeyModel
}

///|
test "scoped view caching skips construction when only the parent changes" {
  let builds = Ref(0)
  let scope = view_key_feature(builds).scope(
    scope_id="child",
    read=(parent : ViewKeyParent) => parent.child,
    write=(child, parent) => { ..parent, child, },
    wrap=(_message : String) => "wrapped",
  )
  let cache = @core.ViewBuilderCache::new()
  let environment = view_key_environment()
  let builder_key = view_key_builder("scoped")
  let parent : ViewKeyParent = {
    title: "one",
    child: { value: 1, caption: "a", },
  }
  let first = scope.view_cached(parent, environment, cache~, builder_key~)
  // The parent model changed but the lens read did not: the child body must
  // not run. This is the composition-boundary win RFC 0008 exists for.
  let second = scope.view_cached(
    { ..parent, title: "two", },
    environment,
    cache~,
    builder_key~,
  )
  inspect(builds.val, content="1")
  inspect(cache.stats().hit_count(), content="1")
  inspect(physical_equal(first, second), content="true")
  let third = scope.view_cached(
    { ..parent, child: { value: 2, caption: "a", }, },
    environment,
    cache~,
    builder_key~,
  )
  inspect(builds.val, content="2")
  inspect(physical_equal(first, third), content="false")
}
