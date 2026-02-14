#ifndef MAGNETICWIDGET_H
#define MAGNETICWIDGET_H

#include <QPointer>
#include <QWidget>

/*
 * a magnetic widget
 * window title bar support not good
*/

class MagneticWidget : public QWidget
{
    Q_OBJECT

public:
    enum AdsorbPosition
    {
        AP_OUTSIDE_LEFT = 0x01,   // Snap to outer left edge
        AP_OUTSIDE_TOP = 0x02,    // Snap to outer top edge
        AP_OUTSIDE_RIGHT = 0x04,  // Snap to outer right edge
        AP_OUTSIDE_BOTTOM = 0x08, // Snap to outer bottom edge
        AP_INSIDE_LEFT = 0x10,    // Snap to inner left edge
        AP_INSIDE_TOP = 0x20,     // Snap to inner top edge
        AP_INSIDE_RIGHT = 0x40,   // Snap to inner right edge
        AP_INSIDE_BOTTOM = 0x80,  // Snap to inner bottom edge
        AP_ALL = 0xFF,            // Snap to all edges
    };
    Q_DECLARE_FLAGS(AdsorbPositions, AdsorbPosition)

public:
    explicit MagneticWidget(QWidget *adsorbWidget, AdsorbPositions adsorbPos = AP_ALL);
    ~MagneticWidget();

    bool isAdsorbed();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;
    void moveEvent(QMoveEvent *event) override;

private:
    void getGeometry(QRect &relativeWidgetRect, QRect &targetWidgetRect);

private:
    AdsorbPositions m_adsorbPos = AP_ALL;
    QPoint m_relativePos;
    bool m_adsorbed = false;
    QPointer<QWidget> m_adsorbWidget;
    // Track adsorbWidgetSize separately: when setGeometry is called, Move event arrives before Resize,
    // but Widget::size() already returns the new size during the Move event
    QSize m_adsorbWidgetSize;
    AdsorbPosition m_curAdsorbPosition;
};

Q_DECLARE_OPERATORS_FOR_FLAGS(MagneticWidget::AdsorbPositions)
#endif // MAGNETICWIDGET_H
