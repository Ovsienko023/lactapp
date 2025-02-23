import Foundation
import CoreBluetooth

struct LactateRecord: Codable, Hashable {
    let id: Int
    let timestamp: Double
    let value: Float

    func toString() -> String {
        return String(format: "%.1f моль/л - %@ (%d)",  value, self.formattedDateStringHMS(), id)
    }

    func formattedValueToString() -> String {
        return String(format: "%.1f", value)
    }

    func formattedDateString() -> String {
        let date = Date(timeIntervalSince1970: self.timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm:ss"

        let newDate = date.addingTimeInterval(158387990) // разница в секундах
        return dateFormatter.string(from: newDate)
    }

    func formattedDateStringHMS() -> String {
        let date = Date(timeIntervalSince1970: self.timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        let newDate = date.addingTimeInterval(158387990) // разница в секундах
        return dateFormatter.string(from: newDate)
    }

    func formattedDateStringForView() -> String {
        let date = Date(timeIntervalSince1970: self.timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd"

        let newDate = date.addingTimeInterval(158387990) // разница в секундах
        return dateFormatter.string(from: newDate)
    }
}

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var lactateData: [String] = []
    @Published var lactateDataValue: [LactateRecord] = []
    @Published var connectedPeripheral: CBPeripheral?

    private var repo = UserDefaultsRepo()
    private var centralManager: CBCentralManager!
    private let serviceUUID = CBUUID(string: "8653000A-43E6-47B7-9CB0-5FC21D4AE340") // UUID сервиса
    private let subscriptionCharacteristicUUID = CBUUID(string: "8653000B-43E6-47B7-9CB0-5FC21D4AE340") // UUID для подписки
    private let writeCharacteristicUUID = CBUUID(string: "8653000C-43E6-47B7-9CB0-5FC21D4AE340") // UUID для отправки сообщений

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth включен")
            startScanning()
        } else {
            print("Bluetooth не доступен")
        }
    }

    func startScanning() {
        print("Начинаю сканирование...")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    func stopScanning() {
        print("Остановка сканирования...")
        centralManager.stopScan()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name,
                  !name.isEmpty,
                  name != "Неизвестное устройство",
                  name.contains("Eaglenos") else {
                return // Игнорируем устройства, у которых нет имени, имя пустое, равно "Неизвестное устройство" или не содержит "Eaglenos"
            }

        self.repo.setDeviceID(value: peripheral.identifier.uuidString)

        // Выполняем проверку и добавление в главный поток
            DispatchQueue.main.async {
                // Если устройства с таким идентификатором ещё нет в массиве, добавляем его
                if !self.discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                    self.discoveredDevices.append(peripheral)
                    self.discoveredDevices.sort { ($0.name ?? "") < ($1.name ?? "") } // Сортировка по имени
                }
            }
    }

    // Подключение к устройству
    func connect(to peripheral: CBPeripheral) {
        print("Попытка подключения к устройству: \(peripheral.name ?? "Неизвестное устройство")")
        centralManager.connect(peripheral, options: nil)
        connectedPeripheral = peripheral
        peripheral.delegate = self
    }

    // Отключение от устройства
    func disconnect() {
        if let peripheral = connectedPeripheral {
            print("Отключение от устройства: \(peripheral.name ?? "Неизвестное устройство")")
            centralManager.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
        }
    }

    // MARK: - CBPeripheralDelegate

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Подключено к устройству: \(peripheral.name ?? "Неизвестное устройство")")
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            print("Обнаружен сервис: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            print("Обнаружена характеристика: \(characteristic.uuid)")

            if characteristic.uuid == subscriptionCharacteristicUUID {
                // Подписываемся на уведомления для получения данных
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == writeCharacteristicUUID {

                if let uuidString = service.peripheral?.identifier.uuidString {
                let recordID = self.repo.getRecordWithLatestId(for: uuidString)

                if recordID == 0 {
                    print("sendLactateAllData")
                    sendLactateAllData(peripheral: peripheral, characteristic: characteristic)
                } else {
                    let deviceID = self.repo.getDeviceIDs()

                    // Отправка кешированных данных
                    let sortedRecords: [LactateRecord] = Array(self.repo.getRecords(for: deviceID).values)
                        .sorted { $0.id > $1.id }

                    sortedRecords.forEach { record in
                        DispatchQueue.main.async {
                            if !self.lactateDataValue.contains(where: { $0.id == record.id }) {
                                self.lactateDataValue.append(record)
                            }
                        }
                    }

                    print("sendLactateDataWithID \(recordID)")
                    sendLactateDataWithID(peripheral: peripheral, characteristic: characteristic, startRecordID: UInt(recordID))
                }
            }
            }
        }
    }

    func sendLactateAllData(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let commandBytes: [UInt8] = [0x04, 0x07, 0x00, 0x01, 0xFF, 0xFF]
        let requestData = Data(createCommand(ackRequired: true, command: commandBytes))

        // Отправляем команду
        peripheral.writeValue(requestData, for: characteristic, type: .withResponse)

        print("Отправлена команда: \(commandBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }

    func sendLactateDataWithID(peripheral: CBPeripheral, characteristic: CBCharacteristic, startRecordID: UInt) {
        var commandBytes: [UInt8] = [0x04] // Используем `0x04`

        // Если передан `1`, попробуем `0`, так как устройство может его игнорировать
        let adjustedStartID = (startRecordID == 1) ? 0 : startRecordID - 2

        // Рассчитываем параметр X для точного выбора ID
        let offsetValue = UInt8((adjustedStartID / 2) * 2 + 1)

        commandBytes += [0x07, 0x00, offsetValue] // Управляем точкой старта

        // Передаём Start ID (Big-Endian)
        commandBytes += [
            UInt8((adjustedStartID >> 24) & 0xFF),
            UInt8((adjustedStartID >> 16) & 0xFF),
            UInt8((adjustedStartID >> 8) & 0xFF),
            UInt8(adjustedStartID & 0xFF)
        ]

        // Если Start ID = 1, запрашиваем `Final ID = 2`, чтобы получить и 1, и 2
        let finalID = (startRecordID == 1) ? 2 : adjustedStartID + 1
        commandBytes += [
            UInt8((finalID >> 24) & 0xFF),
            UInt8((finalID >> 16) & 0xFF),
            UInt8((finalID >> 8) & 0xFF),
            UInt8(finalID & 0xFF)
        ]

        // ACK + контрольный параметр
        commandBytes += [0x01, 0x03]

        let requestData = Data(createCommand(ackRequired: true, command: commandBytes))

        // Отправляем команду
        peripheral.writeValue(requestData, for: characteristic, type: .withResponse)

        print("Отправлена команда: \(commandBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }

    // Метод для обработки получаемых сообщений
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Проверяем, не возникла ли ошибка при обновлении значения
        if let error = error {
            print("Ошибка обновления значения для характеристики \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        let deviceID = repo.getDeviceIDs()

        // Проверяем, что данные получены и не пустые
        guard let data = characteristic.value, !data.isEmpty else {
            print("Не получено данных для характеристики \(characteristic.uuid)")
            return
        }

        // Обработка данных для характеристики, на которую мы подписались
        if characteristic.uuid == subscriptionCharacteristicUUID {
            let record = decodeLactateData(data)


            if let dbrec = repo.getRecord(outerKey: deviceID, innerKey: String(record.id)){
            } else {
                self.repo.setRecord(record, for: deviceID, innerKey: String(record.id))
                print("add rec in db\(record.id)")
                print("add rec in array: \(record.id)")
        }

            // Обновляем UI (или другие наблюдаемые свойства) на главном потоке
            DispatchQueue.main.async {
                if !self.lactateDataValue.contains(where: { $0.id == record.id }) {
                    self.lactateDataValue.append(record)
                }
            }
        } else {
            // Если данные получены от неизвестной характеристики, можно обработать их иначе или вывести сообщение
            print("Получены данные от неизвестной характеристики \(characteristic.uuid): \(data)")
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == writeCharacteristicUUID {
            print("Запрос отправлен успешно")
        }
    }

    private func decodeLactateData(_ data: Data) -> LactateRecord {
            // Преобразуем Data в строку шестнадцатеричных значений, разделённых пробелами,
            // например: "EB 90 00 0D 01 00 10 ..."
            let hexString = data.map { String(format: "%02X", $0) }
                                .joined(separator: " ")

            // Парсим строку с помощью функции parseData, которая возвращает массив CommandRecord
            let records = parseData(hexString: hexString)

            guard let firstRecord = records.first else {
                return LactateRecord(id:0,  timestamp: Date().timeIntervalSince1970 * 1000, value: 0)
            }

            let lactateValue = Float(firstRecord.value) / 10
            let record = LactateRecord(id: firstRecord.id, timestamp: firstRecord.timestamp, value: lactateValue)

            return record
        }

}
