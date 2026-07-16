///|
pub(all) struct CatalogGroup {
  id : String
  title : String
} derive(Eq, Debug)

///|
pub(all) struct CatalogItem {
  id : String
  group_id : String
  title : String
  summary : String
  badge : String
} derive(Eq, Debug)

///|
pub fn catalog_groups() -> Array[CatalogGroup] {
  [
    { id: "host", title: "Host" },
    { id: "graphics", title: "Graphics" },
    { id: "mobile", title: "Mobile" },
  ]
}

///|
pub fn catalog_items() -> Array[CatalogItem] {
  [
    {
      id: "host-services",
      group_id: "host",
      title: "Host Services",
      summary: "Timer, window resize, clipboard, file open, and shortcuts.",
      badge: "host",
    },
    {
      id: "route-session",
      group_id: "host",
      title: "Route & Session",
      summary: "Current platform route and host session labels.",
      badge: "session",
    },
    {
      id: "canvas",
      group_id: "graphics",
      title: "Canvas",
      summary: "Custom paint with drag strokes and animation ticks.",
      badge: "paint",
    },
    {
      id: "mobile-service-probe",
      group_id: "mobile",
      title: "Mobile Service Probe",
      summary: "IME, action, image, and viewport checks for mobile hosts.",
      badge: "mobile",
    },
  ]
}
