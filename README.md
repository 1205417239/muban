DynamicXStandardAdjust 1.0.33

Purpose: companion tweak for DynamicX on iOS 17.2.1 / arm64e.

1.0.33 changes the size path from DynamicXNotificationElement width/height setters to its runtime layout path. It waits for DynamicXNotificationElement to be dynamically registered, then hooks updateLayout and preferredEdgeOutsetsForLayoutMode:suggestedOutsets:maximumOutsets:.

PreferenceLoader layout is unchanged from 1.0.29/1.0.32.
Original DynamicX.dylib is not modified.

Note: OpacityPercent is now applied to the resolved DynamicX view; WhiteStyleEnabled remains a best-effort color override. These should be tested independently after confirming size changes.
