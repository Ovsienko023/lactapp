import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var lactateData: [String] = []
    @Published var connectedPeripheral: CBPeripheral?
    
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
        guard let name = peripheral.name, !name.isEmpty, name != "Неизвестное устройство" else {
            return // Игнорируем устройства без имени или с именем "Неизвестное устройство"
        }
        
        if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
            DispatchQueue.main.async {
                self.discoveredDevices.append(peripheral)
                self.discoveredDevices.sort { $0.name ?? "" < $1.name ?? "" } // Сортировка по имени
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
            } else if characteristic.uuid == writeCharacteristicUUID {
                // Отправляем запрос для получения данных
                let requestData = Data([0x04, 0x07,
                                        0x00, 0x01,
                                        0xFF, 0xFF]) // Пример запроса (замените на нужные данные)
                peripheral.writeValue(requestData, for: characteristic, type: .withResponse)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value, !data.isEmpty {
            if characteristic.uuid == subscriptionCharacteristicUUID {
                // Декодируем данные о лактате
                let lactateLevel = decodeLactateData(data)
                print("Получен уровень лактата: \(lactateLevel)")
                
                DispatchQueue.main.async {
                    self.lactateData.append(lactateLevel)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == writeCharacteristicUUID {
            print("Запрос отправлен успешно")
        }
    }
    
    // Декодирование данных о лактате
    private func decodeLactateData(_ data: Data) -> String {
        let value = data.withUnsafeBytes { $0.load(as: Float.self) }
        return String(format: "%.2f", value)
    }
}
