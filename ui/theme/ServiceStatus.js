.pragma library
function luminance(c){function linear(x){return x<=.04045?x/12.92:Math.pow((x+.055)/1.055,2.4)}return .2126*linear(c.r)+.7152*linear(c.g)+.0722*linear(c.b)}
function color(surface,state){
 var pair=state==="ready"?["#146a40","#77e3aa"]:state==="error"?["#a42b3b","#ff9ca8"]:["#805500","#f5cf7c"]
 var bg=luminance(surface)
 function contrast(hex){var c=Qt.color(hex),l=luminance(c);return (Math.max(bg,l)+.05)/(Math.min(bg,l)+.05)}
 return contrast(pair[0])>=contrast(pair[1])?pair[0]:pair[1]
}
