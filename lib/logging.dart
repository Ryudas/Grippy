import 'dart:io';
import 'package:path_provider/path_provider.dart';  // library for indirect filesystem access



class DataStorage{
  // Gets path of Documents directory for app
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/LOG.txt');
  }

  Future<File> write_data(String data) async {
    final file = await _localFile;

    // Write the file
    return file.writeAsString('$data', mode:FileMode.append); // don't truncate file
  }
}