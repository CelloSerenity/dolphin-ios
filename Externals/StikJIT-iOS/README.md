# StikJIT XCFramework

`StikJIT.xcframework` comes from the StikJIT 2.0.0 release. The original archive SHA-256 is `bde97c1624e3e642d293f15198992291bb757d28f60b539fd609801e80fe1257`.

Only the iOS slice is included; the tvOS slice is omitted because this project builds for iOS.

The release archive omitted its framework `Info.plist` files and emitted module-qualified declarations that the project's Swift compiler resolves against the public `StikJIT` enum instead of the module. This copy adds the missing bundle metadata and uses compatible declarations in the public and private Swift interfaces. The compiled iOS framework binary is unchanged.
