import SwiftUI

/// `@State` became a macro whose plugin ships only with Xcode. The underlying
/// property wrapper is unchanged, so this alias lets CPStack build with just
/// the Command Line Tools as well as with Xcode.
typealias ViewState = SwiftUI.State
