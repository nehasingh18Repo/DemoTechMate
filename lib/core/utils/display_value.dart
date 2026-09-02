String displayValue(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'NA';
  }
  return value.trim();
}
