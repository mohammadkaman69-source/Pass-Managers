import 'package:flutter/material.dart';

import '../services/password_service.dart';
import 'home_page.dart';


class LoginPage extends StatefulWidget {

  const LoginPage({super.key});


  @override
  State<LoginPage> createState() =>
      _LoginPageState();

}



class _LoginPageState extends State<LoginPage> {


  final passwordController =
      TextEditingController();


  final confirmController =
      TextEditingController();


  final emailController =
      TextEditingController();



  bool createMode = false;



  @override
  void initState() {

    super.initState();

    checkPasswordStatus();

  }



  Future<void> checkPasswordStatus() async {


    final exists =
        await PasswordService.hasPassword();


    if(!mounted){
      return;
    }


    setState(() {

      createMode = !exists;

    });

  }



  bool validatePassword(String password) {


    if(password.length < 8){
      return false;
    }
