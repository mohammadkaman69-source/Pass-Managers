import 'package:flutter/material.dart';



class AddPasswordPage extends StatefulWidget {

  const AddPasswordPage({super.key});


  @override
  State<AddPasswordPage> createState() =>
      _AddPasswordPageState();

}




class _AddPasswordPageState
    extends State<AddPasswordPage> {



  final titleController =
      TextEditingController();


  final usernameController =
      TextEditingController();


  final passwordController =
      TextEditingController();


  final websiteController =
      TextEditingController();


  final noteController =
      TextEditingController();





  @override
  Widget build(BuildContext context) {


    return Scaffold(

      appBar: AppBar(

        title:
            const Text("Add Password"),

      ),



      body: Padding(

        padding:
            const EdgeInsets.all(20),



        child: SingleChildScrollView(

          child: Column(

            children: [



              TextField(

                controller:
                    titleController,


                decoration:
                    const InputDecoration(

                  labelText:
                      "Title",

                ),

              ),



              const SizedBox(height:15),



              TextField(

                controller:
                    usernameController,


                decoration:
                    const InputDecoration(

                  labelText:
                      "Username",

                ),

              ),



              const SizedBox(height:15),



              TextField(

                controller:
                    passwordController,


                obscureText:
                    true,


                decoration:
                    const InputDecoration(

                  labelText:
                      "Password",

                ),

              ),



              const SizedBox(height:15),



              TextField(

                controller:
                    websiteController,


                decoration:
                    const InputDecoration(

                  labelText:
                      "Website",

                ),

              ),



              const SizedBox(height:15),



              TextField(

                controller:
                    noteController,


                maxLines:
                    3,


                decoration:
                    const InputDecoration(

                  labelText:
                      "Note",

                ),

              ),



              const SizedBox(height:30),



              ElevatedButton(

                onPressed: () {


                  ScaffoldMessenger.of(context)
                      .showSnackBar(

                    const SnackBar(

                      content:
                          Text(
                            "Save will be added later",
                          ),

                    ),

                  );


                },


                child:
                    const Text("Save"),


              ),



            ],


          ),

        ),

      ),

    );


  }


}
