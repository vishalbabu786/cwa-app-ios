//
//  ColorSelectView.swift
//  Kurzwahl2020
//
//  Created by Vogel, Andreas on 01.03.20.
//  Copyright © 2020 Vogel, Andreas. All rights reserved.
// https://stackoverflow.com/questions/56515871/how-to-open-the-imagepicker-in-swiftui

import SwiftUI

struct ColorSelectView: View {
    @EnvironmentObject var navigation: NavigationStack
    let cm: ColorManagement = ColorManagement()
    
    var body: some View {
        VStack{
            SingleActionBackView( title: "",
                                  buttonText: NSLocalizedString("Back", comment: "Navigation bar Back button"),
                                  action:{
                                    self.navigation.unwind()
            })
            VStack{
                Text("Change the colors for each screen").multilineTextAlignment(.leading).customFont(name: globalDataModel.font, style: .body).padding(.horizontal)
                HStack{
                    Button(action: {
                        self.navigation.advance(NavigationItem(
                            view: AnyView(SelectColorPalette()))) }) {
                                Image(cm.getThumbnailName(withIndex: 0)).resizable()
                                    .frame(width: 100, height: 190).padding()
                    }.buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        self.navigation.advance(NavigationItem(
                            view: AnyView(SelectColorPalette()))) }) {
                                Image(cm.getThumbnailName(withIndex: 1)).resizable()
                                    .frame(width: 100, height: 190).padding()
                    }.buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        self.navigation.advance(NavigationItem(
                            view: AnyView(SelectColorPalette()))) }) {
                                Image(cm.getThumbnailName(withIndex: 2)).resizable()
                                    .frame(width: 100, height: 190).padding()
                    }.buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
        }
    }
}

struct ColorSelectView_Previews: PreviewProvider {
    static var previews: some View {
        ColorSelectView()
    }
}