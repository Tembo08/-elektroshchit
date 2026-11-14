/// Тип объекта
enum ObjectType {
  apartment,      // Квартира
  privateHouse,   // Частный дом
}

/// Система фаз
enum PhaseSystem {
  single,         // 1 фаза
  three,          // 3 фазы
}

/// Система заземления
enum GroundingSystem {
  tnCs,           // TN-C-S
  tnS,            // TN-S
  tt,             // TT
}

/// Тип комнаты
enum RoomType {
  kitchen,
  livingRoom,
  bedroom,
  childrenRoom,
  bathroom,
  toilet,
  combinedBathroom,
  hallway,
  entrance,       // Прихожая
  pantry,
  balcony,
  technical,
  other,
}

/// Тип потребителя / точки
enum ConsumerType {
  // Обычные точки
  socket,
  switchSingle,
  switchDouble,
  switchPassThrough,
  lightPoint,
  chandelier,
  ledStrip,

  // Мощные потребители
  electricStove,
  oven,
  dishwasher,
  washingMachine,
  waterHeater,
  airConditioner,
  underfloorHeating,
  evCharger,
  refrigerator,
  hood,
  boiler,
  otherPowerful,
}

/// Как группировать освещение
enum LightingGrouping {
  perRoom,    // отдельная линия на каждую комнату
  singleLine, // одна линия на весь объект
  twoZones,   // две линии (зоны)
}
