import 'package:flutter/material.dart';

import '../services/password_service.dart';
import 'home_page.dart';


class LoginPage extends StatefulWidget {

  const LoginPage({super.key});


  @override
  State<LoginPage> createState() => _LoginPageState();

}



class _LoginPageState extends State<LoginPage> {


  final TextEditingController controller =
      TextEditingController();


  bool createMode = false;



  @override
  void initState() {

    super.initState();

    checkPasswordStatus();

  }



  Future<void> checkPasswordStatus() async {


    bool exists =
        await PasswordService.hasPassword();


    if(!mounted){
      return;
    }


    setState(() {

      createMode = !exists;

    });


  }



  Future<void> submit() async {


    if(controller.text.isEmpty){

      return;

    }


    if(createMode){


      await PasswordService.savePassword(
        controller.text,
      );


      openHome();


    }else{


      bool result =
          await PasswordService.checkPassword(
            controller.text,
          );


      if(result){


        openHome();


      }else{


        if(!mounted){
          return;
        }


        ScaffoldMessenger.of(context)
        .showSnackBar(

          const SnackBar(

            content:
            Text("Wrong Master Password"),

          ),

        );


      }


    }


  }



  void openHome(){


    if(!mounted){
      return;
    }


    Navigator.pushReplacement(

      context,

      MaterialPageRoute(

        builder:(context)=>
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


          child: Column(

            mainAxisSize:
            MainAxisSize.min,


            children:[


              const Text(

                "Pass Managers",

                style: TextStyle(

                  fontSize:32,

                  fontWeight:
                  FontWeight.bold,

                ),

              ),



              const SizedBox(height:30),



              TextField(

                controller:
                controller,


                obscureText:true,


                decoration:
                InputDecoration(

                  labelText:

                  createMode

                  ? "Create Master Password"

                  : "Enter Master Password",

                ),

              ),



              const SizedBox(height:20),



              ElevatedButton(

                onPressed:submit,


                child:

                Text(

                  createMode

                  ? "Create"

                  : "Login",

                ),

              )


            ],


          ),


        ),


      ),


    );


  }


}
