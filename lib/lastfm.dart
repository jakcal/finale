import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:finale/env.dart';
import 'package:finale/types/generic.dart';
import 'package:finale/types/lalbum.dart';
import 'package:finale/types/lartist.dart';
import 'package:finale/types/lcommon.dart';
import 'package:finale/types/ltrack.dart';
import 'package:finale/types/luser.dart';
import 'package:http/http.dart';
import 'package:http_throttle/http_throttle.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _client = ThrottleClient(10);

Uri _buildUri(String method, Map<String, dynamic> data) {
  final allData = {
    ...data.map((key, value) => MapEntry(key, value.toString())),
    'api_key': apiKey,
    'method': method,
  };

  final hash = (allData.keys.toList()..sort())
          .map((key) => '$key${allData[key]}')
          .join() +
      apiSecret;
  final signature = md5.convert(utf8.encode(hash));
  allData['api_sig'] = signature.toString();
  allData['format'] = 'json';

  return Uri(
      scheme: 'https',
      host: 'ws.audioscrobbler.com',
      path: '2.0',
      queryParameters: allData);
}

abstract class PagedLastfmRequest<T> {
  Future<List<T>> doRequest(int limit, int page, {String period});
}

class GetRecentTracksRequest
    extends PagedLastfmRequest<LRecentTracksResponseTrack> {
  String username;

  GetRecentTracksRequest(this.username);

  @override
  doRequest(int limit, int page, {String period}) async {
    if (username == null) {
      username = (await SharedPreferences.getInstance()).getString('name');
    }

    final response = await _client.get(_buildUri('user.getRecentTracks',
        {'user': username, 'limit': limit, 'page': page}));

    if (response.statusCode == 200) {
      final tracks = LRecentTracksResponseRecentTracks.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['recenttracks'])
          .tracks;

      // For some reason, this endpoint always returns the currently-playing
      // song regardless of which page you request.
      if (page != 1 && tracks.isNotEmpty && tracks.first.date == null) {
        tracks.removeAt(0);
      }

      return tracks;
    } else {
      throw Exception('Could not get recent tracks.');
    }
  }
}

class GetTopArtistsRequest
    extends PagedLastfmRequest<LTopArtistsResponseArtist> {
  String username;

  GetTopArtistsRequest(this.username);

  @override
  doRequest(int limit, int page, {String period}) async {
    if (username == null) {
      username = (await SharedPreferences.getInstance()).getString('name');
    }

    final response = await _client.get(_buildUri('user.getTopArtists',
        {'user': username, 'limit': limit, 'page': page, 'period': period}));

    if (response.statusCode == 200) {
      return LTopArtistsResponseTopArtists.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['topartists'])
          .artists;
    } else {
      throw Exception('Could not get top artists.');
    }
  }
}

class GetTopAlbumsRequest extends PagedLastfmRequest<LTopAlbumsResponseAlbum> {
  String username;

  GetTopAlbumsRequest(this.username);

  @override
  doRequest(int limit, int page, {String period}) async {
    if (username == null) {
      username = (await SharedPreferences.getInstance()).getString('name');
    }

    final response = await _client.get(_buildUri('user.getTopAlbums',
        {'user': username, 'limit': limit, 'page': page, 'period': period}));

    if (response.statusCode == 200) {
      return LTopAlbumsResponseTopAlbums.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['topalbums'])
          .albums;
    } else {
      throw Exception('Could not get top albums.');
    }
  }
}

class GetTopTracksRequest extends PagedLastfmRequest<LTopTracksResponseTrack> {
  String username;

  GetTopTracksRequest(this.username);

  @override
  doRequest(int limit, int page, {String period}) async {
    if (username == null) {
      username = (await SharedPreferences.getInstance()).getString('name');
    }

    final response = await _client.get(_buildUri('user.getTopTracks',
        {'user': username, 'limit': limit, 'page': page, 'period': period}));

    if (response.statusCode == 200) {
      return LTopTracksResponseTopTracks.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['toptracks'])
          .tracks;
    } else {
      throw Exception('Could not get top tracks.');
    }
  }
}

class GetFriendsRequest extends PagedLastfmRequest<LUser> {
  String username;

  GetFriendsRequest(this.username);

  @override
  doRequest(int limit, int page, {String period}) async {
    final response = await _client.get(_buildUri(
        'user.getFriends', {'user': username, 'limit': limit, 'page': page}));

    final Map<String, dynamic> result =
        json.decode(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return LUserFriendsResponse.fromJson(result['friends']).friends;
    } else if (result['error'] == 6) {
      // "No such page" error
      return [];
    } else {
      throw Exception('Could not get friends.');
    }
  }
}

class SearchTracksRequest extends PagedLastfmRequest<LTrackMatch> {
  String query;

  SearchTracksRequest(this.query);

  @override
  Future<List<LTrackMatch>> doRequest(int limit, int page,
      {String period}) async {
    final response = await _client.get(_buildUri(
        'track.search', {'track': query, 'limit': limit, 'page': page}));

    if (response.statusCode == 200) {
      return LTrackSearchResponse.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['results']
                  ['trackmatches'])
          .tracks;
    } else {
      throw Exception('Could not search for tracks.');
    }
  }
}

class SearchArtistsRequest extends PagedLastfmRequest<LArtistMatch> {
  String query;

  SearchArtistsRequest(this.query);

  @override
  Future<List<LArtistMatch>> doRequest(int limit, int page,
      {String period}) async {
    final response = await _client.get(_buildUri(
        'artist.search', {'artist': query, 'limit': limit, 'page': page}));

    if (response.statusCode == 200) {
      return LArtistSearchResponse.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['results']
                  ['artistmatches'])
          .artists;
    } else {
      throw Exception('Could not search for artists.');
    }
  }
}

class SearchAlbumsRequest extends PagedLastfmRequest<LAlbumMatch> {
  String query;

  SearchAlbumsRequest(this.query);

  @override
  Future<List<LAlbumMatch>> doRequest(int limit, int page,
      {String period}) async {
    final response = await _client.get(_buildUri(
        'album.search', {'album': query, 'limit': limit, 'page': page}));

    if (response.statusCode == 200) {
      return LAlbumSearchResponse.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['results']
                  ['albummatches'])
          .albums;
    } else {
      throw Exception('Could not search for albums.');
    }
  }
}

class ArtistGetTopAlbumsRequest extends PagedLastfmRequest<LArtistTopAlbum> {
  String artist;

  ArtistGetTopAlbumsRequest(this.artist);

  @override
  Future<List<LArtistTopAlbum>> doRequest(int limit, int page,
      {String period}) async {
    final response = await _client.get(_buildUri('artist.getTopAlbums',
        {'artist': artist, 'limit': limit, 'page': page}));

    if (response.statusCode == 200) {
      return LArtistGetTopAlbumsResponse.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['topalbums'])
          .albums;
    } else {
      throw Exception('Could not get artist\'s top albums.');
    }
  }
}

class ArtistGetTopTracksRequest extends PagedLastfmRequest<LArtistTopTrack> {
  String artist;

  ArtistGetTopTracksRequest(this.artist);

  @override
  Future<List<LArtistTopTrack>> doRequest(int limit, int page,
      {String period}) async {
    final response = await _client.get(_buildUri('artist.getTopTracks',
        {'artist': artist, 'limit': limit, 'page': page}));

    if (response.statusCode == 200) {
      return LArtistGetTopTracksResponse.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['toptracks'])
          .tracks;
    } else {
      throw Exception('Could not get artist\'s top tracks.');
    }
  }
}

class Lastfm {
  static Future<Response> get(String url) => _client.get(url);

  static Future<LAuthenticationResponseSession> authenticate(
      String token) async {
    final response =
        await _client.post(_buildUri('auth.getSession', {'token': token}));

    if (response.statusCode == 200) {
      return LAuthenticationResponseSession.fromJson(
          json.decode(utf8.decode(response.bodyBytes))['session']);
    } else {
      throw Exception('Could not authenticate.');
    }
  }

  static Future<LUser> getUser(String username) async {
    final response =
        await _client.get(_buildUri('user.getInfo', {'user': username}));

    if (response.statusCode == 200) {
      return LUser.fromJson(
          json.decode(utf8.decode(response.bodyBytes))['user']);
    } else {
      print(response.body);
      throw Exception('Could not get user.');
    }
  }

  static Future<LTrack> getTrack(BasicTrack track) async {
    final username = (await SharedPreferences.getInstance()).getString('name');

    final response = await _client.get(_buildUri('track.getInfo',
        {'track': track.name, 'artist': track.artist, 'username': username}));

    if (response.statusCode == 200) {
      return LTrack.fromJson(
          json.decode(utf8.decode(response.bodyBytes))['track']);
    } else {
      throw Exception('Could not get track.');
    }
  }

  static Future<LAlbum> getAlbum(BasicAlbum album) async {
    final username = (await SharedPreferences.getInstance()).getString('name');

    final response = await _client.get(_buildUri('album.getInfo', {
      'album': album.name,
      'artist': album.artist.name,
      'username': username
    }));

    if (response.statusCode == 200) {
      return LAlbum.fromJson(
          json.decode(utf8.decode(response.bodyBytes))['album']);
    } else {
      throw Exception('Could not get album.');
    }
  }

  static Future<LArtist> getArtist(BasicArtist artist) async {
    final username = (await SharedPreferences.getInstance()).getString('name');

    final response = await _client.get(_buildUri(
        'artist.getInfo', {'artist': artist.name, 'username': username}));

    if (response.statusCode == 200) {
      return LArtist.fromJson(
          json.decode(utf8.decode(response.bodyBytes))['artist']);
    } else {
      throw Exception('Could not get artist.');
    }
  }

  static Future<int> getNumArtists(String username) async {
    final response = await _client.get(_buildUri('user.getTopArtists',
        {'user': username, 'period': 'overall', 'limit': '1', 'page': '1'}));

    if (response.statusCode == 200) {
      return LTopArtistsResponseTopArtists.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['topartists'])
          .attr
          .total;
    } else {
      throw Exception('Could not get num artists.');
    }
  }

  static Future<int> getNumAlbums(String username) async {
    final response = await _client.get(_buildUri('user.getTopAlbums',
        {'user': username, 'period': 'overall', 'limit': '1', 'page': '1'}));

    if (response.statusCode == 200) {
      return LTopAlbumsResponseTopAlbums.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['topalbums'])
          .attr
          .total;
    } else {
      throw Exception('Could not get num albums.');
    }
  }

  static Future<int> getNumTracks(String username) async {
    final response = await _client.get(_buildUri('user.getTopTracks',
        {'user': username, 'period': 'overall', 'limit': '1', 'page': '1'}));

    if (response.statusCode == 200) {
      return LTopTracksResponseTopTracks.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['toptracks'])
          .attr
          .total;
    } else {
      throw Exception('Could not get num albums.');
    }
  }

  static Future<List<LTopArtistsResponseArtist>> getGlobalTopArtists(
      int limit) async {
    final response = await _client
        .get(_buildUri('chart.getTopArtists', {'limit': limit, 'page': 1}));

    if (response.statusCode == 200) {
      return LChartTopArtists.fromJson(
              json.decode(utf8.decode(response.bodyBytes))['artists'])
          .artists;
    } else {
      throw Exception('Could not get global top artists.');
    }
  }

  static Future<LScrobbleResponseScrobblesAttr> scrobble(
      List<BasicTrack> tracks, List<DateTime> timestamps) async {
    final Map<String, dynamic> data = {};
    data['sk'] = (await SharedPreferences.getInstance()).getString('key');

    tracks.asMap().forEach((i, track) {
      data['album[$i]'] = track.album;
      data['artist[$i]'] = track.artist;
      data['track[$i]'] = track.name;
      data['timestamp[$i]'] = timestamps[i].millisecondsSinceEpoch ~/ 1000;
    });

    final response = await _client.post(_buildUri('track.scrobble', data));

    if (response.statusCode == 200) {
      return LScrobbleResponseScrobblesAttr.fromJson(
          json.decode(utf8.decode(response.bodyBytes))['scrobbles']['@attr']);
    } else {
      throw Exception('Could not scrobble.');
    }
  }

  /// Loves or unloves a track. If [love] is true, the track will be loved;
  /// otherwise, it will be unloved.
  static Future<bool> love(FullTrack track, bool love) async {
    final response =
        await _client.post(_buildUri(love ? 'track.love' : 'track.unlove', {
      'track': track.name,
      'artist': track.artist.name,
      'sk': (await SharedPreferences.getInstance()).getString('key')
    }));

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Could not love/unlove track.');
    }
  }
}
