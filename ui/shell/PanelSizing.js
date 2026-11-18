.pragma library

// Logical pixels: compositor scaling already accounts for display density.
// Theme spacing, font tokens and border decoration do not resize the window.
function fit(screenHeight, availableWidth, availableHeight) {
 var scale = Math.min(1, screenHeight > 0 ? screenHeight * .75 / 686 : 1,
                      availableWidth > 0 ? availableWidth / 460 : 1,
                      availableHeight > 0 ? availableHeight / 686 : 1)
 return {width:Math.max(1,Math.floor(460*scale)),height:Math.max(1,Math.floor(686*scale))}
}
