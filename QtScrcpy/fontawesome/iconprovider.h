#ifndef ICONPROVIDER_H
#define ICONPROVIDER_H

#include <QChar>
#include <QIcon>
#include <QString>

class QPushButton;

class IconProvider {
public:
    static IconProvider *instance();

    // Set icon: SF Symbol on macOS, FontAwesome fallback elsewhere
    void setIcon(QPushButton *btn, const QString &sfSymbolName,
                 QChar fontAwesomeChar, int size = 15);

private:
    IconProvider() = default;
};

#endif // ICONPROVIDER_H
