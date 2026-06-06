import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  Future<void> saveUserDetails(
    String empName,
    int empCode,
    int empSite,
    int empBran,
    String empDept,
    String empTL,
    String sales,
    bool hasSalesAccess,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('empName', empName);
    await prefs.setInt('empCode', empCode);
    await prefs.setInt('empSite', empSite); // ✅ Corrected key
    await prefs.setInt('empBran', empBran); // ✅ Corrected key
    await prefs.setString('hriIfscCode', empDept); // ✅ Corrected key
    await prefs.setString('hriAccNo', empTL); // ✅ Corrected key
    await prefs.setString('hriAmount', sales); // ✅ Corrected key
    await prefs.setBool('hasSalesAccess', hasSalesAccess);
  }

  Future<int?> getEmpCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('empCode');
  }

  Future<String?> getEmpName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('empName');
  }

  Future<String?> getEmpPass() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('empPass');
  }

  Future<int?> getEmpSite() async {
    // ✅ Change return type to int?
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('empSite'); // ✅ Corrected key
  }

  Future<int?> getEmpBran() async {
    // ✅ Change return type to int?
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('empBran'); // ✅ Corrected key
  }

  Future<String?> getEmpDept() async {
    // ✅ Change return type to int?
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('hriIfscCode'); // ✅ Corrected key
  }

  Future<String?> getEmpTL() async {
    // ✅ Change return type to int?
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('hriAccNo'); // ✅ Corrected key
  }

  Future<String?> getSalesDetails() async {
    // ✅ Change return type to int?
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('hriAmount'); // ✅ Corrected key
  }

  Future<bool> hasSalesAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hasSalesAccess') ?? false;
  }

  Future<void> savePoType(String poType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('poType', poType);
  }

  Future<String?> getPoType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('poType');
  }
}
