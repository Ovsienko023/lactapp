import Foundation
import SwiftUI

// MARK: - Типы данных и утилиты

/// Пример перечисления для форматов команды. Подберите реальные значения.
enum CommandFormatResponse: UInt8 {
    case byOne  = 0x01
    case byGroup = 0x02
}

/// Пример типа для хранения информации о значении (можно расширить, добавить дополнительные варианты).
enum ValueType: CustomStringConvertible {
    case unknown
    // Добавьте другие случаи по необходимости

    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        }
    }
}

/// Функция для определения типа значения по первому байту записи.
/// Реализуйте логику в соответствии со спецификацией вашего протокола.
func getValueType(_ rawValue: UInt8) -> ValueType {
    // Пример: если rawValue равен 0x00, возвращаем .unknown.
    return .unknown
}

/// Структура для хранения разобранной записи.
/// Conforming to Identifiable позволяет легко использовать записи в SwiftUI списках.
struct CommandRecord: Identifiable {
    let id: Int        // Уникальный идентификатор записи (сформированный из двух байт)
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let valueType: ValueType
    let value: Int
    let beforeMeal: Int
    
    var formattedDateTime: String {
            // Здесь секунды подставляем как 0, так как они отсутствуют
            return String(format: "%d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, 0)
        }
}

// MARK: - Функции для обработки данных

/// Обработка команды "ByOne" (одиночная запись).
func processCommandByOne(hexArray: [UInt8]) -> CommandRecord {
    // Индекс всегда 0, поскольку hexArray передаётся уже с нужного сдвига
    // Структура записи (байты):
    // [0] -> используется для определения valueType,
    // [1-2] -> id, [3-4] -> year, [5] -> month, [6] -> day,
    // [7] -> hour, [8] -> minute, [9-10] -> value, [11] -> beforeMeal
    let valueType = getValueType(hexArray[0])
    let id = (Int(hexArray[1]) << 8) | Int(hexArray[2])
    let year = (Int(hexArray[3]) << 8) | Int(hexArray[4])
    let month = Int(hexArray[5])
    let day = Int(hexArray[6])
    let hour = Int(hexArray[7])
    let minute = Int(hexArray[8])
    let value = (Int(hexArray[9]) << 8) | Int(hexArray[10])
    let beforeMeal = Int(hexArray[11])
    
    return CommandRecord(id: id,
                         year: year,
                         month: month,
                         day: day,
                         hour: hour,
                         minute: minute,
                         valueType: valueType,
                         value: value,
                         beforeMeal: beforeMeal)
}

/// Обработка команды "ByGroup" (групповая запись).
func processCommandByGroup(hexArray: [UInt8]) -> [CommandRecord] {
    var records: [CommandRecord] = []
    
    // Первый байт используется для определения valueType,
    // второй — для количества записей.
    let valueType = getValueType(hexArray[0])
    let size = Int(hexArray[1])
    
    // Начинаем со сдвига: в TypeScript index был равен 1, а затем использовался index+1 для первого байта записи.
    var count = 0
    var index = 1
    while count < size {
        // Обратите внимание, что в оригинальном коде используется:
        //   id: hexArray[index+1] и hexArray[index+2],
        //   year: hexArray[index+3] и hexArray[index+4],
        //   ...
        //   beforeMeal: hexArray[index+11]
        // При этом после каждой записи индекс увеличивается на 10.
        // Возможно, это особенность протокола. Здесь адаптируем буквально:
        let id = (Int(hexArray[index + 1]) << 8) | Int(hexArray[index + 2])
        let year = (Int(hexArray[index + 3]) << 8) | Int(hexArray[index + 4])
        let month = Int(hexArray[index + 5])
        let day = Int(hexArray[index + 6])
        let hour = Int(hexArray[index + 7])
        let minute = Int(hexArray[index + 8])
        let value = (Int(hexArray[index + 9]) << 8) | Int(hexArray[index + 10])
        let beforeMeal = Int(hexArray[index + 11])
        
        let record = CommandRecord(id: id,
                                   year: year,
                                   month: month,
                                   day: day,
                                   hour: hour,
                                   minute: minute,
                                   valueType: valueType,
                                   value: value,
                                   beforeMeal: beforeMeal)
        records.append(record)
        count += 1
        index += 10  // Обратите внимание: если логика записи подразумевает другое смещение, подкорректируйте это значение.
    }
    
    return records
}

/// Разбор входящей строки, содержащей шестнадцатеричные значения, разделённые пробелами.
func parseData(hexString: String) -> [CommandRecord] {
    // Преобразуем строку в массив UInt8.
    let components = hexString.split(separator: " ")
    let hexArray = components.compactMap { UInt8($0, radix: 16) }
    
    // Проверяем наличие заголовка: первые два байта должны быть 0xEB и 0x90.
    guard hexArray.count > 4, hexArray[0] == 0xEB, hexArray[1] == 0x90 else {
        return []
    }
    
    // Четвёртый индекс (то есть пятый байт) определяет тип команды.
    let command = hexArray[4]
    
    // Отбрасываем первые 5 байт (заголовок и тип команды)
    let payload = Array(hexArray.dropFirst(5))
    
//    if command == CommandFormatResponse.byOne.rawValue {
        let record = processCommandByOne(hexArray: payload)
        return [record]
//    }
    
    if command == CommandFormatResponse.byGroup.rawValue {
        return processCommandByGroup(hexArray: payload)
    }
    
    return []
}
