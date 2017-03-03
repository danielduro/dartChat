import 'dart:html';
import 'dart:async';

import 'package:angular2/core.dart';
import 'package:firebase/firebase.dart' as fb;
import '../models/message.dart';

@Injectable()
class FirebaseService {
  fb.Auth _fbAuth;
  fb.GoogleAuthProvider _fbGoogleAuthProvider;
  fb.Database _fbDatabase;
  fb.Storage _fbStorage;
  fb.DatabaseReference _fbRefMessages;
  fb.User user;
  List<Message> messages;

  FirebaseService() {
    fb.initializeApp(
        apiKey: "",
        authDomain: "",
        databaseURL: "",
        storageBucket: ""
    );
    _fbGoogleAuthProvider = new fb.GoogleAuthProvider();
    _fbAuth = fb.auth();
    _fbAuth.onAuthStateChanged.listen(_authChanged);
    _fbDatabase = fb.database();
    _fbRefMessages = _fbDatabase.ref("messages");
    _fbStorage = fb.storage();
  }

  void _authChanged(fb.AuthEvent event) {

    user = event.user;

    if (user != null){
      messages = [];
      _fbRefMessages.limitToLast(12).onChildAdded.listen(_newMessage);
    }

  }

  Future signIn() async {

    try {

      await _fbAuth.signInWithPopup(_fbGoogleAuthProvider);

    }
    catch (error) {

      print("$runtimeType::login() -- $error");

    }
  }

  void signOut() {

    _fbAuth.signOut();
  }

  void _newMessage(fb.QueryEvent event) {
    Message msg = new Message.fromMap(event.snapshot.val());
    messages.add(msg);
    print(msg.text);
  }

  Future sendMessage({String text, String imageURL}) async {

    try {
      Message msg = new Message(user.displayName, text, user.photoURL, imageURL);
      await _fbRefMessages.push(msg.toMap());
    }
    catch (error) {
      print("$runtimeType::sendMessage() -- $error");
    }
  }

  Future sendImage(File file) async {

    fb.StorageReference fbRefImage = _fbStorage.ref("${user.uid}/${new DateTime.now()}/${file.name}");
    fb.UploadTask task = fbRefImage.put(file, new fb.UploadMetadata(contentType: file.type));
    StreamSubscription sub;
    sub = task.onStateChanged.listen((fb.UploadTaskSnapshot snapshot){
      print("Uploading Image -- Transfered ${snapshot.bytesTransferred}/${snapshot.totalBytes}...");
      if (snapshot.bytesTransferred == snapshot.totalBytes) {
        sub.cancel();
      }
    }, onError: (fb.FirebaseError error) {
      print(error.message);
    });

    try {
      fb.UploadTaskSnapshot snapshot = await task.future;

      if (snapshot.state == fb.TaskState.SUCCESS) {
        sendMessage(imageURL: snapshot.downloadURL.toString());
      }
    } catch (error) {
      print(error);
    }

  }

}