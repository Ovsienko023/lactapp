import SwiftUI

struct ContentView: View {
    @StateObject private var bluetoothManager = BluetoothManager()
    
    var body: some View {
        NavigationView {
            VStack {
                if bluetoothManager.discoveredDevices.isEmpty {
                    Text("Поиск устройств...")
                        .font(.headline)
                        .padding()
                } else {
                    List {
                        ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { peripheral in
                            NavigationLink(destination: DeviceDetailView(bluetoothManager: bluetoothManager, peripheral: peripheral)) {
                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Неизвестное устройство")
                                        .font(.headline)
                                    Text("ID: \(peripheral.identifier.uuidString)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Доступные устройства")
            .onAppear {
                bluetoothManager.startScanning()
            }
        }
    }
}
