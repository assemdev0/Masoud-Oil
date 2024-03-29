import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:masoud_oil/data_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'custom_text_form_fieled.dart';
import 'oil_type_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _formKey = GlobalKey<FormState>();
  var nameController = TextEditingController();
  var phoneController = TextEditingController();
  var carTypeController = TextEditingController();
  var anotherOilTypeController = TextEditingController();
  var notesController = TextEditingController();

  bool isFilter = false;
  bool isSendLoading = false;
  bool isLocationLoading = false;
  String token = '';
  String oilTypeName = '';
  String oilTypeNumber = '';
  String oilTypePrice = '';
  List<OilTypeModel> oilTypesModel = [];
  List<DetailsOilTypeModel> oilTypeDetails = [];

  /* List<DetailsOilTypeModel> oilTypeList = [];

  Future<void> getOilType() async {
    final String response =
        await rootBundle.loadString('assets/json/oil_type.json');
    final data = await json.decode(response);
    print(data['items']);
    setState(() {
      oilTypeList = data['items']
          .map<DetailsOilTypeModel>(
              (json) => DetailsOilTypeModel.fromJson(json))
          .toList();
    });
    setState(() {
      initialOilType = oilTypeList[0];
    });
    print(oilTypeList);
  }*/

  final apiKey =
      'AAAAMkuq8Yc:APA91bEkoVR0NAK0iJW89UMbfoVNDEynNwOl0Z8WBNeWLK7Cpxp4H84A03ivkq5UOVADmFsHoEy0waUBxxdiZC5o8ZMp6MvXoBiXVf10V4bLjDxYMaLwL_44pRgbJMpbN_JPCd0zcgRp';
  Position? _currentPosition;
  void _getCurrentLocation() async {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((value) {
      setState(() {
        _currentPosition = value;
        isLocationLoading = false;
        print('${value.latitude}, ${value.longitude}');
        Fluttertoast.showToast(msg: 'تم تحديد الموقع بنجاح');
      });
    }).catchError((error) {
      setState(() {
        isLocationLoading = false;
      });
      Permission.location.isGranted.then((value) {
        if (value) {
          Fluttertoast.showToast(msg: 'حدث خطأ ما\nتأكد من تشغيل الموقع');
        } else {
          Fluttertoast.showToast(msg: 'لم يتم السماح بالوصول إلى الموقع');
        }
      });
    });
  }

  void _sendData() {
    DataModel dataModel = DataModel(
      name: nameController.text,
      phone: phoneController.text,
      oilType: anotherOilTypeController.text == ''
          ? '$oilTypeName $oilTypeNumber'
          : anotherOilTypeController.text,
      notes: notesController.text,
      carType: carTypeController.text,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      date: DateTime.now().toString(),
    );
    print(dataModel);
    FirebaseFirestore.instance
        .collection('data')
        .add(dataModel.toJson())
        .then((value) async {
      setState(() {
        isSendLoading = false;
      });
      _sendNotification();
      _showCustomDialog(context);
    }).catchError((error) {
      Fluttertoast.showToast(msg: 'حدث خطأ ما');
    });
  }

  void _showCustomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تم إرسال الطلب بنجاح\nهل تريد إرسال طلب أخر؟'),
        actions: <Widget>[
          TextButton(
            child: const Text('حسنًا'),
            onPressed: () {
              setState(() {
                nameController.text = '';
                phoneController.text = '';
                carTypeController.text = '';
                notesController.text = '';
                anotherOilTypeController.text = '';
                oilTypeDetails = [];
                _currentPosition = null;
                Navigator.pop(context);
              });
            },
          ),
          TextButton(
            child: const Text('اغلاق البرنامج'),
            onPressed: () {
              setState(() {
                SystemNavigator.pop();
              });
            },
          ),
        ],
      ),
    );
  }

  void _getToken() {
    FirebaseFirestore.instance.collection('tokens').get().then((value) {
      setState(() {
        token = value.docs[0].data()['token'];
        print(token);
      });
    }).catchError((error) {
      Fluttertoast.showToast(msg: 'حدث خطأ ما');
    });
  }

  Future<void> _sendNotification() async {
    QuerySnapshot ref =
        await FirebaseFirestore.instance.collection('tokens').get();

    try {
      for (var snapshot in ref.docs) {
        http.Response response = await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'key=$apiKey',
          },
          body: jsonEncode(
            <String, dynamic>{
              'notification': <String, dynamic>{
                "title": "طلب جديد",
                "body":
                    "اسم صاحب الطلب: ${nameController.text}\nنوع الزيت: ${anotherOilTypeController.text == '' ? ("$oilTypeName $oilTypeNumber") : anotherOilTypeController.text}",
              },
              'priority': 'high',
              'data': <String, dynamic>{
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'id': '1',
                'status': 'done'
              },
              'to': snapshot['token'],
            },
          ),
        );
      }
    } catch (e) {
      print("error push notification");
    }
  }

  void getAllOilTypes() {
    oilTypesModel = [];
    FirebaseFirestore.instance.collection('oilType').get().then((value) {
      for (int i = 0; i < value.docs.length; i++) {
        oilTypesModel.add(OilTypeModel(
          name: value.docs[i].data()['name'],
          id: value.docs[i].id,
        ));
      }
      setState(() {
        oilTypeName = oilTypesModel[0].name.toString();
      });
      print(oilTypesModel.toString());
    }).catchError((error) {
      print(oilTypesModel.toString());
      print(error.toString());
      Fluttertoast.showToast(msg: 'حدث خطأ ما');
    });
    // print(oilTypesModel[0]);
  }

  void getOilTypeDetails({
    required String type,
  }) {
    FirebaseFirestore.instance
        .collection('oilType')
        .doc(type)
        .collection('types')
        .get()
        .then((value) {
      oilTypeDetails = [];
      for (var element in value.docs) {
        setState(() {
          oilTypeDetails.add(DetailsOilTypeModel(
            id: element.id,
            name: element.data()['name'],
            price: element.data()['price'],
          ));
          oilTypeNumber = oilTypeDetails[0].name.toString();
          oilTypePrice = oilTypeDetails[0].price.toString();
        });
      }
      print(oilTypeDetails.toString());
    }).catchError((error) {
      print(oilTypeDetails.toString());
      print(error.toString());
      Fluttertoast.showToast(msg: 'حدث خطأ ما');
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getAllOilTypes();
    _getToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masoud Oil'),
        centerTitle: true,
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.of(context).size.width * 0.05,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'أدخل بياناتك',
                  style: Theme.of(context).textTheme.headline4!.copyWith(
                        color: Colors.black,
                      ),
                ),
                CustomTextFormField(
                  formKey: _formKey,
                  backgroundColor: Colors.white,
                  onTap: () {},
                  controller: nameController,
                  hint: 'الاسم',
                  prefixIcon: Icons.person,
                  keyboardType: TextInputType.name,
                  obscureText: false,
                  readOnly: false,
                  maxLines: 1,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'الرجاء إدخال البيانات';
                    }
                    return null;
                  },
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.015,
                ),
                CustomTextFormField(
                  formKey: _formKey,
                  backgroundColor: Colors.white,
                  onTap: () {},
                  controller: phoneController,
                  hint: 'رقم المحمول',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  obscureText: false,
                  readOnly: false,
                  maxLines: 1,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'الرجاء إدخال البيانات';
                    }
                    return null;
                  },
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.015,
                ),
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.of(context).size.width * 0.05,
                      horizontal: MediaQuery.of(context).size.width * 0.025,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'نوع الزيت:',
                          style:
                              Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        PopupMenuButton(
                          itemBuilder: (context) {
                            return oilTypesModel.map((oilType) {
                              return PopupMenuItem(
                                value: oilType,
                                child: Text(oilType.name.toString()),
                                onTap: () {
                                  setState(() {
                                    getOilTypeDetails(
                                        type: oilType.id.toString());
                                    oilTypeName = oilType.name!;
                                    print(oilTypeName);
                                  });
                                },
                              );
                            }).toList();
                          },
                          tooltip: 'اختر نوع الزيت',
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MediaQuery.of(context).size.width * 0.05,
                              ),
                              side: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.of(context).size.width * 0.02),
                              child: Text(oilTypeName),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (oilTypeDetails.isNotEmpty)
                          Text(
                            'كيلو متر:',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        if (oilTypeDetails.isNotEmpty)
                          PopupMenuButton(
                            itemBuilder: (context) {
                              return oilTypeDetails.map((oilType) {
                                return PopupMenuItem(
                                  value: oilType,
                                  child: Text(oilType.name.toString()),
                                  onTap: () {
                                    setState(() {
                                      oilTypePrice = oilType.price!;
                                      oilTypeNumber = oilType.name!;
                                      print(oilTypePrice);
                                    });
                                  },
                                );
                              }).toList();
                            },
                            tooltip: 'اختر عدد الكيلو متر',
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  MediaQuery.of(context).size.width * 0.05,
                                ),
                                side: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal:
                                        MediaQuery.of(context).size.width *
                                            0.02),
                                child: Text(oilTypeNumber),
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (oilTypePrice != '' && oilTypeDetails.isNotEmpty)
                          Text('السعر: $oilTypePrice',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  )),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.015,
                ),
                CustomTextFormField(
                  formKey: _formKey,
                  backgroundColor: Colors.white,
                  onTap: () {},
                  controller: anotherOilTypeController,
                  hint: 'نوع زيت اخر',
                  prefixIcon: Icons.oil_barrel,
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  readOnly: false,
                  maxLines: 1,
                  validator: (value) {
                    // if (value!.isEmpty) {
                    //   return 'الرجاء إدخال البيانات';
                    // }
                    // return null;
                  },
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.015,
                ),
                CustomTextFormField(
                  formKey: _formKey,
                  backgroundColor: Colors.white,
                  onTap: () {},
                  controller: notesController,
                  hint: 'ملاحظات',
                  prefixIcon: Icons.note_alt,
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  readOnly: false,
                  maxLines: 1,
                  validator: (value) {
                    // if (value!.isEmpty) {
                    //   return 'الرجاء إدخال البيانات';
                    // }
                    // return null;
                  },
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.015,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'يوجد فلتر',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.08,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.25,
                      height: MediaQuery.of(context).size.height * 0.1,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Switch(
                          value: isFilter,
                          onChanged: (value) {
                            setState(() {
                              isFilter = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                if (isFilter)
                  CustomTextFormField(
                    formKey: _formKey,
                    backgroundColor: Colors.white,
                    onTap: () {},
                    controller: carTypeController,
                    hint: 'نوع السيارة',
                    prefixIcon: Icons.directions_car,
                    keyboardType: TextInputType.text,
                    obscureText: false,
                    readOnly: false,
                    maxLines: 1,
                    validator: (value) {
                      if (isFilter) {
                        if (value!.isEmpty) {
                          return 'الرجاء إدخال البيانات';
                        }
                        return null;
                      } else {
                        return null;
                      }
                    },
                  ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.015,
                ),
                if (!isLocationLoading)
                  TextButton(
                    onPressed: () async {
                      setState(() {
                        isLocationLoading = true;
                      });
                      _getCurrentLocation();
                    },
                    child: Text(
                      'تحديد الموقع',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.075,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE4944D),
                      ),
                    ),
                  ),
                if (isLocationLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.05,
                ),
                if (isSendLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (!isSendLoading)
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.width * 0.05,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: MaterialButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate() &&
                            _currentPosition != null &&
                            (oilTypeNumber != '' ||
                                anotherOilTypeController.text != '')) {
                          setState(() {
                            isSendLoading = true;
                          });
                          _sendData();
                        } else {
                          Fluttertoast.showToast(
                              msg: 'يجب إدخال جميع البيانات او تحديد الموقع');
                        }
                      },
                      elevation: 5,
                      color: Theme.of(context).primaryColor,
                      clipBehavior: Clip.antiAlias,
                      child: Text(
                        'ارسال',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.075,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.025,
                ),
                Row(
                  children: [
                    Text(
                      'للاستفسار: ',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.05,
                    ),
                    TextButton(
                      onPressed: () {
                        launchUrlString('tel:01093216112');
                      },
                      child: Text(
                        '01093216112',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE4944D),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.05,
                      child: Text(
                        'أو',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE4944D),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        launchUrlString('tel:01152319096');
                      },
                      child: Text(
                        '01152319096',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE4944D),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.025,
                ),
                Text(
                  'يتم توصيل الطلبات في منطقة العبور فقط',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.025,
                ),
                Text(
                  'الوصول في اقرب وقت',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
