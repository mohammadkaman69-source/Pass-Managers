import 'package:flutter/material.dart';
import '../services/password_service.dart';
import 'home_page.dart';


class LoginPage extends StatefulWidget {

  const LoginPage({super.key});


  @override
  State<LoginPage> createState() => _LoginPageState();

}



class _LoginPageState extends State<LoginPage>{

  final controller = TextEditingController();


  bool creating = false;


  @override
  void initState(){

    super.initState();

    check();

  }


  Future<void> check() async {

    creating = !(await PasswordService.hasPassword());

    setState(() {});

  }



  Future<void> submit() async {


    if(controller.text.isEmpty) return;


    if(creating){

      await PasswordService.savePassword(
        controller.text
      );


      openHome();


    }else{


      bool ok = await PasswordService.checkPassword(
        controller.text
      );


      if(ok){

        openHome();

      }else{

        ScaffoldMessenger.of(context)
        .showSnackBar(
          const SnackBar(
            content: Text("Wrong password")
          )
        );

      }

    }


  }



  void openHome(){

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:(context)=>const HomePage()
      )
    );

  }



  @override
  Widget build(BuildContext context){

    return Scaffold(

      body: Center(

        child: Padding(

          padding: const EdgeInsets.all(30),

          child: Column(

            mainAxisSize: MainAxisSize.min,


            children:[


              const Text(
                "Pass Managers",
                style: TextStyle(
                  fontSize:32,
                  fontWeight:FontWeight.bold
                ),
              ),


              const SizedBox(height:30),


              TextField(

                controller:controller,

                obscureText:true,

                decoration:InputDecoration(

                  labelText:
                  creating
                  ?"Create Master Password"
                  :"Enter Master Password"

                ),

              ),


              const SizedBox(height:20),


              ElevatedButton(

                onPressed:submit,

                child:Text(
                  creating
                  ?"Create"
                  :"Login"
                ),

              )


            ]

          ),

        ),

      ),

    );

  }

}
