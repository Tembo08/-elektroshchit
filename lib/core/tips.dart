/// Подсказки для начинающих электриков.
///
/// Показываются контекстно — на своём экране, маленькой карточкой внизу,
/// чтобы не мешать работе. Полный список — на экране «Шпаргалка».
class Tip {
  final String id;
  final TipScreen screen;
  final String text;

  const Tip({required this.id, required this.screen, required this.text});
}

enum TipScreen { home, rooms, input, lines, overview, result }

const List<Tip> kTips = [
  Tip(
    id: 'sockets-16a',
    screen: TipScreen.rooms,
    text: 'Розеточная группа: автомат 16 А, кабель 2.5 мм², не больше '
        '10 точек. Вилки и розетки тоже на 16 А — больше автомат не защитит.',
  ),
  Tip(
    id: 'powerful-separate',
    screen: TipScreen.rooms,
    text: 'Варочная, духовка, бойлер, стиралка, зарядка электромобиля (EV) — '
        'отдельные линии. Не «сажай» их на общие розетки: летом это первое, '
        'что выбивает.',
  ),
  Tip(
    id: 'bath-10ma',
    screen: TipScreen.rooms,
    text: 'Санузел — отдельное УЗО 10 мА (по ПУЭ достаточно 30 мА, но практика '
        'для мокрых зон — 10). Стиралке и посудомойке нужен тип A.',
  ),
  Tip(
    id: 'tu-from-contract',
    screen: TipScreen.input,
    text: 'Мощность бери из ТУ (технических условий — цифра из договора на '
        'подключение), а не «на глаз». Ошибка на этом шаге делает весь щиток '
        'неправильным.',
  ),
  Tip(
    id: 'input-not-bigger',
    screen: TipScreen.input,
    text: 'Вводной автомат не выше того, что разрешено ТУ. Автомат защищает '
        'вводной кабель и счётчик, а не приборы в доме.',
  ),
  Tip(
    id: 'lines-light-socket',
    screen: TipScreen.lines,
    text: 'Освещение — 10 А и 1.5 мм², розетки — 16 А и 2.5 мм². '
        'Не экономь на линиях: одна группа на всю квартиру — плохая идея.',
  ),
  Tip(
    id: 'lines-points',
    screen: TipScreen.lines,
    text: 'В группе больше 10 розеток или 15 светильников? Дели на линии — '
        'приложение сделает это само, но лучше заранее.',
  ),
  Tip(
    id: 'rcd-selective',
    screen: TipScreen.overview,
    text: 'На вводе — противопожарное УЗО 100 мА тип S, на группах — 30 мА. '
        'Селективность: сначала отключается группа, а не весь дом.',
  ),
  Tip(
    id: 'section-vs-breaker',
    screen: TipScreen.result,
    text: 'Сечение кабеля должно быть не меньше, чем требует автомат: '
        '2.5→16 А, 4→25 А, 6→32 А, 10→40 А, 16→63 А. Проверь строки '
        'с предупреждением.',
  ),
  Tip(
    id: 'check-on-site',
    screen: TipScreen.result,
    text: 'Это черновик. На объекте: протяни клеммы, подпиши линии, сфотографируй '
        'щит до закрытия и повесь схему на дверцу.',
  ),
  Tip(
    id: 'copper-aluminium',
    screen: TipScreen.home,
    text: 'Медь с алюминием — только через клеммы или гильзы. Скрутки греются '
        'и выгорают — это самая частая причина пожаров в щитах.',
  ),
  Tip(
    id: 'long-line',
    screen: TipScreen.home,
    text: 'Длинная линия 16 А на 2.5 мм² (больше ~30 м) — проверь падение '
        'напряжения вручную: просадка больше 5% уже проблема.',
  ),
];

List<Tip> tipsFor(TipScreen screen) =>
    kTips.where((t) => t.screen == screen).toList(growable: false);
