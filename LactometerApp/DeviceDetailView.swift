import SwiftUI
import CoreBluetooth


struct DeviceDetailView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    let peripheral: CBPeripheral

    // Группируем записи по дате (формат "yyyy.MM.dd"), при этом сохраняем сортировку по id (от большего к меньшему)
    var sortedGroupedRecords: [(date: String, records: [LactateRecord])] {
        // Сортируем записи по id, от большего к меньшему
        let sortedRecords = bluetoothManager.lactateDataValue.sorted { $0.id > $1.id }
        var groups: [(String, [LactateRecord])] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"

        // Группируем записи, сохраняя порядок
        for record in sortedRecords {
            let dateKey = record.formattedDateStringForView()

            if let lastGroup = groups.last, lastGroup.0 == dateKey {
                groups[groups.count - 1].1.append(record)
            } else {
                groups.append((record.formattedDateStringForView(), [record]))
            }
        }

        return groups
    }

    var body: some View {
        VStack {



            if !bluetoothManager.lactateDataValue.isEmpty {

                HStack {
                   Text("Время")
                       .font(.headline)
                       .frame(maxWidth: .infinity, alignment: .leading)
                   Text("Значение")
                       .font(.headline)
                       .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding([.horizontal, .top])
                .foregroundColor(.primary)

                List {
                    ForEach(sortedGroupedRecords, id: \.date) { group in
                        Section(header: Text(group.date)) {

                            ForEach(group.records, id: \.id) { record in
                                HStack {
                                    Text(record.formattedDateStringHMS())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    Text(record.formattedValueToString())
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
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

