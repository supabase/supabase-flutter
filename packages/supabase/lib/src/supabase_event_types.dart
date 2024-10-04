@Deprecated('No longer used. May be removed in the future.')
enum SupabaseEventTypes { insert, update, delete, all, broadcast, presence }

// ignore: deprecated_member_use_from_same_package
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
