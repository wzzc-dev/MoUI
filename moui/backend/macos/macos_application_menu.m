#import <AppKit/AppKit.h>
#import <moonbit.h>
#import <objc/runtime.h>
#import <stdint.h>

typedef void (*moui_macos_application_menu_trampoline_t)(void *closure,
                                                          int32_t action_id);

static const void *kMouiApplicationMenuTargetKey =
    &kMouiApplicationMenuTargetKey;
static const void *kMouiMenuBarTargetKey = &kMouiMenuBarTargetKey;
static NSString *const kMouiApplicationMenuMarker =
    @"moui.application-menu-item";
static id g_moui_application_menu_key_equivalent_monitor = nil;
static NSUInteger g_moui_application_menu_key_equivalent_monitor_hits = 0;

@interface MOUIApplicationMenuTarget : NSObject {
  moui_macos_application_menu_trampoline_t _trampoline;
  void *_closure;
}
- (instancetype)initWithTrampoline:
                    (moui_macos_application_menu_trampoline_t)trampoline
                            closure:(void *)closure;
- (void)dispatchMenuItem:(id)sender;
@end

@implementation MOUIApplicationMenuTarget
- (instancetype)initWithTrampoline:
                    (moui_macos_application_menu_trampoline_t)trampoline
                            closure:(void *)closure {
  self = [super init];
  if (self != nil) {
    _trampoline = trampoline;
    _closure = closure;
  }
  return self;
}

- (void)dispatchMenuItem:(id)sender {
  if (_trampoline != NULL && _closure != NULL &&
      [sender respondsToSelector:@selector(tag)]) {
    _trampoline(_closure, (int32_t)[sender tag]);
  }
}

- (void)dealloc {
  if (_closure != NULL) {
    moonbit_decref(_closure);
    _closure = NULL;
  }
  [super dealloc];
}
@end

static BOOL moui_application_menu_marked(NSMenuItem *item) {
  return [[item representedObject] isEqual:kMouiApplicationMenuMarker];
}

static void moui_remove_application_menu_items(NSMenu *menu) {
  for (NSInteger index = menu.numberOfItems - 1; index >= 0; index--) {
    if (moui_application_menu_marked([menu itemAtIndex:index])) {
      [menu removeItemAtIndex:index];
    }
  }
}

static NSInteger moui_application_menu_insertion_index(NSMenu *menu) {
  NSMenu *servicesMenu = NSApp.servicesMenu;
  for (NSInteger index = 0; index < menu.numberOfItems; index++) {
    if ([menu itemAtIndex:index].submenu == servicesMenu) {
      return index;
    }
  }
  return MIN((NSInteger)2, menu.numberOfItems);
}

static NSMenuItem *moui_marked_separator(void) {
  NSMenuItem *separator = [NSMenuItem separatorItem];
  separator.representedObject = kMouiApplicationMenuMarker;
  return separator;
}

static NSDictionary *moui_menu_dictionary(id value) {
  return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSString *moui_string_from_bytes(moonbit_bytes_t bytes) {
  NSUInteger length = (NSUInteger)Moonbit_array_length(bytes);
  return [[[NSString alloc] initWithBytes:(const void *)bytes
                                  length:length
                                encoding:NSUTF8StringEncoding] autorelease] ?: @"";
}

static NSEventModifierFlags moui_macos_key_equivalent_modifier_flags(
    NSEventModifierFlags flags) {
  return flags & (NSEventModifierFlagShift | NSEventModifierFlagControl |
                  NSEventModifierFlagOption | NSEventModifierFlagCommand);
}

static BOOL moui_macos_menu_item_matches_key_equivalent(NSMenuItem *item,
                                                        NSEvent *event) {
  NSString *key = item.keyEquivalent;
  NSString *eventKey = event.charactersIgnoringModifiers;
  if (!item.enabled || item.action == NULL || key.length == 0 ||
      eventKey.length == 0) {
    return NO;
  }
  if (![[key lowercaseString] isEqualToString:[eventKey lowercaseString]]) {
    return NO;
  }
  return moui_macos_key_equivalent_modifier_flags(
             item.keyEquivalentModifierMask) ==
      moui_macos_key_equivalent_modifier_flags(event.modifierFlags);
}

static BOOL moui_macos_perform_exact_key_equivalent(NSMenu *menu,
                                                    NSEvent *event) {
  for (NSMenuItem *item in menu.itemArray) {
    if (moui_macos_menu_item_matches_key_equivalent(item, event) &&
        [NSApp sendAction:item.action to:item.target from:item]) {
      return YES;
    }
    if (item.submenu != nil &&
        moui_macos_perform_exact_key_equivalent(item.submenu, event)) {
      return YES;
    }
  }
  return NO;
}

// `wzzc-dev/window` owns the AppKit application-event bridge. Install this
// monitor after the native menus exist so command-key events take the same
// `NSMenuItem` action path as a click before any host-level key handling.
MOONBIT_FFI_EXPORT
int32_t moui_macos_install_application_menu_key_equivalent_monitor(void) {
  if (g_moui_application_menu_key_equivalent_monitor != nil) {
    return 1;
  }
  g_moui_application_menu_key_equivalent_monitor =
      [[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                             handler:^NSEvent *(NSEvent *event) {
        if ((event.modifierFlags & NSEventModifierFlagCommand) == 0) {
          return event;
        }
        NSMenu *menu = NSApp.mainMenu;
        if (menu != nil &&
            (moui_macos_perform_exact_key_equivalent(menu, event) ||
             [menu performKeyEquivalent:event])) {
          g_moui_application_menu_key_equivalent_monitor_hits += 1;
          return nil;
        }
        return event;
      }] retain];
  return g_moui_application_menu_key_equivalent_monitor != nil ? 1 : 0;
}

enum {
  MOUI_MACOS_EDIT_ACTION_COPY = 0,
  MOUI_MACOS_EDIT_ACTION_CUT = 1,
  MOUI_MACOS_EDIT_ACTION_PASTE = 2,
  MOUI_MACOS_EDIT_ACTION_UNDO = 3,
  MOUI_MACOS_EDIT_ACTION_REDO = 4,
  MOUI_MACOS_EDIT_ACTION_SELECT_ALL = 5,
};

static SEL moui_macos_edit_action_selector(int32_t action) {
  switch (action) {
    case MOUI_MACOS_EDIT_ACTION_COPY:
      return @selector(copy:);
    case MOUI_MACOS_EDIT_ACTION_CUT:
      return @selector(cut:);
    case MOUI_MACOS_EDIT_ACTION_PASTE:
      return @selector(paste:);
    case MOUI_MACOS_EDIT_ACTION_UNDO:
      return @selector(undo:);
    case MOUI_MACOS_EDIT_ACTION_REDO:
      return @selector(redo:);
    case MOUI_MACOS_EDIT_ACTION_SELECT_ALL:
      return @selector(selectAll:);
    default:
      return NULL;
  }
}

static BOOL moui_macos_dispatch_edit_action_to_window(NSWindow *window,
                                                       int32_t action) {
  SEL selector = moui_macos_edit_action_selector(action);
  NSResponder *responder = window != nil ? window.firstResponder : nil;
  return selector != NULL && responder != nil &&
         [responder tryToPerform:selector with:nil];
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_dispatch_first_responder_edit_action(int32_t action) {
  NSWindow *window = NSApp.keyWindow;
  if (window == nil) {
    window = NSApp.mainWindow;
  }
  return moui_macos_dispatch_edit_action_to_window(window, action) ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_install_application_menu_items(
    moonbit_bytes_t payload,
    moui_macos_application_menu_trampoline_t trampoline,
    void *closure) {
  NSMenu *mainMenu = NSApp.mainMenu;
  NSMenu *applicationMenu = mainMenu.numberOfItems > 0
                                ? [mainMenu itemAtIndex:0].submenu
                                : nil;
  if (applicationMenu == nil) {
    moonbit_decref(closure);
    return 0;
  }

  NSData *data = [NSData dataWithBytes:(const void *)payload
                                length:(NSUInteger)Moonbit_array_length(payload)];
  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![decoded isKindOfClass:[NSArray class]]) {
    moonbit_decref(closure);
    return 0;
  }

  moui_remove_application_menu_items(applicationMenu);
  objc_setAssociatedObject(applicationMenu, kMouiApplicationMenuTargetKey, nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  NSArray *descriptors = (NSArray *)decoded;
  if (descriptors.count == 0) {
    moonbit_decref(closure);
    return 1;
  }

  MOUIApplicationMenuTarget *target =
      [[MOUIApplicationMenuTarget alloc] initWithTrampoline:trampoline
                                                    closure:closure];
  if (target == nil) {
    moonbit_decref(closure);
    return 0;
  }
  NSInteger index = moui_application_menu_insertion_index(applicationMenu);
  BOOL insertedCommand = NO;
  for (id value in descriptors) {
    NSDictionary *descriptor = moui_menu_dictionary(value);
    if (descriptor == nil) {
      continue;
    }
    BOOL separator = [descriptor[@"separator"] boolValue];
    NSMenuItem *item = nil;
    if (separator) {
      item = moui_marked_separator();
    } else {
      NSString *title = [descriptor[@"title"] isKindOfClass:[NSString class]]
                            ? descriptor[@"title"]
                            : @"";
      NSString *key =
          [descriptor[@"key_equivalent"] isKindOfClass:[NSString class]]
              ? descriptor[@"key_equivalent"]
              : @"";
      item = [[[NSMenuItem alloc]
          initWithTitle:title
                 action:@selector(dispatchMenuItem:)
          keyEquivalent:key] autorelease];
      item.target = target;
      item.tag = [descriptor[@"action_id"] integerValue];
      item.enabled = [descriptor[@"enabled"] boolValue];
      NSNumber *mask = descriptor[@"key_modifier_mask"];
      if ([mask isKindOfClass:[NSNumber class]] && mask.integerValue >= 0) {
        item.keyEquivalentModifierMask = (NSEventModifierFlags)mask.unsignedIntegerValue;
      }
      item.representedObject = kMouiApplicationMenuMarker;
      insertedCommand = YES;
    }
    [applicationMenu insertItem:item atIndex:index];
    index += 1;
  }

  if (insertedCommand) {
    NSMenuItem *lastInserted = index > 0 ? [applicationMenu itemAtIndex:index - 1] : nil;
    if (lastInserted != nil && ![lastInserted isSeparatorItem]) {
      [applicationMenu insertItem:moui_marked_separator() atIndex:index];
    }
    objc_setAssociatedObject(applicationMenu, kMouiApplicationMenuTargetKey,
                             target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  [target release];
  return 1;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_bind_menu_bar_items(
    moonbit_bytes_t payload,
    moui_macos_application_menu_trampoline_t trampoline,
    void *closure) {
  NSMenu *mainMenu = NSApp.mainMenu;
  if (mainMenu == nil) {
    return 0;
  }

  NSData *data = [NSData dataWithBytes:(const void *)payload
                                length:(NSUInteger)Moonbit_array_length(payload)];
  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![decoded isKindOfClass:[NSArray class]]) {
    return 0;
  }

  moonbit_incref(closure);
  MOUIApplicationMenuTarget *target =
      [[MOUIApplicationMenuTarget alloc] initWithTrampoline:trampoline
                                                    closure:closure];
  if (target == nil) {
    moonbit_decref(closure);
    return 0;
  }

  BOOL boundCommand = NO;
  for (id menuValue in (NSArray *)decoded) {
    NSDictionary *menuDescriptor = moui_menu_dictionary(menuValue);
    if (menuDescriptor == nil) {
      continue;
    }
    NSString *title =
        [menuDescriptor[@"title"] isKindOfClass:[NSString class]]
            ? menuDescriptor[@"title"]
            : @"";
    NSArray *items =
        [menuDescriptor[@"items"] isKindOfClass:[NSArray class]]
            ? menuDescriptor[@"items"]
            : nil;
    if (items == nil) {
      continue;
    }

    NSMenu *submenu = nil;
    for (NSMenuItem *topLevelItem in mainMenu.itemArray) {
      if ([topLevelItem.submenu.title isEqualToString:title]) {
        submenu = topLevelItem.submenu;
        break;
      }
    }
    if (submenu == nil || submenu.numberOfItems != (NSInteger)items.count) {
      continue;
    }

    for (NSUInteger index = 0; index < items.count; index++) {
      NSDictionary *descriptor = moui_menu_dictionary(items[index]);
      NSMenuItem *item = [submenu itemAtIndex:(NSInteger)index];
      if (descriptor == nil || item == nil ||
          [descriptor[@"separator"] boolValue] || [item isSeparatorItem]) {
        continue;
      }
      item.target = target;
      item.action = @selector(dispatchMenuItem:);
      item.tag = [descriptor[@"action_id"] integerValue];
      item.enabled = [descriptor[@"enabled"] boolValue];
      boundCommand = YES;
    }
  }

  if (boundCommand) {
    objc_setAssociatedObject(mainMenu, kMouiMenuBarTargetKey, target,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  [target release];
  return boundCommand ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_perform_menu_item(moonbit_bytes_t menu_title,
                                     moonbit_bytes_t item_title) {
  NSString *menuTitle = moui_string_from_bytes(menu_title);
  NSString *itemTitle = moui_string_from_bytes(item_title);
  for (NSMenuItem *topLevelItem in NSApp.mainMenu.itemArray) {
    NSMenu *submenu = topLevelItem.submenu;
    if (![submenu.title isEqualToString:menuTitle]) {
      continue;
    }
    for (NSMenuItem *item in submenu.itemArray) {
      if ([item.title isEqualToString:itemTitle] && item.action != NULL) {
        return [NSApp sendAction:item.action to:item.target from:item] ? 1 : 0;
      }
    }
  }
  return 0;
}

@interface MOUITestFirstResponderEditView : NSView {
  int32_t _handledAction;
}
- (void)resetHandledAction;
- (int32_t)handledAction;
@end

@implementation MOUITestFirstResponderEditView
- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)resetHandledAction {
  _handledAction = -1;
}

- (int32_t)handledAction {
  return _handledAction;
}

- (void)copy:(id)sender {
  (void)sender;
  _handledAction = MOUI_MACOS_EDIT_ACTION_COPY;
}

- (void)cut:(id)sender {
  (void)sender;
  _handledAction = MOUI_MACOS_EDIT_ACTION_CUT;
}

- (void)paste:(id)sender {
  (void)sender;
  _handledAction = MOUI_MACOS_EDIT_ACTION_PASTE;
}

- (void)undo:(id)sender {
  (void)sender;
  _handledAction = MOUI_MACOS_EDIT_ACTION_UNDO;
}

- (void)redo:(id)sender {
  (void)sender;
  _handledAction = MOUI_MACOS_EDIT_ACTION_REDO;
}

- (void)selectAll:(id)sender {
  (void)sender;
  _handledAction = MOUI_MACOS_EDIT_ACTION_SELECT_ALL;
}
@end

@interface MOUITestEditShortcutTarget : NSObject
@property(nonatomic, assign) NSWindow *window;
- (void)dispatchEditShortcut:(id)sender;
@end

@implementation MOUITestEditShortcutTarget
- (void)dispatchEditShortcut:(id)sender {
  if ([sender respondsToSelector:@selector(tag)]) {
    moui_macos_dispatch_edit_action_to_window(
        self.window, (int32_t)[sender tag]);
  }
}
@end

MOONBIT_FFI_EXPORT
int32_t moui_macos_first_responder_edit_actions_test(void) {
  @autoreleasepool {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0.0, 0.0, 320.0, 200.0)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    MOUITestFirstResponderEditView *view =
        [[MOUITestFirstResponderEditView alloc] initWithFrame:window.contentView.bounds];
    window.contentView = view;
    [view release];

    BOOL passed = [window makeFirstResponder:view];
    for (int32_t action = MOUI_MACOS_EDIT_ACTION_COPY;
         action <= MOUI_MACOS_EDIT_ACTION_SELECT_ALL; action++) {
      [view resetHandledAction];
      passed = passed && moui_macos_dispatch_edit_action_to_window(window, action) &&
               view.handledAction == action;
    }

    window.contentView = nil;
    [window release];
    return passed ? 1 : 0;
  }
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_application_menu_key_equivalent_test(void) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    NSMenu *previousMainMenu = [NSApp.mainMenu retain];
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    NSMenuItem *editTopLevelItem =
        [[NSMenuItem alloc] initWithTitle:@"Edit" action:NULL keyEquivalent:@""];
    editTopLevelItem.submenu = editMenu;
    [mainMenu addItem:editTopLevelItem];
    [editTopLevelItem release];
    [editMenu release];

    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0.0, 0.0, 320.0, 200.0)
                  styleMask:NSWindowStyleMaskBorderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    MOUITestFirstResponderEditView *view =
        [[MOUITestFirstResponderEditView alloc] initWithFrame:window.contentView.bounds];
    window.contentView = view;
    [view release];
    BOOL passed = [window makeFirstResponder:view];

    MOUITestEditShortcutTarget *target = [[MOUITestEditShortcutTarget alloc] init];
    target.window = window;
    static const int32_t actions[] = {
        MOUI_MACOS_EDIT_ACTION_COPY,
        MOUI_MACOS_EDIT_ACTION_CUT,
        MOUI_MACOS_EDIT_ACTION_PASTE,
        MOUI_MACOS_EDIT_ACTION_UNDO,
        MOUI_MACOS_EDIT_ACTION_REDO,
        MOUI_MACOS_EDIT_ACTION_SELECT_ALL,
    };
    static NSString *const titles[] = {
        @"Copy", @"Cut", @"Paste", @"Undo", @"Redo", @"Select All",
    };
    static NSString *const keys[] = { @"c", @"x", @"v", @"z", @"z", @"a" };
    static const NSEventModifierFlags menuModifiers[] = {
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand | NSEventModifierFlagShift,
        NSEventModifierFlagCommand,
    };
    static const NSEventModifierFlags eventModifiers[] = {
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand,
        NSEventModifierFlagCommand | NSEventModifierFlagShift,
        NSEventModifierFlagCommand,
    };
    static const unsigned short keyCodes[] = { 8, 7, 9, 6, 6, 0 };
    const NSUInteger shortcutCount = sizeof(actions) / sizeof(actions[0]);
    for (NSUInteger index = 0; index < shortcutCount; index++) {
      NSMenuItem *item = [[NSMenuItem alloc]
          initWithTitle:titles[index]
                 action:@selector(dispatchEditShortcut:)
          keyEquivalent:keys[index]];
      item.keyEquivalentModifierMask = menuModifiers[index];
      item.tag = actions[index];
      item.target = target;
      [editMenu addItem:item];
      [item release];
    }

    [NSApp setMainMenu:mainMenu];
    passed = passed &&
             moui_macos_install_application_menu_key_equivalent_monitor() != 0;
    int32_t failedShortcuts = 0;
    for (NSUInteger index = 0; index < shortcutCount; index++) {
      [view resetHandledAction];
      NSUInteger monitorHits = g_moui_application_menu_key_equivalent_monitor_hits;
      NSString *characters =
          (eventModifiers[index] & NSEventModifierFlagShift) != 0
              ? [keys[index] uppercaseString]
              : keys[index];
      NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                        location:NSZeroPoint
                                   modifierFlags:eventModifiers[index]
                                       timestamp:0.0
                                    windowNumber:window.windowNumber
                                      context:nil
                                      characters:characters
                     charactersIgnoringModifiers:[keys[index] lowercaseString]
                                       isARepeat:NO
                                         keyCode:keyCodes[index]];
      if (event == nil) {
        failedShortcuts |= (int32_t)(1U << index);
      } else {
        [NSApp sendEvent:event];
        if (view.handledAction != actions[index] ||
            g_moui_application_menu_key_equivalent_monitor_hits <= monitorHits) {
          failedShortcuts |= (int32_t)(1U << index);
        }
      }
    }

    [target release];
    [NSApp setMainMenu:previousMainMenu];
    [previousMainMenu release];
    [mainMenu release];
    window.contentView = nil;
    [window release];
    return passed && failedShortcuts == 0 ? 1 : 0;
  }
}
