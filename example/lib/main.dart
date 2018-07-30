import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_paystack/paystack_sdk.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// To get started quickly, change this to your heroku deployment of
// https://github.com/PaystackHQ/sample-charge-card-backend
// Step 1. Visit https://github.com/PaystackHQ/sample-charge-card-backend
// Step 2. Click "Deploy to heroku"
// Step 3. Login with your heroku credentials or create a free heroku account
// Step 4. Provide your secret key and an email with which to start all test transactions
// Step 5. Copy the url generated by heroku (format https://some-url.herokuapp.com) into the space below
String backendUrl = 'https://wilbur-paystack.herokuapp.com';
// Set this to a public key that matches the secret key you supplied while creating the heroku instance
String paystackPublicKey = '{YOUR_PAYSTACK_PUBLIC_KEY}';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Paystack Example',
      theme: new ThemeData(
        primaryColor: Colors.lightBlue[900],
      ),
      home: new HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _scaffoldKey = GlobalKey<ScaffoldState>();
  var _formKey = GlobalKey<FormState>();
  var _autoValidate = false;
  var _localInProgress = false;
  var _remoteInProgress = false;
  Charge _charge;
  Transaction _transaction;
  String _reference = 'No transaction yet';
  String _error = '';
  String _backendMessage = '';
  String cardNumber;
  String cvv;
  int expiryMonth = 0;
  int expiryYear = 0;

  @override
  void initState() {
    _validateSetupParams();
    PaystackSdk.initialize(publicKey: paystackPublicKey);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var screenWidth = size.width;
    var screenHeight = size.height;

    var appBar = new AppBar(
      title: new Text('Paystack Example'),
    );

    return new Scaffold(
      key: _scaffoldKey,
      appBar: appBar,
      body: new Container(
        color: new Color(0xFF1C3A4B),
        child: new ListView(
          children: <Widget>[
            new Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              width: double.infinity,
              height: ((screenHeight / 2) - appBar.preferredSize.height),
              child: new Form(
                key: _formKey,
                autovalidate: _autoValidate,
                child: new SingleChildScrollView(
                  child: new ListBody(
                    children: <Widget>[
                      new SizedBox(
                        height: 5.0,
                      ),
                      new Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          new Container(
                            width: screenWidth / 1.7,
                            child: new TextFormField(
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                WhitelistingTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                border: const UnderlineInputBorder(),
                                labelText: 'Card number',
                              ),
                              onSaved: (String value) => cardNumber = value,
                              validator: (String value) =>
                                  value.isEmpty ? fieldIsReq : null,
                            ),
                          ),
                          new SizedBox(
                            width: 30.0,
                          ),
                          new Container(
                              width: screenWidth / 5,
                              child: new TextFormField(
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  WhitelistingTextInputFormatter.digitsOnly,
                                  new LengthLimitingTextInputFormatter(4)
                                ],
                                decoration: const InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: 'CVV'),
                                onSaved: (String value) => cvv = value,
                                validator: (String value) =>
                                    value.isEmpty ? fieldIsReq : null,
                              ))
                        ],
                      ),
                      new SizedBox(
                        height: 20.0,
                      ),
                      new Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          new Container(
                            width: screenWidth / 5,
                            child: new TextFormField(
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                WhitelistingTextInputFormatter.digitsOnly,
                                new LengthLimitingTextInputFormatter(2)
                              ],
                              decoration: const InputDecoration(
                                border: const UnderlineInputBorder(),
                                labelText: 'MM',
                              ),
                              onSaved: (String value) =>
                                  expiryMonth = int.parse(value),
                              validator: (String value) =>
                                  value.isEmpty ? fieldIsReq : null,
                            ),
                          ),
                          new SizedBox(
                            width: 30.0,
                          ),
                          new Container(
                              width: screenWidth / 5,
                              child: new TextFormField(
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  WhitelistingTextInputFormatter.digitsOnly,
                                  new LengthLimitingTextInputFormatter(4)
                                ],
                                decoration: const InputDecoration(
                                    border: const UnderlineInputBorder(),
                                    labelText: 'YYYY'),
                                onSaved: (String value) =>
                                    expiryYear = int.parse(value),
                                validator: (String value) =>
                                    value.isEmpty ? fieldIsReq : null,
                              )),
                        ],
                      ),
                      new SizedBox(
                        height: 40.0,
                      ),
                      _localInProgress || _remoteInProgress
                          ? new Container(
                              alignment: Alignment.center,
                              child: Platform.isIOS
                                  ? new CupertinoActivityIndicator()
                                  : new CircularProgressIndicator(),
                            )
                          : new Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _getPlatformButton(
                                    'Charge Card (Init From Server)', false),
                                new SizedBox(
                                  height: 10.0,
                                ),
                                _getPlatformButton(
                                    'Charge Card (Init From App)', true),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
            new Container(
              width: double.infinity,
              height: screenHeight / 2.35, // Can't 2.0
              child: new Container(
                margin: const EdgeInsets.only(top: 15.0),
                padding: const EdgeInsets.all(20.0),
                child: new SingleChildScrollView(
                  child: new ListBody(
                    children: <Widget>[
                      new Text(
                        _reference,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18.0),
                      ),
                      new SizedBox(height: 20.0),
                      new Text(
                        _error,
                        style: new TextStyle(color: Colors.red[400]),
                      ),
                      new SizedBox(
                        height: 20.0,
                      ),
                      new Text(
                        _backendMessage,
                        style: const TextStyle(color: Colors.white),
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _getPlatformButton(String string, bool isLocal) {
    // is still in progress
    Widget widget;
    if (Platform.isIOS) {
      widget = new CupertinoButton(
        onPressed: () => _startAfreshCharge(isLocal),
        color: CupertinoColors.activeBlue,
        child: new Text(
          string,
        ),
      );
    } else {
      widget = new RaisedButton(
        onPressed: () => _startAfreshCharge(isLocal),
        color: Colors.lightBlue[900],
        textColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13.0, horizontal: 10.0),
        child: new Text(
          string.toUpperCase(),
          style: const TextStyle(fontSize: 17.0),
        ),
      );
    }
    return widget;
  }

  _showSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(new SnackBar(
      content: new Text(message),
      duration: const Duration(seconds: 3),
    ));
  }

  bool _allInputsAreValid() {
    final FormState form = _formKey.currentState;
    if (!form.validate()) {
      setState(() {
        _autoValidate = true; // Start validating on every change.
      });
      return false;
    } else {
      form.save();
      return true;
    }
  }

  _startAfreshCharge(bool isLocal) {
    if (!_allInputsAreValid()) {
      return;
    }

    _charge = Charge();
    _charge.card = _getCardFromUI();

    if (isLocal) {
      setState(() => _localInProgress = true);
      // Set transaction params directly in app (note that these params
      // are only used if an access_code is not set. In debug mode,
      // setting them after setting an access code would throw an exception
      _charge
        ..amount = 2000
        ..email = 'faradaywilly@gmail.com'
        ..reference = _getReference()
        ..putCustomField('Charged From', 'Flutter SDK');
      _chargeCard();
    } else {
      // Perform transaction/initialize on Paystack server to get an access code
      // documentation: https://developers.paystack.co/reference#initialize-a-transaction
      setState(() => _remoteInProgress = true);
      _fetchAccessCodeFrmServer();
    }
  }

  _chargeCard() {
    _transaction = null;

    PaystackSdk.chargeCard(context,
        charge: _charge,
        beforeValidate: (transaction) => handleBeforeValidate(transaction),
        onSuccess: (transaction) => handleOnSuccess(transaction),
        onError: (error, transaction) => handleOnError(error, transaction));
  }

  // This is called only before requesting OTP
  // Save reference so you may send to server if error occurs with OTP
  handleBeforeValidate(Transaction transaction) {
    this._transaction = transaction;
    _showSnackBar(_transaction.reference);
    setState(() => _updateReference());
  }

  handleOnError(Object e, Transaction transaction) {
    // If an access code has expired, simply ask your server for a new one
    // and restart the charge instead of displaying error
    this._transaction = transaction;
    if (e is ExpiredAccessCodeException) {
      _startAfreshCharge(false);
      _chargeCard();
      return;
    }

    if (transaction.reference != null) {
      _showSnackBar('${this._transaction.reference} concluded with error: '
          '${e.toString()}');
      _error = '${this._transaction.reference} concluded with error: '
          '${e.toString()}';
      _verifyOnServer();
    } else {
      _showSnackBar(e.toString());
      _error = '${e.toString()}';
    }

    setState(() {
      _localInProgress = false;
      _remoteInProgress = false;
      _updateReference();
    });
  }

  // This is called only after transaction is successful
  handleOnSuccess(Transaction transaction) {
    setState(() {
      _localInProgress = false;
      _remoteInProgress = false;
      this._transaction = transaction;
      _error = '';
      _updateReference();
    });
    _showSnackBar(this._transaction.reference);
    _verifyOnServer();
  }

  _updateReference() {
    if (_transaction.reference != null) {
      _reference = 'Reference: ${_transaction.reference}';
    } else {
      _reference = 'No transaction';
    }
  }

  _validateSetupParams() {
    assert(() {
      if (backendUrl == null || !backendUrl.isNotEmpty) {
        throw new UnimplementedError(
            'Please set a backend url before running the sample');
      }
      if (paystackPublicKey == null ||
          !paystackPublicKey.isNotEmpty ||
          paystackPublicKey == '{YOUR_PAYSTACK_PUBLIC_KEY}') {
        throw new UnimplementedError(
            'Please set a public key before running the sample');
      }
      return true;
    }());
  }

  PaymentCard _getCardFromUI() {
    // Using just the must-required parameters.
    return PaymentCard(
      number: cardNumber,
      cvc: cvv,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
    );

    // Using Cascade notation (similar to Java's builder pattern)
//    return PaymentCard(
//        number: cardNumber,
//        cvc: cvv,
//        expiryMonth: expiryMonth,
//        expiryYear: expiryYear)
//      ..name = 'Segun Chukwuma Adamu'
//      ..country = 'Nigeria'
//      ..addressLine1 = 'Ikeja, Lagos'
//      ..addressPostalCode = '100001';

    // Using optional parameters
//    return PaymentCard(
//        number: cardNumber,
//        cvc: cvv,
//        expiryMonth: expiryMonth,
//        expiryYear: expiryYear,
//        name: 'Ismail Adebola Emeka',
//        addressCountry: 'Nigeria',
//        addressLine1: '90, Nnebisi Road, Asaba, Deleta State');
  }

  String _getReference() {
    String platform;
    if (Platform.isIOS) {
      platform = 'iOS';
    } else {
      platform = 'Android';
    }

    return 'ChargedFrom${platform}_${DateTime
        .now()
        .millisecondsSinceEpoch}';
  }

  void _fetchAccessCodeFrmServer() async {
    String url = '$backendUrl/new-access-code';
    try {
      http.Response response = await http.get(url);
      var body = response.body;
      _charge.accessCode = body;

      _chargeCard();
    } catch (e) {
      setState(() {
        _backendMessage = 'There was a problem getting a new access code form'
            ' the backend: ${e.toString()}';
        _localInProgress = false;
        _remoteInProgress = false;
      });
    }
  }

  void _verifyOnServer() async {
    String url = '$backendUrl/verify/${_transaction.reference}';
    try {
      http.Response response = await http.get(url);
      var body = response.body;

      setState(() {
        _backendMessage = 'Gateway response: $body';
      });
    } catch (e) {
      setState(() {
        _backendMessage = 'There was a problem verifying %s on the backend: '
            '${_transaction.reference} $e';
        _localInProgress = false;
        _remoteInProgress = false;
      });
    }
  }
}

const fieldIsReq = 'Field is required';
