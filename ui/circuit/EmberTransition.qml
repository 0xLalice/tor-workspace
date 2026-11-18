import ".."
import QtQuick
import "../theme/EmberPreset.js" as Ember

// Approved transition, independent of either live Tor snapshots or lab playback.
TransitionRoutes {
 retirementBehavior:2;disappearanceDuration:Ember.lifetime
 mode:3;revealDuration:Ember.definition.reveal
 activityStyle:3;retiredOpacity:Ember.definition.opacity
 ringStyle:3;ringBand:Ember.definition.band
 ringExitStyle:Ember.definition.exit;ringExitDuration:Ember.definition.exitDuration
 ringExitScatter:Ember.definition.scatter;ringExitStrength:Ember.definition.strength
 driftStrength:Ember.definition.drift;visibleFraction:Ember.definition.hold
}
