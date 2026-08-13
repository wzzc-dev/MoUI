#import <AppKit/AppKit.h>
#import <moonbit.h>
#import <objc/runtime.h>
#import <stdint.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

@class MouiMacosAccessibilityBridge;

@interface MouiMacosAccessibilityElement : NSAccessibilityElement
@property(nonatomic, assign) MouiMacosAccessibilityBridge *mouiBridge;
@property(nonatomic, copy) NSString *mouiNodeID;
@property(nonatomic, copy) NSString *mouiGeneration;
@property(nonatomic, copy) NSDictionary *mouiState;
@property(nonatomic, assign) id mouiParent;
@end

@interface MouiMacosAccessibilityBridge : NSObject
@property(nonatomic, assign) NSView *view;
@property(nonatomic, assign) Class originalViewClass;
@property(nonatomic, assign) Class accessibilityViewClass;
@property(nonatomic, retain) NSMutableDictionary<NSString *, MouiMacosAccessibilityElement *> *elements;
@property(nonatomic, retain) NSMutableArray<NSDictionary *> *actions;
@property(nonatomic, copy) NSString *rootID;
@property(nonatomic, copy) NSString *focusedID;
@property(nonatomic, copy) NSString *semanticFocusedID;
- (instancetype)initWithView:(NSView *)view;
- (void)installViewAdapter;
- (BOOL)applyPayload:(NSDictionary *)payload;
- (void)enqueueNode:(MouiMacosAccessibilityElement *)element
               kind:(NSString *)kind
              value:(NSString *)value;
- (NSDictionary *)takeAction;
- (void)dispose;
@end

static const void *MouiMacosAccessibilityBridgeKey = &MouiMacosAccessibilityBridgeKey;

static MouiMacosAccessibilityBridge *moui_ax_bridge_for_view(NSView *view) {
  return view != nil
      ? objc_getAssociatedObject(view, MouiMacosAccessibilityBridgeKey)
      : nil;
}

static NSArray *moui_ax_view_children(NSView *view, SEL selector) {
  (void)selector;
  MouiMacosAccessibilityBridge *bridge = moui_ax_bridge_for_view(view);
  MouiMacosAccessibilityElement *root = bridge.rootID != nil
      ? bridge.elements[bridge.rootID]
      : nil;
  return root != nil ? @[root] : @[];
}

static NSArray<id<NSAccessibilityElement>> *moui_ax_view_navigation_children(
    NSView *view, SEL selector) {
  return (NSArray<id<NSAccessibilityElement>> *)moui_ax_view_children(view, selector);
}

static id moui_ax_view_focused_element(NSView *view, SEL selector) {
  (void)selector;
  MouiMacosAccessibilityBridge *bridge = moui_ax_bridge_for_view(view);
  NSString *focusedID = bridge.semanticFocusedID ?: bridge.focusedID;
  return focusedID != nil ? bridge.elements[focusedID] : nil;
}

static id moui_ax_deepest_element_at_point(
    MouiMacosAccessibilityElement *element, NSPoint point) {
  if (element == nil || !NSPointInRect(point, element.accessibilityFrame)) return nil;
  NSArray *children = element.accessibilityChildren;
  for (NSInteger index = (NSInteger)children.count - 1; index >= 0; index--) {
    id hit = moui_ax_deepest_element_at_point(children[(NSUInteger)index], point);
    if (hit != nil) return hit;
  }
  return element;
}

static id moui_ax_view_hit_test(NSView *view, SEL selector, NSPoint point) {
  (void)selector;
  NSArray *children = moui_ax_view_children(view, @selector(accessibilityChildren));
  return children.count > 0
      ? moui_ax_deepest_element_at_point(children[0], point)
      : nil;
}

static Class moui_ax_view_reported_superclass(NSView *view, SEL selector) {
  (void)selector;
  MouiMacosAccessibilityBridge *bridge = moui_ax_bridge_for_view(view);
  return bridge.originalViewClass != Nil
      ? class_getSuperclass(bridge.originalViewClass)
      : class_getSuperclass(object_getClass(view));
}

static Class moui_ax_view_adapter_class(Class baseClass) {
  NSString *name = [NSString stringWithFormat:@"MouiMacosAccessibility_%s_%lx",
      class_getName(baseClass), (unsigned long)(uintptr_t)baseClass];
  Class subclass = NSClassFromString(name);
  if (subclass != Nil) return subclass;

  subclass = objc_allocateClassPair(baseClass, name.UTF8String, 0);
  if (subclass == Nil) return Nil;
  struct {
    SEL selector;
    IMP implementation;
  } methods[] = {
    {@selector(superclass), (IMP)moui_ax_view_reported_superclass},
    {@selector(accessibilityChildren), (IMP)moui_ax_view_children},
    {@selector(accessibilityChildrenInNavigationOrder), (IMP)moui_ax_view_navigation_children},
    {@selector(accessibilityFocusedUIElement), (IMP)moui_ax_view_focused_element},
    {@selector(accessibilityHitTest:), (IMP)moui_ax_view_hit_test},
  };
  for (NSUInteger index = 0; index < sizeof(methods) / sizeof(methods[0]); index++) {
    Method method = class_getInstanceMethod(baseClass, methods[index].selector);
    if (method == NULL || !class_addMethod(subclass, methods[index].selector,
                                           methods[index].implementation,
                                           method_getTypeEncoding(method))) {
      objc_disposeClassPair(subclass);
      return Nil;
    }
  }
  objc_registerClassPair(subclass);
  return subclass;
}

static BOOL moui_ax_evidence_enabled(void) {
  const char *value = getenv("MOUI_ACCESSIBILITY_EVIDENCE");
  return value != NULL && strcmp(value, "1") == 0;
}

static void moui_ax_evidence_log(NSString *message) {
  if (!moui_ax_evidence_enabled() || message.length == 0) return;
  fprintf(stderr, "moui-a11y %s\n", [message UTF8String]);
  fflush(stderr);
}

static NSString *moui_ax_string(id value) {
  return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSDictionary *moui_ax_dictionary(id value) {
  return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

static NSArray *moui_ax_array(id value) {
  return [value isKindOfClass:[NSArray class]] ? value : @[];
}

static BOOL moui_ax_bool(NSDictionary *object, NSString *key) {
  id value = object[key];
  return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

static NSInteger moui_ax_integer(id value, NSInteger fallback) {
  return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : fallback;
}

static NSNumber *moui_ax_number_or_nil(id value) {
  return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

static NSString *moui_ax_role(NSDictionary *node) {
  NSString *role = moui_ax_string(node[@"role"]);
  if ([role isEqualToString:@"button"] || [role isEqualToString:@"tab"]) return NSAccessibilityButtonRole;
  if ([role isEqualToString:@"checkbox"] || [role isEqualToString:@"switch"]) return NSAccessibilityCheckBoxRole;
  if ([role isEqualToString:@"radio"]) return NSAccessibilityRadioButtonRole;
  if ([role isEqualToString:@"slider"]) return NSAccessibilitySliderRole;
  if ([role isEqualToString:@"progress"]) return NSAccessibilityProgressIndicatorRole;
  if ([role isEqualToString:@"text_field"]) {
    NSDictionary *state = moui_ax_dictionary(node[@"state"]);
    return moui_ax_bool(state, @"multiline") ? NSAccessibilityTextAreaRole : NSAccessibilityTextFieldRole;
  }
  if ([role isEqualToString:@"text"] || [role isEqualToString:@"heading"] ||
      [role isEqualToString:@"status"] || [role isEqualToString:@"alert"]) return NSAccessibilityStaticTextRole;
  if ([role isEqualToString:@"link"]) return NSAccessibilityLinkRole;
  if ([role isEqualToString:@"image"]) return NSAccessibilityImageRole;
  if ([role isEqualToString:@"list"]) return NSAccessibilityListRole;
  if ([role isEqualToString:@"list_item"] || [role isEqualToString:@"row"]) return NSAccessibilityRowRole;
  if ([role isEqualToString:@"grid"]) return NSAccessibilityGridRole;
  if ([role isEqualToString:@"table"]) return NSAccessibilityTableRole;
  if ([role isEqualToString:@"cell"]) return NSAccessibilityCellRole;
  if ([role isEqualToString:@"tree"]) return NSAccessibilityOutlineRole;
  if ([role isEqualToString:@"tree_item"]) return NSAccessibilityRowRole;
  if ([role isEqualToString:@"scroll_view"]) return NSAccessibilityScrollAreaRole;
  if ([role isEqualToString:@"menu"]) return NSAccessibilityMenuRole;
  if ([role isEqualToString:@"combo_box"]) return NSAccessibilityComboBoxRole;
  if ([role isEqualToString:@"option"]) return NSAccessibilityMenuItemRole;
  if ([role isEqualToString:@"separator"]) return NSAccessibilitySplitterRole;
  if ([role isEqualToString:@"web_view"]) return NSAccessibilityGroupRole;
  return NSAccessibilityGroupRole;
}

static NSAccessibilitySubrole moui_ax_subrole(NSDictionary *node) {
  NSString *role = moui_ax_string(node[@"role"]);
  NSDictionary *state = moui_ax_dictionary(node[@"state"]);
  if ([role isEqualToString:@"dialog"]) return NSAccessibilityDialogSubrole;
  if ([role isEqualToString:@"switch"]) return NSAccessibilitySwitchSubrole;
  if ([role isEqualToString:@"tab"]) return NSAccessibilityTabButtonSubrole;
  if ([role isEqualToString:@"text_field"] && moui_ax_bool(state, @"password")) {
    return NSAccessibilitySecureTextFieldSubrole;
  }
  if ([role isEqualToString:@"tree_item"]) return NSAccessibilityOutlineRowSubrole;
  if ([role isEqualToString:@"row"]) return NSAccessibilityTableRowSubrole;
  return nil;
}

static BOOL moui_ax_has_action(NSDictionary *node, NSString *kind) {
  return [moui_ax_array(node[@"actions"]) containsObject:kind];
}

static NSRect moui_ax_screen_frame(NSView *view, NSDictionary *node) {
  NSDictionary *frame = moui_ax_dictionary(node[@"frame"]);
  NSDictionary *origin = moui_ax_dictionary(frame[@"origin"]);
  NSDictionary *size = moui_ax_dictionary(frame[@"size"]);
  CGFloat x = [origin[@"x"] doubleValue];
  CGFloat y = [origin[@"y"] doubleValue];
  CGFloat width = MAX(0.0, [size[@"width"] doubleValue]);
  CGFloat height = MAX(0.0, [size[@"height"] doubleValue]);
  CGFloat localY = NSHeight(view.bounds) - y - height;
  return NSAccessibilityFrameInView(view, NSMakeRect(x, localY, width, height));
}

@implementation MouiMacosAccessibilityElement

- (void)dealloc {
  [_mouiNodeID release];
  [_mouiGeneration release];
  [_mouiState release];
  [super dealloc];
}

- (BOOL)isAccessibilityElement { return YES; }
- (NSString *)accessibilityRole { return moui_ax_role(self.mouiState); }
- (NSAccessibilitySubrole)accessibilitySubrole { return moui_ax_subrole(self.mouiState); }
- (NSString *)accessibilityIdentifier {
  NSString *semanticID = moui_ax_string(self.mouiState[@"semantic_id"]);
  return semanticID.length > 0 ? semanticID : [@"moui.ax." stringByAppendingString:self.mouiNodeID ?: @""];
}
- (NSString *)accessibilityLabel { return moui_ax_string(self.mouiState[@"label"]); }
- (NSString *)accessibilityHelp { return moui_ax_string(self.mouiState[@"description"]); }
- (id)accessibilityParent { return self.mouiParent; }
- (id)accessibilityWindow { return [self.mouiBridge.view accessibilityParent]; }
- (id)accessibilityTopLevelUIElement { return [self.mouiBridge.view accessibilityParent]; }
- (NSRect)accessibilityFrame { return moui_ax_screen_frame(self.mouiBridge.view, self.mouiState); }
- (BOOL)isAccessibilityEnabled { return !moui_ax_bool(moui_ax_dictionary(self.mouiState[@"state"]), @"disabled"); }
- (BOOL)isAccessibilityFocused { return moui_ax_bool(moui_ax_dictionary(self.mouiState[@"state"]), @"focused"); }
- (void)setAccessibilityFocused:(BOOL)focused {
  if (focused && moui_ax_has_action(self.mouiState, @"focus")) {
    [self.mouiBridge enqueueNode:self kind:@"focus" value:@""];
  }
}
- (BOOL)isAccessibilitySelected { return moui_ax_bool(moui_ax_dictionary(self.mouiState[@"state"]), @"selected"); }
- (BOOL)isAccessibilityExpanded { return moui_ax_bool(moui_ax_dictionary(self.mouiState[@"state"]), @"expanded"); }
- (void)setAccessibilityExpanded:(BOOL)expanded {
  NSString *kind = expanded ? @"expand" : @"collapse";
  if (moui_ax_has_action(self.mouiState, kind)) {
    [self.mouiBridge enqueueNode:self kind:kind value:@""];
  }
}
- (BOOL)isAccessibilityRequired { return moui_ax_bool(moui_ax_dictionary(self.mouiState[@"state"]), @"required"); }
- (BOOL)isAccessibilityModal { return moui_ax_bool(moui_ax_dictionary(self.mouiState[@"state"]), @"modal"); }
- (BOOL)isAccessibilityProtectedContent { return moui_ax_bool(moui_ax_dictionary(self.mouiState[@"state"]), @"password"); }

- (id)accessibilityValue {
  NSDictionary *numeric = moui_ax_dictionary(self.mouiState[@"numeric"]);
  NSNumber *current = moui_ax_number_or_nil(numeric[@"current"]);
  if (current != nil) return current;
  NSString *checked = moui_ax_string(moui_ax_dictionary(self.mouiState[@"state"])[@"checked"]);
  if ([checked isEqualToString:@"checked"]) return @1;
  if ([checked isEqualToString:@"mixed"]) return @2;
  if ([checked isEqualToString:@"unchecked"]) return @0;
  return moui_ax_string(self.mouiState[@"value"]);
}
- (void)setAccessibilityValue:(id)value {
  if (moui_ax_has_action(self.mouiState, @"set_numeric_value") && [value respondsToSelector:@selector(stringValue)]) {
    [self.mouiBridge enqueueNode:self kind:@"set_numeric_value" value:[value stringValue]];
  } else if (moui_ax_has_action(self.mouiState, @"set_text") && [value isKindOfClass:[NSString class]]) {
    [self.mouiBridge enqueueNode:self kind:@"set_text" value:value];
  }
}
- (NSString *)accessibilityValueDescription {
  NSDictionary *numeric = moui_ax_dictionary(self.mouiState[@"numeric"]);
  NSString *text = moui_ax_string(numeric[@"value_text"]);
  return text.length > 0 ? text : moui_ax_string(self.mouiState[@"value"]);
}
- (id)accessibilityMinValue { return moui_ax_number_or_nil(moui_ax_dictionary(self.mouiState[@"numeric"])[@"min"]); }
- (id)accessibilityMaxValue { return moui_ax_number_or_nil(moui_ax_dictionary(self.mouiState[@"numeric"])[@"max"]); }

- (NSInteger)accessibilityNumberOfCharacters {
  return (NSInteger)[moui_ax_string(self.mouiState[@"value"]) length];
}
- (NSRange)accessibilitySelectedTextRange {
  NSDictionary *selection = moui_ax_dictionary(moui_ax_dictionary(self.mouiState[@"text"])[@"selection"]);
  NSInteger start = moui_ax_integer(selection[@"start"], 0);
  NSInteger end = moui_ax_integer(selection[@"end"], start);
  if (end < start) { NSInteger temporary = start; start = end; end = temporary; }
  return NSMakeRange((NSUInteger)MAX(0, start), (NSUInteger)MAX(0, end - start));
}
- (void)setAccessibilitySelectedTextRange:(NSRange)range {
  if (!moui_ax_has_action(self.mouiState, @"set_selection")) return;
  NSString *value = [NSString stringWithFormat:@"%lu,%lu", (unsigned long)range.location,
                     (unsigned long)NSMaxRange(range)];
  [self.mouiBridge enqueueNode:self kind:@"set_selection" value:value];
}
- (NSString *)accessibilitySelectedText {
  NSString *value = moui_ax_string(self.mouiState[@"value"]);
  NSRange range = self.accessibilitySelectedTextRange;
  return NSMaxRange(range) <= value.length ? [value substringWithRange:range] : @"";
}
- (NSString *)accessibilityStringForRange:(NSRange)range {
  NSString *value = moui_ax_string(self.mouiState[@"value"]);
  return NSMaxRange(range) <= value.length ? [value substringWithRange:range] : nil;
}

- (NSInteger)accessibilityRowCount { return moui_ax_integer(moui_ax_dictionary(self.mouiState[@"collection"])[@"row_count"], 0); }
- (NSInteger)accessibilityColumnCount { return moui_ax_integer(moui_ax_dictionary(self.mouiState[@"collection"])[@"column_count"], 0); }
- (NSInteger)accessibilityIndex {
  NSDictionary *collection = moui_ax_dictionary(self.mouiState[@"collection"]);
  id row = collection[@"row_index"];
  return row != nil && row != [NSNull null] ? moui_ax_integer(row, 0) : moui_ax_integer(collection[@"set_position"], 1) - 1;
}
- (NSRange)accessibilityRowIndexRange {
  NSDictionary *collection = moui_ax_dictionary(self.mouiState[@"collection"]);
  return NSMakeRange((NSUInteger)MAX(0, moui_ax_integer(collection[@"row_index"], 0)),
                     (NSUInteger)MAX(1, moui_ax_integer(collection[@"row_span"], 1)));
}
- (NSRange)accessibilityColumnIndexRange {
  NSDictionary *collection = moui_ax_dictionary(self.mouiState[@"collection"]);
  return NSMakeRange((NSUInteger)MAX(0, moui_ax_integer(collection[@"column_index"], 0)),
                     (NSUInteger)MAX(1, moui_ax_integer(collection[@"column_span"], 1)));
}

- (NSArray *)accessibilityChildren {
  NSMutableArray *children = [NSMutableArray array];
  for (NSString *nodeID in moui_ax_array(self.mouiState[@"children"])) {
    MouiMacosAccessibilityElement *child = self.mouiBridge.elements[nodeID];
    if (child != nil) [children addObject:child];
  }
  return children;
}
- (NSArray *)accessibilityChildrenInNavigationOrder { return self.accessibilityChildren; }
- (id)accessibilityTitleUIElement {
  NSString *nodeID = [moui_ax_array(moui_ax_dictionary(self.mouiState[@"relations"])[@"labelled_by"]) firstObject];
  return nodeID != nil ? self.mouiBridge.elements[nodeID] : nil;
}
- (NSArray *)accessibilityLinkedUIElements {
  NSMutableArray *elements = [NSMutableArray array];
  NSDictionary *relations = moui_ax_dictionary(self.mouiState[@"relations"]);
  for (NSString *key in @[@"described_by", @"controls", @"error_message", @"active_descendant"]) {
    for (NSString *nodeID in moui_ax_array(relations[key])) {
      id element = self.mouiBridge.elements[nodeID];
      if (element != nil && ![elements containsObject:element]) [elements addObject:element];
    }
  }
  return elements;
}

- (NSArray<NSAccessibilityCustomAction *> *)accessibilityCustomActions {
  NSMutableArray<NSAccessibilityCustomAction *> *actions = [NSMutableArray array];
  for (NSString *direction in @[@"forward", @"backward", @"up", @"down", @"left", @"right"]) {
    if (!moui_ax_has_action(self.mouiState, @"scroll")) break;
    NSString *name = [@"Scroll " stringByAppendingString:direction];
    NSAccessibilityCustomAction *action = [[NSAccessibilityCustomAction alloc]
        initWithName:name handler:^BOOL{
          [self.mouiBridge enqueueNode:self kind:@"scroll" value:direction];
          return YES;
        }];
    [actions addObject:action];
    [action release];
  }
  return actions;
}

- (BOOL)accessibilityPerformPress {
  NSString *kind = moui_ax_has_action(self.mouiState, @"activate") ? @"activate" :
      (moui_ax_has_action(self.mouiState, @"select") ? @"select" : nil);
  if (kind == nil) return NO;
  [self.mouiBridge enqueueNode:self kind:kind value:@""];
  return YES;
}
- (BOOL)accessibilityPerformConfirm {
  if (!moui_ax_has_action(self.mouiState, @"submit")) return NO;
  [self.mouiBridge enqueueNode:self kind:@"submit" value:@""];
  return YES;
}
- (BOOL)accessibilityPerformIncrement {
  if (!moui_ax_has_action(self.mouiState, @"increment")) return NO;
  [self.mouiBridge enqueueNode:self kind:@"increment" value:@""];
  return YES;
}
- (BOOL)accessibilityPerformDecrement {
  if (!moui_ax_has_action(self.mouiState, @"decrement")) return NO;
  [self.mouiBridge enqueueNode:self kind:@"decrement" value:@""];
  return YES;
}
- (BOOL)accessibilityPerformCancel {
  if (!moui_ax_has_action(self.mouiState, @"dismiss")) return NO;
  [self.mouiBridge enqueueNode:self kind:@"dismiss" value:@""];
  return YES;
}
- (BOOL)accessibilityPerformShowMenu {
  if (!moui_ax_has_action(self.mouiState, @"show_menu")) return NO;
  [self.mouiBridge enqueueNode:self kind:@"show_menu" value:@""];
  return YES;
}
- (BOOL)isAccessibilitySelectorAllowed:(SEL)selector {
  if (selector == @selector(accessibilityPerformPress))
    return moui_ax_has_action(self.mouiState, @"activate") || moui_ax_has_action(self.mouiState, @"select");
  if (selector == @selector(accessibilityPerformConfirm)) return moui_ax_has_action(self.mouiState, @"submit");
  if (selector == @selector(accessibilityPerformIncrement)) return moui_ax_has_action(self.mouiState, @"increment");
  if (selector == @selector(accessibilityPerformDecrement)) return moui_ax_has_action(self.mouiState, @"decrement");
  if (selector == @selector(accessibilityPerformCancel)) return moui_ax_has_action(self.mouiState, @"dismiss");
  if (selector == @selector(accessibilityPerformShowMenu)) return moui_ax_has_action(self.mouiState, @"show_menu");
  if (selector == @selector(setAccessibilityValue:))
    return moui_ax_has_action(self.mouiState, @"set_numeric_value") || moui_ax_has_action(self.mouiState, @"set_text");
  if (selector == @selector(setAccessibilitySelectedTextRange:)) return moui_ax_has_action(self.mouiState, @"set_selection");
  if (selector == @selector(setAccessibilityExpanded:))
    return moui_ax_has_action(self.mouiState, @"expand") || moui_ax_has_action(self.mouiState, @"collapse");
  if (selector == @selector(setAccessibilityFocused:)) return moui_ax_has_action(self.mouiState, @"focus");
  return [super isAccessibilitySelectorAllowed:selector];
}

@end

@implementation MouiMacosAccessibilityBridge

- (instancetype)initWithView:(NSView *)view {
  self = [super init];
  if (self != nil) {
    _view = view;
    _originalViewClass = object_getClass(view);
    _elements = [[NSMutableDictionary alloc] init];
    _actions = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)installViewAdapter {
  if (self.view == nil || self.originalViewClass == Nil) return;
  Class subclass = moui_ax_view_adapter_class(self.originalViewClass);
  if (subclass == Nil) return;
  self.accessibilityViewClass = subclass;
  object_setClass(self.view, subclass);
}

- (void)dealloc {
  [_elements release];
  [_actions release];
  [_rootID release];
  [_focusedID release];
  [_semanticFocusedID release];
  [super dealloc];
}

- (void)enqueueNode:(MouiMacosAccessibilityElement *)element
               kind:(NSString *)kind
              value:(NSString *)value {
  if (element == nil || element.mouiNodeID.length == 0 || element.mouiGeneration.length == 0) return;
  [self.actions addObject:@{
    @"node_id": element.mouiNodeID,
    @"generation": element.mouiGeneration,
    @"kind": kind ?: @"",
    @"value": value ?: @""
  }];
  moui_ax_evidence_log([NSString stringWithFormat:
      @"action-request id=%@ node=%@ generation=%@ kind=%@ value=%@",
      element.accessibilityIdentifier, element.mouiNodeID, element.mouiGeneration,
      kind ?: @"", value ?: @""]);
  [self.view.window.contentView setNeedsDisplay:YES];
}

- (NSDictionary *)takeAction {
  if (self.actions.count == 0) return nil;
  NSDictionary *action = [[self.actions objectAtIndex:0] retain];
  [self.actions removeObjectAtIndex:0];
  return [action autorelease];
}

- (BOOL)applyPayload:(NSDictionary *)payload {
  NSString *kind = moui_ax_string(payload[@"kind"]);
  NSString *generation = moui_ax_string(payload[@"generation"]);
  NSArray *nodes = moui_ax_array(payload[@"nodes"]);
  NSArray *removed = moui_ax_array(payload[@"removed"]);
  NSString *previousFocused = [[self.focusedID copy] autorelease];
  moui_ax_evidence_log([NSString stringWithFormat:
      @"commit kind=%@ generation=%@ nodes=%lu removed=%lu announcements=%lu",
      kind, generation, (unsigned long)nodes.count, (unsigned long)removed.count,
      (unsigned long)moui_ax_array(payload[@"announcements"]).count]);

  if ([kind isEqualToString:@"full"]) {
    NSMutableSet *incoming = [NSMutableSet set];
    for (NSDictionary *node in nodes) [incoming addObject:moui_ax_string(node[@"node_id"])];
    for (NSString *nodeID in [self.elements allKeys]) {
      if (![incoming containsObject:nodeID]) {
        NSAccessibilityPostNotification(self.elements[nodeID], NSAccessibilityUIElementDestroyedNotification);
        [self.elements removeObjectForKey:nodeID];
      }
    }
  }

  for (NSString *nodeID in removed) {
    MouiMacosAccessibilityElement *element = self.elements[nodeID];
    if (element != nil) {
      NSAccessibilityPostNotification(element, NSAccessibilityUIElementDestroyedNotification);
      [self.elements removeObjectForKey:nodeID];
    }
  }

  NSMutableArray *changedElements = [NSMutableArray array];
  for (NSDictionary *node in nodes) {
    NSString *nodeID = moui_ax_string(node[@"node_id"]);
    if (nodeID.length == 0) continue;
    MouiMacosAccessibilityElement *element = self.elements[nodeID];
    BOOL created = element == nil;
    NSDictionary *previous = [element.mouiState copy];
    if (created) {
      element = [[MouiMacosAccessibilityElement alloc] init];
      element.mouiBridge = self;
      element.mouiNodeID = nodeID;
      self.elements[nodeID] = element;
      [element release];
    }
    element.mouiGeneration = generation;
    element.mouiState = node;
    [changedElements addObject:element];
    if (created) {
      NSAccessibilityPostNotification(element, NSAccessibilityCreatedNotification);
    } else {
      if (![previous[@"value"] isEqual:node[@"value"]] || ![previous[@"numeric"] isEqual:node[@"numeric"]] ||
          ![moui_ax_dictionary(previous[@"state"])[@"checked"] isEqual:moui_ax_dictionary(node[@"state"])[@"checked"]]) {
        NSAccessibilityPostNotification(element, NSAccessibilityValueChangedNotification);
      }
      if (![previous[@"frame"] isEqual:node[@"frame"]]) {
        NSAccessibilityPostNotification(element, NSAccessibilityMovedNotification);
        NSAccessibilityPostNotification(element, NSAccessibilityResizedNotification);
      }
      if (![previous[@"children"] isEqual:node[@"children"]]) {
        NSAccessibilityPostNotification(element, NSAccessibilityLayoutChangedNotification);
      }
      if (![moui_ax_dictionary(previous[@"text"])[@"selection"] isEqual:moui_ax_dictionary(node[@"text"])[@"selection"]]) {
        NSAccessibilityPostNotification(element, NSAccessibilitySelectedTextChangedNotification);
      }
    }
    [previous release];
  }

  for (MouiMacosAccessibilityElement *element in self.elements.allValues) element.mouiParent = nil;
  for (MouiMacosAccessibilityElement *element in self.elements.allValues) {
    for (NSString *childID in moui_ax_array(element.mouiState[@"children"])) {
      MouiMacosAccessibilityElement *child = self.elements[childID];
      if (child != nil) child.mouiParent = element;
    }
  }

  id rootValue = payload[@"root"];
  self.rootID = [rootValue isKindOfClass:[NSString class]] ? rootValue : nil;
  id focusedValue = payload[@"focused"];
  self.focusedID = [focusedValue isKindOfClass:[NSString class]] ? focusedValue : nil;
  id semanticFocusedValue = payload[@"semantic_focused"];
  self.semanticFocusedID = [semanticFocusedValue isKindOfClass:[NSString class]] ? semanticFocusedValue : nil;
  MouiMacosAccessibilityElement *root = self.rootID != nil ? self.elements[self.rootID] : nil;
  root.mouiParent = [self.view accessibilityParent];
  [self.view setAccessibilityElement:NO];
  if (changedElements.count > 0 || removed.count > 0) {
    NSAccessibilityPostNotificationWithUserInfo(
        self.view, NSAccessibilityLayoutChangedNotification,
        @{NSAccessibilityUIElementsKey: changedElements});
  }
  if ((previousFocused == nil && self.focusedID != nil) ||
      (previousFocused != nil && ![previousFocused isEqualToString:self.focusedID])) {
    MouiMacosAccessibilityElement *focused = self.elements[self.focusedID];
    if (focused != nil) NSAccessibilityPostNotification(focused, NSAccessibilityFocusedUIElementChangedNotification);
  }

  for (NSDictionary *announcement in moui_ax_array(payload[@"announcements"])) {
    NSString *text = moui_ax_string(announcement[@"text"]);
    if (text.length == 0) continue;
    NSString *live = moui_ax_string(announcement[@"live"]);
    moui_ax_evidence_log([NSString stringWithFormat:
        @"announcement generation=%@ live=%@ atomic=%@ text=%@",
        moui_ax_string(announcement[@"generation"]), live,
        [announcement[@"atomic"] boolValue] ? @"true" : @"false", text]);
    NSNumber *priority = [live isEqualToString:@"assertive"] ? @(NSAccessibilityPriorityHigh) : @(NSAccessibilityPriorityMedium);
    NSAccessibilityPostNotificationWithUserInfo(
        NSApp, NSAccessibilityAnnouncementRequestedNotification,
        @{NSAccessibilityAnnouncementKey: text, NSAccessibilityPriorityKey: priority});
  }
  return YES;
}

- (void)dispose {
  for (MouiMacosAccessibilityElement *element in self.elements.allValues) {
    NSAccessibilityPostNotification(element, NSAccessibilityUIElementDestroyedNotification);
    element.mouiBridge = nil;
    element.mouiParent = nil;
  }
  [self.view setAccessibilityChildren:@[]];
  [self.view setAccessibilityChildrenInNavigationOrder:@[]];
  [self.elements removeAllObjects];
  [self.actions removeAllObjects];
  self.rootID = nil;
  self.focusedID = nil;
  self.semanticFocusedID = nil;
  if (self.view != nil && self.originalViewClass != Nil &&
      object_getClass(self.view) == self.accessibilityViewClass) {
    object_setClass(self.view, self.originalViewClass);
  }
  self.originalViewClass = Nil;
  self.accessibilityViewClass = Nil;
  self.view = nil;
}

@end

static NSString *moui_macos_ax_string_from_bytes(moonbit_bytes_t bytes) {
  int32_t length = (int32_t)Moonbit_array_length(bytes);
  if (length <= 0) return @"";
  NSString *string = [[NSString alloc] initWithBytes:(const void *)bytes
                                               length:(NSUInteger)length
                                             encoding:NSUTF8StringEncoding];
  return [string autorelease] ?: @"";
}

static moonbit_bytes_t moui_macos_ax_bytes_from_data(NSData *data) {
  if (data == nil || data.length == 0 || data.length > INT32_MAX) return moonbit_make_bytes(0, 0);
  moonbit_bytes_t bytes = moonbit_make_bytes((int32_t)data.length, 0);
  memcpy(bytes, data.bytes, data.length);
  return bytes;
}

static NSView *moui_macos_ax_view(uint64_t rawView) {
  if (rawView == 0 || ![NSThread isMainThread]) return nil;
  id object = (__bridge id)(void *)(uintptr_t)rawView;
  return [object isKindOfClass:[NSView class]] ? object : nil;
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_accessibility_sync(uint64_t rawView, moonbit_bytes_t payloadBytes) {
  NSView *view = moui_macos_ax_view(rawView);
  if (view == nil) return 1;
  NSData *data = [moui_macos_ax_string_from_bytes(payloadBytes) dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  id value = data != nil ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
  if (![value isKindOfClass:[NSDictionary class]]) return 2;
  MouiMacosAccessibilityBridge *bridge = objc_getAssociatedObject(view, MouiMacosAccessibilityBridgeKey);
  if (bridge == nil) {
    bridge = [[MouiMacosAccessibilityBridge alloc] initWithView:view];
    objc_setAssociatedObject(view, MouiMacosAccessibilityBridgeKey, bridge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [bridge installViewAdapter];
    [bridge release];
  }
  return [bridge applyPayload:value] ? 0 : 3;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t moui_macos_accessibility_take_action(uint64_t rawView) {
  NSView *view = moui_macos_ax_view(rawView);
  MouiMacosAccessibilityBridge *bridge = view != nil
      ? objc_getAssociatedObject(view, MouiMacosAccessibilityBridgeKey) : nil;
  NSDictionary *action = [bridge takeAction];
  if (action == nil) return moonbit_make_bytes(0, 0);
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:action options:0 error:&error];
  return moui_macos_ax_bytes_from_data(data);
}

MOONBIT_FFI_EXPORT
void moui_macos_accessibility_dispose(uint64_t rawView) {
  NSView *view = moui_macos_ax_view(rawView);
  if (view == nil) return;
  MouiMacosAccessibilityBridge *bridge = objc_getAssociatedObject(view, MouiMacosAccessibilityBridgeKey);
  [bridge dispose];
  objc_setAssociatedObject(view, MouiMacosAccessibilityBridgeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

MOONBIT_FFI_EXPORT
void moui_macos_accessibility_record_evidence(moonbit_bytes_t messageBytes) {
  moui_ax_evidence_log(moui_macos_ax_string_from_bytes(messageBytes));
}

MOONBIT_FFI_EXPORT
int32_t moui_macos_accessibility_view_adapter_test(void) {
  @autoreleasepool {
    NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, 80.0)] autorelease];
    id parent = [NSAccessibilityElement
        accessibilityElementWithRole:NSAccessibilityWindowRole
        frame:NSMakeRect(0.0, 0.0, 100.0, 80.0)
        label:@"Test window"
        parent:nil];
    [view setAccessibilityParent:parent];
    Class originalClass = object_getClass(view);
    MouiMacosAccessibilityBridge *bridge = [[MouiMacosAccessibilityBridge alloc] initWithView:view];
    objc_setAssociatedObject(view, MouiMacosAccessibilityBridgeKey, bridge,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [bridge installViewAdapter];

    NSDictionary *emptyState = @{};
    NSDictionary *rootNode = @{
      @"node_id": @"1",
      @"semantic_id": @"test.root",
      @"role": @"group",
      @"state": emptyState,
      @"actions": @[],
      @"children": @[@"2"],
      @"frame": @{
        @"origin": @{@"x": @0, @"y": @0},
        @"size": @{@"width": @100, @"height": @80},
      },
    };
    NSDictionary *buttonNode = @{
      @"node_id": @"2",
      @"semantic_id": @"test.button",
      @"role": @"button",
      @"label": @"Run",
      @"state": emptyState,
      @"actions": @[@"activate"],
      @"children": @[],
      @"frame": @{
        @"origin": @{@"x": @10, @"y": @10},
        @"size": @{@"width": @40, @"height": @20},
      },
    };
    BOOL applied = [bridge applyPayload:@{
      @"kind": @"full",
      @"generation": @"7",
      @"root": @"1",
      @"focused": @"2",
      @"semantic_focused": [NSNull null],
      @"nodes": @[rootNode, buttonNode],
      @"removed": @[],
      @"announcements": @[],
    }];
    NSArray *children = view.accessibilityChildren;
    NSArray *navigationChildren = view.accessibilityChildrenInNavigationOrder;
    MouiMacosAccessibilityElement *root = children.firstObject;
    MouiMacosAccessibilityElement *button = root.accessibilityChildren.firstObject;
    NSRect buttonFrame = button.accessibilityFrame;
    NSPoint buttonCenter = NSMakePoint(NSMidX(buttonFrame), NSMidY(buttonFrame));
    BOOL passed = applied && object_getClass(view) != originalClass &&
        children.count == 1 && navigationChildren.firstObject == root &&
        root.mouiParent == parent && button.mouiParent == root &&
        view.accessibilityFocusedUIElement == button &&
        [view accessibilityHitTest:buttonCenter] == button;

    [bridge dispose];
    BOOL restored = object_getClass(view) == originalClass;
    objc_setAssociatedObject(view, MouiMacosAccessibilityBridgeKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [bridge release];
    return passed && restored ? 1 : 0;
  }
}
