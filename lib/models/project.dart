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

class EnquiryModel {
  final int enquiryId;
  final String enquiryName;

  EnquiryModel({
    required this.enquiryId,
    required this.enquiryName,
  });

  factory EnquiryModel.fromJson(Map<String, dynamic> json) {
    return EnquiryModel(
      enquiryId: json['ENQUIRYID'] ?? 0,
      enquiryName: json['ENQUIRYNAME'] ?? '',
    );
  }
}

class SalesChecklistModel {
  int? chklno;
  DateTime? chkldt;

  String? clientname;
  String? enqidname;
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

  // ── New file fields ──────────────────────────────
  String?
      chkfname; // comma-separated saved filenames e.g. "SCL1-1.pdf,SCL1-2.jpg"
  String? chkftype; // comma-separated file extensions e.g. "pdf,jpg"
  int? chkfcount; // total number of files

  // ── New approval fields ──────────────────────────
  String? chkappstatus; // approval status
  int? chkappuser; // user who approved
  DateTime? chkappdate; // approval date

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
    this.enqidname,
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
    // new
    this.chkfname,
    this.chkftype,
    this.chkfcount,
    this.chkappstatus,
    this.chkappuser,
    this.chkappdate,
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
      enqidname: json['ENQIDNAME'],
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
      // new
      chkfname: json['CHKFNAME'],
      chkftype: json['CHKFTYPE'],
      chkfcount: json['CHKFCOUNT'],
      chkappstatus: json['CHKAPPSTATUS'],
      chkappuser: json['CHKAPPUSER'],
      chkappdate: json['CHKAPPDATE'] != null
          ? DateTime.parse(json['CHKAPPDATE'])
          : null,
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
      "ENQIDNAME": enqidname,
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
      // new
      "CHKFNAME": chkfname,
      "CHKFTYPE": chkftype,
      "CHKFCOUNT": chkfcount,
      "CHKAPPSTATUS": chkappstatus,
      "CHKAPPUSER": chkappuser,
      "CHKAPPDATE": chkappdate?.toIso8601String(),
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

class SalesStagelistModel {
  final int? bsno;
  final DateTime? bsdate;
  final int? cusid; // Make sure this matches the API field
  final int? projid; // Make sure this matches the API field
  final String? stageid;
  final String? stagename;
  double? stagepercentage;
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
    this.stagepercentage,
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
      stagepercentage: json['STAGEPER'] != null
          ? double.tryParse(json['STAGEPER'].toString())
          : null,
      deleted: json['DELETED'],
      adduser: json['ADDUSER'],
      adddate: json['ADDDATE'] != null ? DateTime.parse(json['ADDDATE']) : null,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      "CUSID": cusid,
      "PROJID": projid,
      "STAGEID": stageid,
      "STAGENAME": stagename,
      "STAGEPER": stagepercentage?.toString() ?? '', // ← add
      "ADDUSER": adduser,
      "ADDDATE": adddate?.toIso8601String(),
    };
  }
}

class FileUploadModel {
  final String filename;
  final String filedata; // base64 string

  FileUploadModel({required this.filename, required this.filedata});

  Map<String, dynamic> toJson() => {
        'FILENAME': filename,
        'FILEDATA': filedata,
      };
}

class SalesBillingModel {
  final int sbno;
  final int? cusid;
  final int? projid;
  /*final String? stageName;
  final double? stagePer;*/
  final String? billno;
  final DateTime? billdate;
  final String? billdesc;
  final String? perofwork; // ← add
  final double? workdoneamnt; // ← add
  final double? billamnt;
  final double? gstper;
  final double? gstamnt;
  final double? billtotamnt;
  final double? tdsamnt; // ← add (was itamnt)
  final double? tdscgstamnt; // ← add
  final double? tdssgstamnt; // ← add
  final double? secdepamnt; // ← add (was retnamnt)
  final double? labcessamnt; // ← add
  final double? mobintamnt; // ← add
  final double? secadvamnt; // ← add
  final String? secadvremks; // ← add (String)
  final double? mobadvamnt; // ← add
  final String? mobadvremks; // ← add
  final double? othdedamnt; // ← add (was dedamnt)
  final String? othdedremks; // ← add
  final double? whamnt;
  final String? whremks; // ← add
  final double? mobadvrecamnt; // ← add
  final String? mobadvrecremks; // ← add
  final double? whrlseamnt;
  final String? whrlseremks; // ← add
  final double? totdedamnt; // ← add
  final double? netrecamnt; // ← add
  final double? netrecdamnt; // ← add (was recamnt)
  final DateTime? netrecddt;
  final String? netrecdremks; // ← add
  final double? outstandamnt; // ← add
  final double? itper; // keep for backward compat
  final double? itamnt; // keep for backward compat
  final double? retnper; // keep for backward compat
  final double? retnamnt; // keep for backward compat
  final double? dedamnt; // keep for backward compat
  final double? recamnt; // keep for backward compat
  final DateTime? recdate;
  final int? adduser;
  final DateTime? adddate;
  final int? edituser;
  final DateTime? editdate;
  final List<FileUploadModel>? files;
  final String? billfiles;
  final String? sbfname;
  final String? sbftype;
  final int? sbfcount;
  final String? stagename;
  final String? stageper;

  String? removedFiles;

  SalesBillingModel(
      {required this.sbno,
      this.cusid,
      this.projid,
      /*this.stageName,
      this.stagePer,*/
      this.billno,
      this.billdate,
      this.billdesc,
      this.perofwork,
      this.workdoneamnt,
      this.billamnt,
      this.gstper,
      this.gstamnt,
      this.billtotamnt,
      this.tdsamnt,
      this.tdscgstamnt,
      this.tdssgstamnt,
      this.secdepamnt,
      this.labcessamnt,
      this.mobintamnt,
      this.secadvamnt,
      this.secadvremks,
      this.mobadvamnt,
      this.mobadvremks,
      this.othdedamnt,
      this.othdedremks,
      this.whamnt,
      this.whremks,
      this.mobadvrecamnt,
      this.mobadvrecremks,
      this.whrlseamnt,
      this.whrlseremks,
      this.totdedamnt,
      this.netrecamnt,
      this.netrecdamnt,
      this.netrecddt,
      this.netrecdremks,
      this.outstandamnt,
      this.itper,
      this.itamnt,
      this.retnper,
      this.retnamnt,
      this.dedamnt,
      this.recamnt,
      this.recdate,
      this.adduser,
      this.adddate,
      this.edituser,
      this.editdate,
      this.files,
      this.billfiles,
      this.sbfname,
      this.sbftype,
      this.sbfcount,
      this.removedFiles,
      this.stagename,
      this.stageper});

  factory SalesBillingModel.fromJson(Map<String, dynamic> json) {
    return SalesBillingModel(
      sbno: json['SBNO'] ?? 0,
      cusid: json['CUSID'],
      projid: json['PROJID'],
      /*stageName: json['STAGEIDNAME'],
      stagePer: double.tryParse(json['STAGEPER'].toString()) ?? 0,*/
      billno: json['BILLNO'],
      billdate: json['BILLDATE'] != null
          ? DateTime.tryParse(json['BILLDATE'].toString())
          : null,
      billdesc: json['BILLDESC'],
      perofwork: json['PEROFWORK'],
      workdoneamnt: _toDouble(json['WORKDONEAMNT']),
      billamnt: _toDouble(json['BILLAMNT']),
      gstper: _toDouble(json['GSTPER']),
      gstamnt: _toDouble(json['GSTAMNT']),
      billtotamnt: _toDouble(json['TOTBILLAMNT']),
      tdsamnt: _toDouble(json['TDSAMNT']),
      tdscgstamnt: _toDouble(json['TDSCGSTAMNT']),
      tdssgstamnt: _toDouble(json['TDSSGSTAMNT']),
      secdepamnt: _toDouble(json['SECDEPAMNT']),
      labcessamnt: _toDouble(json['LABCESSAMNT']),
      mobintamnt: _toDouble(json['MOBINTAMNT']),
      secadvamnt: _toDouble(json['SECADVAMNT']),
      secadvremks: json['SECADVREMKS'],
      mobadvamnt: _toDouble(json['MOBADVAMNT']),
      mobadvremks: json['MOBADVREMKS'],
      othdedamnt: _toDouble(json['OTHDEDAMNT']),
      othdedremks: json['OTHDEDREMKS'],
      whamnt: _toDouble(json['WHAMNT']),
      whremks: json['WHREMKS'],
      mobadvrecamnt: _toDouble(json['MOBADVRECAMNT']),
      mobadvrecremks: json['MOBADVRECREMKS'],
      whrlseamnt: _toDouble(json['WHRLSEAMNT']),
      whrlseremks: json['WHRLSEREMKS'],
      totdedamnt: _toDouble(json['TOTDEDAMNT']),
      netrecamnt: _toDouble(json['NETRECAMNT']),
      netrecddt: json['NETRECDDT'] != null
          ? DateTime.tryParse(json['NETRECDDT'].toString())
          : null,
      netrecdamnt: _toDouble(json['NETRECDAMNT']),
      netrecdremks: json['NETRECDREMKS'],
      outstandamnt: _toDouble(json['OUTSTANDAMNT']),
      // backward compat
      itper: _toDouble(json['ITPER'] ?? json['GSTPER']),
      itamnt: _toDouble(json['ITAMNT'] ?? json['TDSAMNT']),
      retnper: _toDouble(json['RETNPER']),
      retnamnt: _toDouble(json['RETNAMNT'] ?? json['SECDEPAMNT']),
      dedamnt: _toDouble(json['DEDAMNT'] ?? json['OTHDEDAMNT']),
      recamnt: _toDouble(json['RECAMNT'] ?? json['NETRECDAMNT']),
      recdate: json['RECDATE'] != null
          ? DateTime.tryParse(json['RECDATE'].toString())
          : null,
      adduser: json['ADDUSER'],
      adddate: json['ADDDATE'] != null
          ? DateTime.tryParse(json['ADDDATE'].toString())
          : null,
      edituser: json['EDITUSER'],
      editdate: json['EDITDATE'] != null
          ? DateTime.tryParse(json['EDITDATE'].toString())
          : null,
      billfiles: json['BILLFILES'],
      sbfname: json['SBFNAME'],
      sbftype: json['SBFTYPE'],
      sbfcount: json['SBFCOUNT'],
      stagename: json['STAGENAME'] as String?,
      stageper: json['STAGEPER'] as String?,
    );
  }

  // ── Helper ───────────────────────────────────────────────────────────────
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  Map<String, dynamic> toJson() => {
        'SBNO': sbno,
        'CUSID': cusid,
        'PROJID': projid,
        /*'STAGEIDNAME': stageName,
        'STAGEPER': stagePer,*/
        'BILLNO': billno,
        'BILLDATE': billdate?.toIso8601String(),
        'BILLDESC': billdesc,
        'PEROFWORK': perofwork,
        'WORKDONEAMNT': workdoneamnt,
        'BILLAMNT': billamnt,
        'GSTPER': gstper,
        'GSTAMNT': gstamnt,
        'TOTBILLAMNT': billtotamnt,
        'TDSAMNT': tdsamnt,
        'TDSCGSTAMNT': tdscgstamnt,
        'TDSSGSTAMNT': tdssgstamnt,
        'SECDEPAMNT': secdepamnt,
        'LABCESSAMNT': labcessamnt,
        'MOBINTAMNT': mobintamnt,
        'SECADVAMNT': secadvamnt,
        'SECADVREMKS': secadvremks,
        'MOBADVAMNT': mobadvamnt,
        'MOBADVREMKS': mobadvremks,
        'OTHDEDAMNT': othdedamnt,
        'OTHDEDREMKS': othdedremks,
        'WHAMNT': whamnt,
        'WHREMKS': whremks,
        'MOBADVRECAMNT': mobadvrecamnt,
        'MOBADVRECREMKS': mobadvrecremks,
        'WHRLSEAMNT': whrlseamnt,
        'WHRLSEREMKS': whrlseremks,
        'TOTDEDAMNT': totdedamnt,
        'NETRECAMNT': netrecamnt,
        'NETRECDAMNT': netrecdamnt,
        'NETRECDREMKS': netrecdremks,
        'OUTSTANDAMNT': outstandamnt,
        'SBFNAME': sbfname,
        'SBFTYPE': sbftype,
        'SBFCOUNT': sbfcount,
        'REMOVEDFILES': removedFiles ?? '',
      };
}

class SalesBillingSummaryModel {
  final int? customerId;
  final int? projectId;
  final String? projectCode;
  final String? customerName;
  final String projectName;
  final double woValueInclGst;
  final double billed;
  final double? recamnt;
  final double balanceAmnt;

  SalesBillingSummaryModel({
    this.customerId,
    this.projectId,
    this.projectCode,
    this.customerName,
    required this.projectName,
    required this.woValueInclGst,
    required this.billed,
    this.recamnt,
    required this.balanceAmnt,
  });

  /*factory SalesBillingSummaryModel.fromJson(Map<String, dynamic> json) {
    // Debug: Print the entire JSON to see what's coming from API
    debugPrint('===== SalesBillingSummaryModel.fromJson =====');
    debugPrint('Full JSON: $json');
    debugPrint('PROJECTCODE from JSON: ${json['PROJECTCODE']}');
    debugPrint('PROJECTCODE type: ${json['PROJECTCODE']?.runtimeType}');

    String projectName = json['PROJECTNAME']?.toString() ?? '';
    String customerName = json['CUSTOMERNAME']?.toString() ?? '';

    // ✅ Get project code directly from JSON
    String? projectCode;
    if (json['PROJECTCODE'] != null) {
      projectCode = json['PROJECTCODE'].toString();
      debugPrint('✅ Project Code extracted: $projectCode');
    } else {
      debugPrint('⚠️ PROJECTCODE is null in API response');
    }

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
      customerId: extractCustomerId(customerName),
      projectId: extractProjectId(projectName),
      projectCode: projectCode, // ✅ Use the extracted project code
      customerName: customerName,
      projectName: projectName,
      woValueInclGst: (json['WOVALUEINCLGST'] ?? 0).toDouble(),
      billed: (json['BILLEDAMOUNT'] ?? 0).toDouble(),
      recamnt: json['RECEIVED'] != null
          ? (json['RECEIVED'] as num).toDouble()
          : null,
      balanceAmnt: (json['BALANCEAMNT'] ?? 0).toDouble(),
    );
  }*/
  factory SalesBillingSummaryModel.fromJson(Map<String, dynamic> json) {
    debugPrint('===== SalesBillingSummaryModel.fromJson =====');
    debugPrint('Full JSON: $json');

    String projectName = json['PROJECTNAME']?.toString() ?? '';
    String customerName = json['CUSTOMERNAME']?.toString() ?? '';

    String? projectCode;
    if (json['PROJECTCODE'] != null) {
      projectCode = json['PROJECTCODE'].toString();
    }

    // ✅ Read CUSTOMERID and PROJECTID directly from JSON — no regex needed
    int? customerId;
    if (json['CUSTOMERID'] != null) {
      customerId = int.tryParse(json['CUSTOMERID'].toString());
    }

    int? projectId;
    if (json['PROJECTID'] != null) {
      projectId = int.tryParse(json['PROJECTID'].toString());
    }

    return SalesBillingSummaryModel(
      customerId: customerId,
      projectId: projectId,
      projectCode: projectCode,
      customerName: customerName,
      projectName: projectName,
      woValueInclGst: (json['WOVALUEINCLGST'] ?? 0).toDouble(),
      billed: (json['BILLEDAMOUNT'] ?? 0).toDouble(),
      recamnt: json['RECEIVED'] != null
          ? (json['RECEIVED'] as num).toDouble()
          : null,
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

class SalesDesignModel {
  int? sdno;
  int? cusid;
  int? projid;
  String? sddt;
  String? selename;
  String? seleunit;
  String? seletot;
  int? selesno;

  // Sales Files
  String? sfname;
  String? sftype;
  int? sfcount;

  // Design Files
  String? dfname;
  String? dftype;
  int? dfcount;

  String? deleqnty;
  String? deletot;
  String? deleremks;
  int? adduser;
  int? edituser;
  int? deluser;
  DateTime? adddate;
  DateTime? editdate;
  DateTime? deldate;
  String? deleted;

  // ✅ Separate removed files
  String? removedSalesFiles;
  String? removedDesignFiles;

  // ✅ Separate file upload lists
  List<FileUploadModel>? salesFiles;
  List<FileUploadModel>? designFiles;

  // ✅ Keep for backward compatibility (optional)
  String? removedfiles;
  List<FileUploadModel>? files;

  final int? changedSelesno;

  SalesDesignModel(
      {this.sdno,
      this.cusid,
      this.projid,
      this.sddt,
      this.selename,
      this.seleunit,
      this.seletot,
      this.selesno,
      this.sfname,
      this.sftype,
      this.sfcount,
      this.dfname,
      this.dftype,
      this.dfcount,
      this.deleqnty,
      this.deletot,
      this.deleremks,
      this.adduser,
      this.edituser,
      this.deluser,
      this.adddate,
      this.editdate,
      this.deldate,
      this.deleted,
      this.removedSalesFiles,
      this.removedDesignFiles,
      this.salesFiles,
      this.designFiles,
      this.removedfiles,
      this.files,
      this.changedSelesno});

  factory SalesDesignModel.fromJson(Map<String, dynamic> json) {
    return SalesDesignModel(
      sdno: json['SDNO'] as int?,
      cusid: json['CUSID'] as int?,
      projid: json['PROJID'] as int?,
      sddt: json['SDDT'] as String?,
      selename: json['SELENAME'] as String?,
      seleunit: json['SELEUNIT'] as String?,
      seletot: json['SELETOT'] as String?,
      selesno: json['SELESNO'] as int?,
      sfname: json['SFNAME'] as String?,
      sftype: json['SFTYPE'] as String?,
      sfcount: json['SFCOUNT'] as int?,
      dfname: json['DFNAME'] as String?,
      dftype: json['DFTYPE'] as String?,
      dfcount: json['DFCOUNT'] as int?,
      deleqnty: json['DELEQNTY'] as String?,
      deletot: json['DELETOT'] as String?,
      deleremks: json['DELEREMKS'] as String?,
      adduser: json['ADDUSER'],
      edituser: json['EDITUSER'],
      deluser: json['DELUSER'],
      adddate:
          json['ADDDATE'] != null ? DateTime.tryParse(json['ADDDATE']) : null,
      editdate:
          json['EDITDATE'] != null ? DateTime.tryParse(json['EDITDATE']) : null,
      deldate:
          json['DELDATE'] != null ? DateTime.tryParse(json['DELDATE']) : null,
      deleted: json['DELETED'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SDNO': sdno,
      'CUSID': cusid,
      'PROJID': projid,
      'SDDT': sddt,
      'SELENAME': selename,
      'SELEUNIT': seleunit,
      'SELETOT': seletot,
      'CHANGEDSELESNO': changedSelesno,
      'SFNAME': sfname,
      'SFTYPE': sftype,
      'SFCOUNT': sfcount,
      'DFNAME': dfname,
      'DFTYPE': dftype,
      'DFCOUNT': dfcount,
      'DELEQNTY': deleqnty,
      'DELETOT': deletot,
      'DELEREMKS': deleremks,
      'ADDUSER': adduser,
      'EDITUSER': edituser,
      'DELUSER': deluser,
      'ADDDATE': adddate?.toIso8601String(),
      'EDITDATE': editdate?.toIso8601String(),
      'DELDATE': deldate?.toIso8601String(),
      'DELETED': deleted,
      'REMOVEDSALESFILES': removedSalesFiles,
      'REMOVEDDESIGNFILES': removedDesignFiles,
      'SALESFILES': salesFiles?.map((f) => f.toJson()).toList(),
      'DESIGNFILES': designFiles?.map((f) => f.toJson()).toList(),
      // Keep for backward compatibility
      'REMOVEDFILES': removedfiles,
      'FILES': files?.map((f) => f.toJson()).toList(),
    };
  }
}

class DesignFileUploadModel {
  String? filename;
  String? filedata;

  DesignFileUploadModel({
    this.filename,
    this.filedata,
  });

  Map<String, dynamic> toJson() {
    return {
      'FILENAME': filename,
      'FILEDATA': filedata,
    };
  }
}

class SalesEntryModel {
  String elementName;
  String unit;
  String totalQty;
  String designTotal;
  String dremarks;
  final String? sfname;
  final String? sftype;

  SalesEntryModel({
    required this.elementName,
    required this.unit,
    required this.totalQty,
    this.designTotal = '',
    this.dremarks = '',
    this.sfname,
    this.sftype,
  });
}

class ElementMasterModel {
  final int? eleCode; // ✅ Changed to int to match C# model
  final String? eleName;
  final String? eleUnit;

  ElementMasterModel({
    this.eleCode,
    this.eleName,
    this.eleUnit,
  });

  factory ElementMasterModel.fromJson(Map<String, dynamic> json) {
    return ElementMasterModel(
      eleCode: json['ELECODE'] as int?, // ✅ Parse as int
      eleName: json['ELENAME'] ?? '',
      eleUnit: json['ELEUNIT'] ?? '',
    );
  }

  @override
  String toString() {
    return 'ElementMasterModel(eleCode: $eleCode, eleName: $eleName, eleUnit: $eleUnit)';
  }
}

class ProjectcontrolModel {
  int? SPCNO;
  int? CUSID;
  int? PROJID;
  String? SPCDT;
  String? SPCNAME;
  String? SPCTOT;
  int? SPCSNO;

  // Sales Files
  String? SFNAME;
  String? SFTYPE;
  int? SFCOUNT;

  // Design Files
  String? PCTOT;
  String? PCFNAME;
  String? PCFTYPE;
  int? PCFCOUNT;
  String? PCREMKS;
  int? ADDUSER;
  int? EDITUSER;
  int? DELUSER;
  DateTime? ADDDATE;
  DateTime? EDITDATE;
  DateTime? DELDATE;
  String? DELETED;

  // ✅ Separate removed files
  String? removedSalesFiles;
  String? removedDesignFiles;

  // ✅ Separate file upload lists
  List<FileUploadModel>? salesFiles;
  List<FileUploadModel>? designFiles;

  // ✅ Keep for backward compatibility (optional)
  String? removedfiles;
  List<FileUploadModel>? files;

  final int? changedSPCsno;

  ProjectcontrolModel(
      {this.SPCNO,
      this.CUSID,
      this.PROJID,
      this.SPCDT,
      this.SPCNAME,
      this.SPCTOT,
      this.SPCSNO,
      this.SFNAME,
      this.SFTYPE,
      this.SFCOUNT,
      this.PCFNAME,
      this.PCFTYPE,
      this.PCFCOUNT,
      this.PCTOT,
      this.PCREMKS,
      this.ADDUSER,
      this.EDITUSER,
      this.DELUSER,
      this.ADDDATE,
      this.EDITDATE,
      this.DELDATE,
      this.DELETED,
      this.removedSalesFiles,
      this.removedDesignFiles,
      this.salesFiles,
      this.designFiles,
      this.removedfiles,
      this.files,
      this.changedSPCsno});

  factory ProjectcontrolModel.fromJson(Map<String, dynamic> json) {
    return ProjectcontrolModel(
      SPCNO: json['SPCNO'] as int?,
      CUSID: json['CUSID'] as int?,
      PROJID: json['PROJID'] as int?,
      SPCDT: json['SPCDT'] as String?,
      SPCNAME: json['SPCNAME'] as String?,
      SPCTOT: json['SPCTOT'] as String?,
      SPCSNO: json['SPCSNO'] as int?,
      SFNAME: json['SFNAME'] as String?,
      SFTYPE: json['SFTYPE'] as String?,
      SFCOUNT: json['SFCOUNT'] as int?,
      PCFNAME: json['PCFNAME'] as String?,
      PCFTYPE: json['PCFTYPE'] as String?,
      PCFCOUNT: json['PCFCOUNT'] as int?,
      PCTOT: json['PCTOT'] as String?,
      PCREMKS: json['PCREMKS'] as String?,
      ADDUSER: json['ADDUSER'],
      EDITUSER: json['EDITUSER'],
      DELUSER: json['DELUSER'],
      ADDDATE:
          json['ADDDATE'] != null ? DateTime.tryParse(json['ADDDATE']) : null,
      EDITDATE:
          json['EDITDATE'] != null ? DateTime.tryParse(json['EDITDATE']) : null,
      DELDATE:
          json['DELDATE'] != null ? DateTime.tryParse(json['DELDATE']) : null,
      DELETED: json['DELETED'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SPCNO': SPCNO,
      'CUSID': CUSID,
      'PROJID': PROJID,
      'SPCDT': SPCDT,
      'SPCNAME': SPCNAME,
      'SPCTOT': SPCTOT,
      'CHANGEDSPCSNO': changedSPCsno,
      'SFNAME': SFNAME,
      'SFTYPE': SFTYPE,
      'SFCOUNT': SFCOUNT,
      'PCFNAME': PCFNAME,
      'PCFTYPE': PCFTYPE,
      'PCFCOUNT': PCFCOUNT,
      'PCTOT': PCTOT,
      'PCREMKS': PCREMKS,
      'ADDUSER': ADDUSER,
      'EDITUSER': EDITUSER,
      'DELUSER': DELUSER,
      'ADDDATE': ADDDATE?.toIso8601String(),
      'EDITDATE': EDITDATE?.toIso8601String(),
      'DELDATE': DELDATE?.toIso8601String(),
      'DELETED': DELETED,
      'REMOVEDSALESFILES': removedSalesFiles,
      'REMOVEDDESIGNFILES': removedDesignFiles,
      'SALESFILES': salesFiles?.map((f) => f.toJson()).toList(),
      'DESIGNFILES': designFiles?.map((f) => f.toJson()).toList(),
      // Keep for backward compatibility
      'REMOVEDFILES': removedfiles,
      'FILES': files?.map((f) => f.toJson()).toList(),
    };
  }
}

class PCEntryModel {
  String elementName;
  String sTotal;
  String pcTotal;
  String pcremarks;
  final String? sfname;
  final String? sftype;

  PCEntryModel({
    required this.elementName,
    this.sTotal = '',
    this.pcTotal = '',
    this.pcremarks = '',
    this.sfname,
    this.sftype,
  });
}

class SecureAdvanceEntry {
  final double amount;
  final String remarks;
  const SecureAdvanceEntry({required this.amount, required this.remarks});
}

class NetAmountRecd {
  final double amount;
  final String remarks;
  final String date; // stored as formatted string e.g. "2024-06-24"
  final double? outstanding;

  const NetAmountRecd(
      {required this.amount,
      required this.remarks,
      required this.date,
      this.outstanding});
}

class BillingData {
  final int? id;
  final int customerId;
  final int projectId;
  final Map<String, String> rowData;

  BillingData({
    this.id,
    required this.customerId,
    required this.projectId,
    required this.rowData,
  });

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'projectId': projectId,
      'rowData': rowData,
    };
  }
}

class SalesDesignSummaryModel {
  final int? sdno;
  final int? customerId;
  final int? projectId;
  final String? projectName;

  final double? salesQnty;
  final double? designQnty;

  SalesDesignSummaryModel({
    this.sdno,
    this.customerId,
    this.projectId,
    this.projectName,
    this.salesQnty,
    this.designQnty,
  });

  factory SalesDesignSummaryModel.fromJson(Map<String, dynamic> json) {
    return SalesDesignSummaryModel(
      sdno: json['SDNO'],
      customerId: json['CUSTOMERID'],
      projectId: json['PROJECTID'],
      projectName: json['PROJECTNAME'],
      salesQnty: double.tryParse(json['SALESQNTY'].toString()) ?? 0,
      designQnty: double.tryParse(json['DESIGNQNTY'].toString()) ?? 0,
    );
  }
}

class SalesPCSummaryModel {
  final int? spcno;
  final int? customerId;
  final int? projectId;
  final String? projectName;

  final double? salesQnty;
  final double? pcQnty;

  SalesPCSummaryModel({
    this.spcno,
    this.customerId,
    this.projectId,
    this.projectName,
    this.salesQnty,
    this.pcQnty,
  });

  factory SalesPCSummaryModel.fromJson(Map<String, dynamic> json) {
    return SalesPCSummaryModel(
      spcno: json['SPCNO'],
      customerId: json['CUSTOMERID'],
      projectId: json['PROJECTID'],
      projectName: json['PROJECTNAME'],
      salesQnty: double.tryParse(json['SALESQNTY'].toString()) ?? 0,
      pcQnty: double.tryParse(json['PCQNTY'].toString()) ?? 0,
    );
  }
}

class StageModel {
  final int? stageId;
  final String? stageName;
  final String? stagePer;

  StageModel({this.stageId, this.stageName, this.stagePer});

  factory StageModel.fromJson(Map<String, dynamic> json) {
    return StageModel(
      stageId: json['STAGEID'] is int
          ? json['STAGEID']
          : int.tryParse(json['STAGEID']?.toString() ?? ''),
      stageName: json['STAGENAME']?.toString(),
      stagePer: json['STAGEPER']?.toString(),
    );
  }
}
