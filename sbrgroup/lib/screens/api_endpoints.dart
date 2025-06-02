import 'dart:convert';
import 'dart:io';

import 'package:ajna/screens/util.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart'; // Import the path package
// Import for MediaType

class ApiService {
  static int? userId;
  static String? accessToken;
  static String? token;

  // static const String baseUrl1 = 'http://localhost:1093/';
  // static const String baseUrl2 = 'http://localhost:1093/';
  // static const String baseUrl3 = 'http://localhost:1093/';
  // static const String baseUrl4 = 'http://localhost:1093/';

  // static const String baseUrl1 = 'http://15.207.212.144/';
  // static const String baseUrl2 = 'http://15.207.212.144/';
  // static const String baseUrl3 = 'http://15.207.212.144/';
  // static const String baseUrl4 = 'http://15.207.212.144/';
  // static const String notificationUrl = 'http://15.207.212.144';

  // static const String baseUrl1 = 'http://65.2.49.230:1093/';
  // static const String baseUrl2 = 'http://65.2.49.230:1093/';
  // static const String baseUrl3 = 'http://65.2.49.230:1093/';
  // static const String baseUrl4 = 'http://65.2.49.230:1093/';
  // static const String notificationUrl = 'http://65.2.49.230:1093';

  static const String baseUrl1 = 'https://sbrgroup.salesncrm.com/';
  static const String baseUrl2 = 'https://sbrgroup.salesncrm.com/';
  static const String baseUrl3 = 'https://sbrgroup.salesncrm.com/';
  static const String baseUrl4 = 'https://sbrgroup.salesncrm.com/';
  static const String notificationUrl = 'https://sbrgroup.salesncrm.com';

  // static const String baseUrl1 = 'https://53bc-49-207-215-77.ngrok-free.app/';
  // static const String baseUrl2 = 'https://53bc-49-207-215-77.ngrok-free.app/';
  // static const String baseUrl3 = 'https://53bc-49-207-215-77.ngrok-free.app/';
  // static const String baseUrl4 = 'https://53bc-49-207-215-77.ngrok-free.app/';
  // static const String notificationUrl =
  //     'https://53bc-49-207-215-77.ngrok-free.app';

  static final List<String> excludedEndpoints = [
    'api/user/user/signUp',
    'api/user/user/login',
    'api/user/user/mob/login',
    'api/user/user/refreshToken',
    'api/user/user/updatepassword',
    'api/user/user/verify',
    'api/user/user/generateotp',
    'api/user/user/reset',
  ];

  // Initialize the access token
  static Future<void> initialize() async {
    userId = await Util.getUserId();
    try {
      accessToken = await Util
          .getAccessToken(); // Ensure Util.getAccessToken() is defined
      token = await Util.getToken();
      print('AccessToken in initialize: $accessToken');
    } catch (error) {
      print('Error during initialization: $error');
      // Handle error, e.g., show a snackbar or retry
      rethrow; // Re-throw the error for further handling
    }
  }

  // Check if the endpoint is excluded from authorization
  static bool isExcludedEndpoint(String endpoint) {
    return excludedEndpoints.any((excluded) => endpoint.contains(excluded));
  }

  // POST request method
  static Future<http.Response> postRequest(
      String baseUrl, String endpoint, Map<String, dynamic> data) async {
    await initialize();

    final Uri uri = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (!isExcludedEndpoint(endpoint) && accessToken != null)
        'Authorization': 'Bearer $accessToken',
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    http.Response response = await http.post(
      uri,
      body: json.encode(data),
      headers: headers,
    );

    if (response.statusCode == 401) {
      // Attempt to refresh the token
      final refreshSuccess = await _refreshToken();
      if (refreshSuccess) {
        // Retry the original request with the new token
        headers['Authorization'] = 'Bearer $accessToken';
        response = await http.post(
          uri,
          body: json.encode(data),
          headers: headers,
        );
      }
    }

    _handleResponse(response); // Optional: Handle response status
    return response;
  }

  // Token refresh method
  static Future<bool> _refreshToken() async {
    final Uri refreshUri =
        Uri.parse('https://sbrgroup.salesncrm.com/api/user/user/refreshToken');

    // Define headers
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'No-Auth': 'True', // Custom header indicating no authentication required
    };

    // Ensure tokens are not null
    if (accessToken == null || token == null) {
      print('Access token or refresh token is null.');
      return false;
    }

    // Define request body
    final Map<String, dynamic> body = {
      'accessToken': accessToken,
      'token': token,
    };

    try {
      final response = await http.post(
        refreshUri,
        headers: headers,
        body: json.encode(body),
      );

      // Check if the response is successful
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Update tokens
        accessToken = responseData['accessToken'];
        token = responseData['token'];

        // Save the new tokens using SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('accessToken', accessToken!);
        await prefs.setString('token', token!);

        return true;
      } else {
        // Handle token refresh failure
        print('Token refresh failed with status: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      // Handle any errors during the request
      print('Error during token refresh: $error');
      return false;
    }
  }

  // GET request method
  static Future<http.Response> getRequest(
      String baseUrl, String endpoint) async {
    await initialize();

    final Uri uri = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      if (!isExcludedEndpoint(endpoint) && accessToken != null)
        'Authorization': 'Bearer $accessToken',
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    http.Response response = await http.get(
      uri,
      headers: headers,
    );

    if (response.statusCode == 401) {
      // Attempt to refresh the token
      final refreshSuccess = await _refreshToken();
      if (refreshSuccess) {
        // Retry the original request with the new token
        headers['Authorization'] = 'Bearer $accessToken';
        response = await http.get(
          uri,
          headers: headers,
        );
      }
    }

    _handleResponse(response); // Optional: Handle response status
    return response;
  }

  static Future<http.Response> putRequest(
    String baseUrl,
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    // Initialize if needed
    // await initialize();

    final Uri uri = Uri.parse('$baseUrl$endpoint');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Authorization':
          'Bearer $accessToken', // Uncomment if authorization is needed
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    http.Response response = await http.put(
      uri,
      body: json.encode(data),
      headers: headers,
    );

    if (response.statusCode == 401) {
      // Attempt to refresh the token
      final refreshSuccess = await _refreshToken();
      if (refreshSuccess) {
        // Retry the original request with the new token
        headers['Authorization'] = 'Bearer $accessToken';
        response = await http.put(
          uri,
          body: json.encode(data),
          headers: headers,
        );
      }
    }

    _handleResponse(response); // Optional: Handle response status
    return response;
  }

  // Optional: Handle HTTP response status
  static void _handleResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('Failed request: ${response.statusCode} ${response.reasonPhrase}');
      // Optionally: throw an exception or handle errors
    }
  }

  static Future<http.Response> login(
      String identifier, String password, String androidId) async {
    return await postRequest(baseUrl1, 'api/user/user/mob/login', {
      'identifier': identifier,
      'password': password,
      'androidId': androidId,
      'organizationId': 2,
    });
  }

  // static Future<http.Response> login(String identifier, String password) async {
  //   return await postRequest(baseUrl1, 'api/user/user/mob/login', {
  //     'identifier': identifier,
  //     'password': password,
  //     'organizationId': 2,
  //   });
  // }

  static Future<http.Response> checkForUpdate() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/mob?refKey=ajna_version');
  }

  static Future<http.Response> getApkDownloadUrl() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/mob?refKey=Url_Ajna');
  }

  static Future<http.Response> fetchAdditionalData(int roleId) async {
    return await getRequest(
        baseUrl1, 'api/user/roleMenuItem/moblie/icon/$roleId');
  }

  static Future<http.Response> fetchQRScanDetails(int userId) async {
    return await getRequest(
        baseUrl1, 'api/user/user/qrscan/details?userId=$userId');
  }

  static Future<http.Response> sendError(String errorDetails) async {
    return await getRequest(
        baseUrl1, 'api/user/user/sendemailtotechteam?errorMsg=$errorDetails');
  }

  static Future<http.Response> fetchOrgDetails(int organizationId) async {
    return await getRequest(baseUrl1, 'api/user/organization/$organizationId');
  }

  static Future<http.Response> fetchOrgUsers(int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/user/fetchall?userName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> fetchOrgManagers(int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/user/fetchall?userName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> fetchOrgRoles(int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/role/fetchall?roleName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> signUp(
      String userName,
      String email,
      String password,
      String phoneNumber,
      String roleId,
      String managerId,
      int organizationId) async {
    return await postRequest(baseUrl1, 'api/user/user/signUp', {
      'userName': userName,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
      'roleId': roleId,
      'managerId': managerId,
      'organizationId': organizationId,
    });
  }

  static Future<http.Response> generateOtp(String email) async {
    return await getRequest(baseUrl1, 'api/user/user/generateotp/$email');
  }

  static Future<http.Response> verifyOtp(String email, String otp) async {
    return await getRequest(baseUrl1, 'api/user/user/verify/$email/$otp');
  }

  static Future<http.Response> updatePassword(
      String email, String password) async {
    return await getRequest(
        baseUrl1, 'api/user/user/updatepassword/$email/$password');
  }

  static Future<http.Response> fetchFilterDays() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Filter_Days');
  }

  static Future<http.Response> fetchDashboardData(
      String range, int userId, int roleId) async {
    return await getRequest(baseUrl1,
        'api/lead/lead/dashboard/leads?userId=$userId&roleId=$roleId&range=$range');
  }

  static Future<http.Response> fetchFollowups(
      String range, int userId, int roleId) async {
    return await getRequest(baseUrl1,
        'api/lead/followup/dashboard/followups?userId=$userId&roleId=$roleId&range=$range');
  }

  static Future<http.Response> getCommonReferenceDetails(
      String typeName) async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/$typeName');
  }

  static Future<http.Response> fetchResetUsers(String organizationId) async {
    return await getRequest(
        baseUrl1, 'api/user/user/fetchall?organizationId=$organizationId');
  }

  static Future<http.Response> resetAndroidId(int userId) async {
    return await getRequest(
        baseUrl1, 'api/user/user/mob/resetandroidid?userId=$userId');
  }

  static Future<http.Response> fetchConsumptionTypeList() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Consumption_Type');
  }

  static Future<http.Response> fetchConsumptionYearList() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Consumption_Year');
  }

  //Start baseUrl2 - http://localhost:9006/

  static Future<http.Response> fetchReportProjectWise(
      int organizationId, String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallreportprojectwise?organizationId=$organizationId&range=$selectedDateRange');
  }

  static Future<http.Response> fetchReportLocationWise(
      int organizationId, int projectId, String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallreportlocationwise?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange');
  }

  static Future<http.Response> fetchReportUserWise(int organizationId,
      int projectId, String selectedDateRange, int qrgeneratorId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallreportuserwise?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange&qrgeneratorId=$qrgeneratorId');
  }

  static Future<http.Response> fetchReportScheduleWise(
      int organizationId,
      int projectId,
      String selectedDateRange,
      int qrgeneratorId,
      int userId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallwithfilter?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange&qrgeneratorId=$qrgeneratorId&userId=$userId');
  }

  static Future<http.Response> fetchQrReGenerate(
      int projectId, int selectedOrgId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/facility/getAll/withoutpage?orgId=$selectedOrgId&projectId=$projectId');
  }

  static Future<http.Response> postQrData(Map<String, dynamic> qrData) async {
    return await postRequest(
        baseUrl2, 'api/facility-management/facility/save', qrData);
  }

  // // Method to submit QR transaction data
  // static Future<http.Response> submitQrTransactionData(
  //     Map<String, dynamic> scannedQrData, File selfie) async {
  //   final url =
  //       Uri.parse('${baseUrl2}api/facility-management/qrtransaction/save');

  //   final request = http.MultipartRequest('POST', url);

  //   // Add the scanned data as a field in the request
  //   request.fields['scannedData'] = jsonEncode(scannedQrData);
  //   // Add the _selfie file to the request
  //   request.files.add(
  //     http.MultipartFile(
  //       'file',
  //       selfie.readAsBytes().asStream(),
  //       selfie.lengthSync(),
  //       filename: selfie.path.split('/').last,
  //       contentType: MediaType('image', 'jpeg'),
  //     ),
  //   );
  //   // Add the Authorization header with the accessToken
  //   request.headers['Authorization'] = 'Bearer $accessToken';

  //   try {
  //     final streamedResponse = await request.send();
  //     final responseBody = await streamedResponse.stream.bytesToString();
  //     return http.Response(responseBody, streamedResponse.statusCode);
  //   } catch (e) {
  //     throw Exception('Error during upload: $e');
  //   }
  // }
  static Future<http.Response> submitQrTransactionData(
      String qrTransactionData, File imageFile) async {
    final url =
        Uri.parse('${baseUrl2}api/facility-management/qrtransaction/save');

    var request = http.MultipartRequest('POST', url);

    request.fields['qrTransactionDataBean'] = qrTransactionData;

    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          imageFile.path,
          contentType: MediaType(
            'image',
            path.extension(imageFile.path).replaceFirst('.', ''),
          ),
        ),
      );
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response;
    } catch (e) {
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchScanSchedules(int userId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/securitypatrol/getsecuritypartolbyuserwise?userId=$userId');
  }

  static Future<http.Response> fetchQrLocations(String projectId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/securitypatrol/getallsecuritypatrolformob?projectId=$projectId&securityPatrolName=');
  }

  static Future<http.Response> fetchloadCustomers() async {
    return await getRequest(
        baseUrl2, 'api/facility-management/customer/fetchall');
  }

  static Future<http.Response> saveConsumptionData(
      Map<String, dynamic> data) async {
    return await postRequest(
        baseUrl2, 'api/facility-management/consumption/save', data);
  }

  //Start baseUrl3 - http://localhost:9002/

  static Future<http.Response> fetchOrgProjects(int organizationId) async {
    return await getRequest(
        baseUrl3, 'api/project/project/org?organizationId=$organizationId');
  }

  static Future<http.Response> fetchQrProjects(int selectedOrgId) async {
    return await getRequest(
        baseUrl3, 'api/project/project/org?organizationId=$selectedOrgId');
  }

  static Future<http.Response> fetchProjectsUserManage(
      int intOrganizationId) async {
    return await getRequest(
        baseUrl3, 'api/project/project/org?organizationId=$intOrganizationId');
  }

  static Future<http.Response> addUserManagementDetails(
      int projectId, int referenceId, int userId) async {
    return await postRequest(baseUrl4, 'api/lead/usermanage/add/SP', {
      'projectId': projectId,
      'referenceId': referenceId,
      'userId': userId,
    });
  }

  static Future<http.Response> fetchLeadSource() async {
    return await getRequest(
        baseUrl4, 'api/lead/leadsource/fetchall?leadSourceName=');
  }

  static Future<http.Response> saveVisit() async {
    return await getRequest(baseUrl4, 'api/lead/site/visit/save');
  }

  static Future<http.Response> saveSiteVisit(
    String name,
    String phoneNumber,
    String email,
    String address,
    int projectId,
    int flatTypeId,
    String budget,
    int sourceId,
    int subSourceId,
    DateTime followupDateTime,
    String remarks,
    int userId,
    int pincode,
    bool isSiteVisitForm,
  ) async {
    // Manually append query parameters to the endpoint
    String endpoint = 'api/lead/lead/save?isSiteVistForm=$isSiteVisitForm';

    return await postRequest(
      baseUrl4,
      endpoint,
      {
        'name': name,
        'phoneNumber': phoneNumber,
        'email': email,
        'homeLocation': address,
        'projectId': projectId,
        'preferredFlatType': flatTypeId.toString(),
        'budget': budget,
        'sourceId': sourceId,
        'subSourceId': subSourceId,
        'followupDateTime': followupDateTime.toIso8601String(),
        'remarks': remarks,
        'assignedToSales': userId,
        'pincode': pincode,
      },
    );
  }

  static Future<http.Response> updateRecord(
    int leadId,
    String name,
    String phoneNumber,
    String email,
    String address,
    int projectId,
    int flatTypeId,
    String budget,
    int sourceId,
    int subSourceId,
    DateTime followupDateTime,
    String remarks,
    int userId,
    int pincode,
    bool isSiteVisitForm,
  ) async {
    // Manually append query parameters to the endpoint
    String endpoint = 'api/lead/lead/update?isSiteVistForm=$isSiteVisitForm';

    return await putRequest(
      baseUrl4,
      endpoint,
      {
        'id': leadId,
        'name': name,
        'phoneNumber': phoneNumber,
        'email': email,
        'homeLocation': address,
        'projectId': projectId,
        'preferredFlatType': flatTypeId.toString(),
        'budget': budget,
        'sourceId': sourceId,
        'subSourceId': subSourceId,
        'followupDateTime': followupDateTime.toIso8601String(),
        'remarks': remarks,
        'assignedToSales': userId,
        'pincode': pincode,
      },
    );
  }

  static Future<http.Response> fetchLeadStatuses(String moduleNames) async {
    return await getRequest(baseUrl1,
        'api/user/commonreferencedetails/lead/status?typeName=Lead_Status&moduleNames=$moduleNames');
  }

  static Future<http.Response> fetchLeadTypes() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Lead_Type');
  }

  static Future<http.Response> fetchLeadSources() async {
    return await getRequest(
        baseUrl4, 'api/lead/leadsource/fetchall?leadSourceName=');
  }

  static Future<http.Response> fetchSubSources(int sourceId) async {
    return await getRequest(
        baseUrl4, 'api/lead/leadsubsource/fetchall?sourceId=$sourceId');
  }

  static Future<http.Response> fetchCountries() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Country_Code');
  }

  static Future<http.Response> fetchProjects() async {
    return await getRequest(baseUrl3, 'api/project/project/findAll?name=');
  }

  static Future<http.Response> fetchUnitTypes() async {
    return await getRequest(baseUrl3, 'api/project/unit/type/findAll');
  }

  static Future<http.Response> fetchBudgets() async {
    return await getRequest(
        baseUrl1, 'api/user/commonreferencedetails/types/Budget_Type');
  }

  static Future<http.Response> addLead(Map<String, dynamic> leadData) async {
    return await postRequest(baseUrl4, 'api/lead/lead/save', leadData);
  }

  static Future<http.Response> fetchRecord(String phoneNumber) async {
    // Ensure to handle null or invalid base URL and endpoint
    return await getRequest(
      baseUrl4,
      'api/lead/lead/fetchLeadByMobile?phoneNumber=$phoneNumber',
    );
  }

  static Future<http.Response> SalesUsers(
      int organizationId, int projectId) async {
    final String url =
        'api/lead/usermanage/users/S?organizationId=$organizationId&projectId=$projectId';
    return await getRequest(baseUrl1, url);
  }

  static Future<http.Response> sendAttendace(Map<String, dynamic> data) async {
    return await postRequest(
        baseUrl2, 'api/facility-management/attendance/submit', data);
  }

  static Future<http.Response> fetchTransactions({
    required String searchQuery,
    String beneficiaryName = '',
    String transactionType = '',
    String remiterName = '',
    String rangeOfDays = '0', // Default to '0'
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final endpoint = 'api/account/accountentry/fetchall';

    // Prepare the query parameters
    final queryParameters = {
      'remiterName': searchQuery,
      'beneficiaryName': beneficiaryName,
      'transactionType': transactionType,
      'startDate': startDate != null ? startDate.toIso8601String() : '',
      'endDate': endDate != null ? endDate.toIso8601String() : '',
    };

    // Include rangeOfDays only if no custom date range is set
    if (startDate == null || endDate == null) {
      queryParameters['rangeOfDays'] = rangeOfDays;
    } else {
      queryParameters['rangeOfDays'] =
          '0'; // Set rangeOfDays to '0' for custom date ranges
    }

    // Construct the URI with the query parameters
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);

    // Call the getRequest method with the base URL and constructed endpoint
    return await getRequest(baseUrl1, uri.toString());
  }

  static Future<http.Response> getAddressByPinCode(
      String pincode, String location) async {
    final String endpoint =
        'api/lead/lead/pincode?pincode=$pincode&location=$location';
    return await getRequest(baseUrl1, endpoint);
  }

  static Future<http.Response> fetchUserAttendaceLocations(int userId) async {
    return await getRequest(baseUrl3,
        'api/facility-management/attendance/getqrassigned?userId=$userId');
  }

  static Future<http.Response> checkLoginStatus(int userId) async {
    return await getRequest(baseUrl3,
        'api/facility-management/attendance/loginorlogout?userId=$userId');
  }

  static Future<http.Response> fetchAccountEntries({
    required String searchQuery,
    String beneficiaryName = '',
    String transactionType = '',
    String amount = '',
    String minAmount = '',
    String maxAmount = '',
    String selectedAmountType = '',
    String rangeOfDays = '0',
    DateTime? startDate,
    DateTime? endDate,
    required int page,
    required int size,
  }) async {
    final String endpoint = 'api/account/accountentry/fetchallWithPagination';

    // Prepare the query parameters
    final Map<String, String> queryParameters = {
      'remiterName': searchQuery,
      'beneficiaryName': beneficiaryName,
      'transactionType': transactionType,
      'amount': amount,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'selectedAmountType': selectedAmountType,
      'rangeOfDays': rangeOfDays,
      'startDate': startDate != null ? startDate.toIso8601String() : '',
      'endDate': endDate != null ? endDate.toIso8601String() : '',
      'page': page.toString(),
      'size': size.toString(),
    };
    // Include rangeOfDays only if no custom date range is set
    if (startDate == null || endDate == null) {
      queryParameters['rangeOfDays'] = rangeOfDays;
    } else {
      queryParameters['rangeOfDays'] =
          '0'; // Set rangeOfDays to '0' for custom date ranges
    }

    // final String queryString = Uri(queryParameters: queryParameters).query;
    // final String fullEndpoint = '$baseUrl1$endpoint?$queryString';
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);
    return await getRequest(baseUrl1, uri.toString());
  }

  static Future<http.Response> fetchAccountEntryAmounts({
    String remiterName = '',
    String beneficiaryName = '',
    String transactionType = '',
    String amount = '',
    String minAmount = '',
    String maxAmount = '',
    String selectedAmountType = '',
    String rangeOfDays = '0',
    DateTime? startDate,
    DateTime? endDate,
    required String searchQuery,
  }) async {
    final String endpoint = 'api/account/accountentry/fetchamounts';

    // Prepare the query parameters
    final Map<String, String> queryParameters = {
      'remiterName': searchQuery,
      'beneficiaryName': beneficiaryName,
      'transactionType': transactionType,
      'amount': amount,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'selectedAmountType': selectedAmountType,
      'rangeOfDays': rangeOfDays,
      'startDate': startDate != null ? startDate.toIso8601String() : '',
      'endDate': endDate != null ? endDate.toIso8601String() : '',
    };

    // Include rangeOfDays only if no custom date range is set
    if (startDate == null || endDate == null) {
      queryParameters['rangeOfDays'] = rangeOfDays;
    } else {
      queryParameters['rangeOfDays'] =
          '0'; // Set rangeOfDays to '0' for custom date ranges
    }

    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);

    // final String queryString = Uri(queryParameters: queryParameters).query;
    // final String fullEndpoint = '$endpoint?$queryString';

    return await getRequest(baseUrl1, uri.toString());
  }

  static Future<http.Response> downloadImage({
    required String projectName,
    required String date,
    required String userName,
    required String phoneNumber,
    required String imageUrl,
  }) async {
    // Encode each query parameter to ensure proper URL formatting
    String encodedProjectName = Uri.encodeComponent(projectName);
    String encodedDate = Uri.encodeComponent(date);
    String encodedUserName = Uri.encodeComponent(userName);
    String encodedPhoneNumber = Uri.encodeComponent(phoneNumber);
    String encodedImageUrl = Uri.encodeComponent(imageUrl);

    // Use encoded values in the endpoint URL
    String endpoint =
        'api/facility-management/qrreport/get-image?projectName=$encodedProjectName&date=$encodedDate&userName=$encodedUserName&phoneNumber=$encodedPhoneNumber&imageUrl=$encodedImageUrl';

    // Make the HTTP request
    return await getRequest(baseUrl1, endpoint); // Use getRequest
  }

  static Future<http.Response> fetchScheduleReports(
    int organizationId,
    int projectId,
    String selectedDateRange,
  ) async {
    return await getRequest(baseUrl2,
        'api/facility-management/qrreport/getallschedulewithreports?organizationId=$organizationId&projectId=$projectId&range=$selectedDateRange');
  }

  static Future<http.Response> submitIssue(
      String issueData, File imageFile) async {
    final url = Uri.parse('${baseUrl2}api/project/issues/save');

    var request = http.MultipartRequest('POST', url);

    // Change the key from 'qrTransactionDataBean' to 'issues'
    request.fields['issues'] = issueData;

    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile', // Ensure this key matches what the backend expects
          imageFile.path,
          contentType: MediaType(
            'image',
            path.extension(imageFile.path).replaceFirst('.', ''),
          ),
        ),
      );
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response;
    } catch (e) {
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchAttendanceReport(
      int userId,
      int organizationId,
      String selectedLocation,
      String shiftIds,
      String selectedRole,
      String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/shiftBasedAttendance/dashboard/attendance/data?userId=$userId&organizationId=$organizationId&shiftIds=$shiftIds&locationId=$selectedLocation&roleId=$selectedRole&range=$selectedDateRange');
  }

  static Future<http.Response> fetchAttendanceLocation(
      int? organizationId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/facility/getQrByOrganizationId?organizationId=$organizationId');
  }

  static Future<http.Response> fetchshiftData() async {
    return await getRequest(
        baseUrl2, 'api/user/commonreferencedetails/types/Shift_Timings');
  }

  static Future<http.Response> fetchLocation(int? organizationId) async {
    return await getRequest(baseUrl2,
        'api/facility-management/facility/getattendancelocationbyorg?orgId=$organizationId');
  }

  // static fetchAttendanceDetails(int i, int j, String selectedLocation, String selectedShift, String selectedDateRange) {}

  static Future<http.Response> fetchAttendanceDetails(
      int userId,
      String userName,
      String attendanceStatus,
      String selectedLocation,
      String selectedShift,
      String selectedRole,
      String selectedDateRange,
      String page,
      int size) async {
    return await getRequest(
        baseUrl2,
        // 'api/facility-management/attendance/dashboard/attendance/data?userId=$userId&organizationId=$organizationId&shiftId=$selectedShift&locationId=$selectedLocation&range=$selectedDateRange'
        'api/facility-management/shiftBasedAttendance/allAttendance?userName=$userName&userId=$userId&page=$page&size=$size&&attendanceStatus=$attendanceStatus&shiftIds=$selectedShift&locationId=$selectedLocation&roleId=$selectedRole&range=$selectedDateRange');
  }

  // Method to store device token with query parameters (matching your Java backend)
  static Future<http.Response> storeDeviceToken(int userId, String deviceToken,
      String androidId, int organizationId) async {
    // Prepare the data as URL query parameters
    final String url = Uri.parse(
            '$notificationUrl/api/user/fcm/storetoken?userId=$userId&deviceToken=$deviceToken&androidId=$androidId&organizationId=$organizationId')
        .toString();

    // Headers setup: Adding Authorization header if accessToken exists
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization': 'Bearer $accessToken', // Add Authorization header
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    try {
      // Send the POST request with query parameters in the URL and headers
      final response = await http.post(
        Uri.parse(url),
        headers: headers, // Add the headers here
      );

      return response;
    } catch (e) {
      throw Exception("Error during post request: $e");
    }
  }

  // static updateDeviceTokenWithAndroidId(int userId, String newToken, String androidId) {}

  // Method to store device token with query parameters (using PUT method)
  static Future<http.Response> updateDeviceTokenWithAndroidId(int userId,
      String deviceToken, String androidId, int organizationId) async {
    // Prepare the data as URL query parameters
    final String url = Uri.parse(
            '$notificationUrl/api/user/fcm/updateDeviceToken?userId=$userId&deviceToken=$deviceToken&androidId=$androidId&organizationId=$organizationId')
        .toString();

    // Headers setup: Adding Authorization header if accessToken exists
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization': 'Bearer $accessToken', // Add Authorization header
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    try {
      // Send the PUT request with query parameters in the URL and headers
      final response = await http.put(
        Uri.parse(url),
        headers: headers, // Add the headers here
      );

      // Return the response for further processing
      return response;
    } catch (e) {
      throw Exception("Error during PUT request: $e");
    }
  }

  // Method to send notification using query parameters
  // Updated sendNotification method
  static Future<http.Response> sendNotification({
    required List<int> userIds,
    required String title,
    required String body,
    String? route = '', // Default route if not provided
    required int organizationId, // Organization ID passed as parameter
  }) async {
    if (userIds.isEmpty) {
      throw Exception("User IDs must not be empty.");
    }

    String userIdsString = userIds.join(',');

    // Prepare the URL with query parameters
    final String url = Uri.parse(
      '$notificationUrl/api/user/fcm/sendnotification?userIds=$userIdsString&title=$title&body=$body&route=$route&organizationId=$organizationId',
    ).toString();

    // Setup headers
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization':
            'Bearer $accessToken', // Add Authorization header if available
    };

    try {
      // Send the POST request with query parameters in the URL and headers
      final response = await http.post(
        Uri.parse(url),
        headers: headers, // Attach headers if necessary
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        throw Exception('Failed to send notification: ${response.body}');
      }

      // Return the response
      return response;
    } catch (e) {
      throw Exception("Error sending notification: $e");
    }
  }

  static Future<http.Response> fetchRoleReport(
      int userId,
      int organizationId,
      String selectedLocation,
      String shiftIds,
      String selectedRole,
      String selectedDateRange) async {
    // Ensure that there are no invisible characters
    final String url =
        'api/facility-management/shiftBasedAttendance/rolebasedreport?userId=$userId&organizationId=$organizationId&shiftIds=$shiftIds&locationId=$selectedLocation&range=$selectedDateRange';

    return await getRequest(baseUrl2, url);
  }

  static Future<http.Response> fetchRoles(
      int? organizationId, String selectedLocation) async {
    return await getRequest(baseUrl2,
        'api/hrm/employee/getrolebasedonproject?organizationId=$organizationId&locationId=$selectedLocation');
  }

  static Future<http.Response> deleteDeviceToken(
    int userId,
    String androidId,
    int organizationId,
    String deviceToken,
  ) async {
    // Prepare the data as URL query parameters
    final String url = Uri.parse(
            '$notificationUrl/api/user/fcm/delete?userId=$userId&androidId=$androidId&organizationId=$organizationId&deviceToken=$deviceToken')
        .toString();

    // Headers setup: Adding Authorization header if accessToken exists
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      if (accessToken != null)
        'Authorization': 'Bearer $accessToken', // Add Authorization header
      if (userId != null) 'proxyId': userId.toString(),
      if (userId != null) 'userId': userId.toString(),
    };

    try {
      // Send the PUT request with query parameters in the URL and headers
      final response = await http.delete(
        Uri.parse(url),
        headers: headers, // Add the headers here
      );

      // Return the response for further processing
      return response;
    } catch (e) {
      throw Exception("Error during PUT request: $e");
    }
  }

  static Future<http.Response> fetchOrgProjectsInOtScreen(
      int organizationId) async {
    return await getRequest(baseUrl3,
        'api/project/project/findAll?name=&organizationId=$organizationId');
  }

  static Future<http.Response> fetchOrgRoleInOtScreen(
      int intOraganizationId) async {
    return await getRequest(baseUrl1,
        'api/user/role/fetchall?roleName=&organizationId=$intOraganizationId');
  }

  static Future<http.Response> fetchOrgEmployeeInOtScreen(
      int intOraganizationId, int projectAssigned, int employeeRoleId) async {
    return await getRequest(baseUrl1,
        'api/hrm/employee/getall/org?organizationId=$intOraganizationId&firstName=&projectAssigned=$projectAssigned&employeeRoleId=$employeeRoleId');
  }

  static Future<http.Response> postOt(
      Map<String, dynamic> employeeOTBean) async {
    return await postRequest(
        baseUrl1, 'api/facility-management/employeeOT/save', employeeOTBean);
  }

  static Future<http.Response> fetchOtReport({
    required String projectId,
    required String roleId,
    required String firstName,
    required String range,
    required int? organizationId,
  }) async {
    return await getRequest(baseUrl2,
        'api/facility-management/employeeOT/employee/getall?toLocation=&projectId=$projectId&organizationId=$organizationId&roleId=$roleId&firstName=$firstName&range=$range');
  }

  static Future<http.Response> fetchOtReportProjectWise(
      int organizationId, String selectedDateRange) async {
    return await getRequest(baseUrl2,
        'api/facility-management/employeeOT/employee/otcount?toLocation=&projectId=&organizationId=$organizationId&range=$selectedDateRange');
  }

  static Future<http.Response> fetchRolesInOT(
      int? organizationId, String selectedLocation) async {
    return await getRequest(baseUrl2,
        'api/hrm/employee/getrolebasedonproject?organizationId=$organizationId&locationId=$selectedLocation');
  }

  static Future<http.Response> fetchProjectsInOtScreen(int? orgId) async {
    return await getRequest(
        baseUrl2, 'api/project/project/findAll?name=&organizationId=$orgId');
  }

  static Future<http.Response> submitFoTransactionData(
      String qrTransactionData, File imageFile) async {
    final url =
        Uri.parse('${baseUrl2}api/facility-management/fieldOfficerPatrol/save');

    var request = http.MultipartRequest('POST', url);

    request.fields['fieldOfficerPatrolBean'] = qrTransactionData;

    if (imageFile != null && await imageFile.exists()) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageFile',
          imageFile.path,
          contentType: MediaType(
            'image',
            path.extension(imageFile.path).replaceFirst('.', ''),
          ),
        ),
      );
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response;
    } catch (e) {
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchFieldOfficerPatrolReports(
    int organizationId,
    String projectId,
    String selectedDateRange,
    int page,
    int pageSize,
    String searchQuery,
  ) async {
    return await getRequest(baseUrl2,
        'api/facility-management/fieldOfficerPatrol/getallfiledofficepatrol?organizationId=$organizationId&projectId=$projectId&rangeOfDays=$selectedDateRange&page=$page&size=$pageSize&userName=$searchQuery');
  }

  static Future<http.Response> FodownloadImage({
    required String projectName,
    required String date,
    required String userName,
    required String phoneNumber,
    required String imageUrl,
  }) async {
    // Encode each query parameter to ensure proper URL formatting
    String encodedProjectName = Uri.encodeComponent(projectName);
    String encodedDate = Uri.encodeComponent(date);
    String encodedUserName = Uri.encodeComponent(userName);
    String encodedPhoneNumber = Uri.encodeComponent(phoneNumber);
    String encodedImageUrl = Uri.encodeComponent(imageUrl);

    // Use encoded values in the endpoint URL
    String endpoint =
        'api/facility-management/fieldOfficerPatrol/get-fieldofficer-image?projectName=$encodedProjectName&date=$encodedDate&userName=$encodedUserName&phoneNumber=$encodedPhoneNumber&imageUrl=$encodedImageUrl';

    // Make the HTTP request
    return await getRequest(baseUrl1, endpoint); // Use getRequest
  }

  static Future<http.Response> submitRegisterFace(
      String empId, File imageFile, List<double> embeddings) async {
    final url =
        Uri.parse('${baseUrl2}api/facility-management/attendance/register');

    var request = http.MultipartRequest('POST', url);

    // Convert list to JSON string
    String embeddingsJson = jsonEncode(embeddings);
    request.fields['employeeId'] = empId;
    request.fields['embeddings'] = embeddingsJson;

    if (await imageFile.exists()) {
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final mimeType = fileExtension == '.png' ? 'png' : 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'fileName',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ),
      );
    } else {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    // Add Authorization header
    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('✅ Face registered: ${response.body}');
      } else {
        print('❌ Server error: ${response.statusCode}, Body: ${response.body}');
      }

      return response;
    } catch (e) {
      print('🚨 Error during face registration: $e');
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> submitCaptureFace({
    required File imageFile,
    required List<double> embeddings,
    required int shiftId,
    required int? organizationId,
    required bool isLogin,
    required int? locationId, // true = login, false = logout
  }) async {
    final endpoint = isLogin ? 'loginPersonDetection' : 'logoutPersonDetection';

    final url = Uri.parse(
      '${baseUrl2}api/facility-management/shiftBasedAttendance/$endpoint',
    );

    var request = http.MultipartRequest('POST', url);

    request.fields['embeddings'] = jsonEncode(embeddings);
    request.fields['shiftId'] = shiftId.toString();
    request.fields['organizationId'] = organizationId.toString();
    request.fields['locationId'] = locationId.toString();

    if (await imageFile.exists()) {
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final mimeType = fileExtension == '.png' ? 'png' : 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ),
      );
    } else {
      throw Exception('Image file does not exist: ${imageFile.path}');
    }

    request.headers['Authorization'] = 'Bearer $accessToken';

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print(
            '✅ [${isLogin ? 'IN' : 'OUT'}] Face capture submitted successfully');
      } else {
        print(
            '❌ [${isLogin ? 'IN' : 'OUT'}] Server responded with ${response.statusCode}: ${response.body}');
      }

      return response;
    } catch (e) {
      print('🚨 [${isLogin ? 'IN' : 'OUT'}] Error submitting capture: $e');
      throw Exception('Error during upload: $e');
    }
  }

  static Future<http.Response> fetchUsersForFace(
      String organizationId, String userName) async {
    return await getRequest(baseUrl1,
        'api/user/user/fetchall?organizationId=$organizationId&userName=$userName');
  }
}
