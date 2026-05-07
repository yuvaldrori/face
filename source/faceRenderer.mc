//
// FaceRenderer.mc
// Stateless drawing primitives and UI rendering logic
//

import Toybox.Graphics;
import Toybox.Lang;

module FaceRenderer {

    //
    // Render text with custom character tracking using cached dimensions
    //
    function drawCachedTightText(dc as $.Toybox.Graphics.Dc, x as Number, y as Number, font as Object, text as String, widths as Array<Number>, totalW as Number, tracking as Number, debug as Boolean, mainColor as ColorValue) as Void {
        var chars = text.toCharArray();
        var curX = (x - (totalW / 2)) as Number;
        var fontH = dc.getFontHeight(font as $.Toybox.Graphics.FontDefinition) as Number;

        for (var i = 0; i < chars.size(); i++) {
            var s = chars[i].toString();
            if (debug) {
                dc.setColor(FaceLogic.COLOR_GREEN, FaceLogic.COLOR_BLACK);
                dc.drawRectangle(curX, y, widths[i] as Number, fontH);
                dc.setColor(mainColor, $.Toybox.Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(curX, y, font as $.Toybox.Graphics.FontDefinition, s, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
            curX += widths[i] + tracking;
        }
    }

    //
    // Draw a ring arc based on ratio
    //
    function drawRingArc(dc as $.Toybox.Graphics.Dc, radius as Number, ratio as Float, color as ColorValue, cx as Number, cy as Number) as Void {
        if (ratio <= 0) { return; }
        dc.setColor(color, FaceLogic.COLOR_BLACK);
        var endAngle = 90 + (360 * ratio);
        dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE, 90, endAngle.toNumber());
    }

    //
    // Draw the heart icon (lobes + bottom polygon)
    //
    function drawHeartIcon(dc as $.Toybox.Graphics.Dc, color as Number) as Void {
        dc.setColor(color, FaceLogic.COLOR_BLACK);
        var r = $.LayoutGenerated.HEART_LOBE_R;
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_L_X, $.LayoutGenerated.HEART_LOBE_Y, r); 
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_R_X, $.LayoutGenerated.HEART_LOBE_Y, r);
        
        var pts = $.LayoutGenerated.HEART_POLY;
        dc.fillPolygon([[pts[0][0], pts[0][1]], [pts[1][0], pts[1][1]], [pts[2][0], pts[2][1]]]);
    }

}
