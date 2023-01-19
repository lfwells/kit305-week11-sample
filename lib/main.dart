import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

//1. import for camera
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';

//add for download/upload
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';

//add these for web
import 'package:http/http.dart' as http;
import 'dart:convert';

//https://firebase.flutter.dev/docs/storage/usage/
//https://medium.com/codechai/uploading-image-to-firebase-storage-in-flutter-app-android-ios-31ddd66843fc
//https://ptyagicodecamp.github.io/loading-image-from-firebase-storage-in-flutter-app-android-ios-web.html

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: PictureList(),
    ),
  );
}


class PictureList extends StatefulWidget {
  @override
  _PictureListState createState() => _PictureListState();
}

class _PictureListState extends State<PictureList> {

  Future<List<Reference>> fetchImages() async {
    try {
      ListResult result = await FirebaseStorage.instance.ref("/uploads").listAll();
      result.items.forEach((Reference ref) {
        print('Found file: $ref');
      });

      return result.items;
    } on FirebaseException catch(e) {
      print(e);
      return <Reference>[];//return empty list of references on error
    }
  }

  late Future<List<Reference>> _loadImageList;
  late bool _uploading;

  @override
  void initState() {
    super.initState();

    _loadImageList = fetchImages();
    _uploading = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:Text("Picture List")
      ),
      body:FutureBuilder<List<Reference>>( //see slides for more detail on FutureBuilder
        future:_loadImageList,
        builder: (context, snapshot) {
          if (snapshot.hasData == false) {
            return Center(child: CircularProgressIndicator());
          }

          var images = snapshot.data!;
          return ListView.builder(
              itemCount: images.length,
              itemBuilder: (context, i) {
                return ImageListTile(images: images, i:i);
              }
          );
        }
      ),
      floatingActionButton: FloatingActionButton(
        child: _uploading ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors. black),) : Icon(Icons.add),
        onPressed: () async {

          setState(() {
            _uploading = true; //visual feedback of upload
          });

          //web browser upload code (static image, not from camera)
          if (kIsWeb)
          {
            await webUpload();
          }
          //below is android ios, camera upload example
          else
          {
            await androidIOSUpload();
          }

          setState(() { //force rebuild of list
            _loadImageList = fetchImages();
            _uploading = false;
          });
        }
      ),
    );
  }
  Future webUpload() async
  {
    //https://stackoverflow.com/questions/59546381/how-to-get-image-from-url-to-a-file-in-flutter
    final http.Response responseData = await http.get(Uri.parse(
        "https://pbs.twimg.com/media/Ct-BV8PVIAAnS2b?format=jpg&name=large"));
    var uint8list = responseData.bodyBytes.toList();
    var base64 = "data:image/jpeg;base64," + base64Encode(uint8list);
    try {
      await FirebaseStorage.instance
          .ref('uploads/hello-world' + DateTime
          .now()
          .millisecondsSinceEpoch
          .toString() + '.jpeg')
          .putString(base64, format: PutStringFormat.dataUrl);
    } on FirebaseException {
      // e.g, e.code == 'canceled'
    }
  }
  Future androidIOSUpload() async
  {
    // 2. Obtain a list of the available cameras on the device.
    final cameras = await availableCameras();

    // Get a specific camera from the list of available cameras.
    final firstCamera = cameras.first;

    //use the TakePictureScreen to get an image. This is like doing a startActivityForResult
    var picture = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TakePictureScreen(
              // Pass the appropriate camera to the TakePictureScreen widget.
                camera: firstCamera
            )
        )
    );

    //now do the upload
    try {
      await FirebaseStorage.instance
          .ref('uploads/hello-world' + DateTime
                                          .now()
                                          .millisecondsSinceEpoch
                                          .toString() + '.jpeg')
          .putFile(picture);
    } on FirebaseException {
      // e.g, e.code == 'canceled'
    }
  }
}

class ImageListTile extends StatelessWidget {
  const ImageListTile({
    Key? key,
    required this.images,
    required this.i,
  }) : super(key: key);

  final List<Reference> images;
  final int i;

  @override
  Widget build(BuildContext context) {
    return ListTile(
        title: Text(images[i].name),
        leading: FutureBuilder<String>( //complicated, because getDownloadUrl is async
          future: images[i].getDownloadURL(),
          builder: (context, snapshot) {
            if (snapshot.hasData == false)
            {
              return CircularProgressIndicator();
            }

            var downloadURL = snapshot.data!;
            return SizedBox(width:64, child: Image.network(downloadURL));
          }
        ),
    );
  }
}



//------------------------------------------
//camera example follows:
//------------------------------------------

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;

  const TakePictureScreen({
    Key? key,
    required this.camera,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take a picture')),
      // Wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner
      // until the controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera_alt),
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and get the file `image`
            // where it was saved.
            final image = await _controller.takePicture();
            final picture = File(image.path);

            Navigator.pop(context, picture); //comment out these two lines
            return; //comment out these two lines

            //this was the camera sample from flutter, show the image full-screen. Comment out pop and return above to see it
            // If the picture was taken, display it on a new screen.
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}