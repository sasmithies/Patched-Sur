//
//  DownloadView.swift
//  Patched Sur - For Catalina
//
//  Created by Benjamin Sova on 9/23/20.
//

import SwiftUI
import Files
import Combine

struct InstallPackageView: View {
    @State var downloadStatus = "Fetching URLs..."
    @State var installInfo: InstallAssistant?
    @State var downloadProgress: CGFloat = 0
    @State var buttonBG = Color.accentColor
    @State var invalidPassword = false
    @Binding var password: String
    @Binding var p: Int
    @Binding var overrideInstaller: Bool
    @Binding var track: ReleaseTrack
    @State var currentSize = 10
    @State var downloadSize = 10
    let timer = Timer.publish(every: 2, on: .current, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Text("Downloading Install Assistant Package").bold()
            Text("The Install Assistant is the file that contains the macOS installer used to, well, install macOS. In our case, we can't just use the app. Later on (the next step), we need to use the createinstallmedia tool provided by this package to create an installer USB. This USB drive then has to be patched so it will even let us boot into it. Simple enough, right?")
                .padding()
                .multilineTextAlignment(.center)
            ZStack {
                if downloadStatus == "Fetching URLs..." {
                    Color.secondary
                        .cornerRadius(10)
                        .frame(minWidth: 200, maxWidth: 450)
                    Text("Fetching URLs...")
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .onAppear {
                            DispatchQueue.global(qos: .background).async {
                                do {
                                    let allInstallInfo = try InstallAssistants(data: try Data(contentsOf: URL(string: "https://bensova.github.io/patched-sur/installers/\(track == .developer ? "Developer" : "Public").json")!))
                                    installInfo = allInstallInfo.sorted(by: { (one, two) -> Bool in
                                        if one.orderNumber > two.orderNumber {
                                            return true
                                        }
                                        return false
                                    })[0]
                                    downloadStatus = "Download macOS \(installInfo!.version)"
                                } catch {
                                    downloadStatus = error.localizedDescription
                                }
                            }
                        }
                        .padding(6)
                        .padding(.horizontal, 4)
                } else if downloadStatus.hasPrefix("Download macOS") {
                    Button {
                        if let sizeString = try? shellOut(to: "curl -sI \(installInfo!.url) | grep -i Content-Length | awk '{print $2}'"), let sizeInt = Int(sizeString) {
                            downloadSize = sizeInt
                        }
                        downloadStatus = downloadStatus.replacingOccurrences(of: "Download", with: "Downloading") + "..."
                    } label: {
                        ZStack {
                            buttonBG
                                .cornerRadius(10)
                            Text(downloadStatus)
                                .foregroundColor(.white)
                                .padding(6)
                                .padding(.horizontal, 4)
                        }
                        .onHover { (hovering) in
                            buttonBG = hovering ? Color.accentColor.opacity(0.7) : Color.accentColor
                        }
                    }.buttonStyle(BorderlessButtonStyle())
                } else if downloadStatus.hasPrefix("Downloading macOS ") {
                    VStack {
                        ZStack {
                            ProgressBar(value: $downloadProgress)
                                .onReceive(timer, perform: { _ in
                                    if let sizeCode = try? shellOut(to: "stat -f %z ~/.patched-sur/InstallAssistant.pkg") {
                                        currentSize = Int(Float(sizeCode) ?? 10000)
                                        downloadProgress = CGFloat(Float(sizeCode) ?? 10000) / CGFloat(downloadSize)
                                    }
                                })
                            Text(downloadStatus)
                                .foregroundColor(.white)
                                .lineLimit(5)
                                .padding(6)
                                .padding(.horizontal, 4)
                                .onAppear {
                                    _ = try? shellOut(to: "rm ~/.patched-sur/InstallAssistant.pkg")
                                    if (try? (try? File(path: "~/.patched-sur/InstallerVersion.txt"))?.readAsString()) == installInfo?.version {
                                        overrideInstaller = true
                                        downloadStatus = ""
                                        return
                                    }
                                    DispatchQueue.global(qos: .background).async {
                                        do {
                                            try shellOut(to: "curl -o InstallAssistant.pkg \(installInfo!.url)", at: "~/.patched-sur")
                                            let versionFile = try Folder(path: "~/.patched-sur").createFileIfNeeded(at: "InstallerVersion.txt")
                                            try versionFile.write(installInfo!.version, encoding: .utf8)
                                            downloadStatus = ""
                                        } catch {
                                            downloadStatus = error.localizedDescription
                                        }
                                    }
                                }
                        }
                    }
                } else if downloadStatus == "" {
                    HStack {
                        ZStack {
                            Color.secondary
                                .cornerRadius(10)
                                .frame(width: 300)
                                .opacity(0.7)
                            SecureField("Enter password to install...", text: $password)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .padding(6)
                                .padding(.horizontal, 4)
                                .disabled(false)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .colorScheme(.dark)
                        }
                        Button {
                            if password != "" {
                                do {
                                    try shellOut(to: "echo \"\(password)\" | sudo -S echo Hi")
                                    downloadStatus = "Installing Package..."
                                } catch {
                                    invalidPassword = true
                                    password = ""
                                }
                            }
                        } label: {
                            ZStack {
                                buttonBG
                                    .cornerRadius(10)
                                    .onHover(perform: { hovering in
                                        if !(password == "") {
                                            if invalidPassword {
                                                buttonBG = hovering ? Color.red.opacity(0.7) : Color.red
                                            } else {
                                                buttonBG = hovering ? Color.accentColor.opacity(0.7) : Color.accentColor
                                            }
                                        }
                                    })
                                Text("Continue")
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .padding(.horizontal, 10)
                            }
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .padding(.top, 10)
                        .opacity(password == "" ? 0.4 : 1)
                    }
                } else if downloadStatus == "Installing Package..." {
                    Color.secondary
                        .cornerRadius(10)
                    Text(downloadStatus)
                        .foregroundColor(.white)
                        .lineLimit(4)
                        .padding(6)
                        .padding(.horizontal, 4)
                        .onAppear {
                            DispatchQueue.global(qos: .background).async {
                                do {
                                    try shellOut(to: "echo \"\(password)\" | sudo -S installer -pkg ~/.patched-sur/InstallAssistant.pkg -target /")
                                    p = 5
                                } catch {
                                    downloadStatus = error.localizedDescription
                                }
                            }
                        }
                } else {
                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.declareTypes([.string], owner: nil)
                        pasteboard.setString(downloadStatus, forType: .string)
                    } label: {
                        ZStack {
                            buttonBG
                                .cornerRadius(10)
                                .frame(minWidth: 200, maxWidth: 450)
                                .onHover(perform: { hovering in
                                    buttonBG = hovering ? Color.red.opacity(0.7) : .red
                                })
                                .onAppear(perform: {
                                    if buttonBG != .red && buttonBG != Color.red.opacity(0.7) {
                                        buttonBG = .red
                                    }
                                })
                            Text(downloadStatus)
                                .foregroundColor(.white)
                                .lineLimit(4)
                                .padding(6)
                                .padding(.horizontal, 4)
                        }
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .fixedSize()
        }
    }
}

struct DownloadView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadView(p: .constant(2))
            .frame(minWidth: 500, maxWidth: 500, minHeight: 300, maxHeight: 300)
            .background(Color.white)
    }
}

struct ProgressBar: View {
    @Binding var value: CGFloat
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().frame(minWidth: 285)
                .opacity(0.3)
                .foregroundColor(Color(.systemTeal))
            
            Rectangle().frame(width: min(value*285, 285))
                .foregroundColor(Color(.systemBlue))
                .animation(.linear)
        }.cornerRadius(10)
    }
}