///|
priv struct StoryGroup {
  id : String
  name : String
  detail : String
}

///|
priv struct ComponentGalleryStoryInfo {
  id : ComponentGalleryStoryId
  group : String
  name : String
  description : String
  badge : String
  tone : @views.BadgeTone
}

///|
fn story_groups() -> Array[StoryGroup] {
  [
    {
      id: "getting-started",
      name: "Getting Started",
      detail: "The gallery shell and six runtime targets",
    },
    {
      id: "components",
      name: "Components",
      detail: "Reusable MoUI controls composed from @views",
    },
    {
      id: "layout",
      name: "Layout",
      detail: "Adaptive structure for phones, desktops, and Web",
    },
    {
      id: "platforms",
      name: "Platforms",
      detail: "Thin entrypoints over the same shared app",
    },
  ]
}

///|
fn component_gallery_stories() -> Array[ComponentGalleryStoryInfo] {
  [
    {
      id: ComponentGalleryStoryId::Welcome,
      group: "getting-started",
      name: "Welcome",
      description: "Component Gallery is a grouped story browser for MoUI controls running across six platforms.",
      badge: "intro",
      tone: @views.BadgeTone::Accent,
    },
    {
      id: ComponentGalleryStoryId::Buttons,
      group: "components",
      name: "Buttons",
      description: "Button variants, simple state updates, and action density.",
      badge: "control",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryStoryId::Inputs,
      group: "components",
      name: "Inputs",
      description: "Text input, segmented choices, picker, checkbox, and slider in one form story.",
      badge: "form",
      tone: @views.BadgeTone::Success,
    },
    {
      id: ComponentGalleryStoryId::Feedback,
      group: "components",
      name: "Feedback",
      description: "Badges, progress status, and compact data cards for live state.",
      badge: "status",
      tone: @views.BadgeTone::Warning,
    },
    {
      id: ComponentGalleryStoryId::Layout,
      group: "layout",
      name: "Adaptive Layout",
      description: "Responsive grid, row/column composition, and viewport-aware surfaces.",
      badge: "adaptive",
      tone: @views.BadgeTone::Neutral,
    },
    {
      id: ComponentGalleryStoryId::Platforms,
      group: "platforms",
      name: "Platform Routes",
      description: "macOS, Linux, Windows, Android, iOS, and Web entrypoints running this same story app.",
      badge: "six hosts",
      tone: @views.BadgeTone::Accent,
    },
  ]
}

///|
pub fn story_id_to_string(id : ComponentGalleryStoryId) -> String {
  match id {
    ComponentGalleryStoryId::Welcome => "welcome"
    ComponentGalleryStoryId::Buttons => "buttons"
    ComponentGalleryStoryId::Inputs => "inputs"
    ComponentGalleryStoryId::Feedback => "feedback"
    ComponentGalleryStoryId::Layout => "layout"
    ComponentGalleryStoryId::Platforms => "platforms"
  }
}

///|
pub fn story_id_from_string(id : String) -> ComponentGalleryStoryId? {
  match id {
    "welcome" => Some(ComponentGalleryStoryId::Welcome)
    "buttons" => Some(ComponentGalleryStoryId::Buttons)
    "inputs" => Some(ComponentGalleryStoryId::Inputs)
    "feedback" => Some(ComponentGalleryStoryId::Feedback)
    "layout" => Some(ComponentGalleryStoryId::Layout)
    "platforms" => Some(ComponentGalleryStoryId::Platforms)
    _ => None
  }
}

///|
fn story_info(id : ComponentGalleryStoryId) -> ComponentGalleryStoryInfo {
  for story in component_gallery_stories() {
    if story.id == id {
      return story
    }
  }
  component_gallery_stories()[0]
}

///|
fn story_matches_query(
  story : ComponentGalleryStoryInfo,
  query : String,
) -> Bool {
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    true
  } else {
    story.name.to_lower().contains(needle) ||
    story.group.to_lower().contains(needle) ||
    story.description.to_lower().contains(needle) ||
    story.badge.to_lower().contains(needle)
  }
}

///|
fn filtered_stories(query : String) -> Array[ComponentGalleryStoryInfo] {
  let rows : Array[ComponentGalleryStoryInfo] = []
  for story in component_gallery_stories() {
    if story_matches_query(story, query) {
      rows.push(story)
    }
  }
  rows
}

///|
fn first_story_matching(query : String) -> ComponentGalleryStoryId? {
  for story in component_gallery_stories() {
    if story_matches_query(story, query) {
      return Some(story.id)
    }
  }
  None
}

///|
fn story_group_has_matches(group_id : String, query : String) -> Bool {
  for story in component_gallery_stories() {
    if story.group == group_id && story_matches_query(story, query) {
      return true
    }
  }
  false
}

///|
fn filtered_story_count(query : String) -> Int {
  filtered_stories(query).length()
}
