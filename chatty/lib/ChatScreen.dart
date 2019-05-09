import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chatty/ChatMessageListItem.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

final googleSIgnIn = new GoogleSignIn();
final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;
var currentUserEmail;
var _scaffoldContext;

class ChatScreen extends StatefulWidget {
  @override
  ChatScreenState createState() {
    return new ChatScreenState();
  }
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textEditingController =
      new TextEditingController();
  bool _isComposingMessage = false;
  final reference = FirebaseDatabase.instance.reference().child('messages');

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Chatty"),
        elevation: Theme.of(context).platform == TargetPlatrform.android ? 4.0 : 0.0,
        actions: <Widget>[
          new IconButton(
            icon: new Icon(Icons.exit_to_app),
            onPressed: _signOut
          ),
        ],
      ),
      body: new Container(
        child: new Column(
          children: <Widget>[
            new Flexible(
              child: new FirebaseAnimatedList(
                  query: reference,
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  // Comparing timestamps to determine the order
                  sort: (a, b) => b.key.compareTo(a.key),
                  itemBuilder: (_, DataSnapshot messageSnapshot,
                      Animation<double> animation, index) {
                    return new ChatMessageListItem(
                      messageSnapShot: messageSnapshot,
                      animation: animation,
                    ); // ChatMessageListItem
                  }, // Animation
              ), // FirebaseAnimatedList
            ), // Flexible
            new Divider(height: 1.0),
            new Container(
              decoration: new BoxDecoration(color: Theme.of(context).cardColor),
              child: _buildTextComposer(),
            ),
            new Builder(
              builder: (BuildContext context) {
                _scaffoldContext = context;
                return new Container(width: 0.0, height: 0.0);
              },
            ) // Builder
          ], // <Widget>[]
        ), // Column
        decoration: Theme.of(context).platform == TargetPlatform.android
          ? new BoxDecoration(
            border: new Border(
              top: new BorderSide(
                color: Colors.grey[200],
              ) // BorderSide
            ) // Border
        ) : null,
      ), // Container
    ); // Scaffold
  } // Widget

  CupertinoButton getIOSSendButton() {
    return new CupertinoButton(
      icon: new Text("Send"),
      onPressed: _isComposingMessage
          ? () => _textMessageSubmitted(_textEditingController.text)
          : null,
    ); // IconButton
  }

  IconButton getDefaultSendButton() {
    return new IconButton(
      icon: new Text(Icons.send),
      onPressed: _isComposingMessage
          ? () => _textMessageSubmitted(_textEditingController.text)
          : null,
    ); // IconButton
  }

  Widget _buildTextCompose() {
    return new IconTheme(
      data: new IconThemeData(
          color: _isComposingMessage
              ? Theme.of(context).accentColor
              : Theme.of(context).disabledColor
      ), // IconThemeData
      child: new Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: new Row(
          children: <Widget>[
            new Container(
              margin: EdgeInsets.symmetric(4.0),
              child: new IconButton(
                  icon: new Icon(
                    Icons.photo_camera,
                    color: Theme.of(context).accentColor,
                  ), // Icon
                  onPressed: () async {
                    await _ensureLoggedIn();
                    File imageFile = await ImagePicker.pickImage();
                    int timeStamp = new DateTime.now().millisecondsSinceEpoch;
                    StorageReference storageReference = FirebaseStorage.instance.ref()
                        .child("img_" + timeStamp.toString() + ".jpg");
                    StorageUploadTask uploadTask =
                    StorageReference.putFile(imageFile);
                    Uri downloadUrl = (await uploadTask.future).downloadUrl;
                    _sendMessage(
                        messageText: null, imageUrl: downloadUrl.toString()
                    ); // _sendMessage
                  } // onPressed async
              ), // IconButton
            ), // Container
            new Flexible(
              child: new TextField(
                controller: _textEditingController,
                onChanged: (String messageText) {
                  setState(() {
                    _isComposingMessage = messageText.length > 0;
                  });
                },
                onSubmitted: _textMessageSubmitted,
                decoration: new InputDecoration.collapsed(hintText: "Send message"),
              ), // TextField
            ), // Flexible
            new Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.android
                  ? getDefaultSendButton()
                  : getIOSSendButton(),
            ), // Container
          ], // <Widget>
        ), // Row
      ), // Child Container
    ); // IconTheme
  }

  Future<Null> _textMessageSubmitted(String text) async {
    _textEditingController.clear();
    setState(() {
      _isComposingMessage = false;
    });
    await _ensureLoggedIn();
    _sendMessage(messageText: text, imageUrl: null);
  }

  void _sendMessage({String messageText, String imageUrl}) {
    reference.push().set({
      'text': messageText,
      'email': googleSIgnIn.currentUser.email,
      'imageUrl': imageUrl,
      'senderName': googleSIgnIn.currentUser.displayName,
      'senderPhotoUrl': googleSIgnIn.currentUser.photoUrl
    });
    analytics.logEvent(name: 'Send message');
  }

  Future<Null> _ensureLoggedIn() async {
    GoogleSignInAccount signedInUser = googleSIgnIn.currentUser;
    if (signedInUser == null)
      signedInUser = await googleSIgnIn.signInSilently();
    if (signedInUser == null)
      signedInUser = await googleSIgnIn.signIn();
    analytics.logLogin();

    currentUserEmail = googleSIgnIn.currentUser.email;

    if (await auth.currentUser() == null) {
      GoogleSignInAuthentication credentials =
      await googleSIgnIn.currentUser.authentication;
      await auth.signInWithGoogle(
          idToken: credentials.idToken, accessToken: credentials.accessToken
      );
    }
  }

  Future _signOut() async {
    await auth.signOut();
    googleSIgnIn.signOut();
    Scaffold
      .of(_scaffoldContext)
      .showSnackBar(new SnackBar(content: new Text("User logged out")));
  }
}