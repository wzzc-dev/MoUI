///|
using @views {animated_canvas, fill_rounded_rect, pop_opacity, push_opacity}

///|
fn welcome_demo(
  model : ComponentGalleryModel,
  theme : @moui.Theme,
  width : Double,
  compact : Bool,
) -> @moui.View[ComponentGalleryMsg] {
  let inner = section_inner_width(width)
  let gap = theme.spacing_scale.sm
  // Cap the desired columns, then pass the matching cell width back to
  // responsive_grid so its uncapped column calculation cannot exceed it.
  let stat_columns = welcome_grid_columns(
    available=inner,
    min_column_width=if compact { inner } else { 168.0 },
    column_spacing=gap,
    max_columns=3,
  )
  let group_columns = welcome_grid_columns(
    available=inner,
    min_column_width=if compact { inner } else { 220.0 },
    column_spacing=gap,
    max_columns=4,
  )
  let stat_width = welcome_cell_width(inner, stat_columns, gap)
  let group_width = welcome_cell_width(inner, group_columns, gap)
  column(
    [
      component_demo_section(
        "Catalog",
        "Focused component demos first; runtime proof stays available without becoming the main content.",
        column(
          [
            responsive_grid(
              [
                stat_card(
                  "Components",
                  "\{catalog_items().length()}",
                  caption="focused entries",
                  tone=@views.FeedbackTone::Info,
                  theme~,
                  width=stat_width,
                ),
                stat_card(
                  "Groups",
                  "\{catalog_groups().length()}",
                  caption="browse sections",
                  tone=@views.FeedbackTone::Success,
                  theme~,
                  width=stat_width,
                ),
                stat_card(
                  "Hosts",
                  "\{platform_runtime_infos().length()}",
                  caption="desktop/mobile/web",
                  tone=@views.FeedbackTone::Warning,
                  theme~,
                  width=stat_width,
                ),
              ],
              width=inner,
              min_column_width=stat_width,
              row_spacing=gap,
              column_spacing=gap,
            ),
            wrapped_text(
              "Use the left Stories rail to open small component demos. Each demo is plain app code you can reuse in another MoUI example.",
              role=@views.TextRole::Body,
              theme~,
              width=inner,
              height=56.0,
              align=@text.TextAlign::TextStart,
            ),
          ],
          spacing=gap,
          align=@views.CrossAlign::Stretch,
        ),
        theme,
        width,
      ),
      component_demo_section(
        "Component Groups",
        "The catalog is organized by how a user reaches for components.",
        responsive_grid(
          [
            component_tile(
              "Controls", "Button, text inputs, checkbox, toggle, radio, chips, picker, slider.",
              theme, group_width,
            ),
            component_tile(
              "Feedback", "Badge, progress, banner, callout, state panels, toast, snackbar.",
              theme, group_width,
            ),
            component_tile(
              "Display & Layout", "Stat cards, avatars, dividers, toolbars, surfaces, grids, scroll view.",
              theme, group_width,
            ),
            component_tile(
              "Runtime", "Host routes and platform proof stay available from Platform / Runtime stories.",
              theme, group_width,
            ),
          ],
          width=inner,
          min_column_width=group_width,
          row_spacing=gap,
          column_spacing=gap,
        ),
        theme,
        width,
      ),
      component_demo_section(
        "Live Canvas",
        "A bouncing orb on an animated_canvas. The paint clock drives motion; no host timer is required.",
        welcome_bouncing_ball_canvas(theme, inner),
        theme,
        width,
      ),
      component_demo_section(
        "Runtime Hosts",
        "The same component gallery adapts to each runtime route.",
        platform_badge_grid(model, theme, inner, compact),
        theme,
        width,
      ),
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|
/// Bouncing-ball canvas used on the Welcome page. The ball reflects off the
/// canvas edges; motion is driven by the `animated_canvas` paint clock
/// (`now_ms`), so it loops without a `TimerSource` subscription.
fn welcome_bouncing_ball_canvas(
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[ComponentGalleryMsg] {
  let canvas_height = 160.0
  let radius = 18.0
  let speed_x = 110.0
  let speed_y = 78.0
  animated_canvas(
    measure=constraints => {
      constraints.constrain(@geometry.Size::new(width~, height=canvas_height))
    },
    draw=(ctx, frame, now_ms) => {
      // Background panel.
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=frame, radius=12.0),
        @graphics.Brush::solid(@graphics.Color::rgba(r=0.93, g=0.95, b=0.98)),
      )
      // Bouncing ball position from the paint clock.
      let travel_x = (frame.size.width - 2.0 * radius).max(1.0)
      let travel_y = (frame.size.height - 2.0 * radius).max(1.0)
      let period_x = travel_x / speed_x
      let period_y = travel_y / speed_y
      let tx = now_ms / 1000.0 % period_x
      let ty = now_ms / 1000.0 % period_y
      let phase_x = tx / period_x
      let phase_y = ty / period_y
      // Triangle wave: 0 -> 1 -> 0 within one period.
      let norm_x = if phase_x < 0.5 {
        phase_x * 2.0
      } else {
        2.0 - phase_x * 2.0
      }
      let norm_y = if phase_y < 0.5 {
        phase_y * 2.0
      } else {
        2.0 - phase_y * 2.0
      }
      let ball_x = frame.origin.x + radius + norm_x * travel_x
      let ball_y = frame.origin.y + radius + norm_y * travel_y
      let ball = @geometry.Rect::new(
        x=ball_x - radius,
        y=ball_y - radius,
        width=2.0 * radius,
        height=2.0 * radius,
      )
      // Soft trailing shadow under the ball.
      push_opacity(ctx, 0.18)
      let shadow = @geometry.Rect::new(
        x=ball_x - radius * 0.9,
        y=frame.origin.y + frame.size.height - radius * 0.6,
        width=radius * 1.8,
        height=radius * 0.5,
      )
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=shadow, radius=radius * 0.25),
        @graphics.Brush::solid(@graphics.Color::rgba(r=0.1, g=0.1, b=0.15)),
      )
      pop_opacity(ctx)
      // The orb itself, using the theme primary color.
      fill_rounded_rect(
        ctx,
        @graphics.RoundedRect::new(rect=ball, radius~),
        @graphics.Brush::solid(theme.palette.primary),
      )
    },
    semantics_label="Welcome bouncing ball canvas",
  )
}

///|
/// Same column-count rule as `@views.responsive_grid`, with an optional cap so
/// welcome sections stay readable on very wide canvases.
fn welcome_grid_columns(
  available~ : Double,
  min_column_width~ : Double,
  column_spacing~ : Double,
  max_columns~ : Int,
) -> Int {
  let min_column_width = min_column_width.max(1.0)
  let max_columns = max_columns.max(1)
  let mut columns = 1
  let mut candidate = 2
  while candidate <= max_columns {
    let needed = candidate.to_double() * min_column_width +
      (candidate - 1).to_double() * column_spacing
    if needed > available {
      break
    }
    columns = candidate
    candidate = candidate + 1
  }
  columns
}

///|
fn welcome_cell_width(
  available : Double,
  columns : Int,
  column_spacing : Double,
) -> Double {
  let columns = columns.max(1)
  ((available - (columns - 1).to_double() * column_spacing) /
  columns.to_double()).max(1.0)
}
