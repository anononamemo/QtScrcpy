#include "iconprovider.h"
#include "iconhelper.h"

#include <QPushButton>

#ifdef Q_OS_MACOS
#include "macosglasseffect.h"
#endif

IconProvider *IconProvider::instance()
{
    static IconProvider s_instance;
    return &s_instance;
}

void IconProvider::setIcon(QPushButton *btn, const QString &sfSymbolName,
                           QChar fontAwesomeChar, int size)
{
#ifdef Q_OS_MACOS
    QIcon icon = MacOSNative::sfSymbolIcon(sfSymbolName, size);
    if (!icon.isNull()) {
        btn->setIcon(icon);
        btn->setIconSize(QSize(size + 4, size + 4));
        btn->setText("");
        return;
    }
#else
    Q_UNUSED(sfSymbolName);
#endif
    // Fallback: FontAwesome
    IconHelper::Instance()->SetIcon(btn, fontAwesomeChar, size);
}
