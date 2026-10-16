// How long the parts of the welcome dart's press animation take (no browser
// needed, so they can be tested).

/// The dart's flight of half a centimetre: the same speed as the nudge it
/// already had when you hover it (150 ms).
const int dartFlightMs = 150;

/// How long the dart wiggles, stuck in the circle, before the next screen.
const int dartWiggleMs = 550;

/// How long the scroll-to-top dart takes to fade away after it has stuck at the top
/// and wiggled.
const int dartLeaveMs = 250;

/// How long the Back dart takes to slide half a centimetre and fade out smoothly
/// (no circle, no wiggle) before the menu comes. The CSS transition of
/// `.back-stage.fading` is the same length.
const int dartFadeMs = 320;
