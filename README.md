1.0.25 fixes the GitHub Actions SDK module failure by removing UIKit/Foundation imports.
The tweak accesses UIKit/Foundation classes through Objective-C runtime messaging.
Only the white-style function is tested.
