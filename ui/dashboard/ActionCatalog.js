.pragma library
// Feature names, help and status belong to the application, never a theme.
var entries=[
 {kind:"browser",title:"Tor Browser",detail:"Browse through the Tor network."},
 {kind:"terminal",title:"Tor Terminal",detail:"Open a terminal routed through Tor."},
 {kind:"share",title:"Share a file",detail:"Share files through a temporary onion link.",activeDetail:"File sharing is active. Manage links or stop sharing."},
 {kind:"chat",title:"Tor Chat",detail:"Start a temporary chat room through Tor.",activeDetail:"A room is running. Open it, copy its link, or stop it."},
 {kind:"website",title:"Website folder",detail:"Serve files from a website folder.",blockedDetail:"Stop app publishing first."},
 {kind:"app",title:"Running app",detail:"Connect an already-running app to Tor.",blockedDetail:"Stop website publishing first."},
 {kind:"darknet",title:"Access the darknet",detail:"Discover onion sites with Ahmia in Tor Browser."},
 {kind:"options",title:"Options",detail:"Configure Tor Workspace."},
 {kind:"theme",title:"Themes",detail:"Customize the globe, colors, and effects."}
];
var networkKinds=entries.slice(0,7).map(e=>e.kind);
function resolve(entry,state) {
 var kind=entry.kind,active=!!state.active[kind],blocked=!!state.blocked[kind];
 var description=blocked?entry.blockedDetail:active&&entry.activeDetail?entry.activeDetail:entry.detail;
 var accessible=kind==="share"&&active?"File sharing active. Open sharing controls":kind==="chat"&&state.chatActivity?state.chatActivity+". Open room controls":entry.title+(active?", active":"");
 return Object.assign({},entry,{enabled:kind==="theme"||kind==="options"||(state.networkEnabled&&!blocked),active:active,detail:description,accessible:accessible});
}
