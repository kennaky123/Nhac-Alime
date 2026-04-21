import 'dart:convert';
import 'package:flutter/services.dart';

import '../model/song.dart';
import 'package:http/http.dart' as http;

abstract interface class DataSource {
  Future<List<Song>?> loadData();
}

class RemoteDataSource implements DataSource {
  @override
  Future<List<Song>?> loadData() async {
    final url = 'https://thantrieu.com/resources/braniumapis/songs.json';
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    //await chổ này nghĩa là chờ hàm http.get() chạy xong nó mới chạy tiếp
    // hàm http.get nó trả về dữ liệu future nên mới để await ở trong đó
    // dữ liệu future nếu ko để await thì nó sẽ trả về cho mình dữ liệu thô mà nó phải gửi lên sever
    // hàm này nó phải gửi lên sever rồi nó mới trả về cho mình dữ liệu cần dùng
    // dữ liệu thô ở đây là nó gửi request 1 file json về dữ liệu bài hát của thằng thân triệu nó để trên web của nó, mình phải request dữ liệu đó về máy rồi xử lý biến nó thành 1 dữ liệu List các bài hát

    if (response.statusCode == 200) {
      final bodyContent = utf8.decode(response.bodyBytes);
      var songWrapper = jsonDecode(bodyContent) as Map;
      var songList = songWrapper['songs'] as List;
      List<Song> songs = songList.map((song) => Song.fromJson(song)).toList();
      return songs;
    } else {
      return null;
    }
  }
}

class LocalDataSource implements DataSource {
  @override
  Future<List<Song>?> loadData() async {
    final String response = await rootBundle.loadString('assets/songs.json');
    final jsonBody = jsonDecode(response) as Map;
    final songList = jsonBody['songs'] as List;
    List<Song> songs = songList.map((song) => Song.fromJson(song)).toList();
    return songs;
  }
}