import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_app/models/note_model.dart';
import 'package:notes_app/repositories/note_repo.dart';
import 'package:notes_app/repositories/user_repo.dart';
import 'package:uuid/uuid.dart';

final noteDetailViewModel = ChangeNotifierProvider.autoDispose(
  (ref) => NoteDetailViewModel(ref.read(noteRepoProvider), ref.read(userRepoProvider))
);

const uuid = Uuid();

class NoteDetailViewModel extends ChangeNotifier {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isReadOnly = true;
  late final NoteRepo _noteRepo;
  late final UserRepo _userRepo;
  late final StreamSubscription<List<ConnectivityResult>> internetSubscription;
  Note? note;
  bool hasInternetConnection = true;
  bool noteChange = false;
  bool canSave = false;

  NoteDetailViewModel(NoteRepo noteRepo, UserRepo userRepo) {
    _noteRepo = noteRepo;
    _userRepo = userRepo;
  }

  Future<void> get(String id) async {
    note = await _noteRepo.get(id);
    titleController.text = note!.title;
    contentController.text = note!.content;
    notifyListeners();
  }

  Future<void> add(String title, String content) async {
    note = Note(
      id: uuid.v4(),
      title: title,
      content: content,
      updatedAt: DateTime.now().toString(),
      idUser: _userRepo.user?.id,
      isTrash: false
    );
    await _noteRepo.addLocal(note!);
    if (_userRepo.user != null && hasInternetConnection) {
      await _noteRepo.addRemote(note!);
    }
    log('Add');
    noteChange = true;
    notifyListeners();
  }

  Future<void> update(String id, String title, String content) async {
    note = Note(
      id: id,
      title: title,
      content: content,
      updatedAt: DateTime.now().toString(),
      idUser: _userRepo.user?.id,
      isTrash: false
    );
    await _noteRepo.updateLocal(note!);
    if(_userRepo.user != null && hasInternetConnection) {
      await _noteRepo.updateRemote(note!);
    }
    noteChange = true;
    notifyListeners();
  }

  Future<void> archive(String id) async {
    try {
      await _noteRepo.archiveLocal(id);
      if (_userRepo.user != null && hasInternetConnection) {
        await _noteRepo.archiveRemote(id);
      }
      note = null;
      noteChange = true;
      notifyListeners();
    } catch(err) {
      log(err.toString());
    } 
  }

  void toggleEdit() {
    isReadOnly = !isReadOnly;
    notifyListeners();
  }

  void clear() {
    canSave = false;
    titleController.clear();
    contentController.clear();
  }
  
  void resetChangeStatus() {
    noteChange = false;
  }

  void compare() {
    if((titleController.text.isNotEmpty && contentController.text.isNotEmpty) &&
      (titleController.text != note?.title || contentController.text != note?.content)) {
      canSave = true;
      notifyListeners();
    } else {
      canSave = false;
      notifyListeners();
    }
  }
}