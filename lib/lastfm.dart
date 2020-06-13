import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:finale/env.dart';
import 'package:finale/types/generic.dart';
import 'package:finale/types/lalbum.dart';
import 'package:finale/types/lartist.dart';
import 'package:finale/types/lcommon.dart';
import 'package:finale/types/ltrack.dart';
import 'package:finale/types/luser.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String _base = 'https://ws.audioscrobbler.com/2.0/';

String _encode(String str) {
  return Uri.encodeComponent(str).replaceAll(r'%20', '+');
}

String _buildURL(String method,
    {Map<String, dynamic> data = const {}, List<String> encode = const []}) {
  final allData = {
    ...data,
    ...{'api_key': apiKey, 'method': method}
  };
  var allDataKeys = allData.keys.toList();
  allDataKeys.sort();

  final hash =
      allDataKeys.map((key) => '$key${allData[key]}').join() + apiSecret;
  final signature = md5.convert(utf8.encode(hash));
  allData['api_sig'] = signature.toString();

  allDataKeys = allData.keys.toList();
  allDataKeys.sort();
  return _base +
      '?format=json&' +
      allDataKeys
          .map((key) =>
              key +
              '=' +
              (encode.indexOf(key.replaceAll(r'\[\d+]', '')) != -1
                      ? _encode(allData[key])
                      : allData[key])
                  .toString())
          .join('&');
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

    final response = await http.get(_buildURL('user.getRecentTracks',
        data: {'user': username, 'limit': limit, 'page': page},
        encode: ['user']));

    if (response.statusCode == 200) {
      final tracks = LRecentTracksResponseRecentTracks.fromJson(
              json.decode(response.body)['recenttracks'])
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

    final response = await http.get(_buildURL('user.getTopArtists', data: {
      'user': username,
      'limit': limit,
      'page': page,
      'period': period
    }, encode: [
      'user',
      'period'
    ]));

    if (response.statusCode == 200) {
      return LTopArtistsResponseTopArtists.fromJson(
              json.decode(response.body)['topartists'])
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

    final response = await http.get(_buildURL('user.getTopAlbums', data: {
      'user': username,
      'limit': limit,
      'page': page,
      'period': period
    }, encode: [
      'user',
      'period'
    ]));

    if (response.statusCode == 200) {
      return LTopAlbumsResponseTopAlbums.fromJson(
              json.decode(response.body)['topalbums'])
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

    final response = await http.get(_buildURL('user.getTopTracks', data: {
      'user': username,
      'limit': limit,
      'page': page,
      'period': period
    }, encode: [
      'user',
      'period'
    ]));

    if (response.statusCode == 200) {
      return LTopTracksResponseTopTracks.fromJson(
              json.decode(response.body)['toptracks'])
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
    final response = await http.get(_buildURL('user.getFriends',
        data: {'user': username, 'limit': limit, 'page': page},
        encode: ['user']));

    final Map<String, dynamic> result = json.decode(response.body);

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
    final response = await http.get(_buildURL('track.search',
        data: {'track': query, 'limit': limit, 'page': page},
        encode: ['track']));

    if (response.statusCode == 200) {
      return LTrackSearchResponse.fromJson(
              json.decode(response.body)['results']['trackmatches'])
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
    final response = await http.get(_buildURL('artist.search',
        data: {'artist': query, 'limit': limit, 'page': page},
        encode: ['artist']));

    if (response.statusCode == 200) {
      return LArtistSearchResponse.fromJson(
              json.decode(response.body)['results']['artistmatches'])
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
    final response = await http.get(_buildURL('album.search',
        data: {'album': query, 'limit': limit, 'page': page},
        encode: ['album']));

    if (response.statusCode == 200) {
      return LAlbumSearchResponse.fromJson(
              json.decode(response.body)['results']['albummatches'])
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
    final response = await http.get(_buildURL('artist.getTopAlbums',
        data: {'artist': artist, 'limit': limit, 'page': page},
        encode: ['artist']));

    if (response.statusCode == 200) {
      return LArtistGetTopAlbumsResponse.fromJson(
              json.decode(response.body)['topalbums'])
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
    final response = await http.get(_buildURL('artist.getTopTracks',
        data: {'artist': artist, 'limit': limit, 'page': page},
        encode: ['artist']));

    if (response.statusCode == 200) {
      return LArtistGetTopTracksResponse.fromJson(
              json.decode(response.body)['toptracks'])
          .tracks;
    } else {
      throw Exception('Could not get artist\'s top tracks.');
    }
  }
}

class Lastfm {
  static Future<LAuthenticationResponseSession> authenticate(
      String token) async {
    final response =
        await http.post(_buildURL('auth.getSession', data: {'token': token}));

    if (response.statusCode == 200) {
      return LAuthenticationResponseSession.fromJson(
          json.decode(response.body)['session']);
    } else {
      throw Exception('Could not authenticate.');
    }
  }

  static Future<LUser> getUser(String username) async {
    final response =
        await http.get(_buildURL('user.getInfo', data: {'user': username}));

    if (response.statusCode == 200) {
      return LUser.fromJson(json.decode(response.body)['user']);
    } else {
      throw Exception('Could not get user.');
    }
  }

  static Future<LTrack> getTrack(BasicTrack track) async {
    final username = (await SharedPreferences.getInstance()).getString('name');

    final response = await http.get(_buildURL('track.getInfo', data: {
      'track': track.name,
      'artist': track.artist,
      'username': username
    }, encode: [
      'track',
      'artist',
      'username'
    ]));

    if (response.statusCode == 200) {
      return LTrack.fromJson(json.decode(response.body)['track']);
    } else {
      throw Exception('Could not get track.');
    }
  }

  static Future<LAlbum> getAlbum(BasicAlbum album) async {
    final username = (await SharedPreferences.getInstance()).getString('name');

    final response = await http.get(_buildURL('album.getInfo', data: {
      'album': album.name,
      'artist': album.artist.name,
      'username': username
    }, encode: [
      'album',
      'artist',
      'username'
    ]));

    if (response.statusCode == 200) {
      return LAlbum.fromJson(json.decode(response.body)['album']);
    } else {
      throw Exception('Could not get album.');
    }
  }

  static Future<LArtist> getArtist(BasicArtist artist) async {
    final username = (await SharedPreferences.getInstance()).getString('name');

    final response = await http.get(_buildURL('artist.getInfo',
        data: {'artist': artist.name, 'username': username},
        encode: ['artist', 'username']));

    if (response.statusCode == 200) {
      return LArtist.fromJson(json.decode(response.body)['artist']);
    } else {
      throw Exception('Could not get artist.');
    }
  }

  static Future<int> getNumArtists(String username) async {
    final response = await http.get(_buildURL('user.getTopArtists', data: {
      'user': username,
      'period': 'overall',
      'limit': '1',
      'page': '1'
    }, encode: [
      'user',
      'period'
    ]));

    if (response.statusCode == 200) {
      return LTopArtistsResponseTopArtists.fromJson(
              json.decode(response.body)['topartists'])
          .attr
          .total;
    } else {
      throw Exception('Could not get num artists.');
    }
  }

  static Future<int> getNumAlbums(String username) async {
    final response = await http.get(_buildURL('user.getTopAlbums', data: {
      'user': username,
      'period': 'overall',
      'limit': '1',
      'page': '1'
    }, encode: [
      'user',
      'period'
    ]));

    if (response.statusCode == 200) {
      return LTopAlbumsResponseTopAlbums.fromJson(
              json.decode(response.body)['topalbums'])
          .attr
          .total;
    } else {
      throw Exception('Could not get num albums.');
    }
  }

  static Future<int> getNumTracks(String username) async {
    final response = await http.get(_buildURL('user.getTopTracks', data: {
      'user': username,
      'period': 'overall',
      'limit': '1',
      'page': '1'
    }, encode: [
      'user',
      'period'
    ]));

    if (response.statusCode == 200) {
      return LTopTracksResponseTopTracks.fromJson(
              json.decode(response.body)['toptracks'])
          .attr
          .total;
    } else {
      throw Exception('Could not get num albums.');
    }
  }

  static Future<List<LTopArtistsResponseArtist>> getGlobalTopArtists(
      int limit) async {
    final response = await http.get(
        _buildURL('chart.getTopArtists', data: {'limit': limit, 'page': 1}));

    if (response.statusCode == 200) {
      return LChartTopArtists.fromJson(json.decode(response.body)['artists'])
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

    final response = await http.post(_buildURL('track.scrobble',
        data: data, encode: ['album', 'artist', 'track']));

    if (response.statusCode == 200) {
      return LScrobbleResponseScrobblesAttr.fromJson(
          json.decode(response.body)['scrobbles']['@attr']);
    } else {
      throw Exception('Could not scrobble.');
    }
  }

  /// Loves or unloves a track. If [love] is true, the track will be loved;
  /// otherwise, it will be unloved.
  static Future<bool> love(FullTrack track, bool love) async {
    final response =
        await http.post(_buildURL(love ? 'track.love' : 'track.unlove', data: {
      'track': track.name,
      'artist': track.artist.name,
      'sk': (await SharedPreferences.getInstance()).getString('key')
    }, encode: [
      'track',
      'artist'
    ]));

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Could not love/unlove track.');
    }
  }
}
