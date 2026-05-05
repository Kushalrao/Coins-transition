//
//  VacationsApp.swift
//  Vacations
//
//  Created by Kushal Yadav on 05/05/26.
//

import SwiftUI
import CoreText

@main
struct VacationsApp: App {
    init() {
        FontLoader.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum FontLoader {
    static func registerFonts() {
        let names = ["LexendDeca-VF"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
