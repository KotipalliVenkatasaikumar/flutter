class ScanSchedule {
  final int scheduleId;
  final int scheduleTimeId;
  final String projectName;
  final String location;
  final String scheduleTime;
  final String status;
  final String userName;

  ScanSchedule({
    required this.scheduleId,
    required this.scheduleTimeId,
    required this.projectName,
    required this.location,
    required this.scheduleTime,
    required this.status,
    required this.userName,
  });

  // Convert a ScanSchedule instance into a Map
  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'scheduleTimeId': scheduleTimeId,
      'projectName': projectName,
      'location': location,
      'scheduleTime': scheduleTime,
      'status': status,
      'userName': userName,
    };
  }

  // Convert a Map into a ScanSchedule instance
  factory ScanSchedule.fromMap(Map<String, dynamic> map) {
    return ScanSchedule(
      scheduleId: map['scheduleId'],
      scheduleTimeId: map['scheduleTimeId'],
      projectName: map['projectName'],
      location: map['location'],
      scheduleTime: map['scheduleTime'],
      status: map['status'],
      userName: map['userName'],
    );
  }

  // Convert a JSON object into a ScanSchedule instance
  factory ScanSchedule.fromJson(Map<String, dynamic> json) {
    return ScanSchedule(
      scheduleId: json['scheduleId'],
      scheduleTimeId: json['scheduleTimeId'],
      projectName: json['projectName'],
      location: json['location'],
      scheduleTime: json['scheduleTime'],
      status: json['status'],
      userName: json['userName'],
    );
  }
}
