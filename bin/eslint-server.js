var PORT = 9696;
var net = require('net');
var stripAnsi = require('strip-ansi');
var espree = require('espree');
var eslint = require('eslint');
var SourceCode = eslint.SourceCode;
var linter = eslint.linter;
var cli = new eslint.CLIEngine();
var tmp = require('tmp');
var fs = require('fs');

var server = net.createServer(function (socket) {
  'use strict';

  var file, code = "";
  socket.setEncoding('utf8');

  socket.on('data', (json) => {

    var msg = JSON.parse(json);
    var msgId = msg[0];
    var msgContent = JSON.parse(msg[1]);
    var file = msgContent.file;

    var code = msgContent.code;
    var result = lint(code, file);

    socket.write(JSON.stringify([msgId, result]));
  });

  socket.on('end', (json) => {

    //console.log('got end');

  });

});

function parse(code) {
  return espree.parse(code, {
    range: true,
    loc: true,
    comment: true,
    attachComment: true,
    tokens: true,
    ecmaVersion: 8,
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true,
      modules: true,
      globalReturn: true,
      impliedStrict: true,
      experimentalObjectRestSpread: true
    }
  });
}

function lint(code, file) {

  try {
    var config = cli.getConfigForFile(file);
  } catch(e) {
    console.error(e);
    console.log('unable to obtain eslint config for file:', file);
    return {
      error: e.message
    };
  }

  //format the globals config as array, or CLIEngine will complain
  config.globals = Object.keys(config.globals);

  //set fix to true
  config.fix = true;
  //config.color = false;

  var engine = new eslint.CLIEngine(config)

  var report = engine.executeOnText(code, file);
  var result = report.results[0];
  var fixed = result.output;

  var errorfile = "";
  if (result.messages.length) {
    var formatter = engine.getFormatter("compact");

    var formattedMessages = formatter(report.results);
    var errorfile = tmp.fileSync().name;
    fs.writeFileSync(errorfile, stripAnsi(formattedMessages));
  }

  if (fixed) {
    return {
      fixed: fixed,
      messages: result.messages,
      errorfile: errorfile
    };
  } else {
    return {
      messages: result.messages,
      errorfile: errorfile
    }
  }
}

server.on('error', (err) => {
  throw err;
});

server.listen(PORT, () => {
  console.log('server bound to port:', PORT);
});
