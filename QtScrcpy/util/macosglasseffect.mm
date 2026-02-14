#include "macosglasseffect.h"

#import <Cocoa/Cocoa.h>
#include <QWidget>
#include <QImage>
#include <QPixmap>
#include <QIcon>
#include <QDebug>

// ============================================================================
// Helper: Get NSWindow from QWidget
// ============================================================================

static NSWindow* windowFromWidget(QWidget *widget)
{
    if (!widget) return nil;
    WId wid = widget->winId();
    if (!wid) return nil;
    NSView *nsView = (__bridge NSView *)reinterpret_cast<void *>(wid);
    return nsView ? [nsView window] : nil;
}

// ============================================================================
// Legacy namespace (backward compat)
// ============================================================================

namespace MacOSGlassEffect {

bool applyGlassEffect(QWidget *widget)
{
    NSWindow *nsWindow = windowFromWidget(widget);
    if (!nsWindow) {
        qWarning("MacOSGlassEffect: could not get NSWindow");
        return false;
    }

    nsWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    nsWindow.titlebarAppearsTransparent = YES;
    // Keep window OPAQUE — setOpaque:NO breaks Qt6 Metal rendering
    return true;
}

} // namespace MacOSGlassEffect

// ============================================================================
// NativeToolbarController — ObjC delegate for NSToolbar
// ============================================================================

@interface NativeToolbarController : NSObject <NSToolbarDelegate>
@property (nonatomic, strong) NSToolbar *toolbar;
@property (nonatomic, strong) NSArray<NSString *> *itemIdentifiers;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *symbolMap;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *labelMap;
@property (nonatomic, copy) void (^clickCallback)(NSString *identifier);
@end

@implementation NativeToolbarController

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    Q_UNUSED(toolbar);
    return self.itemIdentifiers;
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    Q_UNUSED(toolbar);
    return self.itemIdentifiers;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag {
    Q_UNUSED(toolbar);
    Q_UNUSED(flag);

    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];

    NSString *label = self.labelMap[itemIdentifier];
    item.label = label ? label : itemIdentifier;
    item.paletteLabel = item.label;
    item.target = self;
    item.action = @selector(toolbarItemClicked:);

    // Set SF Symbol image
    NSString *symbolName = self.symbolMap[itemIdentifier];
    if (symbolName) {
        if (@available(macOS 11.0, *)) {
            NSImage *img = [NSImage imageWithSystemSymbolName:symbolName
                           accessibilityDescription:item.label];
            if (img) {
                item.image = img;
            }
        }
    }

    return item;
}

- (void)toolbarItemClicked:(NSToolbarItem *)sender {
    if (self.clickCallback) {
        self.clickCallback(sender.itemIdentifier);
    }
}

@end

// ============================================================================
// MacOSNative namespace implementation
// ============================================================================

namespace MacOSNative {

// ---------- Window Effects ----------

bool applyUnifiedTitlebar(QWidget *widget)
{
    NSWindow *nsWindow = windowFromWidget(widget);
    if (!nsWindow) {
        qWarning("MacOSNative: could not get NSWindow for unified titlebar");
        return false;
    }

    // Content extends under titlebar — unified look
    nsWindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
    nsWindow.titlebarAppearsTransparent = YES;
    nsWindow.titleVisibility = NSWindowTitleHidden;

    // DO NOT set opaque:NO — breaks Qt6 Metal rendering
    // DO NOT set backgroundColor to clearColor for same reason

    qDebug("MacOSNative: unified titlebar applied");
    return true;
}

bool applyVibrancy(QWidget *widget, int material)
{
    NSWindow *nsWindow = windowFromWidget(widget);
    if (!nsWindow) {
        qWarning("MacOSNative: could not get NSWindow for vibrancy");
        return false;
    }

    NSView *contentView = [nsWindow contentView];
    if (!contentView) {
        qWarning("MacOSNative: no contentView for vibrancy");
        return false;
    }

    // Check if we already added a vibrancy view (by class + identifier)
    for (NSView *subview in contentView.subviews) {
        if ([subview isKindOfClass:[NSVisualEffectView class]] &&
            [subview.identifier isEqualToString:@"QtScrcpyVibrancy"]) {
            return true; // Already applied
        }
    }

    NSVisualEffectView *effectView = [[NSVisualEffectView alloc]
                                       initWithFrame:contentView.bounds];
    effectView.material = (NSVisualEffectMaterial)material;
    effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effectView.state = NSVisualEffectStateActive;
    effectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    effectView.identifier = @"QtScrcpyVibrancy";

    // Insert BEHIND all Qt content
    [contentView addSubview:effectView positioned:NSWindowBelow
           relativeTo:contentView.subviews.firstObject];

    qDebug("MacOSNative: vibrancy applied (material=%d)", material);
    return true;
}

qreal titlebarHeight(QWidget *widget)
{
    NSWindow *nsWindow = windowFromWidget(widget);
    if (!nsWindow) return 28.0; // Safe default

    NSRect contentLayoutRect = nsWindow.contentLayoutRect;
    NSRect contentViewBounds = [[nsWindow contentView] bounds];
    return contentViewBounds.size.height - contentLayoutRect.size.height;
}

bool applyVibrantAppearance(QWidget *widget)
{
    NSWindow *nsWindow = windowFromWidget(widget);
    if (!nsWindow) return false;

    if (isDarkMode()) {
        nsWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    } else {
        nsWindow.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
    }
    return true;
}

// ---------- Theme Detection ----------

bool isDarkMode()
{
    if (@available(macOS 10.14, *)) {
        NSAppearance *appearance = [NSApp effectiveAppearance];
        NSAppearanceName name = [appearance
            bestMatchFromAppearancesWithNames:@[
                NSAppearanceNameAqua,
                NSAppearanceNameDarkAqua
            ]];
        return [name isEqualToString:NSAppearanceNameDarkAqua];
    }
    return false;
}

static id s_themeObserver = nil;

void observeThemeChanges(std::function<void(bool isDark)> callback)
{
    if (s_themeObserver) {
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:s_themeObserver];
        s_themeObserver = nil;
    }

    s_themeObserver = [[NSDistributedNotificationCenter defaultCenter]
        addObserverForName:@"AppleInterfaceThemeChangedNotification"
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *note) {
            Q_UNUSED(note);
            if (callback) {
                callback(isDarkMode());
            }
        }];
}

// ---------- SF Symbols ----------

static QImage nsImageToQImage(NSImage *nsImage)
{
    if (!nsImage) return QImage();

    // Get CGImage representation
    CGImageRef cgImage = [nsImage CGImageForProposedRect:nil context:nil hints:nil];
    if (!cgImage) return QImage();

    size_t w = CGImageGetWidth(cgImage);
    size_t h = CGImageGetHeight(cgImage);

    QImage qImage(static_cast<int>(w), static_cast<int>(h),
                  QImage::Format_ARGB32_Premultiplied);
    qImage.fill(Qt::transparent);

    // Draw CGImage into QImage's buffer
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
        qImage.bits(), w, h, 8, qImage.bytesPerLine(),
        colorSpace,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(colorSpace);

    if (ctx) {
        CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cgImage);
        CGContextRelease(ctx);
    }

    return qImage;
}

QPixmap sfSymbolPixmap(const QString &symbolName, qreal pointSize)
{
    if (@available(macOS 11.0, *)) {
        NSString *name = symbolName.toNSString();

        NSImage *nsImage = [NSImage imageWithSystemSymbolName:name
                           accessibilityDescription:nil];
        if (!nsImage) return QPixmap();

        // Configure size
        NSImageSymbolConfiguration *config =
            [NSImageSymbolConfiguration configurationWithPointSize:pointSize
                                       weight:NSFontWeightRegular];
        nsImage = [nsImage imageWithSymbolConfiguration:config];

        // Render tinted copy using template rendering
        NSSize imgSize = NSMakeSize(pointSize * 1.4, pointSize * 1.4);
        NSImage *tinted = [[NSImage alloc] initWithSize:imgSize];
        [tinted lockFocus];

        [[NSColor labelColor] set];
        NSRect drawRect = NSMakeRect(0, 0, imgSize.width, imgSize.height);
        [nsImage drawInRect:drawRect fromRect:NSZeroRect
              operation:NSCompositingOperationSourceOver fraction:1.0];

        // Apply tint via source-atop compositing
        NSRectFillUsingOperation(drawRect, NSCompositingOperationSourceAtop);

        [tinted unlockFocus];

        QImage qImg = nsImageToQImage(tinted);
        if (qImg.isNull()) return QPixmap();

        return QPixmap::fromImage(qImg);
    }
    return QPixmap();
}

QIcon sfSymbolIcon(const QString &symbolName, qreal pointSize)
{
    QPixmap pm = sfSymbolPixmap(symbolName, pointSize);
    if (pm.isNull()) return QIcon();
    return QIcon(pm);
}

// ---------- Native Toolbar ----------

void* createNativeToolbar(QWidget *window,
                          const QStringList &itemIdentifiers,
                          std::function<void(const QString &identifier)> callback)
{
    NSWindow *nsWindow = windowFromWidget(window);
    if (!nsWindow) {
        qWarning("MacOSNative: could not get NSWindow for toolbar");
        return nullptr;
    }

    NativeToolbarController *controller = [[NativeToolbarController alloc] init];

    // Convert QStringList to NSArray
    NSMutableArray<NSString *> *nsIds = [NSMutableArray arrayWithCapacity:itemIdentifiers.size()];
    for (const QString &id : itemIdentifiers) {
        [nsIds addObject:id.toNSString()];
    }
    controller.itemIdentifiers = nsIds;

    // SF Symbol mapping for known toolbar items
    controller.symbolMap = @{
        @"Home":        @"house",
        @"Back":        @"chevron.left",
        @"AppSwitch":   @"rectangle.on.rectangle",
        @"Power":       @"power",
        @"VolumeUp":    @"speaker.wave.3",
        @"VolumeDown":  @"speaker.wave.1",
        @"Screenshot":  @"camera",
        @"FullScreen":  @"arrow.up.left.and.arrow.down.right",
        @"Menu":        @"square",
        @"Touch":       @"hand.tap",
        @"Clipboard":   @"doc.on.doc",
    };

    controller.labelMap = @{
        @"Home":        @"Home",
        @"Back":        @"Back",
        @"AppSwitch":   @"App Switch",
        @"Power":       @"Power",
        @"VolumeUp":    @"Vol +",
        @"VolumeDown":  @"Vol -",
        @"Screenshot":  @"Screenshot",
        @"FullScreen":  @"Full Screen",
        @"Menu":        @"Menu",
        @"Touch":       @"Touch",
        @"Clipboard":   @"Clipboard",
    };

    // Wrap C++ callback
    controller.clickCallback = ^(NSString *identifier) {
        if (callback) {
            callback(QString::fromNSString(identifier));
        }
    };

    // Create and attach toolbar
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"QtScrcpyVideoToolbar"];
    toolbar.delegate = controller;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    toolbar.allowsUserCustomization = NO;
    controller.toolbar = toolbar;

    [nsWindow setToolbar:toolbar];
    if (@available(macOS 11.0, *)) {
        [nsWindow setToolbarStyle:NSWindowToolbarStyleUnified];
    }

    qDebug("MacOSNative: native toolbar created with %d items",
           (int)itemIdentifiers.size());

    // Retain controller so it survives after this scope (no ARC)
    [controller retain];
    return (void *)controller;
}

void destroyNativeToolbar(void *controllerPtr)
{
    if (!controllerPtr) return;

    NativeToolbarController *controller = (NativeToolbarController *)controllerPtr;

    // Remove toolbar from window
    if (controller.toolbar) {
        for (NSWindow *w in [NSApp windows]) {
            if (w.toolbar == controller.toolbar) {
                [w setToolbar:nil];
                break;
            }
        }
    }

    controller.clickCallback = nil;
    controller.toolbar = nil;
    [controller release]; // Balance the retain in createNativeToolbar
}

} // namespace MacOSNative
