import Foundation

// MARK: - Класс для работы с UserDefaults
class UserDefaultsRepo {
    /// Ключ, по которому хранится весь словарь в UserDefaults
    private let storageKey = "lactateRecordsStorage"

    /// Используем стандартный UserDefaults, можно подставить другой для тестирования
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Вложенная структура: внешний словарь, где ключ — String, а значение — внутренний словарь,
    /// в котором ключ — String, а значение — LactateRecord.
    private var storage: [String: [String: LactateRecord]] {
        get {
            guard let data = defaults.data(forKey: storageKey) else { return [:] }
            do {
                let dict = try JSONDecoder().decode([String: [String: LactateRecord]].self, from: data)
                return dict
            } catch {
                print("Ошибка декодирования данных: \(error)")
                return [:]
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                defaults.set(data, forKey: storageKey)
            } catch {
                print("Ошибка кодирования данных: \(error)")
            }
        }
    }

    func getDeviceIDs() -> String {
        // Чтение значения
        if let greeting = defaults.string(forKey: "deviceID") {
            return greeting
        }
        return ""
    }

    func setDeviceID(value: String) {
        defaults.set(value, forKey: "deviceID")
    }

    // MARK: - CRUD операции

    /// Получить запись для заданных outerKey и innerKey.
    func getRecord(outerKey: String, innerKey: String) -> LactateRecord? {
        return storage[outerKey]?[innerKey]
    }

    /// Получить все записи для заданного outerKey.
    func getRecords(for outerKey: String) -> [String: LactateRecord] {
        return storage[outerKey] ?? [:]
    }

    func getRecordWithLatestId(for outerKey: String) -> Int {
        // Получаем все записи для данного outerKey
        let records = getRecords(for: outerKey)

        // Извлекаем все id из записей
        let ids = records.values.map { $0.id }

        // Возвращаем максимальный id или 0, если массив пустой
        let qwe = ids.max() ?? 0
        print(qwe)
        return qwe
    }

    /// Добавить или обновить запись для заданных outerKey и innerKey.
    func setRecord(_ record: LactateRecord, for outerKey: String, innerKey: String) {
        var currentStorage = storage
        var innerDict = currentStorage[outerKey] ?? [:]
        innerDict[innerKey] = record
        currentStorage[outerKey] = innerDict
        storage = currentStorage
    }

    /// Удалить запись по outerKey и innerKey.
    func deleteRecord(for outerKey: String, innerKey: String) {
        var currentStorage = storage
        guard var innerDict = currentStorage[outerKey] else { return }
        innerDict.removeValue(forKey: innerKey)
        currentStorage[outerKey] = innerDict
        storage = currentStorage
    }
}
