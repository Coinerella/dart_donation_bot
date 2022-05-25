import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:color_logger/color_logger.dart';
import 'package:hive/hive.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dart_donation_bot/discord.dart' as discord;

WebSocketChannel? connection;
Timer? pingTimer;
Timer? reconnectTimer;
late Box hiveBox;

const donationScriptHash =
    "f83cf3b3ccddc19323fccef53417926f3303070abf4c6492164d2b0f513ad4e6";
const donationAddress = "p92W3t7YkKfQEPDb7cG9jQ6iMh7cpKLvwK";
const serverUrl = "wss://allingas.peercoinexplorer.net:50004";

var console = ColorLogger();

Future<void> connect() async {
  console.log('connecting');
  if (connection == null) {
    try {
      connection = WebSocketChannel.connect(
        Uri.parse(serverUrl),
      );
    } catch (e) {
      console.log(e.toString(), status: LogStatus.error);
    }
    connection!.stream.listen(
      (elem) {
        replyHandler(elem);
      },
      onError: (e) {
        console.log(e.toString(), status: LogStatus.error);
      },
      onDone: () {
        console.log('connection done');
        cleanUpOnDone();
      },
    );

    sendMessage(
      'blockchain.scripthash.subscribe',
      donationAddress,
      [donationScriptHash],
    );

    handleScriptHashSubscribeNotification(donationScriptHash);

    startPingTimer();

    reconnectTimer = null;
    hiveBox = await Hive.openBox('storage');

    // test to find change
    // hiveBox.put(
    //     'b91e3a5a6a2d128eb36c1d2187238909d759e3408f1422c6d2c48f2e65012332',
    //     {"tx_pos": 1});
    // hiveBox.delete(
    //     '70cdae7a0d4c93f5eb6b7ed151a90226445d6a1db67d46120423541627be2a3e');

    // test to find donation
    // hiveBox.delete(
    //     '44ab092b4e1fe2c6257885292920339640b6256dd30d42efef48ee0941fd37d4');

    // test to find mint
    //   hiveBox.put(
    //       '3137b4470d423a010c4ce1589045b03c070f3ae89de479a85a2539ef9a9b8495', {
    //     "tx_hash":
    //         "3137b4470d423a010c4ce1589045b03c070f3ae89de479a85a2539ef9a9b8495",
    //     "height": 495282,
    //     "value": 4999980000
    //   });
    //   hiveBox.delete(
    //       '68ead34c48b7d06906cb1f4a68457f412e6778a6c3b6bc3813753b9f8362cebe');

    //another test to find mint
    // hiveBox.delete(
    //     'dddb2cd63830c6ab6f237313fb3ddde1614fe18bebfd1a1cedda1b3dbdab7edd');
  }
}

void replyHandler(reply) {
  var decoded = json.decode(reply);
  var id = decoded['id'];
  var idString = id.toString();
  var result = decoded['result'];
  // console.log('replyHandler result $result');

  if (decoded['id'] != null) {
    console.log(
      'ElectrumConnection replyHandler id: $idString',
    );
    if (idString.startsWith('utxo_')) {
      handleUtxo(id, result);
    } else if (idString.startsWith('tx_')) {
      handleTx(id, result);
    }
  } else if (decoded['params'] != null) {
    switch (decoded['method']) {
      case 'blockchain.scripthash.subscribe':
        handleScriptHashSubscribeNotification(decoded['params'][0]);
        break;
    }
  }
}

void sendMessage(String method, String? id, [List? params]) {
  if (connection != null) {
    connection!.sink.add(
      json.encode(
        {'id': id, 'method': method, if (params != null) 'params': params},
      ),
    );
  }
}

void startPingTimer() {
  pingTimer ??= Timer.periodic(
    Duration(minutes: 7),
    (_) {
      sendMessage('server.ping', 'ping');
    },
  );
}

void cleanUpOnDone() {
  pingTimer?.cancel();
  pingTimer = null;
  connection = null;

  reconnectTimer = Timer(Duration(seconds: 5), () => connect());
}

void handleScriptHashSubscribeNotification(String? hashId) async {
  //got update notification for hash => get utxos
  //fire listunspent to get utxo
  sendMessage(
    'blockchain.scripthash.listunspent',
    'utxo_$donationAddress',
    [hashId],
  );
}

void handleUtxo(String id, List utxos) async {
  for (final tx in utxos) {
    final hash = tx["tx_hash"];
    if (hiveBox.get(hash) == null) {
      console.log("Writing unknown utxo $hash");
      //write to hive
      hiveBox.put(hash, tx);
      //request tx details
      sendMessage(
        'blockchain.transaction.get',
        'tx_$hash',
        [hash, true],
      );
    }
  }
}

void handleTx(String id, Map tx) async {
  var txId = id.replaceFirst('tx_', '');
  console.log('txId: $txId');

  bool knownVIN = false;
  bool mintMarkerFound = false;
  bool changeFound = false;
  bool txPosIdentical = false;
  double inValue = 0;
  double outValue = 0;

  tx["vin"].forEach(
    (e) {
      console.log('tx has vin ${e["txid"]}');
      var hiveResult = hiveBox.get(e["txid"]);

      if (hiveResult != null) {
        console.log('input is a (former) known utxo');
        knownVIN = true;
        inValue += hiveResult["value"] ?? 0;
        if (hiveResult["tx_pos"] == e["vout"]) {
          txPosIdentical = true;
        }
      }
    },
  );

  if (knownVIN == true) {
    //check for mint tx marker (first vout is value 0 and nonstandard)
    if (tx["vout"][0]["value"] == 0 &&
        tx["vout"][0]["scriptPubKey"]["type"] == "nonstandard") {
      console.log('found mint marker');
      mintMarkerFound = true;
    } else {
      //check if its a change tx
      tx["vout"].forEach(
        (e) {
          if (e["scriptPubKey"]["type"] == "scripthash" &&
              e["scriptPubKey"]["addresses"].contains(donationAddress)) {
            if (txPosIdentical == true) {
              console.log(
                  'found donationAddress in VOUTs of a tx where we know one of the VINs == change');

              changeFound = true;
            }
          }
        },
      );
    }
  }

  //count vout value
  tx["vout"].forEach(
    (e) {
      if (e["scriptPubKey"]["type"] == "scripthash" &&
          e["scriptPubKey"]["addresses"].contains(donationAddress)) {
        outValue += e["value"];
      }
    },
  );

  if (changeFound == false && mintMarkerFound == false) {
    //discord: we have a donation
    console.log('donation = $outValue');
    discord.sendDonationMessage(roundDouble(outValue, 6));
  } else if (mintMarkerFound == true) {
    //discord: we have a mint
    double mint = outValue - (inValue / 1000000);
    console.log('$outValue, $inValue');
    console.log('mint = $mint');

    discord.sendMintMessage(roundDouble(mint, 6));
  }
}

double roundDouble(double value, int places) {
  double mod = pow(10.0, places).toDouble();
  return ((value * mod).round().toDouble() / mod);
}
