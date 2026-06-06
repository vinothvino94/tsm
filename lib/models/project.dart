import 'package:flutter/cupertino.dart';

class Project {
  final int projectId;
  final String projectName;

  Project({
    required this.projectId,
    required this.projectName,
  });

  // ✅ fromJson constructor
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      projectId: int.tryParse(json['PROJECTID'].toString()) ?? 0,
      projectName: json['PROJECTNAME'] ?? '',
    );
  }

  // ✅ Optional: toString override for displaying in dropdown
  @override
  String toString() => '$projectId - $projectName';

  // ✅ Equality for DropdownSearch
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId;

  @override
  int get hashCode => projectId.hashCode;
}

class TimesheetEntry {
  List<Map<String, dynamic>> elementItems;
  String elementId;
  String type;
  String workType;
  String remarks;
  int? projectId;

  // Store as string, but handle both decimal and time formats
  String totHrs = "0:00"; // Default to time format

  int tsSlNo;
  String? projectName;
  bool isModified = false;
  DateTime? entryDate;
  bool isSelected = false;
  String status = '';
  bool isExisting = false;

  bool canEdit = false;
  bool isEdited;
  String? designingDrafting;
  String? draftingType;
  String? deptType;
  String? fn;
  String? an;
  String? tsuptime;
  bool isElementUsedByAnother = false;
  String? elementErrorMessage;

  // Helper getters for hours and minutes (for UI)
  int get hours {
    try {
      if (totHrs.isEmpty) return 0;

      // Check if it's decimal format (1.5, 2.25, etc.)
      if (totHrs.contains('.')) {
        final decimalValue = double.tryParse(totHrs) ?? 0.0;
        return decimalValue.floor();
      }

      // Check if it's time format (1:30, 2:15, etc.)
      if (totHrs.contains(':')) {
        final parts = totHrs.split(':');
        return int.tryParse(parts[0]) ?? 0;
      }

      // Try to parse as integer hours
      return int.tryParse(totHrs) ?? 0;
    } catch (e) {
      debugPrint('Error parsing hours from totHrs: $e');
      return 0;
    }
  }

  int get minutes {
    try {
      if (totHrs.isEmpty) return 0;

      // Check if it's decimal format (1.5, 2.25, etc.)
      if (totHrs.contains('.')) {
        final decimalValue = double.tryParse(totHrs) ?? 0.0;
        final hours = decimalValue.floor();
        final minutesFraction = decimalValue - hours;
        return (minutesFraction * 60).round();
      }

      // Check if it's time format (1:30, 2:15, etc.)
      if (totHrs.contains(':')) {
        final parts = totHrs.split(':');
        return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      }

      return 0;
    } catch (e) {
      debugPrint('Error parsing minutes from totHrs: $e');
      return 0;
    }
  }

  // Helper method to set totHrs from hours and minutes
  void setHoursMinutes(int hours, int minutes) {
    // Ensure minutes is valid (0-59)
    final validMinutes = minutes.clamp(0, 59);

    // If minutes >= 60, add to hours
    final extraHours = validMinutes ~/ 60;
    final finalHours = hours + extraHours;
    final finalMinutes = validMinutes % 60;

    // Store in time format for UI
    totHrs = "$finalHours:${finalMinutes.toString().padLeft(2, '0')}";
  }

  // When loading from backend, ensure minutes are valid
  void setFromDecimal(double decimalValue) {
    try {
      final hours = decimalValue.floor();
      final decimalMinutes = decimalValue - hours;
      final minutes = (decimalMinutes * 60).round();

      // Call setHoursMinutes to handle overflow
      setHoursMinutes(hours, minutes);
    } catch (e) {
      debugPrint('Error setting from decimal: $e');
      totHrs = "0:00";
    }
  }

  // Convert to special decimal format for backend (1.25 → 1.15, 1.50 → 1.30, 1.75 → 1.45)
  double get totHrsAsDecimal {
    try {
      final hours = this.hours;
      final minutes = this.minutes;

      // Convert minutes to decimal format where:
      // 15 minutes = 0.25 → but backend expects 0.15
      // 30 minutes = 0.50 → but backend expects 0.30
      // 45 minutes = 0.75 → but backend expects 0.45

      double minutesDecimal;

      if (minutes == 0) {
        minutesDecimal = 0.0;
      } else if (minutes == 15) {
        minutesDecimal = 0.15;
      } else if (minutes == 30) {
        minutesDecimal = 0.30;
      } else if (minutes == 45) {
        minutesDecimal = 0.45;
      } else {
        // For other minute values, use standard conversion
        minutesDecimal = minutes / 100.0;
      }

      return hours + minutesDecimal;
    } catch (e) {
      debugPrint('Error converting totHrs to decimal: $e');
      return 0.0;
    }
  }

  TimesheetEntry({
    List<Map<String, dynamic>>? elementItems,
    required this.elementId,
    required this.type,
    required this.workType,
    required this.remarks,
    this.projectId,
    required this.tsSlNo,
    this.projectName,
    this.status = '',
    this.deptType,
    this.isExisting = false,
    this.isModified = false,
    this.isSelected = false,
    this.canEdit = false,
    this.isEdited = false,
    this.designingDrafting,
    this.draftingType,
    this.fn,
    this.an,
    this.tsuptime,
    this.entryDate,
    this.totHrs = "0:00",
  }) : elementItems = elementItems ?? [];
}

class TimesheetViewModel {
  final int? tsNo;
  final int? tsSlNo;
  final String? tsDt;
  final int? siteCode;
  final String? eleId;
  final String? type;
  final String? workType;
  final String? remarks;
  final int? deptCode;
  final int? tlCode;
  final String? tsStatus;
  final String? deleted;
  bool isSelected = false; // ✅ REQUIRED
  // Hours & Minutes coming from API
  // final String? hours;
  // final String? minutes;

  // Total Hours (H.MM or HH:MM depending on backend)
  final String? totHrs;

  // --- User tracking fields ---
  final int? addUser;
  final String? addUserName;
  final String? addDate;
  final int? editUser;
  final String? editDate;
  final int? delUser;
  final String? delDate;
  final int? appUser;
  final String? appUserName;
  final String? appDate;
  final String? appRemarks;
  final int? reChkUser;
  final String? reChkUserName;
  final String? reChkDate;
  final String? reChkRemarks;
  final String? reChkData;
  final String? deptType;
  final String? tsUpTime;
  final String? reassignData;

  bool isBlocked = false;
  bool isElementUsedByAnother = false;

  final String? eleName;
  final int? eleQnty;
  final String? draftingType;

  TimesheetViewModel({
    this.tsNo,
    this.tsSlNo,
    this.tsDt,
    this.siteCode,
    this.eleId,
    this.type,
    this.workType,
    this.remarks,
    this.deptCode,
    this.tlCode,
    this.tsStatus,
    this.deleted,
    this.addUser,
    this.addUserName,
    this.addDate,
    this.editUser,
    this.editDate,
    this.delUser,
    this.delDate,
    this.appUser,
    this.appUserName,
    this.appDate,
    this.appRemarks,
    this.reChkUser,
    this.reChkUserName,
    this.reChkDate,
    this.reChkRemarks,
    this.reChkData,
    this.deptType,
    this.tsUpTime,
    this.reassignData,
    this.totHrs,
    this.eleName,
    this.eleQnty,
    this.draftingType,
    // this.hours,
    // this.minutes,
  });

  factory TimesheetViewModel.fromJson(Map<String, dynamic> json) {
    return TimesheetViewModel(
      tsNo: json['TSNO'],
      tsSlNo: json['TSSLNO'],
      tsDt: json['TSDT'],
      siteCode: json['SITECODE'],
      eleId: json['ELEID'],
      type: json['TYPE'],
      workType: json['WORKTYPE'],
      remarks: json['REMARKS'],
      deptCode: json['DEPTCODE'],
      tlCode: json['TLCODE'],
      tsStatus: json['TSSTATUS'],
      deleted: json['DELETED'],
      totHrs: _parseTotHrsFromBackend(json['TOTHRS']), // Use helper function

      addUser: json['ADDUSER'],
      addUserName: json['ADDUSERNAME'],
      addDate: json['ADDDATE'],
      editUser: json['EDITUSER'],
      editDate: json['EDITDATE'],
      delUser: json['DELUSER'],
      delDate: json['DELDATE'],
      appUser: json['APPUSER'],
      appUserName: json['APPUSERNAME'],
      appDate: json['APPDATE'],
      appRemarks: json['APPREMARKS'],
      reChkUser: json['RECHKUSER'],
      reChkUserName: json['RECHKUSERNAME'],
      reChkDate: json['RECHKDATE'],
      reChkRemarks: json['RECHKREMARKS'],
      reChkData: json['RECHKDATA'],
      deptType: json['TSDEPTTYPE'],
      tsUpTime: json['TSUPTIME'],
      reassignData: json['REASSIGNDATA'],

      eleName: json['ELENAME'],
      eleQnty: json['ELEQNTY'],
      draftingType: json['DRAFTINGTYPE'],
    );
  }
  static String? _parseTotHrsFromBackend(dynamic value) {
    if (value == null) return null;

    try {
      if (value is String) {
        return value; // Keep as-is, let parseTotHrs handle it
      } else if (value is double || value is int) {
        return value.toString(); // Convert to string
      }
    } catch (e) {
      debugPrint('Error parsing TOTHRS in ViewModel: $e');
    }

    return null;
  }

  static String _convertBackendDecimalToTime(String decimalStr) {
    try {
      final decimalValue = double.tryParse(decimalStr) ?? 0.0;
      final hours = decimalValue.floor();
      final decimalMinutes = decimalValue - hours;

      // 🔥 SPECIAL CONVERSION: 0.15 → 15 minutes, 0.30 → 30 minutes, 0.45 → 45 minutes
      int minutes;

      if (decimalMinutes == 0.0) {
        minutes = 0;
      } else if (decimalMinutes == 0.15) {
        minutes = 15;
      } else if (decimalMinutes == 0.30) {
        minutes = 30;
      } else if (decimalMinutes == 0.45) {
        minutes = 45;
      } else {
        // Check if it's old data format (0.25, 0.50, 0.75)
        final roundedValue = (decimalMinutes * 100).round();
        if (roundedValue == 25) {
          minutes = 15; // 0.25 → 15 minutes
        } else if (roundedValue == 50) {
          minutes = 30; // 0.50 → 30 minutes
        } else if (roundedValue == 75) {
          minutes = 45; // 0.75 → 45 minutes
        } else {
          // For any other value, use standard conversion
          // This handles cases like 0.10, 0.20, etc.
          minutes = (decimalMinutes * 60).round();
        }
      }

      return "$hours:${minutes.toString().padLeft(2, '0')}";
    } catch (e) {
      debugPrint('Error converting backend decimal to time: $e');
      return "0:00";
    }
  }

  // Add this method to your TimesheetViewModel class
  TimesheetEntry toTimesheetEntry() {
    // Convert totHrs from backend format to display format
    String displayTotHrs = "0:00";

    if (totHrs != null && totHrs!.isNotEmpty) {
      // If totHrs is already in HH:MM format
      if (totHrs!.contains(':')) {
        displayTotHrs = totHrs!;
      }
      // If totHrs is in decimal format (1.25, 2.50, etc.)
      else if (totHrs!.contains('.')) {
        displayTotHrs = _convertBackendDecimalToTime(totHrs!);
      }
      // If it's just a number
      else {
        try {
          final hours = int.tryParse(totHrs!) ?? 0;
          displayTotHrs = "$hours:00";
        } catch (e) {
          displayTotHrs = "0:00";
        }
      }
    }

    return TimesheetEntry(
      elementId: eleId ?? '',
      type: type ?? '',
      workType: workType ?? '',
      remarks: remarks ?? '',
      projectId: null, // Set appropriate value
      tsSlNo: tsSlNo ?? 0,
      projectName: '', // Set appropriate value
      status: tsStatus ?? '',
      deptType: deptType,
      isExisting: true, // Since it comes from backend
      isModified: false,
      isSelected: false,
      canEdit:
          tsStatus == 'Draft' || tsStatus == 'Rejected', // Example condition
      isEdited: false,
      designingDrafting: '',
      draftingType: '',
      fn: '',
      an: '',
      tsuptime: tsUpTime,
      entryDate: tsDt != null ? DateTime.tryParse(tsDt!) : null,
      totHrs: displayTotHrs, // Properly formatted for TimesheetEntry
    );
  }
}

class UsedWorkType {
  final String workType;
  final String employeeCode;
  final String status;
  final DateTime? submittedDate;

  UsedWorkType({
    required this.workType,
    required this.employeeCode,
    required this.status,
    this.submittedDate,
  });

  factory UsedWorkType.fromJson(Map<String, dynamic> json) {
    return UsedWorkType(
      workType: json['workType']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      submittedDate: json['submittedDate'] != null
          ? DateTime.tryParse(json['submittedDate'].toString())
          : null,
    );
  }
}

class TimeSheet {
  int siteCode;
  int addUser;
  String eleId;
  String reassignData;

  TimeSheet({
    required this.siteCode,
    required this.addUser,
    required this.eleId,
    required this.reassignData,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'SITECODE': siteCode,
      'ADDUSER': addUser,
      'ELEID': eleId,
      'REASSIGNDATA': reassignData,
    };
  }
}

class SummaryReportModel {
  final String projectName;
  final String? eleName;
  final int dwg;
  final double qnty;
  final String tsdt;
  final String workType;

  SummaryReportModel({
    required this.projectName,
    required this.eleName,
    required this.dwg,
    required this.qnty,
    required this.tsdt,
    required this.workType,
  });

  factory SummaryReportModel.fromJson(Map<String, dynamic> json) {
    return SummaryReportModel(
      projectName: json['PROJECTNAME'] ?? '',
      eleName: json['ELENAME'],
      dwg: json['DWG'] ?? 0,
      qnty: (json['QNTY'] ?? 0).toDouble(),
      tsdt: json['TSDT'] ?? '',
      workType: (json['WORKTYPE'] ?? '').toString(),
    );
  }
}

class SalesEmployeeModel {
  final int empCode;
  final String empName;

  SalesEmployeeModel({
    required this.empCode,
    required this.empName,
  });

  factory SalesEmployeeModel.fromJson(Map<String, dynamic> json) {
    return SalesEmployeeModel(
      empCode: json['EMPCODE'],
      empName: json['EMPNAME'],
    );
  }
}

class CustomerModel {
  final int customerId;
  final String companyName;

  CustomerModel({
    required this.customerId,
    required this.companyName,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      customerId: json['CUSTOMERID'],
      companyName: json['CompanyName'],
    );
  }
}

class SalesChecklistModel {
  int? chklno;
  DateTime? chkldt;

  String? clientname;
  String? projectname;
  String? verifiedby;
  String? reviewedby;
  String? siteaddress;
  String? billingaddress;
  String? sitegstno;
  String? billinggstno;

  DateTime? effectivedate;
  double? wovalueinclgst;

  String? projecttenure;
  String? defliabperiod;
  String? contracttype;
  String? billingmethod;
  String? paymentterms;
  String? milestones;
  String? retention;
  String? bgreq;
  String? escdetails;
  String? taxstrchanges;

  String? scopeofworksigned;
  String? wpmethodology;
  String? antitermitework;
  String? siteaccessissues;
  String? dewatering;
  String? electricitywater;
  String? steelcementbrands;
  String? nontenitemsmar;
  String? soilexcdetails;
  String? buildingapp;
  String? soilinv;
  String? barrication;
  String? treecuttingdem;
  String? labouraccom;
  String? brickwork;
  String? sitesecurity;
  String? lightingarr;

  String? forcemajeurecon;
  String? arbitrationclause;
  String? labcomins;
  String? liquidateddamages;
  String? stabilitycertclause;
  String? groutteemaxapp;
  String? exjointreq;
  String? idlecharges;
  String? thirdpartytests;

  String? deleted;

  int? adduser;
  DateTime? adddate;

  int? edituser;
  DateTime? editdate;

  int? deluser;
  DateTime? deldate;

  SalesChecklistModel({
    this.chklno,
    this.chkldt,
    this.clientname,
    this.projectname,
    this.verifiedby,
    this.reviewedby,
    this.siteaddress,
    this.billingaddress,
    this.sitegstno,
    this.billinggstno,
    this.effectivedate,
    this.wovalueinclgst,
    this.projecttenure,
    this.defliabperiod,
    this.contracttype,
    this.billingmethod,
    this.paymentterms,
    this.milestones,
    this.retention,
    this.bgreq,
    this.escdetails,
    this.taxstrchanges,
    this.scopeofworksigned,
    this.wpmethodology,
    this.antitermitework,
    this.siteaccessissues,
    this.dewatering,
    this.electricitywater,
    this.steelcementbrands,
    this.nontenitemsmar,
    this.soilexcdetails,
    this.buildingapp,
    this.soilinv,
    this.barrication,
    this.treecuttingdem,
    this.labouraccom,
    this.brickwork,
    this.sitesecurity,
    this.lightingarr,
    this.forcemajeurecon,
    this.arbitrationclause,
    this.labcomins,
    this.liquidateddamages,
    this.stabilitycertclause,
    this.groutteemaxapp,
    this.exjointreq,
    this.idlecharges,
    this.thirdpartytests,
    this.deleted,
    this.adduser,
    this.adddate,
    this.edituser,
    this.editdate,
    this.deluser,
    this.deldate,
  });

  factory SalesChecklistModel.fromJson(Map<String, dynamic> json) {
    return SalesChecklistModel(
      chklno: json['CHKLNO'],
      chkldt: json['CHKLDT'] != null ? DateTime.parse(json['CHKLDT']) : null,
      clientname: json['CLIENTNAME'],
      projectname: json['PROJECTNAME'],
      verifiedby: json['VERIFIEDBY'],
      reviewedby: json['REVIEWEDBY'],
      siteaddress: json['SITEADDRESS'],
      billingaddress: json['BILLINGADDRESS'],
      sitegstno: json['SITEGSTNO'],
      billinggstno: json['BILLINGGSTNO'],
      effectivedate: json['EFFECTIVEDATE'] != null
          ? DateTime.parse(json['EFFECTIVEDATE'])
          : null,
      wovalueinclgst: json['WOVALUEINCLGST'] != null
          ? double.tryParse(json['WOVALUEINCLGST'].toString())
          : null,
      projecttenure: json['PROJECTTENURE'],
      defliabperiod: json['DEFLIABPERIOD'],
      contracttype: json['CONTRACTTYPE'],
      billingmethod: json['BILLINGMETHOD'],
      paymentterms: json['PAYMENTTERMS'],
      milestones: json['MILESTONES'],
      retention: json['RETENTION'],
      bgreq: json['BGREQ'],
      escdetails: json['ESCDETAILS'],
      taxstrchanges: json['TAXSTRCHANGES'],
      scopeofworksigned: json['SCOPEOFWORKSIGNED'],
      wpmethodology: json['WPMETHODOLOGY'],
      antitermitework: json['ANTITERMITEWORK'],
      siteaccessissues: json['SITEACCESSISSUES'],
      dewatering: json['DEWATERING'],
      electricitywater: json['ELECTRICITYWATER'],
      steelcementbrands: json['STEELCEMENTBRANDS'],
      nontenitemsmar: json['NONTENITEMSMAR'],
      soilexcdetails: json['SOILEXCDETAILS'],
      buildingapp: json['BUILDINGAPP'],
      soilinv: json['SOILINV'],
      barrication: json['BARRICATION'],
      treecuttingdem: json['TREECUTTINGDEM'],
      labouraccom: json['LABOURACCOM'],
      brickwork: json['BRICKWORK'],
      sitesecurity: json['SITESECURITY'],
      lightingarr: json['LIGHTINGARR'],
      forcemajeurecon: json['FORCEMAJEURECON'],
      arbitrationclause: json['ARBITRATIONCLAUSE'],
      labcomins: json['LABCOMINS'],
      liquidateddamages: json['LIQUIDATEDDAMAGES'],
      stabilitycertclause: json['STABILITYCERTCLAUSE'],
      groutteemaxapp: json['GROUTTEEMAXAPP'],
      exjointreq: json['EXJOINTREQ'],
      idlecharges: json['IDLECHARGES'],
      thirdpartytests: json['THIRDPARTYTESTS'],
      deleted: json['DELETED'],
      adduser: json['ADDUSER'],
      adddate: json['ADDDATE'] != null ? DateTime.parse(json['ADDDATE']) : null,
      edituser: json['EDITUSER'],
      editdate:
          json['EDITDATE'] != null ? DateTime.parse(json['EDITDATE']) : null,
      deluser: json['DELUSER'],
      deldate: json['DELDATE'] != null ? DateTime.parse(json['DELDATE']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "CHKLNO": chklno,
      "CHKLDT": chkldt?.toIso8601String(),
      "CLIENTNAME": clientname,
      "PROJECTNAME": projectname,
      "VERIFIEDBY": verifiedby,
      "REVIEWEDBY": reviewedby,
      "SITEADDRESS": siteaddress,
      "BILLINGADDRESS": billingaddress,
      "SITEGSTNO": sitegstno,
      "BILLINGGSTNO": billinggstno,
      "EFFECTIVEDATE": effectivedate?.toIso8601String(),
      "WOVALUEINCLGST": wovalueinclgst,
      "PROJECTTENURE": projecttenure,
      "DEFLIABPERIOD": defliabperiod,
      "CONTRACTTYPE": contracttype,
      "BILLINGMETHOD": billingmethod,
      "PAYMENTTERMS": paymentterms,
      "MILESTONES": milestones,
      "RETENTION": retention,
      "BGREQ": bgreq,
      "ESCDETAILS": escdetails,
      "TAXSTRCHANGES": taxstrchanges,
      "SCOPEOFWORKSIGNED": scopeofworksigned,
      "WPMETHODOLOGY": wpmethodology,
      "ANTITERMITEWORK": antitermitework,
      "SITEACCESSISSUES": siteaccessissues,
      "DEWATERING": dewatering,
      "ELECTRICITYWATER": electricitywater,
      "STEELCEMENTBRANDS": steelcementbrands,
      "NONTENITEMSMAR": nontenitemsmar,
      "SOILEXCDETAILS": soilexcdetails,
      "BUILDINGAPP": buildingapp,
      "SOILINV": soilinv,
      "BARRICATION": barrication,
      "TREECUTTINGDEM": treecuttingdem,
      "LABOURACCOM": labouraccom,
      "BRICKWORK": brickwork,
      "SITESECURITY": sitesecurity,
      "LIGHTINGARR": lightingarr,
      "FORCEMAJEURECON": forcemajeurecon,
      "ARBITRATIONCLAUSE": arbitrationclause,
      "LABCOMINS": labcomins,
      "LIQUIDATEDDAMAGES": liquidateddamages,
      "STABILITYCERTCLAUSE": stabilitycertclause,
      "GROUTTEEMAXAPP": groutteemaxapp,
      "EXJOINTREQ": exjointreq,
      "IDLECHARGES": idlecharges,
      "THIRDPARTYTESTS": thirdpartytests,
      "DELETED": deleted,
      "ADDUSER": adduser,
      "ADDDATE": adddate?.toIso8601String(),
      "EDITUSER": edituser,
      "EDITDATE": editdate?.toIso8601String(),
      "DELUSER": deluser,
      "DELDATE": deldate?.toIso8601String(),
    };
  }
}

/*class SalesStagelistModel {
  int? bsno;
  DateTime? bsdate;
  int? cusid;
  int? projid;
  String? stageid; // Changed from int? to String?
  String? stagename;
  String? deleted;
  int? adduser;
  DateTime? adddate;
  int? edituser;
  DateTime? editdate;
  int? deluser;
  DateTime? deldate;

  SalesStagelistModel({
    this.bsno,
    this.bsdate,
    this.cusid,
    this.projid,
    this.stageid,
    this.stagename,
    this.deleted,
    this.adduser,
    this.adddate,
    this.edituser,
    this.editdate,
    this.deluser,
    this.deldate,
  });

  factory SalesStagelistModel.fromJson(Map<String, dynamic> json) {
    return SalesStagelistModel(
      bsno: json['BSNO'],
      bsdate: json['BSDATE'] != null ? DateTime.parse(json['BSDATE']) : null,
      cusid: json['CUSID'],
      projid: json['PROJID'],
      stageid: json['STAGEID']?.toString(),
      stagename: json['STAGENAME'],
      deleted: json['DELETED'],
      adduser: json['ADDUSER'],
      adddate: json['ADDDATE'] != null ? DateTime.parse(json['ADDDATE']) : null,
      edituser: json['EDITUSER'],
      editdate:
          json['EDITDATE'] != null ? DateTime.parse(json['EDITDATE']) : null,
      deluser: json['DELUSER'],
      deldate: json['DELDATE'] != null ? DateTime.parse(json['DELDATE']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'BSNO': bsno,
      'BSDATE': bsdate?.toIso8601String(),
      'CUSID': cusid,
      'PROJID': projid,
      'STAGEID': stageid,
      'STAGENAME': stagename,
      'DELETED': deleted,
      'ADDUSER': adduser,
      'ADDDATE': adddate?.toIso8601String(),
      'EDITUSER': edituser,
      'EDITDATE': editdate?.toIso8601String(),
      'DELUSER': deluser,
      'DELDATE': deldate?.toIso8601String(),
    };
  }
}*/
class SalesStagelistModel {
  final int? bsno;
  final DateTime? bsdate;
  final int? cusid; // Make sure this matches the API field
  final int? projid; // Make sure this matches the API field
  final String? stageid;
  final String? stagename;
  final String? deleted;
  int? adduser;
  DateTime? adddate;

  SalesStagelistModel({
    this.bsno,
    this.bsdate,
    this.cusid,
    this.projid,
    this.stageid,
    this.stagename,
    this.deleted,
    this.adduser,
    this.adddate,
  });

  factory SalesStagelistModel.fromJson(Map<String, dynamic> json) {
    return SalesStagelistModel(
      bsno: json['BSNO'],
      bsdate: json['BSDATE'] != null ? DateTime.parse(json['BSDATE']) : null,
      cusid: json['CUSID'],
      projid: json['PROJID'],
      stageid: json['STAGEID'],
      stagename: json['STAGENAME'],
      deleted: json['DELETED'],
      adduser: json['ADDUSER'],
      adddate: json['ADDDATE'] != null ? DateTime.parse(json['ADDDATE']) : null,
    );
  }
}

class SalesBillingModel {
  int? sbno;
  DateTime? sbdt;
  int? cusid;
  int? projid;
  String? stageid;
  double? amount;
  String? invno;
  DateTime? invdt;
  String? deleted;
  int? adduser;
  DateTime? adddate;
  int? edituser;
  DateTime? editdate;
  int? deluser;
  DateTime? deldate;

  SalesBillingModel({
    this.sbno,
    this.sbdt,
    this.cusid,
    this.projid,
    this.stageid,
    this.amount,
    this.invno,
    this.invdt,
    this.deleted,
    this.adduser,
    this.adddate,
    this.edituser,
    this.editdate,
    this.deluser,
    this.deldate,
  });

  factory SalesBillingModel.fromJson(Map<String, dynamic> json) {
    return SalesBillingModel(
      sbno: json['SBNO'],
      sbdt: json['SBDT'] != null ? DateTime.parse(json['SBDT']) : null,
      cusid: json['CUSID'],
      projid: json['PROJID'],
      stageid: json['STAGEID'],
      amount:
          json['AMOUNT'] != null ? (json['AMOUNT'] as num).toDouble() : null,
      invno: json['INVNO'],
      invdt: json['INVDT'] != null ? DateTime.parse(json['INVDT']) : null,
      deleted: json['DELETED'],
      adduser: json['ADDUSER'],
      adddate: json['ADDDATE'] != null ? DateTime.parse(json['ADDDATE']) : null,
      edituser: json['EDITUSER'],
      editdate:
          json['EDITDATE'] != null ? DateTime.parse(json['EDITDATE']) : null,
      deluser: json['DELUSER'],
      deldate: json['DELDATE'] != null ? DateTime.parse(json['DELDATE']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SBNO': sbno,
      'SBDT': sbdt?.toIso8601String(),
      'CUSID': cusid,
      'PROJID': projid,
      'STAGEID': stageid,
      'AMOUNT': amount,
      'INVNO': invno,
      'INVDT': invdt?.toIso8601String(),
      'DELETED': deleted,
      'ADDUSER': adduser,
      'ADDDATE': adddate?.toIso8601String(),
      'EDITUSER': edituser,
      'EDITDATE': editdate?.toIso8601String(),
      'DELUSER': deluser,
      'DELDATE': deldate?.toIso8601String(),
    };
  }
}

/*class SalesBillingSummaryModel {
  final String? projectId;
  final String? customerId;
  final String projectName;
  final double woValueInclGst;
  final double billed;
  final double balanceAmnt;

  SalesBillingSummaryModel({
    this.projectId,
    this.customerId,
    required this.projectName,
    required this.woValueInclGst,
    required this.billed,
    required this.balanceAmnt,
  });

  factory SalesBillingSummaryModel.fromJson(Map<String, dynamic> json) {
    return SalesBillingSummaryModel(
      projectId: json['PROJECTID']?.toString() ??
          json['ProjectId']?.toString() ??
          json['projectId']?.toString(),
      customerId: json['CUSTOMERID']?.toString() ??
          json['CustomerId']?.toString() ??
          json['customerId']?.toString() ??
          // Try to extract from project name if needed
          _extractCustomerIdFromProjectName(json['PROJECTNAME']),
      projectName: json['PROJECTNAME'] ?? '',
      woValueInclGst: (json['WOVALUEINCLGST'] ?? 0).toDouble(),
      billed: (json['BILLED'] ?? 0).toDouble(),
      balanceAmnt: (json['BALANCEAMNT'] ?? 0).toDouble(),
    );
  }
  static String? _extractCustomerIdFromProjectName(dynamic projectName) {
    if (projectName == null) return null;
    String name = projectName.toString();
    // Try to extract first number from project name (like "1001 - PROJECT NAME")
    RegExp regex = RegExp(r'^(\d+)');
    Match? match = regex.firstMatch(name);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }
}*/

class SalesBillingSummaryModel {
  final int? customerId; // Add customer ID
  final int? projectId; // Keep project ID
  final String projectName;
  final double woValueInclGst;
  final double billed;
  final double balanceAmnt;

  SalesBillingSummaryModel({
    this.customerId,
    this.projectId,
    required this.projectName,
    required this.woValueInclGst,
    required this.billed,
    required this.balanceAmnt,
  });

  factory SalesBillingSummaryModel.fromJson(Map<String, dynamic> json) {
    String projectName = json['PROJECTNAME']?.toString() ?? '';

    // Extract IDs from the project name (format: "CustomerID - ProjectID - ProjectName" or "ProjectID - ProjectName")
    int? extractCustomerId(String name) {
      if (name.isEmpty) return null;
      RegExp regex = RegExp(r'^(\d+)');
      Match? match = regex.firstMatch(name);
      return match != null ? int.tryParse(match.group(1)!) : null;
    }

    int? extractProjectId(String name) {
      if (name.isEmpty) return null;
      // Try to extract second number if exists (CustomerID - ProjectID - Name)
      RegExp regex = RegExp(r'^\d+ - (\d+)');
      Match? match = regex.firstMatch(name);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
      // Fallback to first number if only one exists
      RegExp singleRegex = RegExp(r'^(\d+)');
      Match? singleMatch = singleRegex.firstMatch(name);
      return singleMatch != null ? int.tryParse(singleMatch.group(1)!) : null;
    }

    return SalesBillingSummaryModel(
      customerId: extractCustomerId(projectName),
      projectId: extractProjectId(projectName),
      projectName: projectName,
      woValueInclGst: (json['WOVALUEINCLGST'] ?? 0).toDouble(),
      billed: (json['BILLED'] ?? 0).toDouble(),
      balanceAmnt: (json['BALANCEAMNT'] ?? 0).toDouble(),
    );
  }
}

class ChecklistCustomer {
  final int customerId;
  final String companyName;

  ChecklistCustomer({
    required this.customerId,
    required this.companyName,
  });

  factory ChecklistCustomer.fromJson(Map<String, dynamic> json) {
    String fullCompanyName = json['CompanyName'] ?? '';
    int customerId = 0;
    String companyName = fullCompanyName;

    // Parse the ID from the beginning of the string (format: "ID - CompanyName")
    if (fullCompanyName.contains(' - ')) {
      List<String> parts = fullCompanyName.split(' - ');
      if (parts.isNotEmpty) {
        customerId = int.tryParse(parts[0]) ?? 0;
        companyName = parts.length > 1 ? parts.sublist(1).join(' - ') : '';
      }
    }

    return ChecklistCustomer(
      customerId: customerId,
      companyName: companyName,
    );
  }

  // Optional: Get the display string
  String get displayString => "$customerId - $companyName";
}
