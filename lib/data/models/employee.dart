class Employee {
  final int? id;
  final String? externalId;
  final String name;
  final String? gender;
  final String? gangCode;
  final int? gangId;
  final bool isActive;

  Employee({
    this.id,
    this.externalId,
    this.name = '',
    this.gender,
    this.gangCode,
    this.gangId,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'external_id': externalId, 'name': name,
      'gender': gender, 'gang_code': gangCode, 'gang_id': gangId,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?, externalId: map['external_id'] as String?,
      name: map['name'] as String? ?? '', gender: map['gender'] as String?,
      gangCode: map['gang_code'] as String?, gangId: map['gang_id'] as int?,
      isActive: (map['is_active'] as int?) == 1,
    );
  }
}