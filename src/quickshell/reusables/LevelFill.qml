import QtQuick
import QtQuick.Shapes

// Level fill for the bar pills, drawn as a GPU Shape (no JS Canvas raster + texture upload).
Shape {
    id: root

    property real fillRatio: 0
    property real radius: 0
    property color color: "white"

    readonly property real fillY: height * (1.0 - fillRatio)

    visible: fillRatio > 0 && width > 0 && height > 0
    preferredRendererType: Shape.CurveRenderer
    opacity: 0.95

    // Pill outline below the fill level. The rounded corners are traced exactly (the Shape
    // can't be clipped to a rounded rect cheaply), insetting the level line when the
    // level sits inside a corner.
    readonly property string outline: {
        const w = width, h = height;
        if (!visible) return "";
        const r = Math.max(0, Math.min(radius, w / 2, h / 2));
        const y = Math.max(0, Math.min(h, fillY));
        const dy = y < r ? r - y : (y > h - r ? y - (h - r) : 0);
        const inset = r - Math.sqrt(Math.max(0, r * r - dy * dy));
        const arc = (x, yy) => ` A ${r} ${r} 0 0 1 ${x} ${yy}`;

        let p = `M ${inset} ${y} L ${w - inset} ${y}`;
        if (y < r) p += arc(w, r);
        p += y < h - r ? ` L ${w} ${h - r}` + arc(w - r, h) : arc(w - r, h);
        p += ` L ${r} ${h}`;
        if (y < h - r) {
            p += arc(0, h - r);
            p += y < r ? ` L 0 ${r}` + arc(inset, y) : ` L 0 ${y}`;
        } else {
            p += arc(inset, y);
        }
        return p + " Z";
    }

    ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillGradient: LinearGradient {
            x1: 0; y1: 0
            x2: 0; y2: root.height
            GradientStop { position: 0; color: Qt.lighter(root.color, 1.25) }
            GradientStop { position: 1; color: root.color }
        }
        PathSvg { path: root.outline }
    }
}
