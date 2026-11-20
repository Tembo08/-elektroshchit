import 'package:flutter/material.dart';

/// «О приложении»: версия, назначение, политика конфиденциальности и
/// предупреждение о том, что расчёт черновой. Текст политики продублирован
/// здесь, чтобы он был доступен без интернета — этого требует магазин.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Держать в одном месте с pubspec.yaml (version: 1.0.1+2).
  static const _version = '1.1.1';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.electrical_services,
                  color: scheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Электрощит',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Версия $_version',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Расчёт квартирного и домового электрощита: линии, автоматы, УЗО, '
            'кабель, падение напряжения, спецификация и PDF-отчёт.',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Важно'),
          _paragraph(
            context,
            'Результат расчёта — черновик. Он не заменяет проект, '
            'подписанный электриком с допуском. Перед закупкой и монтажом '
            'проверьте схему со специалистом.',
          ),
          const SizedBox(height: 20),
          _sectionTitle(context, 'Конфиденциальность'),
          _paragraph(
            context,
            'Приложение не собирает и не передаёт персональные данные. '
            'Названия объектов, комнаты, мощности и длины трасс хранятся '
            'только на этом устройстве.',
          ),
          _paragraph(
            context,
            'Нет аналитики, рекламы и облачной синхронизации. Данные не '
            'покидают устройство: расчёт идёт локально, PDF вы сохраняете '
            'сами — тем способом, который выберете.',
          ),
          _paragraph(
            context,
            'Удалить проект можно в разделе «Мои проекты». Полное удаление '
            'данных — при удалении приложения.',
          ),
          const SizedBox(height: 20),
          _sectionTitle(context, 'Нормы'),
          _paragraph(
            context,
            'Сечения, автоматы, УЗО, коэффициенты спроса и лимиты берутся из '
            'справочника внутри приложения (ПУЭ, СП 256.1325800) и не '
            'заменяют официальные документы.',
          ),
          const SizedBox(height: 28),
          Text(
            'Сделано для электриков и тех, кто собирает щит своими руками.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      );

  Widget _paragraph(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
