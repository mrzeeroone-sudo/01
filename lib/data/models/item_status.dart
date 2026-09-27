/// يطابق النوع public.item_status في supabase/schema.sql.
enum ItemStatus {
  newItem('new'),
  assigned('assigned'),
  bought('bought'),
  deferred('deferred'),
  rejected('rejected'),
  cancelled('cancelled');

  const ItemStatus(this.dbValue);

  final String dbValue;

  static ItemStatus fromDb(String value) => values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => throw ArgumentError.value(value, 'item_status'),
  );
}
