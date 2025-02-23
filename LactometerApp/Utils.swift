import Foundation


enum NumberConversionError: Error {
    case numberOutOfRange
}

func numberToTwoBytes(_ num: Int) -> [UInt8]? {
    guard num >= 0 && num <= 0xFFFF else { return nil }
    
    let highByte = UInt8((num >> 8) & 0xFF)
    let lowByte = UInt8(num & 0xFF)
    
    return [highByte, lowByte]
}


/// Вычисляет CRC для массива байт, суммируя их с переполнением по модулю 0xFFFF
func calculateCRC(for data: [UInt8]) -> UInt16 {
    var crc: UInt16 = 0
    for byte in data {
        // Используем &+ для переполнения с обёртыванием
        crc = (crc &+ UInt16(byte)) & 0xFFFF
    }
    return crc
}

/// Формирует команду для отправки.
/// - Parameters:
///   - ackRequired: Требуется ли подтверждение (ACK). Если true, добавляется байт 0x01, иначе 0x00.
///   - command: Массив байт с данными команды.
/// - Returns: Итоговый массив байт команды.
func createCommand(ackRequired: Bool, command: [UInt8]) -> [UInt8] {
    // Фиксированный заголовок и переданные данные
    let baseCommand: [UInt8] = [0xEB, 0x90, 0x00, 0x0D] + command

    // Добавляем байт подтверждения
    let ack: UInt8 = ackRequired ? 0x01 : 0x00
    let commandWithAck = baseCommand + [ack]
    
    // Вычисляем CRC для полученной команды
    let crc = calculateCRC(for: commandWithAck)
    let crcBytes: [UInt8] = [
        UInt8((crc >> 8) & 0xFF),  // Старший байт
        UInt8(crc & 0xFF)          // Младший байт
    ]
    
    // Завершающие байты (CR и LF)
    let endPosition: [UInt8] = [0x0D, 0x0A]
    
    // Формируем итоговую команду
    return commandWithAck + crcBytes + endPosition
}

func formattedDateString(from timestamp: Double) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
    
    let newDate = date.addingTimeInterval(158387990) // разница в секундах
    return dateFormatter.string(from: newDate)
}
