import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:color_logger/color_logger.dart';
import 'package:grpc/grpc.dart';
import 'package:hive/hive.dart';

import 'package:dart_donation_bot/discord.dart' as discord;

import 'generated/marisma.pbgrpc.dart';

ColorLogger console = ColorLogger();

final Map<String, String> _env = Platform.environment;
final donationAddress = _env['DONATION_ADDRESS'] ?? '';

late MarismaClient _marisma;
late Box _hiveBox;

Future<void> connect() async {
  console.log('connecting');
  final useSSL = _env["USE_SSL"] == "true";
  _marisma = MarismaClient(
    ClientChannel(
      _env["MARISMA_SERVER_HOST"]!,
      port: int.parse(_env["MARISMA_SERVER_PORT"]!),
      options: ChannelOptions(
        credentials: useSSL
            ? ChannelCredentials.secure()
            : ChannelCredentials.insecure(),
      ),
    ),
  );

  //open hive
  _hiveBox = await Hive.openBox('storage');

  //subscribe to address
  subscribeToDonationAddress();
}

void subscribeToDonationAddress([bool retry = false]) {
  final addressStatusStream = StreamController<AddressRequest>();

  //listen to marisma stream
  _marisma.addressStatusStream(addressStatusStream.stream).listen(
        (_) async {
          await handleUtxos(
            await _marisma.getAddressUtxoList(
              AddressListRequest()..address = donationAddress,
            ),
          );
        },
        onError: (e) =>
            console.log(e.toString(), status: LogStatus.error), //TODO
        onDone: () async {
          //TODO: handle reconnect
        },
      );

  //add address to stream
  addressStatusStream.sink.add(AddressRequest()..address = donationAddress);
}

Future<void> handleUtxos(AddressUtxoListReply utxoReply) async {
  for (final tx in utxoReply.utxos) {
    final decoded = jsonDecode(tx);
    final hash = decoded["txid"];

    if (_hiveBox.get(hash) == null) {
      console.log("Writing unknown utxo $hash");
      //write to hive
      await _hiveBox.put(hash, tx);

      //request tx details from marisma
      await handleTx(
        await _marisma.getTransaction(
          TxRequest()..txid = hash,
        ),
      );
    }
  }
}

Future<void> handleTx(TxReply txReply) async {
  final tx = jsonDecode(txReply.tx);
  var txId = tx['txid'];
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
      var hiveResult = _hiveBox.get(e["txid"]);

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
              e["scriptPubKey"]["address"].contains(donationAddress)) {
            if (txPosIdentical == true) {
              console.log(
                'found donationAddress in VOUTs of a tx where we know one of the VINs == change',
              );

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
          e["scriptPubKey"]["address"].contains(donationAddress)) {
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
