import 'package:flutter/material.dart';

import '../services/password_service.dart';
import 'home_page.dart';


class LoginPage extends StatefulWidget {

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();

}


class _LoginPageState extends State<LoginPage> {

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmController =
      TextEditingController();

  final TextEditingController emailController =
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


    if (!mounted) {
      return;
    }


    setState(() {

      createMode = !exists;

    });

  }



  bool validatePassword(String password) {

    if (password.length < 8) {
      return false;
    }


    final hasLetter =
        RegExp(r'[A-Za-z]').hasMatch(password);


    final hasNumber =
        RegExp(r'[0-9]').hasMatch(password);


    return hasLetter && hasNumber;

  }



  bool validateEmail(String email) {

    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);

  }



  Future<void> submit() async {


    if (createMode) {


      if (!validatePassword(passwordController.text)) {

        showMessage(
          "Password must be at least 8 characters and contain letters and numbers",
        );

        return;

      }



      if (passwordController.text !=
          confirmController.text) {


        showMessage(
          "Passwords do not match",
        );

        return;

      }



      if (!validateEmail(emailController.text)) {


        showMessage(
          "Invalid email format",
        );

        return;

      }



      await PasswordService.saveCredentials(
        passwordController.text,
        emailController.text,
      );


      openHome();



    } else {


      if (passwordController.text.isEmpty) {


        showMessage(
          "Enter Master Password",
        );

        return;

      }



      final result =
          await PasswordService.checkPassword(
            passwordController.text,
          );



      if (result) {

        openHome();

      } else {

        showMessage(
          "Wrong Master Password",
        );

      }


    }

  }



  void showMessage(String message) {


    if (!mounted) {
      return;
    }


    ScaffoldMessenger.of(context)
        .showSnackBar(

      SnackBar(
        content: Text(message),
      ),

    );

  }



  void openHome() {


    if (!mounted) {
      return;
    }


    Navigator.pushReplacement(

      context,

      MaterialPageRoute(

        builder: (context) =>
            const HomePage(),

      ),

    );

  }



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      body: Center(

        child: Padding(

          padding:
              const EdgeInsets.all(30),


          child: SingleChildScrollView(

            child: Column(

              mainAxisSize:
                  MainAxisSize.min,


              children: [


                const Text(

                  "Pass Managers",

                  style: TextStyle(

                    fontSize: 32,

                    fontWeight:
                        FontWeight.bold,

                  ),

                ),



                const SizedBox(height: 30),



                TextField(

                  controller:
                      passwordController,


                  obscureText: true,


                  decoration:
                      const InputDecoration(

                    labelText:
                        "Master Password",

                  ),

                ),



                if (createMode) ...[


                  const SizedBox(height: 20),



                  TextField(

                    controller:
                        confirmController,


                    obscureText: true,


                    decoration:
                        const InputDecoration(

                      labelText:
                          "Confirm Master Password",

                    ),

                  ),



                  const SizedBox(height: 20),



                  TextField(

                    controller:
                        emailController,


                    keyboardType:
                        TextInputType.emailAddress,


                    decoration:
                        const InputDecoration(

                      labelText:
                          "Recovery Email",

                    ),

                  ),


                ],



                const SizedBox(height: 25),



                ElevatedButton(

                  onPressed:
                      submit,


                  child: Text(

                    createMode
                        ? "Create"
                        : "Login",

                  ),

                ),



                if (!createMode) ...[


                  const SizedBox(height: 25),



                  const Text(

                    "Forgot Password?",

                    style: TextStyle(

                      color:
                          Colors.grey,

                    ),

                  ),



                  const SizedBox(height: 8),



                  const Text(

                    "Password recovery will be available soon",

                    style: TextStyle(

                      color:
                          Colors.grey,

                      fontSize: 12,

                    ),

                  ),


                ],


              ],

            ),

          ),

        ),

      ),

    );

  }


}
