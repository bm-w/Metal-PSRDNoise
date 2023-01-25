//
//  App.swift
//  Metal-SwiftUI
//

import SwiftUI


@main struct Metal_SwiftUIApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}


// MARK: - Utilities

func asserted<T>(_ value: T?) -> T? { assert(value != nil); return value }
