import SwiftUI
import StudioCore

private let mediaNames = ["MPRV","MPLY","MNXT","MUTE","VOLU","VOLD","MSTP","EJCT","MFFD","MRWD","BRIU","BRID"]
private struct ActionForm: Equatable {
    var kind = "none", label = "", key = "A", mods: [String] = [], text = "", target = "next", mode = "to"
    var steps: [JSON] = []
    init(_ action: JSON = .null) {
        kind = action["type"].string.isEmpty ? "none" : action["type"].string
        if kind == "key", mediaNames.contains(action["key"].string) { kind = "media" }
        label = action["label"].string
        key = action["key"].string.isEmpty ? "A" : action["key"].string
        mods = action["mods"].array.map(\.string); text = action["text"].string
        target = action["layer"].number.map { String(Int($0)) } ?? (action["layer"].string.isEmpty ? "next" : action["layer"].string)
        mode = action["mode"].string.isEmpty ? "to" : action["mode"].string
        steps = action["steps"].array
    }
    func action() -> JSON {
        var fields: [String:JSON] = ["type":.string(kind == "media" ? "key" : kind), "label":.string(label)]
        switch kind {
        case "key", "media": fields["key"] = .string(key); fields["mods"] = .array(mods.map(JSON.string))
        case "text": fields["text"] = .string(text)
        case "layer": fields["mode"] = .string(mode); fields["layer"] = Int(target).map { .number(Double($0)) } ?? .string(target)
        case "macro": fields["steps"] = .array(steps)
        default: break
        }
        return .object(fields)
    }
}
struct ActionEditor: View {
    @ObservedObject var session: Session
    @State private var form = ActionForm()
    @State private var original = ActionForm()
    @State private var error = ""
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack(spacing:12) {
                Image(systemName:keySymbol(session.selected)).font(.system(size:22)).frame(width:44,height:44).background(Porcelain.inset,in:RoundedRectangle(cornerRadius:11))
                VStack(alignment:.leading,spacing:3) {
                    Text(keyLabel(session.selected)).font(.system(size:19,weight:.semibold,design:.rounded))
                    Text("Key \(session.selectedKey+1) · \(session.layerName.capitalized) layer").font(.system(size:12)).foregroundStyle(Porcelain.muted)
                }
                Spacer()
            }
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    caption("WHEN PRESSED")
                    Picker("Action",selection:$form.kind) {
                        Text("Shortcut").tag("key"); Text("Macro").tag("macro"); Text("Text").tag("text")
                        Text("Media").tag("media"); Text("Layer").tag("layer"); Text("None").tag("none")
                    }.pickerStyle(.segmented).controlSize(.small).font(.system(size:10)).labelsHidden().accessibilityLabel("When pressed action type")
                    actionFields
                    Divider()
                    caption("SCREEN LABEL")
                    TextField("Up to 10 ASCII characters",text:$form.label).textFieldStyle(.roundedBorder).accessibilityLabel("Screen label")
                    Text("Shown briefly on the OLED when this action fires.").font(.caption).foregroundStyle(Porcelain.muted)
                    VStack(spacing:0) {
                        preservedRow("When held", session.selected["hold"] == .null ? "None" : keyLabel(session.selected["hold"]))
                        Divider()
                        preservedRow("Icon on key","Inferred preview")
                        Divider()
                        preservedRow("Shows on screen",form.label.isEmpty ? "No label" : form.label)
                    }.background(Porcelain.inset,in:RoundedRectangle(cornerRadius:12))
                    Text("Hold actions and other settings are preserved. Edit them in the browser configurator for now.").font(.caption).foregroundStyle(Porcelain.muted)
                }.padding(.bottom,12)
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Porcelain.accent).accessibilityLabel("Validation error: \(error)") }
            HStack {
                Button("Revert") { form = original; error = "" }.disabled(form == original)
                Spacer()
                Button("Apply to draft") {
                    do { try session.apply(form.action()); original = form; error = "" }
                    catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(form == original || session.state == .syncing).keyboardShortcut(.return,modifiers:.command)
            }
            Text(form == original ? "Saved in draft" : "Unapplied changes · apply or revert to select another key").font(.caption2).foregroundStyle(Porcelain.muted)
        }.padding(20).background(Porcelain.surface)
            .onAppear { form = ActionForm(session.selected); original = form; session.editing = false }
            .onChange(of:form) { value in session.editing = value != original }
            .onChange(of:session.selected) { value in form = ActionForm(value); original = form; session.editing = false }
            .onChange(of:form.kind) { kind in if kind == "media" && !mediaNames.contains(form.key) { form.key = "MPLY" } }
    }
    @ViewBuilder private var actionFields: some View {
        if form.kind == "key" || form.kind == "media" {
            keyPicker("Key",value:$form.key,names:form.kind == "media" ? mediaNames : Keymap.keyNames)
            ModifierPicker(selected:$form.mods)
        }
        if form.kind == "text" { VStack(alignment:.leading) { caption("TYPE TEXT"); TextEditor(text:$form.text).font(.system(.body,design:.monospaced)).frame(height:100).border(Porcelain.inset) } }
        if form.kind == "layer" {
            Picker("Mode",selection:$form.mode) { Text("Switch to").tag("to"); Text("While held").tag("mo"); Text("Toggle").tag("tg"); Text("Default").tag("df") }
            Picker("Layer",selection:$form.target) {
                Text("Next layer").tag("next"); Text("Previous layer").tag("prev")
                ForEach(Array((session.draft?.layers ?? []).enumerated()),id:\.offset) { index,layer in Text(layer["name"].string).tag(String(index)) }
            }
        }
        if form.kind == "macro" { MacroListEditor(steps:$form.steps) }
    }
    private func preservedRow(_ label:String,_ value:String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(Porcelain.muted).lineLimit(1) }.font(.system(size:12)).padding(12)
    }
}
func keyPicker(_ title:String,value:Binding<String>,names:[String]) -> some View {
    Picker(title,selection:value) { ForEach(names,id:\.self) { Text($0).tag($0) } }.pickerStyle(.menu)
}
struct ModifierPicker: View {
    @Binding var selected:[String]
    var body: some View {
        VStack(alignment:.leading,spacing:5) {
            caption("MODIFIERS")
            LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:4),spacing:6) {
                ForEach(Keymap.modifiers,id:\.self) { mod in
                    Toggle(mod,isOn:Binding(get:{ selected.contains(mod) },set:{ enabled in selected.removeAll { $0 == mod }; if enabled { selected.append(mod) } })).toggleStyle(.button).font(.system(size:10))
                }
            }
        }
    }
}
struct MacroStepEditor: View {
    @Binding var step: JSON
    let index: Int
    let remove: () -> Void
    private func field(_ name:String,default fallback:String = "") -> Binding<String> {
        Binding(get:{ step.object[name]?.string ?? fallback },set:{ text in var fields = step.object; fields[name] = .string(text); step = .object(fields) })
    }
    var delayText: String { step["ms"].number.map { String(format:"%.0f",$0) } ?? "100" }
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text("\(index+1)").font(.caption.monospaced()).foregroundStyle(Porcelain.muted)
                Picker("Step",selection:field("do")) {
                    Text("Tap").tag("tap"); Text("Press").tag("press"); Text("Release").tag("release"); Text("Wait").tag("delay"); Text("Type").tag("text")
                }.labelsHidden()
                Button(action:remove) { Image(systemName:"minus.circle") }.buttonStyle(.plain).accessibilityLabel("Remove step \(index+1)")
            }
            if ["tap","press","release"].contains(step["do"].string) {
                keyPicker("Key",value:field("key",default:"A"),names:Keymap.keyNames)
                ModifierPicker(selected:Binding(get:{ step["mods"].array.map(\.string) },set:{ values in var fields = step.object; fields["mods"] = .array(values.map(JSON.string)); step = .object(fields) }))
            } else if step["do"].string == "delay" {
                TextField("Milliseconds",text:Binding(get:{ delayText },set:{ value in var fields=step.object; fields["ms"] = Double(value).map(JSON.number) ?? .string(value); step = .object(fields) })).textFieldStyle(.roundedBorder)
            } else { TextField("Text",text:field("text")).textFieldStyle(.roundedBorder) }
        }.padding(10).background(Porcelain.inset,in:RoundedRectangle(cornerRadius:10))
            .onChange(of:step["do"]) { value in
                var fields=step.object
                if ["tap","press","release"].contains(value.string), fields["key"] == nil { fields["key"] = .string("A") }
                if value.string == "delay", fields["ms"] == nil { fields["ms"] = .number(100) }
                if value.string == "text", fields["text"] == nil { fields["text"] = .string("") }
                step = .object(fields)
            }
    }
}

struct MacroListEditor: View {
    @Binding var steps: [JSON]
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text("MACRO STEPS").font(.caption).foregroundStyle(Porcelain.muted)
            ForEach(Array(steps.enumerated()),id: \.offset) { item in
                MacroStepEditor(step: Binding<JSON>(get:{ steps[item.offset] },set:{ steps[item.offset] = $0 }),index:item.offset,remove:{ steps.remove(at:item.offset) })
            }
            Button("Add step") { steps.append(JSON.object(["do": JSON.string("tap"), "key": JSON.string("A")])) }
            Text("Recording and Run arrive in slice 2.").font(.caption).foregroundStyle(Porcelain.muted)
        }
    }
}
