import 'dart:io';
import 'dart:convert' as convert;

import 'package:todo_server_mysql/todo_server_mysql.dart';

/*
 * Based on http://www.dartlang.org/articles/json-web-service/.
 * A web server that responds to GET and POST requests.
 * Use it at http://localhost:8080.
 */

const String HOST = "127.0.0.1"; // eg: localhost
const int PORT = 8080;

TaskTable taskTable;

_integrateDataFromClient(List<Map> jsonList) {
  var clientTasks = new Tasks.fromJson(jsonList);
  var serverTasks = taskTable.tasks;
  var serverTaskList = serverTasks.toList();
  for (var serverTask in serverTaskList) {
    if (!clientTasks.contains(serverTask.title)) {
      serverTasks.remove(serverTask);
    }
  }
  for (var clientTask in clientTasks) {
    if (serverTasks.contains(clientTask.title)) {
      var serverTask = serverTasks.find(clientTask.title);
      if (serverTask.updated.millisecondsSinceEpoch <
          clientTask.updated.millisecondsSinceEpoch) {
        serverTask.completed = clientTask.completed;
        serverTask.updated = clientTask.updated;
      }
    } else {
      serverTasks.add(clientTask);
    }
  }
}

start() {
  HttpServer.bind(HOST, PORT)
    .then((server) {
      server.listen((HttpRequest request) {
        switch (request.method) {
          case "GET":
            handleGet(request);
            break;
          case 'POST':
            handlePost(request);
            break;
          case 'OPTIONS':
            handleOptions(request);
            break;
          default: defaultHandler(request);
        }
      });
    })
    .catchError(print)
    .whenComplete(() => print('Server at http://$HOST:$PORT'));
}

void handleGet(HttpRequest request) {
  HttpResponse res = request.response;
  print('${request.method}: ${request.uri.path}');

  addCorsHeaders(res);
  res.headers.contentType =
      new ContentType("application", "json", charset: 'utf-8');
  List<Map> jsonList = taskTable.tasks.toJson();
  String jsonString = convert.JSON.encode(jsonList);
  print('JSON list in GET: ${jsonList}');
  res.write(jsonString);
  res.close();
}

void handlePost(HttpRequest request) {
  print('${request.method}: ${request.uri.path}');
  request.listen((List<int> buffer) {
    var jsonString = new String.fromCharCodes(buffer);
    List<Map> jsonList = convert.JSON.decode(jsonString);
    print('JSON list in POST: ${jsonList}');
    _integrateDataFromClient(jsonList);
  },
  onError: print);
}

/**
 * Add Cross-site headers to enable accessing this server from pages
 * not served by this server
 *
 * See: http://www.html5rocks.com/en/tutorials/cors/
 * and http://enable-cors.org/server.html
 */
void addCorsHeaders(HttpResponse response) {
  response.headers.add('Access-Control-Allow-Origin', '*, ');
  response.headers.add('Access-Control-Allow-Methods', 'POST, OPTIONS');
  response.headers.add('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
}

void handleOptions(HttpRequest request) {
  HttpResponse res = request.response;
  addCorsHeaders(res);
  print('${request.method}: ${request.uri.path}');
  res.statusCode = HttpStatus.NO_CONTENT;
  res.close();
}

void defaultHandler(HttpRequest request) {
  HttpResponse res = request.response;
  addCorsHeaders(res);
  print('${request.method}: ${request.uri.path}');
  res.statusCode = HttpStatus.NOT_FOUND;
  res.write('Not found: ${request.method}, ${request.uri.path}');
  res.close();
}

void main() {
  var todoDb = new TodoDb();
  todoDb.open().then((_) {
    taskTable = todoDb.taskTable;
    start(); // start webserver
  });
}


