import SwiftUI
import CoreBluetooth

struct DeviceDetailView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral
    
    var body: some View {
        VStack {
            if !bluetoothManager.lactateData.isEmpty {
                List {
                    ForEach(bluetoothManager.lactateData, id: \.self) { data in
                        Text(data)
                            .font(.headline)
                            .padding()
                    }
                }
                .navigationTitle("Измерения")
            } else {
                Text("Получение данных...")
                    .font(.headline)
                    .padding()
            }
        }
        .onAppear {
            bluetoothManager.stopScanning() // Останавливаем поиск
            bluetoothManager.connect(to: peripheral) // Подключаемся к устройству
        }
        .onDisappear {
            bluetoothManager.disconnect() // Отключаемся при выходе из экрана
        }
    }
}
