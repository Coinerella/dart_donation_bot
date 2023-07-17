import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:color_logger/color_logger.dart';
import 'package:grpc/grpc.dart';
import 'package:hive/hive.dart';

import './discord.dart' as discord;
import 'generated/marisma.pbgrpc.dart';

class MarismaConnection {
  //constructor
  MarismaConnection() {
    connect();
  }

  final ColorLogger _console = ColorLogger();

  late Map<String, String> _env;
  late String _donationAddress;
  late Box _hiveBox;
  late MarismaClient _marisma;
  Timer? _pingTimer;

  Future<void> connect() async {
    _console.log('connecting');

    //load env
    _env = Platform.environment;
    _donationAddress = _env['DONATION_ADDRESS'] ?? '';
    final useSSL = _env["USE_SSL"] == "true";

    _marisma = MarismaClient(
      ClientChannel(
        _env["MARISMA_SERVER_HOST"]!,
        port: int.parse(_env["MARISMA_SERVER_PORT"]!),
        options: ChannelOptions(
          credentials: useSSL
              ? ChannelCredentials.secure()
              : ChannelCredentials.insecure(),
          keepAlive: ClientKeepAliveOptions(
            pingInterval: Duration(seconds: 90),
            permitWithoutCalls: true,
          ),
        ),
      ),
    );

    //open hive
    _hiveBox = await Hive.openBox('storage');

    //subscribe to address
    subscribeToDonationAddress();
  }

  Future<void> handleTx(TxReply txReply) async {
    final tx = jsonDecode(txReply.tx);
    var txId = tx['txid'];
    _console.log('txId: $txId');

    bool knownVIN = false;
    bool mintMarkerFound = false;
    bool changeFound = false;
    bool txPosIdentical = false;
    double inValue = 0;
    double outValue = 0;

    tx["vin"].forEach(
      (e) {
        _console.log('tx has vin ${e["txid"]} at ${e["vout"]}');
        var hiveResult = _hiveBox.get('${e["txid"]}${e["vout"]}');

        if (hiveResult != null) {
          _console.log('input is a (former) known utxo');

          final asMap = jsonDecode(hiveResult);
          knownVIN = true;
          inValue += asMap["value"] ?? 0;
          if (asMap["tx_pos"] == e["vout"]) {
            txPosIdentical = true;
          }
        }
      },
    );

    if (knownVIN == true) {
      //check for mint tx marker (first vout is value 0 and nonstandard)
      if (tx["vout"][0]["value"] == 0 &&
          tx["vout"][0]["scriptPubKey"]["type"] == "nonstandard") {
        _console.log('found mint marker');
        mintMarkerFound = true;
      } else {
        //check if its a change tx
        tx["vout"].forEach(
          (e) {
            if (e["scriptPubKey"]["type"] == "scripthash" &&
                e["scriptPubKey"]["address"].contains(_donationAddress)) {
              if (txPosIdentical == true) {
                _console.log(
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
            e["scriptPubKey"]["address"].contains(_donationAddress)) {
          outValue += e["value"];
        }
      },
    );

    if (changeFound == false && mintMarkerFound == false) {
      //discord: we have a donation
      _console.log('donation = $outValue');
      discord.sendDonationMessage(roundDouble(outValue, 6));
    } else if (mintMarkerFound == true) {
      //discord: we have a mint
      double mint = outValue - inValue;
      _console.log('$outValue, $inValue');
      _console.log('mint = $mint');

      discord.sendMintMessage(roundDouble(mint, 6));
    }
  }

  Future<void> handleUtxos(AddressUtxoListReply utxoReply) async {
    for (final tx in utxoReply.utxos) {
      final decoded = jsonDecode(tx);
      final hash = decoded["txid"];
      final txPos = decoded["tx_pos"];

      if (_hiveBox.get('$hash$txPos') == null) {
        _console.log("Writing unknown utxo $hash at $txPos");
        //write to hive
        await _hiveBox.put('$hash$txPos', tx);

        //request tx details from marisma
        await handleTx(
          await _marisma.getTransaction(
            TxRequest()..txid = hash,
          ),
        );
      }
    }
  }

  double roundDouble(double value, int places) {
    double mod = pow(10.0, places).toDouble();
    return ((value * mod).round().toDouble() / mod);
  }

  void subscribeToDonationAddress({bool retry = false}) async {
    _console.log('connecting to stream (retry: $retry)');

    if (retry == true) {
      await Future.delayed(Duration(seconds: 5));
    }

    final addressStatusStream = StreamController<AddressRequest>();
    StreamSubscription<dynamic>?
        subscription; // Declare a subscription variable

    void handleStreamData(AddressStatusStreamReply reply) async {
      if (reply.hasPong() == false) {
        //ignore pong events
        await handleUtxos(
          await _marisma.getAddressUtxoList(
            AddressListRequest()
              ..address = _donationAddress
              ..ascending = true
              ..minimumHeight = -1,
          ),
        );
      }
    }

    void handleStreamError(dynamic e) {
      _console.log(
        e.toString(),
        status: LogStatus.error,
      );
      // Reconnect by canceling the current subscription and creating a new one
      subscription?.cancel();
      subscription = null;
      _pingTimer?.cancel();
      _pingTimer = null;
      subscribeToDonationAddress(retry: true);
    }

    void handleStreamDone() {
      _console.log(
        'stream done',
        status: LogStatus.info,
      );
      // Reconnect by canceling the current subscription and creating a new one
      subscription?.cancel();
      subscription = null;
      _pingTimer?.cancel();
      _pingTimer = null;
      subscribeToDonationAddress(retry: true);
    }

    // Listen to marisma stream
    subscription =
        _marisma.addressStatusStream(addressStatusStream.stream).listen(
              handleStreamData,
              onError: handleStreamError,
              onDone: handleStreamDone,
            );

    _console.log('connected to stream');

    //start ping timer
    _pingTimer = Timer.periodic(
      Duration(minutes: 5),
      (timer) {
        addressStatusStream.sink.add(
          AddressRequest()..ping = 'ping',
        );
      },
    );

    // Add address to stream
    addressStatusStream.sink.add(AddressRequest()..address = _donationAddress);
  }
}
