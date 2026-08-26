class AppCategories {
  static const String grocery = 'Grocery';
  static const String pharmacy = 'Pharmacy';
  static const String stationery = 'Stationery';
  static const String hardware = 'Hardware';

  static const List<String> allCategories = [
    grocery,
    pharmacy,
    stationery,
    hardware,
  ];

  static const Map<String, List<String>> subcategories = {
    grocery: ['Rice', 'Flour', 'Oil', 'Pulses', 'Spices', 'Beverages', 'Snacks'],
    pharmacy: ['First Aid', 'OTC Medicines', 'Personal Care', 'Baby Care', 'Supplements'],
    stationery: ['Notebooks', 'Pens & Markers', 'Paper', 'Office Supplies', 'Art Supplies'],
    hardware: ['Tools', 'Electrical', 'Plumbing', 'Paints', 'Fasteners'],
  };
}
