// main.swift
// HarbourMaster
//
// Application entry point.

import AppKit

// Create the shared NSApplication instance and attach the delegate.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Run the main event loop (never returns).
app.run()
