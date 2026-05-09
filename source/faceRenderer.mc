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
    function drawCachedTightText(dc as $.Toybox.Graphics.Dc, x as $.Toybox.Lang.Number, y as $.Toybox.Lang.Number, font as $.Toybox.Graphics.FontDefinition or $.Toybox.Graphics.VectorFont, text as $.Toybox.Lang.String, widths as $.Toybox.Lang.Array<$.Toybox.Lang.Number>, totalW as $.Toybox.Lang.Number, tracking as $.Toybox.Lang.Number, debug as $.Toybox.Lang.Boolean, mainColor as $.Toybox.Graphics.ColorValue, fontH as $.Toybox.Lang.Number) as Void {
        var chars = text.toCharArray();
        var curX = (x - (totalW / 2)) as $.Toybox.Lang.Number;

        dc.setColor(mainColor, $.Toybox.Graphics.COLOR_TRANSPARENT);

        for (var i = 0; i < chars.size(); i++) {
            var s = chars[i].toString();
            if (debug) {
                dc.setColor($.FaceLogic.COLOR_GREEN, $.Toybox.Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(curX, y, widths[i], fontH);
                dc.setColor(mainColor, $.Toybox.Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(curX, y, font, s, $.Toybox.Graphics.TEXT_JUSTIFY_LEFT);
            curX += widths[i] + tracking;
        }
    }

    //
    // Draw a ring arc based on ratio
    //
    function drawRingArc(dc as $.Toybox.Graphics.Dc, radius as $.Toybox.Lang.Number, ratio as $.Toybox.Lang.Float, color as $.Toybox.Graphics.ColorValue, cx as $.Toybox.Lang.Number, cy as $.Toybox.Lang.Number) as Void {
        if (ratio <= 0) { return; }
        dc.setColor(color, $.FaceLogic.COLOR_BLACK);
        var endAngle = 90 + (360 * ratio);
        dc.drawArc(cx, cy, radius, $.Toybox.Graphics.ARC_COUNTER_CLOCKWISE, 90, endAngle.toNumber());
    }

    //
    // Draw the heart icon (lobes + bottom polygon)
    //
    function drawHeartIcon(dc as $.Toybox.Graphics.Dc, color as $.Toybox.Graphics.ColorValue) as Void {
        dc.setColor(color, $.FaceLogic.COLOR_BLACK);
        var r = $.LayoutGenerated.HEART_LOBE_R;
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_L_X, $.LayoutGenerated.HEART_LOBE_Y, r); 
        dc.fillCircle($.LayoutGenerated.HEART_LOBE_R_X, $.LayoutGenerated.HEART_LOBE_Y, r);
        
        var pts = $.LayoutGenerated.HEART_POLY;
        dc.fillPolygon([[pts[0][0], pts[0][1]], [pts[1][0], pts[1][1]], [pts[2][0], pts[2][1]]]);
    }

}
