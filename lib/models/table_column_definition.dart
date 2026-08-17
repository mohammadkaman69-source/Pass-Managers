class TableColumnDefinition {
  String name;
  int? fieldId;

  TableColumnDefinition(
    this.name, {
    this.fieldId,
  });

  TableColumnDefinition copy() {
    return TableColumnDefinition(
      name,
      fieldId: fieldId,
    );
  }
}
