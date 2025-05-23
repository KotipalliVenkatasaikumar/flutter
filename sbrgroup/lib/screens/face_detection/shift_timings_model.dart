class ShiftTiming {
  final int id;
  final int referenceTypeId;
  final String commonRefKey;
  final String commonRefValue;
  final String? value;
  final String? name;
  final String? phoneNumberPattren;
  final String? refValue;
  final int? refOrder;

  ShiftTiming({
    required this.id,
    required this.referenceTypeId,
    required this.commonRefKey,
    required this.commonRefValue,
    this.value,
    this.name,
    this.phoneNumberPattren,
    this.refValue,
    this.refOrder,
  });

  factory ShiftTiming.fromJson(Map<String, dynamic> json) {
    return ShiftTiming(
      id: json['id'] ?? 0,
      referenceTypeId: json['referenceTypeId'] ?? 0,
      commonRefKey: json['commonRefKey'] ?? '',
      commonRefValue: json['commonRefValue'] ?? '',
      value: json['value'],
      name: json['name'],
      phoneNumberPattren: json['phoneNumberPattren'],
      refValue: json['refValue'],
      refOrder: json['refOrder'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'referenceTypeId': referenceTypeId,
      'commonRefKey': commonRefKey,
      'commonRefValue': commonRefValue,
      'value': value,
      'name': name,
      'phoneNumberPattren': phoneNumberPattren,
      'refValue': refValue,
      'refOrder': refOrder,
    };
  }
}
