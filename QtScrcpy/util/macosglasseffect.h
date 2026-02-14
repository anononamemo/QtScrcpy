#ifndef MACOSGLASSEFFECT_H
#define MACOSGLASSEFFECT_H

#include <QIcon>
#include <QPixmap>
#include <QString>
#include <QStringList>
#include <functional>

class QWidget;

// Legacy namespace — kept for backward compatibility
namespace MacOSGlassEffect {
    bool applyGlassEffect(QWidget *widget);
}

// Full native macOS bridge
namespace MacOSNative {

// --- Window Effects ---

// Unified titlebar: content extends under titlebar, title hidden.
// Traffic light buttons remain visible. Must be called after show()/winId().
bool applyUnifiedTitlebar(QWidget *widget);

// Apply NSVisualEffectView behind Qt content for vibrancy/blur.
// material values match NSVisualEffectMaterial enum.
bool applyVibrancy(QWidget *widget, int material);

enum VibrancyMaterial {
    Sidebar = 7,                  // NSVisualEffectMaterialSidebar
    HeaderView = 10,              // NSVisualEffectMaterialHeaderView
    ContentBackground = 18,       // NSVisualEffectMaterialContentBackground
    UnderWindowBackground = 21    // NSVisualEffectMaterialUnderWindowBackground
};

// Query titlebar height (distance from top of contentView to contentLayoutRect)
qreal titlebarHeight(QWidget *widget);

// Set vibrant appearance matching system dark/light mode.
// Safe alternative to NSVisualEffectView — doesn't conflict with Qt Metal rendering.
bool applyVibrantAppearance(QWidget *widget);

// --- Theme Detection ---

bool isDarkMode();
// Register callback for system dark/light mode changes.
void observeThemeChanges(std::function<void(bool isDark)> callback);

// --- SF Symbols ---

// Load an SF Symbol as QIcon. Returns null icon if symbol not found or macOS < 11.
QIcon sfSymbolIcon(const QString &symbolName, qreal pointSize = 15.0);
QPixmap sfSymbolPixmap(const QString &symbolName, qreal pointSize = 15.0);

// --- Native Toolbar (NSToolbar) ---

// Create NSToolbar attached to the window backing the widget.
// itemIdentifiers: list of toolbar item IDs (use "NSToolbarFlexibleSpaceItem" for flex space).
// callback: called with item identifier when a toolbar button is clicked.
// Returns opaque handle to ObjC controller (pass to destroyNativeToolbar).
void* createNativeToolbar(QWidget *window,
                          const QStringList &itemIdentifiers,
                          std::function<void(const QString &identifier)> callback);
void destroyNativeToolbar(void *controller);

} // namespace MacOSNative

#endif // MACOSGLASSEFFECT_H
