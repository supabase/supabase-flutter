enum SupabaseEventTypes { insert, update, delete, all, broadcast, presence }

extension SupabaseEventTypesName on SupabaseEventTypes {
  String name() {
    final name = toString().split('.').last;
    if (name == 'all') {
      return '*';
    } else {
      return name.toUpperCase();
    }
  }
}
