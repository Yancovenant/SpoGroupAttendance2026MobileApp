class Gang {
  final int? id;
  final String name;
  final String? gangCode;
  final String? remarks;

  Gang({this.id, this.name = '', this.gangCode, this.remarks});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'gang_code': gangCode, 'remarks': remarks};

  factory Gang.fromMap(Map<String, dynamic> map) {
    return Gang(id: map['id'] as int?, name: map['name'] as String? ?? '',
        gangCode: map['gang_code'] as String?, remarks: map['remarks'] as String?);
  }
}