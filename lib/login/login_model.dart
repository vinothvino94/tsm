class LoginModel {
  final String empCode;
  final String empPass;
  final String oldEmpPass;

  LoginModel({
    required this.empCode,
    required this.empPass,
    required this.oldEmpPass,
  });

  Map<String, dynamic> toJson() => {
        'EMPCODE': empCode,
        'EMPPASS': empPass,
        'OLDEMPPASS': oldEmpPass,
      };

  factory LoginModel.fromJson(Map<String, dynamic> json) {
    return LoginModel(
      empCode: json['EMPCODE'],
      empPass: json['EMPPASS'],
      oldEmpPass: json['OLDEMPPASS'],
    );
  }
}
