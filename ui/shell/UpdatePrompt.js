.pragma library
function text(pluginPath, revision) {
  return "Update Tor Workspace at "+JSON.stringify(pluginPath)+" to "+revision+". This release needs administrator setup on this machine. Check the working tree, review the selected changes, and explain what needs privileges. Preserve local edits. Fast-forward only to the selected commit if it is still the checked upstream revision. If it is already installed, resume setup. Follow docs/INSTALL.md for missing steps only. Request authentication in the system terminal. Preserve Tor state and settings, then reload and verify the plugin."
}
