class TableColumnDefinition {
  String name;

  TableColumnDefinition(this.name);

  TableColumnDefinition copy() {
    return TableColumnDefinition(name);
  }
}
