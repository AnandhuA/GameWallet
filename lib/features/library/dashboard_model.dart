import '../../core/models.dart';
import '../../core/companion_models.dart';

/// Pure selectors over local records. Undated legacy finishes are not recent.
class DashboardModel {
  final List<PlaySessionPlan> plans;
  final List<(Game, GamePlaythrough)> finishes;
  DashboardModel(
    List<LibraryEntry> entries,
    List<PlaySessionPlan> sessions,
    DateTime now,
  ) : plans =
          (sessions
                  .where(
                    (p) =>
                        !p.completed &&
                        (p.hasTime
                            ? !p.scheduled.isBefore(now)
                            : !calendarDate(
                                p.scheduled,
                              ).isBefore(calendarDate(now))),
                  )
                  .toList()
                ..sort((a, b) => a.scheduled.compareTo(b.scheduled)))
              .take(2)
              .toList(),
      finishes =
          (entries
                  .expand(
                    (e) => e.playthroughs
                        .where((r) => r.completed && r.endDate != null)
                        .map((r) => (e.game, r)),
                  )
                  .toList()
                ..sort((a, b) => b.$2.endDate!.compareTo(a.$2.endDate!)))
              .take(3)
              .toList();
}
