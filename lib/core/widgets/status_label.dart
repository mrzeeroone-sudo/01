import '../../data/models/item_status.dart';
import '../l10n/app_localizations.dart';

String statusLabel(AppLocalizations l10n, ItemStatus status) =>
    switch (status) {
      ItemStatus.newItem => l10n.statusNew,
      ItemStatus.assigned => l10n.statusAssigned,
      ItemStatus.bought => l10n.statusBought,
      ItemStatus.deferred => l10n.statusDeferred,
      ItemStatus.rejected => l10n.statusRejected,
      ItemStatus.cancelled => l10n.statusCancelled,
    };
