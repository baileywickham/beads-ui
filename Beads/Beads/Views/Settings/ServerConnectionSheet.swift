import SwiftUI

struct ServerConnectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onSave: (DoltConnection) -> Void

    @State private var name = ""
    @State private var host = ""
    @State private var port = "3306"
    @State private var user = "root"
    @State private var password = ""
    @State private var database = ""
    @State private var localPath = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var discoveredDatabases: [String] = []

    private enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Server") {
                    LabeledContent("Host") {
                        TextField("", text: $host, prompt: Text("10.0.1.50"))
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Port") {
                        TextField("", text: $port, prompt: Text("3306"))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    LabeledContent("Username") {
                        TextField("", text: $user, prompt: Text("root"))
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Password") {
                        SecureField("", text: $password, prompt: Text("optional"))
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Database") {
                    if discoveredDatabases.isEmpty {
                        LabeledContent("Name") {
                            TextField("", text: $database, prompt: Text("beads"))
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        LabeledContent("Name") {
                            Picker("", selection: $database) {
                                Text("Select...").tag("")
                                ForEach(discoveredDatabases, id: \.self) { db in
                                    Text(db).tag(db)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                Section("Optional") {
                    LabeledContent("Display Name") {
                        TextField("", text: $name, prompt: Text("My Dolt Server"))
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Local Path") {
                        TextField("", text: $localPath, prompt: Text("~/workspace/myproject"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .formStyle(.grouped)

            if let result = testResult {
                HStack(spacing: 6) {
                    switch result {
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected")
                    case .failure(let message):
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(message)
                            .lineLimit(2)
                    }
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                Button("Test Connection") {
                    testConnection()
                }
                .disabled(host.isEmpty || isTesting)

                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Connect") {
                    let conn = DoltConnection(
                        host: host,
                        port: Int(port) ?? 3306,
                        user: user,
                        password: password.isEmpty ? nil : password,
                        database: database,
                        name: name.isEmpty ? nil : name,
                        localPath: localPath.isEmpty ? nil : (localPath as NSString).expandingTildeInPath
                    )
                    onSave(conn)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(host.isEmpty || database.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480)
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        discoveredDatabases = []
        let conn = DoltConnection(
            host: host,
            port: Int(port) ?? 3306,
            user: user,
            password: password.isEmpty ? nil : password,
            database: database.isEmpty ? "information_schema" : database
        )
        Task {
            let ds = DoltDataSource(connection: conn)
            defer { Task { await ds.close() } }
            do {
                let databases = try await ds.discoverDatabases()
                discoveredDatabases = databases
                testResult = .success
                // Auto-select first database if none chosen
                if database.isEmpty, let first = databases.first {
                    database = first
                }
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }
}
