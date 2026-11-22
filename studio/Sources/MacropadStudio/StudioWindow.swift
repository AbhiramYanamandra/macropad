import AppKit
import SwiftUI
import StudioCore

enum Porcelain {
    static let background = Color(hex: "efece5"), surface = Color(hex: "f8f6f0"), inset = Color(hex: "efebe3")
    static let accent = Color(hex: "c43d1d"), ink = Color(hex: "1a1812"), muted = Color(hex: "625c52")
}
extension Color {
    init(hex: String) {
        let value = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255)
    }
}
func keySymbol(_ action: JSON) -> String {
    switch action["type"].string {
    case "macro": return "list.bullet.rectangle"
    case "text": return "text.cursor"
    case "layer": return "square.3.layers.3d"
    case "none", "": return "minus"
    default:
        switch action["key"].string {
        case "MPLY": return "playpause"; case "MPRV": return "backward.end"; case "MNXT": return "forward.end"
        case "MUTE": return "speaker.slash"; case "VOLU": return "speaker.plus"; case "VOLD": return "speaker.minus"
        case "S": return "square.and.arrow.down"; case "P": return "doc"; case "F5": return "ladybug"
        default: return "command"
        }
    }
}
func keyLabel(_ action: JSON) -> String {
    let label = action["label"].string
    if !label.isEmpty { return label }
    return action["key"].string.isEmpty ? action["type"].string.uppercased() : action["key"].string
}

struct StudioWindow: View {
    @ObservedObject var session: Session
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("Macropad Studio").font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                HStack(spacing: 7) {
                    Circle().fill(session.snapshot == nil || [.disconnected,.unknown,.invalid].contains(session.state) ? Color.orange : Color.green).frame(width: 7, height: 7)
                    Text("Macropad mk2").bold()
                    Text(session.snapshot == nil ? "No pad selected" : "\(session.state.rawValue.capitalized) · selected \(session.layerName)").foregroundStyle(Porcelain.muted)
                }.font(.system(size: 12)).padding(.horizontal,12).padding(.vertical,7).background(Porcelain.inset,in: Capsule())
                Spacer()
                Button { session.chooseFolder() } label: { Label("Open pad…",systemImage:"folder") }.disabled(session.state == .syncing)
                Button { session.undo() } label: { Label("Undo",systemImage:"arrow.uturn.backward") }.disabled(session.history.isEmpty || session.editing || session.state == .syncing)
                Button { session.sync() } label: { Label(session.state == .syncing ? "Syncing…" : "Sync to pad",systemImage:"arrow.triangle.2.circlepath") }
                    .buttonStyle(.borderedProminent).tint(Porcelain.accent).disabled(!session.canSync).keyboardShortcut("s")
            }.padding(.horizontal,20).frame(height: 54).background(Porcelain.surface)
            Divider()
            HStack(spacing: 0) {
                rail
                Divider()
                if session.destination == "Keys" {
                    if session.draft != nil {
                        keysStage
                        Divider()
                        ActionEditor(session: session).frame(width: 330).id("\(session.selectedLayer)-\(session.selectedKey)")
                    } else { welcome }
                } else { futureDestination }
            }
            Divider()
            HStack {
                Image(systemName: [.unknown,.invalid,.conflict].contains(session.state) ? "exclamationmark.triangle" : "info.circle")
                Text(session.message).lineLimit(2)
                Spacer()
                if [.unknown,.disconnected,.conflict].contains(session.state) { Button("Inspect reconnected pad") { session.inspectReconnect() } }
            }.font(.system(size: 12)).foregroundStyle(Porcelain.muted).padding(.horizontal,20).frame(minHeight: 42).background(Porcelain.surface)
        }.background(Porcelain.background).foregroundStyle(Porcelain.ink).tint(Porcelain.accent)
            .disabled(session.state == .opening)
    }
    private var rail: some View {
        VStack(spacing: 8) {
            nav("Keys","square.grid.2x2")
            nav("Display","display")
            nav("Layers","square.3.layers.3d")
            Spacer()
            nav("Settings","slider.horizontal.3")
        }.padding(.horizontal,8).padding(.vertical,18).frame(width: 70).background(Porcelain.surface)
    }
    private func nav(_ name: String, _ icon: String) -> some View {
        Button { session.destination = name } label: {
            VStack(spacing: 6) { Image(systemName:icon).font(.system(size:19)); Text(name).font(.system(size:11)) }
                .frame(width:62,height:60).foregroundStyle(session.destination == name ? Porcelain.accent : Porcelain.muted)
                .background(session.destination == name ? Porcelain.accent.opacity(0.08) : Color.clear,in:RoundedRectangle(cornerRadius:10))
        }.buttonStyle(.plain).disabled(session.editing || session.state == .syncing)
    }
    private var welcome: some View {
        VStack(spacing: 22) {
            Image(systemName:"square.grid.3x3").font(.system(size:50,weight:.ultraLight)).foregroundStyle(Porcelain.accent)
            Text("Make it yours.").font(.system(size:36,weight:.semibold,design:.rounded))
            Text("Nine keys. Your real layout.\nOpen CIRCUITPY to get started.").multilineTextAlignment(.center).foregroundStyle(Porcelain.muted)
            Button("Open pad folder…") { session.chooseFolder() }.buttonStyle(.borderedProminent).controlSize(.large)
            Text("Your files stay on your Mac and the selected pad.").font(.caption).foregroundStyle(Porcelain.muted)
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    private var keysStage: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing: 6) {
                    ForEach(Array((session.draft?.layers ?? []).enumerated()),id:\.offset) { index, layer in
                        Button { session.selectedLayer = index } label: {
                            HStack(spacing:7) { Circle().fill(Color(hex:layer["color"].string)).frame(width:8,height:8); Text(layer["name"].string.capitalized) }
                                .padding(.horizontal,14).padding(.vertical,9)
                                .background(session.selectedLayer == index ? Porcelain.surface : Color.clear,in:Capsule())
                                .overlay(Capsule().stroke(.black.opacity(session.selectedLayer == index ? 0.08 : 0)))
                        }.buttonStyle(.plain).disabled(session.editing || session.state == .syncing)
                    }
                    Spacer()
                    Text("Combos · \(session.draft?.combos.count ?? 0)").font(.system(size:12)).foregroundStyle(Porcelain.muted).padding(8)
                }.padding(.horizontal,20).padding(.vertical,14)
            }.frame(height:64)
            GeometryReader { proxy in
                ZStack(alignment:.top) {
                    RadialGradient(colors:[Porcelain.surface,Porcelain.background],center:.center,startRadius:0,endRadius:450)
                    VStack(spacing:22) {
                        HStack(alignment:.top) {
                            VStack(alignment:.leading,spacing:5) { caption("SCREEN"); Text("Static layer preview").font(.system(size:12)) }.padding(12).background(Porcelain.surface,in:RoundedRectangle(cornerRadius:10))
                            Spacer()
                            VStack(alignment:.leading,spacing:5) { caption(session.draft?.knob == true ? "KNOB · FITTED" : "KNOB · NOT FITTED"); Text("Encoder settings are preserved.").font(.system(size:11)) }.padding(12).background(Porcelain.surface,in:RoundedRectangle(cornerRadius:10))
                        }.padding(.horizontal,28).padding(.top,24)
                        Spacer(minLength:0)
                        PadDrawing(session:session).frame(width:318,height:388)
                            .scaleEffect(min(1,max(0.65,(proxy.size.height-145)/388)))
                            .frame(width:318*min(1,max(0.65,(proxy.size.height-145)/388)),height:388*min(1,max(0.65,(proxy.size.height-145)/388)))
                        Spacer(minLength:0)
                    }
                }.frame(width:proxy.size.width,height:proxy.size.height)
            }.clipped()
            Divider()
            HStack(spacing:10) {
                Image(systemName:"cursorarrow.rays"); Text("Editor preview").bold()
                Text("Select a key · 7 + 9 cycles the pad layer").foregroundStyle(Porcelain.muted)
                Spacer()
            }.font(.system(size:12)).padding(20).background(Porcelain.surface.opacity(0.6))
        }.frame(maxWidth:.infinity)
    }
    private var futureDestination: some View {
        VStack(spacing:16) {
            Image(systemName:"square.3.layers.3d").font(.largeTitle).foregroundStyle(Porcelain.accent)
            Text(session.destination).font(.title2).bold()
            Text("Not delivered in slice 1").font(.headline)
            Text("Your existing settings, layers and assets are preserved.\nUse the browser configurator for these workflows.").multilineTextAlignment(.center).foregroundStyle(Porcelain.muted)
            if session.destination == "Settings" {
                Text(session.draft?.knob == true ? "Knob · fitted" : "Knob · not fitted")
                Button("Recover locally saved draft") { session.recoverDraft() }.disabled(session.draft == nil)
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}
func caption(_ text: String) -> some View { Text(text).font(.system(size:10,weight:.semibold)).tracking(1.1).foregroundStyle(Porcelain.muted) }

struct PadDrawing: View {
    @ObservedObject var session: Session
    var body: some View {
        VStack(spacing:20) {
            HStack {
                ScreenPreview(session:session).frame(width:152,height:42).padding(6).background(Color(hex:"050506"),in:RoundedRectangle(cornerRadius:6))
                Spacer()
            }.frame(height:60)
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:3),spacing:6) {
                ForEach(0..<9,id:\.self) { index in
                    let action = session.draft?.action(layer:session.selectedLayer,key:index) ?? .null
                    Button { session.selectedKey = index } label: {
                        VStack(spacing:8) { Image(systemName:keySymbol(action)).font(.system(size:24,weight:.light)); Text(keyLabel(action)).font(.system(size:10,weight:.medium)).lineLimit(1).minimumScaleFactor(0.7) }
                            .foregroundStyle(Porcelain.ink).frame(maxWidth:.infinity).frame(height:73)
                            .background(LinearGradient(colors:[Color(hex:"fbf9f4"),Color(hex:"ebe7de")],startPoint:.top,endPoint:.bottom),in:RoundedRectangle(cornerRadius:9))
                            .shadow(color:Color(hex:"887d69").opacity(0.3),radius:1,y:3)
                            .overlay(alignment:.topLeading) { Text("\(index+1)").font(.system(size:8,design:.monospaced)).foregroundStyle(Porcelain.muted.opacity(0.65)).padding(7) }
                            .overlay(alignment:.topTrailing) { if session.draft?.combos.contains(where:{ $0["keys"].array.contains(.number(Double(index))) }) == true { Image(systemName:"link").font(.system(size:8)).foregroundStyle(Porcelain.accent).padding(7) } }
                            .padding(4).background(.black.opacity(0.055),in:RoundedRectangle(cornerRadius:12))
                            .overlay(RoundedRectangle(cornerRadius:12).stroke(session.selectedKey == index ? Porcelain.accent : .clear,lineWidth:2).padding(-2))
                    }.buttonStyle(.plain).accessibilityLabel("Key \(index+1), \(keyLabel(action))")
                        .disabled(session.editing || session.state == .syncing)
                }
            }
        }.padding(.horizontal,25).padding(.top,24).padding(.bottom,28)
            .background(LinearGradient(colors:[Color(hex:"f5f2ea"),Color(hex:"dfdacf")],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:22))
            .overlay(alignment:.top) { Circle().fill(Color(hex:session.draft?.layers[session.selectedLayer]["color"].string ?? "000000")).frame(width:7,height:7).shadow(color:.white,radius:5).padding(.top,10) }
            .overlay(RoundedRectangle(cornerRadius:22).stroke(.white.opacity(0.8),lineWidth:1))
            .shadow(color:Color(hex:"70552a").opacity(0.25),radius:25,y:26)
    }
}
struct ScreenPreview: View {
    @ObservedObject var session: Session
    var body: some View {
        GeometryReader { proxy in
            if let data = imageData, let bitmap = try? MonochromeBitmap(data:data) {
                Canvas { context, size in
                    let pixelWidth=size.width/128, pixelHeight=size.height/32
                    for y in 0..<32 {
                        for x in 0..<128 where bitmap.pixels[y*128+x] {
                            context.fill(Path(CGRect(x:CGFloat(x)*pixelWidth,y:CGFloat(y)*pixelHeight,width:pixelWidth,height:pixelHeight)),with:.color(.white))
                        }
                    }
                }.frame(width:proxy.size.width,height:proxy.size.height)
            } else {
                Text(session.layerName).font(.system(size:15,weight:.bold,design:.monospaced)).foregroundStyle(.white).frame(width:proxy.size.width,height:proxy.size.height)
            }
        }.background(.black)
    }
    private var imageData: Data? {
        guard let snapshot = session.snapshot, let map = session.draft else { return nil }
        let path = map.layers[session.selectedLayer]["image"].string
        guard let url = try? PadStore.safeChild(snapshot.root,path:path) else { return nil }
        return try? Data(contentsOf:url)
    }
}
