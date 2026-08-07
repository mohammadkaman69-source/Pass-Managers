import 'package:flutter/material.dart';

import 'add_password_page.dart';


class HomePage extends StatefulWidget {

  const HomePage({super.key});


  @override
  State<HomePage> createState() =>
      _HomePageState();

}



class _HomePageState extends State<HomePage> {


  @override
  Widget build(BuildContext context) {


    return Scaffold(

      appBar: AppBar(

        title:
            const Text("Pass Managers"),

      ),



      body: Center(

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.center,


          children: [


            const Icon(

              Icons.lock_outline,

              size:80,

            ),



            const SizedBox(height:20),



            const Text(

              "No passwords saved yet",

              style: TextStyle(

                fontSize:18,

              ),

            ),



            const SizedBox(height:30),



            ElevatedButton.icon(

              onPressed: () {


                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder:(context) =>
                        const AddPasswordPage(),

                  ),

                );


              },


              icon:
                  const Icon(Icons.add),


              label:
                  const Text("Add Password"),


            ),



          ],


        ),


      ),


    );


  }


}
